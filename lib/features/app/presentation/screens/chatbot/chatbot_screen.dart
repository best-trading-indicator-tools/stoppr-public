import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/config/env_config.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart' as record;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/core/streak/achievements_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/features/onboarding/data/repositories/questionnaire_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stoppr/core/api_rate_limit/api_rate_limit_service.dart'; // Added import
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/usage/feature_quota_service.dart'; // Add quota service
import 'package:superwallkit_flutter/superwallkit_flutter.dart'; // Add Superwall import
import 'package:stoppr/core/utils/text_sanitizer.dart';

// Helper class to keep prompt generation separate and easily accessible
class MelindaPromptHelper {
  // Static method for generating the system prompt
  static String getSystemPrompt({
    required String userName,
    required int streakDays,
    required DateTime? streakStartDate,
    required DateTime? goalDate,
    required String reasonToQuit,
    required bool isTempted,
    required dynamic highestAchievement,
    required dynamic nextAchievement,
    required bool challengeStarted,
    required int challengeCurrentDay,
    required double challengePercentage,
    bool isVoiceResponse = false,
    // New parameters for questionnaire data
    Map<int, String>? questionnaireAnswers,
    List<String>? symptoms,
    List<String>? goals,
    // Consumption tracking data
    String? consumptionLevel,
    int? sugaryTreatsPerWeek,
    String? treatSize,
    double? caloriesPerWeek,
    double? caloriesPerQuarter,
    double? caloriesPerYear,
    required String userLanguageCode, // Added language code parameter
  }) {
    // Helper to get a display name for the language code
    String getLanguageDisplayName(String code) {
      switch (code) {
        case 'en':
          return 'English';
        case 'es':
          return 'Spanish';
        // Add other supported languages here
        default:
          return code; // Fallback to code if not mapped
      }
    }

    final languageInstruction = "LANGUAGE PREFERENCE: Your primary language for responding should be ${getLanguageDisplayName(userLanguageCode)} (${userLanguageCode}). However, if the user's current message is clearly in a different language (e.g., they type or speak in Spanish while your primary language is English), YOU MUST ADAPT and respond in the language of their current input for that specific turn. If the user then reverts to ${getLanguageDisplayName(userLanguageCode)}, you should also revert to responding in ${getLanguageDisplayName(userLanguageCode)}.";

    // Process questionnaire answers into a readable format if available
    String questionnaireSection = '';
    if (questionnaireAnswers != null && questionnaireAnswers.isNotEmpty) {
      questionnaireSection = '''
      USER'S QUESTIONNAIRE RESPONSES:
      ${questionnaireAnswers.containsKey(1) ? "- Sugar consumption frequency: ${questionnaireAnswers[1]}" : ""}
      ${questionnaireAnswers.containsKey(2) ? "- Time of day when cravings hit: ${questionnaireAnswers[2]}" : ""}
      ${questionnaireAnswers.containsKey(3) ? "- Feelings after consuming sugar: ${questionnaireAnswers[3]}" : ""}
      ${questionnaireAnswers.containsKey(4) ? "- Primary craving triggers: ${questionnaireAnswers[4]}" : ""}
      ${questionnaireAnswers.containsKey(6) ? "- Self-assessment of consumption: ${questionnaireAnswers[6]}" : ""}
      ${questionnaireAnswers.containsKey(7) ? "- Previous reduction attempts: ${questionnaireAnswers[7]}" : ""}
      ${questionnaireAnswers.containsKey(8) ? "- Motivation for reducing sugar: ${questionnaireAnswers[8]}" : ""}
      ${questionnaireAnswers.containsKey(9) ? "- Confidence level: ${questionnaireAnswers[9]}" : ""}
      ${questionnaireAnswers.containsKey(10) ? "- Biggest anticipated challenge: ${questionnaireAnswers[10]}" : ""}
      ${questionnaireAnswers.containsKey(11) ? "- Priority level: ${questionnaireAnswers[11]}" : ""}
      ${questionnaireAnswers.containsKey(12) ? "- Preferred support type: ${questionnaireAnswers[12]}" : ""}
      ${questionnaireAnswers.containsKey(13) ? "- Gender: ${questionnaireAnswers[13]}" : ""}
      ''';
    }

    // Process symptoms into a readable format if available
    String symptomsSection = '';
    if (symptoms != null && symptoms.isNotEmpty) {
      symptomsSection = '''
      USER'S REPORTED SYMPTOMS:
      ${symptoms.map((s) => "- $s").join("\n")}
      ''';
    }

    // Process goals into a readable format if available
    String goalsSection = '';
    if (goals != null && goals.isNotEmpty) {
      goalsSection = '''
      USER'S GOALS:
      ${goals.map((g) => "- $g").join("\n")}
      ''';
    }

    // Process consumption tracking data if available
    String consumptionSection = '';
    if (consumptionLevel != null || sugaryTreatsPerWeek != null) {
      consumptionSection = '''
      USER'S CONSUMPTION TRACKING:
      ${consumptionLevel != null ? "- Consumption level: $consumptionLevel" : ""}
      ${sugaryTreatsPerWeek != null ? "- Sugary treats per week: $sugaryTreatsPerWeek" : ""}
      ${treatSize != null ? "- Typical treat size: $treatSize" : ""}
      ${caloriesPerWeek != null ? "- Empty calories per week: ${caloriesPerWeek.toInt()} calories" : ""}
      ${caloriesPerQuarter != null ? "- Empty calories per quarter: ${caloriesPerQuarter.toInt()} calories" : ""}
      ${caloriesPerYear != null ? "- Empty calories per year: ${caloriesPerYear.toInt()} calories" : ""}
      ''';
    }

    return '''
      You are Melinda, an empathetic AI therapeutic assistant focused on helping users overcome sugar addiction through a Cognitive Behavioral Therapy (CBT) approach.
      
      $languageInstruction

      USER INFORMATION:
      ${userName.isNotEmpty ? "The user's name is $userName. Address them by name occasionally to create rapport and personalize the conversation." : "Address the user warmly but without using a name."}
      
      USER'S APP DATA:
      - Current Streak: ${streakDays} days${streakStartDate != null ? " (started on ${streakStartDate.toString().split(' ')[0]})" : ""}
      - Goal Date: ${goalDate != null ? goalDate.toString().split(' ')[0] : "Not set"} (90 days from streak start)
      - Brain Rewiring Progress: ${((streakDays / 90) * 100).clamp(0, 100).toStringAsFixed(1)}%
      ${reasonToQuit.isNotEmpty ? "- Reason for Quitting: \"$reasonToQuit\"" : "- No reason for quitting specified yet"}
      - Temptation Status: ${isTempted ? "Currently feeling tempted" : "Not currently feeling tempted"}
      
      ${highestAchievement != null ? "- Highest Achievement: ${highestAchievement.name} (${highestAchievement.description})" : "- No achievements unlocked yet"}
      ${nextAchievement != null ? "- Next Achievement: ${nextAchievement.name} (${nextAchievement.description}) - Requires ${nextAchievement.daysRequired} days, ${nextAchievement.daysRequired - streakDays} more to go" : ""}
      
      - 28-Day Challenge: ${challengeStarted ? "In progress - Day $challengeCurrentDay (${(challengePercentage * 100).toStringAsFixed(1)}% complete)" : "Not started yet"}
      
      $questionnaireSection
      
      $symptomsSection
      
      $goalsSection
      
      $consumptionSection
      
      REFERENCE THIS INFORMATION CONTEXTUALLY IN YOUR RESPONSES:
      - Celebrate milestone streaks with enthusiasm
      - If they're close to unlocking a new achievement, mention it as motivation
      - Reference their personal reasons for quitting when providing motivation
      - If they express struggling, remind them how far they've come
      - If they're tempted, acknowledge it and offer specific coping strategies
      - Connect their current streak to changes happening in their brain
      - Refer to their milestone dates (start, current streak, goal date) when relevant
      - Provide science-based information about their current phase of recovery based on streak length
      - If they have a low streak (under 7 days), focus on immediate coping strategies
      - For longer streaks (14+ days), emphasize habit formation and identity change
      - Reference their questionnaire answers to personalize advice based on their specific triggers and patterns
      - Address their reported symptoms with targeted solutions
      - Connect their goals to their current struggles and progress
      - Use their consumption data to highlight the health benefits they're gaining by reducing sugar
      
      THERAPEUTIC APPROACH:
      1. Practice reflective listening - paraphrase and summarize what the user shares to demonstrate understanding
      2. Use a warm, compassionate tone while maintaining professional boundaries
      3. Ask open-ended questions that prompt self-reflection rather than yes/no answers
      4. Guide users toward their own insights rather than simply providing advice
      5. Validate emotions and normalize struggles with addiction ("What you're feeling is understandable")
      6. Focus on identifying triggers, patterns, and developing coping strategies
      
      SUGAR ADDICTION EXPERTISE:
      - Provide evidence-based information about sugar's neurological and physiological effects
      - Explain withdrawal symptoms and timeline (typically 2-5 days acute, 2-3 weeks for adaptation)
      - Distinguish between physical cravings (first 3-5 days) and psychological habits (longer-term)
      - Connect behavior patterns to underlying emotional needs sugar might be fulfilling
      
      CONVERSATION TECHNIQUES:
      - Ask one open-ended question at the end of most responses to keep the conversation flowing
      - Examples: "What do you notice happens right before a craving hits?" "How does your body feel when you resist a craving?"
      - Use the Socratic method to help users discover their own insights
      - Frame challenges as opportunities for growth and learning
      - Acknowledge small wins and progress ("That's a significant insight" or "You're developing important awareness")
      
      RESPONSE STRUCTURE:
      1. Brief acknowledgment/validation of what they've shared
      2. Provide relevant insight or perspective (concise, 1-2 sentences)
      3. Connect to practical application or coping strategy when appropriate
      4. End with an open-ended question that deepens exploration
      
      IMPORTANT GUIDELINES${isVoiceResponse ? " FOR VOICE RESPONSES" : ""}:
      - Keep responses conversational and concise (3-5 sentences${isVoiceResponse ? " maximum" : ""})
      ${isVoiceResponse ? "- Make responses even more concise than text chat due to voice medium" : ""}
      - Responses should feel warm and personalized, not clinical or formulaic
      - Never diagnose medical conditions or provide medical advice
      - Recommend consulting healthcare professionals for concerning symptoms
      - If the user shares a success, celebrate it specifically ("That's impressive that you found the strength to...")
      - If the user expresses distress, acknowledge emotions before offering strategies
    ''';
  }
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  bool _isVoiceMode = false;
  bool _isListening = false;
  bool _isPlaying = false;
  bool _isThinking = false;
  bool _isProcessing = false; // Added missing variable
  bool _isPreparingAudio = false; // Added variable for audio preparation state
  String _responseText = ''; // Added missing variable
  String _selectedVoice = 'nova'; // Default voice
  final List<String> _voiceOptions = [
    'alloy',
    'echo',
    'fable',
    'onyx',
    'nova',
    'shimmer'
  ];
  final List<String> _voiceDisplayNames = [
    'Alloy',
    'Echo',
    'Fable',
    'Onyx (Deep Male)',
    'Nova',
    'Shimmer'
  ];
  
  // Audio recording and playback
  final _audioRecorder = record.AudioRecorder();
  final _audioPlayer = AudioPlayer();
  String? _recordingPath;

  // Follow-up questions that dynamically change based on conversation
  List<String> _suggestedFollowUpQuestions = [
    'Why do I crave sugar?',
    'How can I stop a craving right now?',
    'What happens when I quit sugar?',
    'Why is sugar so addictive?',
    'How long until cravings stop?',
  ];

  // Flag to track if we're generating follow-up questions
  bool _isGeneratingQuestions = false;
  
  // Debounce timer for API calls
  Timer? _apiCallDebounceTimer;
  // Throttle duration
  final Duration _throttleDuration = const Duration(milliseconds: 500);

  // New class to track expanded question states
  final Map<int, bool> _expandedQuestions = {};

  // Rate limit state
  bool _rateLimitExceeded = false; // Added rate limit state variable
  
  // Feature quota service
  final _quotaService = FeatureQuotaService();

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('Page View Chatbot Screen');
    
    // Initialize Groq API key (no initialization needed, used directly in HTTP calls)
    
    // Add initial message from the chatbot
    // Initialize _suggestedFollowUpQuestions after context is available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        // Get user's first name from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final userName = prefs.getString('user_first_name') ?? '';
        
        final localizations = AppLocalizations.of(context);
        if (localizations != null) {
          setState(() {
            _suggestedFollowUpQuestions = [
              localizations.translate('chatbot_followUp_q1'),
              localizations.translate('chatbot_followUp_q2'),
              localizations.translate('chatbot_followUp_q3'),
              localizations.translate('chatbot_followUp_q4'),
              localizations.translate('chatbot_followUp_q5'),
            ];
          });
          
          // Build initial message with user's first name if available
          String initialMessage = localizations.translate('chatbot_initialMessage');
          if (userName.isNotEmpty) {
            initialMessage = initialMessage.replaceFirst(
              'Hello!',
              'Hello, $userName!',
            );
          }
          
          _addBotMessage(
            initialMessage,
            isInitial: true,
          );
        } else {
          // Fallback to default questions if localizations not available
          setState(() {
            _suggestedFollowUpQuestions = [
              'Why do I crave sugar so much?',
              'How can I stop a sugar craving right now?',
              'What happens to my body when I quit sugar?',
              'Why is sugar so addictive?',
              'How long until my cravings will stop?',
            ];
          });
          
          // Build fallback initial message with user's first name if available
          String fallbackMessage = "Hello! I'm Melinda, your AI assistant. I'm here to help you on your journey to overcome sugar addiction. What would you like to know?";
          if (userName.isNotEmpty) {
            fallbackMessage = "Hello, $userName! I'm Melinda, your AI assistant. I'm here to help you on your journey to overcome sugar addiction. What would you like to know?";
          }
          
          _addBotMessage(
            fallbackMessage,
            isInitial: true,
          );
        }
      }
    });
    
    // Configure audio player with better error handling
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    
    // Set up audio player completion listener
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
      });
    });
    
    // Add state change monitoring
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      print('Player state changed to: $state');
      if (state == PlayerState.completed) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    
    // Properly dispose of audio resources
    _audioRecorder.dispose();
    
    // Make sure to stop any ongoing playback first
    _audioPlayer.stop();
    
    // Release resources to avoid memory leaks
    _audioPlayer.release();
    
    _apiCallDebounceTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;

    // Sanitize user input to prevent UTF-16 encoding crashes
    final sanitizedMessage = TextSanitizer.sanitizeForDisplay(message);
    if (sanitizedMessage.isEmpty) return;

    // FEATURE FLAG: Temporarily disable quota system for A/B test
    const bool QUOTA_SYSTEM_ENABLED = false; // Set to true to re-enable quota system
    
    // Check quota before processing message (DISABLED for A/B test)
    if (QUOTA_SYSTEM_ENABLED) {
      final canUse = await _quotaService.canUseChatbot();
      if (!canUse) {
        MixpanelService.trackButtonTap('Chatbot Quota Exceeded Paywall Shown');
        _showPaywall();
        return;
      }
    }

    // Cancel any existing API call debounce timer
    _apiCallDebounceTimer?.cancel();

    setState(() {
      _messages.add(
        ChatMessage(text: sanitizedMessage, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
      _messageController.clear();

      // Clear suggested questions when sending a new message
      _suggestedFollowUpQuestions = [];
      
      // Show typing indicator
      _isTyping = true;
      _rateLimitExceeded = false; // Reset rate limit flag on new message attempt
    });

    // Scroll to the bottom of the chat
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      // --- Rate Limit Check ---
      final canRequest = await ApiRateLimitService.canMakeRequest();
      if (!canRequest) {
        final currentCount = await ApiRateLimitService.getCurrentCount();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isTyping = false;
          _rateLimitExceeded = true; 
        });
        _addBotMessage(
          "You have reached your daily limit of 20 AI interactions ($currentCount/20 used). Please try again tomorrow.",
          isError: true,
        );
        return; // Stop processing if rate limit exceeded
      }
      // --- End Rate Limit Check ---

      // Try to get the user's personal data from SharedPreferences and services
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_first_name') ?? '';
      
      // Get streak data
      final streakService = StreakService();
      final streakData = streakService.currentStreak;
      final streakDays = streakData.days;
      final streakStartDate = streakData.startTime;
      
      // Get achievement data
      final achievementsService = AchievementsService();
      final highestAchievement =
          achievementsService.getHighestUnlockedAchievement();
      final nextAchievementIndex =
          highestAchievement == null
              ? 0
              : achievementsService.achievements.indexWhere(
                    (a) => a.id == highestAchievement.id,
                  ) +
                  1;
      final nextAchievement =
          nextAchievementIndex < achievementsService.achievements.length
          ? achievementsService.achievements[nextAchievementIndex] 
          : null;
      
      // Get goal date (90 days from streak start)
      final goalDateTimestamp = prefs.getInt('target_quit_timestamp');
      final goalDate =
          goalDateTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(goalDateTimestamp) 
              : (streakStartDate != null
                  ? streakStartDate.add(const Duration(days: 90))
                  : null);
      
      // Get reason to quit
      final reasonToQuit = prefs.getString('reason_to_quit') ?? '';
      
      // Get challenge progress
      final challengeStarted = prefs.getBool('challenge_started') ?? false;
      final challengeCurrentDay = prefs.getInt('challenge_current_day') ?? 0;
      final challengePercentage =
          challengeStarted && challengeCurrentDay > 0
          ? challengeCurrentDay / 28 
          : 0.0;
      
      // Get temptation status
      final isTempted = prefs.getBool('is_tempted') ?? false;

      // NEW CODE: Get consumption tracking data from SharedPreferences
      final consumptionLevel = prefs.getString('consumption_level');
      final sugaryTreatsPerWeek = prefs.getInt('sugar_treats_per_week');
      final treatSize = prefs.getString('treat_size');
      final caloriesPerWeek = prefs.getDouble('calories_per_week');
      final caloriesPerQuarter = prefs.getDouble('calories_per_quarter');
      final caloriesPerYear = prefs.getDouble('calories_per_year');

      // NEW CODE: Create a map to hold questionnaire answers from SharedPreferences
      final Map<int, String> questionnaireAnswers = {};

      // NEW CODE: Try to load questionnaire data, symptoms, and goals from Firebase
      List<String> symptoms = [];
      List<String> goals = [];
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final questionnaireRepository = QuestionnaireRepository();
        try {
          // Try to get questionnaire answers from Firebase
          final questionnaireData = await questionnaireRepository
              .getQuestionnaireAnswers(currentUser.uid);
          if (questionnaireData != null) {
            questionnaireData.answers.forEach((key, value) {
              final questionNumber = int.tryParse(key.replaceAll('q', ''));
              if (questionNumber != null) {
                questionnaireAnswers[questionNumber] = value;
              }
            });
          }

          // Try to get symptoms from Firebase
          symptoms = await questionnaireRepository.getSymptoms(currentUser.uid);

          // Try to get goals from Firebase
          goals = await questionnaireRepository.getGoals(currentUser.uid);
        } catch (e) {
          print('Error fetching questionnaire data: $e');
        }
      }

      // Get the system prompt using the helper method with the new data
      final systemPrompt = MelindaPromptHelper.getSystemPrompt(
        userName: userName,
        streakDays: streakDays,
        streakStartDate: streakStartDate,
        goalDate: goalDate,
        reasonToQuit: reasonToQuit,
        isTempted: isTempted,
        highestAchievement: highestAchievement,
        nextAchievement: nextAchievement,
        challengeStarted: challengeStarted,
        challengeCurrentDay: challengeCurrentDay,
        challengePercentage: challengePercentage,
        // NEW CODE: Pass the new data to the system prompt
        questionnaireAnswers:
            questionnaireAnswers.isNotEmpty ? questionnaireAnswers : null,
        symptoms: symptoms.isNotEmpty ? symptoms : null,
        goals: goals.isNotEmpty ? goals : null,
        consumptionLevel: consumptionLevel,
        sugaryTreatsPerWeek: sugaryTreatsPerWeek,
        treatSize: treatSize,
        caloriesPerWeek: caloriesPerWeek,
        caloriesPerQuarter: caloriesPerQuarter,
        caloriesPerYear: caloriesPerYear,
        userLanguageCode: prefs.getString('language_code') ?? 'en', // Pass language code
      );

      // Set thinking state before making the Groq API request
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _isThinking = true;
      });

      // --- Increment Rate Limit Count ---
      await ApiRateLimitService.incrementRequestCount(); 
      // --- End Increment Rate Limit Count ---
      
      // Record chatbot usage after successful API call (DISABLED for A/B test)
      if (QUOTA_SYSTEM_ENABLED) {
        await _quotaService.recordChatbotUse();
      }

      // Use Groq API to generate a response
      final groqApiKey = EnvConfig.groqApiKey;
      if (groqApiKey == null || groqApiKey.isEmpty) {
        throw Exception('Groq API key is missing or empty');
      }

      // Prepare messages for Groq API
      final messages = [
        {
          'role': 'system',
          'content': systemPrompt,
        },
        ..._messages.map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            }),
      ];

      // Call Groq API
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqApiKey',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-maverick-17b-128e-instruct', // Groq's fast and capable model
          'messages': messages,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
      }

      // Extract the bot response
      final responseJson = jsonDecode(response.body);
      final rawResponse = responseJson['choices']?[0]?['message']?['content'] ??
          "I'm sorry, I couldn't generate a response.";
      // Sanitize the bot response before using it
      final botResponse = TextSanitizer.sanitizeForDisplay(rawResponse);

      // Hide thinking indicator before adding the message
      if (!mounted) return;
      setState(() {
        _isThinking = false;
      });

      _addBotMessage(botResponse);

      // Generate follow-up questions with debounce
      _generateFollowUpQuestions(botResponse);
    } catch (e) {
      // Hide typing and thinking indicators on error
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _isThinking = false;
      });
      
      _addBotMessage(
        "I'm sorry, I encountered an error while processing your request. Please try again later.",
        isError: true,
      );
      print('Error generating response: $e');
    } finally {
      // Ensure loading indicator stops even if rate limit was hit before try block completes fully
      if (mounted && !_rateLimitExceeded) { // Check mounted and if rate limit wasn't the cause
         setState(() {
           _isLoading = false; 
         });
      } else if (mounted && _rateLimitExceeded) {
        // If rate limit was exceeded, isLoading was already set to false
        // Do nothing here to avoid unnecessary setState calls
      }
    }
  }

  Future<void> _convertTextToSpeech(String text) async {
    if (text.isEmpty) return;
    
    // If already playing, stop playback
    if (_isPlaying) {
      await _audioPlayer.stop();
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _isPreparingAudio = false; // Reset preparing flag
      });
      return;
    }
    
    // Set preparing flag to true immediately when user taps on "Play message"
    if (!mounted) return;
    setState(() {
      _isPreparingAudio = true;
    });
    
    try {
      // Set thinking off, but don't set _isPlaying yet
      if (!mounted) return;
      setState(() {
        _isThinking = false;
      });
      
      // Limit text length for TTS to 4000 characters (OpenAI TTS limit)
      final limitedText = text.length > 4000 
          ? TextSanitizer.safeSubstring(text, 0, 4000) 
          : text;
      
      // OpenAI TTS API endpoint (Groq TTS requires terms acceptance)
      final url = Uri.parse('https://api.openai.com/v1/audio/speech');
      
      // Request payload
      final payload = jsonEncode({
        'model': 'tts-1-hd',
        'input': limitedText,
        'voice': _selectedVoice,
      });
      
      // Make the TTS API request
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${EnvConfig.openaiApiKey}',
          'Content-Type': 'application/json',
        },
        body: payload,
      );
      
      if (response.statusCode == 200) {
        // Get the temporary directory
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/jarvis_response.mp3';
        
        // Write the audio data to a file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Verify file was written correctly
        final fileSize = file.lengthSync();
        print('Audio file created at: $filePath with size: $fileSize bytes');
        
        if (fileSize == 0) {
          throw Exception('Audio file is empty');
        }
        
        // Reset player before new playback
        await _audioPlayer.stop();
        
        // Set volume to maximum
        await _audioPlayer.setVolume(1.0);
        
        // Use try-catch for playback to handle potential interruptions
        try {
          // Play the audio and wait for it to start
          await _audioPlayer.play(DeviceFileSource(filePath));
          print('Audio playback started');
          
          // NOW set _isPlaying to true AFTER audio playback has started
          if (!mounted) return;
          setState(() {
            _isPlaying = true;
            _isPreparingAudio = false; // Reset preparing flag now that we're playing
          });
        } catch (playbackError) {
          print('Playback error: $playbackError');
          if (!mounted) return;
          setState(() {
            _isPlaying = false;
            _isPreparingAudio = false; // Reset preparing flag on error
          });
        }
      } else {
        print(
          'Error converting text to speech: ${response.statusCode} - ${utf8.decode(response.bodyBytes, allowMalformed: true)}',
        );
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _isPreparingAudio = false; // Reset preparing flag
        });
      }
    } catch (e) {
      print('Error in text-to-speech: $e');
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _isPlaying = false;
        _isPreparingAudio = false; // Reset preparing flag on error
      });
    }
  }

  void _addBotMessage(
    String message, {
    bool isError = false,
    bool isInitial = false,
  }) {
    setState(() {
      _messages.add(
        ChatMessage(
        text: message,
        isUser: false,
        isError: isError,
        timestamp: DateTime.now(),
        isInitial: isInitial,
        ),
      );
    });
    
    // Scroll to the bottom of the chat
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _toggleVoiceMode() {
    setState(() {
      _isVoiceMode = !_isVoiceMode;
    });
    
    if (_isVoiceMode) {
      _showVoiceSelectionDialog();
    } else {
      // Stop any currently playing audio when turning off voice mode
      _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _startListening() async {
    // Track Mixpanel mic button tap for Chatbot Voice Mode
    MixpanelService.trackButtonTap('Chatbot Voice mode Mic Tap');
    if (_isListening) {
      // Stop recording
      await _stopListening();
      return;
    }
    
    // Check microphone permission
    if (await _audioRecorder.hasPermission()) {
      // Get the temporary directory for storing recordings
      final directory = await getTemporaryDirectory();
      _recordingPath = '${directory.path}/jarvis_recording.m4a';
      
      // Start recording for speech-to-text transcription
      await _audioRecorder.start(
        const record.RecordConfig(
          encoder: record.AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );
      
      setState(() {
        _isListening = true;
      });
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    
    // Stop recording
    final path = await _audioRecorder.stop();
    
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _isProcessing = true;
    });
    
    if (path != null) {
      try {
        // Get the recorded audio file
        final file = File(path);
        final bytes = await file.readAsBytes();
        
        // Convert the audio to text using Groq ASR API
        final transcription = await _convertSpeechToText(bytes);
        print('Transcription result: $transcription');
        
        if (transcription.isNotEmpty) {
          // Place transcribed text in input field without sending
          if (!mounted) return;
          setState(() {
            _messageController.text = transcription;
            _isProcessing = false;
            _isThinking = false;
            _isPreparingAudio = false; // Reset preparing flag
          });
        } else {
          print('Transcription was empty, not processing further');
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _isThinking = false;
            _isPreparingAudio = false; // Reset preparing flag
          });
        }
      } catch (e) {
        print('Error processing speech to text: $e');
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _isThinking = false;
          _isPreparingAudio = false; // Reset preparing flag
        });
      }
    }
  }

  Future<String> _convertSpeechToText(Uint8List audioBytes) async {
    try {
      final groqApiKey = EnvConfig.groqApiKey;
      if (groqApiKey == null || groqApiKey.isEmpty) {
        print('Groq API key is missing');
        return '';
      }

      // Groq ASR API endpoint
      final url = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
      
      // Create a multipart request
      final request = http.MultipartRequest('POST', url);
      
      // Add headers and API key
      request.headers.addAll({
        'Authorization': 'Bearer $groqApiKey',
      });
      
      // Add the audio file
      request.files.add(
        http.MultipartFile.fromBytes('file', audioBytes, filename: 'audio.m4a'),
      );
      
      // Use Groq's fast whisper model (turbo for lowest latency, fallback to v3)
      request.fields['model'] = 'whisper-large-v3-turbo';
      
      // Send the request
      final response = await request.send();
      
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final json = jsonDecode(responseBody);
        final text = json['text'] as String?;
        if (text != null && text.isNotEmpty) {
          // Sanitize the transcription result before returning
          return TextSanitizer.sanitizeForDisplay(text);
        }
        // If turbo model fails, try v3 model
        request.fields['model'] = 'whisper-large-v3';
        final retryResponse = await request.send();
        if (retryResponse.statusCode == 200) {
          final retryBody = await retryResponse.stream.bytesToString();
          final retryJson = jsonDecode(retryBody);
          final retryText = retryJson['text'] as String?;
          if (retryText != null && retryText.isNotEmpty) {
            return TextSanitizer.sanitizeForDisplay(retryText);
          }
        }
        return '';
      } else {
        print('Error in Groq speech-to-text: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      print('Error in Groq speech-to-text: $e');
      return '';
    }
  }

  Future<String> _generateChatResponse(String userInput) async {
    try {
      // Try to get the user's personal data from SharedPreferences and services
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_first_name') ?? '';
      
      // Get streak data
      final streakService = StreakService();
      final streakData = streakService.currentStreak;
      final streakDays = streakData.days;
      final streakStartDate = streakData.startTime;
      
      // Get achievement data
      final achievementsService = AchievementsService();
      final highestAchievement =
          achievementsService.getHighestUnlockedAchievement();
      final nextAchievementIndex =
          highestAchievement == null
              ? 0
              : achievementsService.achievements.indexWhere(
                    (a) => a.id == highestAchievement.id,
                  ) +
                  1;
      final nextAchievement =
          nextAchievementIndex < achievementsService.achievements.length
          ? achievementsService.achievements[nextAchievementIndex] 
          : null;
      
      // Get goal date (90 days from streak start)
      final goalDateTimestamp = prefs.getInt('target_quit_timestamp');
      final goalDate =
          goalDateTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(goalDateTimestamp) 
              : (streakStartDate != null
                  ? streakStartDate.add(const Duration(days: 90))
                  : null);
      
      // Get reason to quit
      final reasonToQuit = prefs.getString('reason_to_quit') ?? '';
      
      // Get challenge progress
      final challengeStarted = prefs.getBool('challenge_started') ?? false;
      final challengeCurrentDay = prefs.getInt('challenge_current_day') ?? 0;
      final challengePercentage =
          challengeStarted && challengeCurrentDay > 0
          ? challengeCurrentDay / 28 
          : 0.0;
      
      // Get temptation status
      final isTempted = prefs.getBool('is_tempted') ?? false;

      // Get consumption tracking data from SharedPreferences
      final consumptionLevel = prefs.getString('consumption_level');
      final sugaryTreatsPerWeek = prefs.getInt('sugar_treats_per_week');
      final treatSize = prefs.getString('treat_size');
      final caloriesPerWeek = prefs.getDouble('calories_per_week');
      final caloriesPerQuarter = prefs.getDouble('calories_per_quarter');
      final caloriesPerYear = prefs.getDouble('calories_per_year');

      // Create a map to hold questionnaire answers from SharedPreferences
      final Map<int, String> questionnaireAnswers = {};

      // Try to load questionnaire data, symptoms, and goals from Firebase
      List<String> symptoms = [];
      List<String> goals = [];
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final questionnaireRepository = QuestionnaireRepository();
        try {
          // Try to get questionnaire answers from Firebase
          final questionnaireData = await questionnaireRepository
              .getQuestionnaireAnswers(currentUser.uid);
          if (questionnaireData != null) {
            questionnaireData.answers.forEach((key, value) {
              final questionNumber = int.tryParse(key.replaceAll('q', ''));
              if (questionNumber != null) {
                questionnaireAnswers[questionNumber] = value;
              }
            });
          }

          // Try to get symptoms from Firebase
          symptoms = await questionnaireRepository.getSymptoms(currentUser.uid);

          // Try to get goals from Firebase
          goals = await questionnaireRepository.getGoals(currentUser.uid);
        } catch (e) {
          print('Error fetching questionnaire data: $e');
        }
      }

      // Get the system prompt using the helper method with the new data
      final systemPrompt = MelindaPromptHelper.getSystemPrompt(
        userName: userName,
        streakDays: streakDays,
        streakStartDate: streakStartDate,
        goalDate: goalDate,
        reasonToQuit: reasonToQuit,
        isTempted: isTempted,
        highestAchievement: highestAchievement,
        nextAchievement: nextAchievement,
        challengeStarted: challengeStarted,
        challengeCurrentDay: challengeCurrentDay,
        challengePercentage: challengePercentage,
        isVoiceResponse: true, // This signals to make responses more voice-friendly
        questionnaireAnswers:
            questionnaireAnswers.isNotEmpty ? questionnaireAnswers : null,
        symptoms: symptoms.isNotEmpty ? symptoms : null,
        goals: goals.isNotEmpty ? goals : null,
        consumptionLevel: consumptionLevel,
        sugaryTreatsPerWeek: sugaryTreatsPerWeek,
        treatSize: treatSize,
        caloriesPerWeek: caloriesPerWeek,
        caloriesPerQuarter: caloriesPerQuarter,
        caloriesPerYear: caloriesPerYear,
        userLanguageCode: prefs.getString('language_code') ?? 'en', // Pass language code
      );
      
      // Initialize Groq API key, handling null safely
      final groqApiKey = EnvConfig.groqApiKey;
      if (groqApiKey == null || groqApiKey.isEmpty) {
        throw Exception('Groq API key is missing or empty');
      }
      
      // Generate a chat response using Groq API
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqApiKey',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-maverick-17b-128e-instruct', // Groq's fast and capable model
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': userInput,
            },
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
      }

      // Extract the bot response
      final responseJson = jsonDecode(response.body);
      final rawResponse = responseJson['choices']?[0]?['message']?['content'] ??
          "I'm sorry, I couldn't generate a response.";
      // Sanitize the response before returning
      return TextSanitizer.sanitizeForDisplay(rawResponse);
    } catch (e) {
      print('Error generating response: $e');
      return "I'm sorry, I encountered an error while processing your request. Please try again.";
    }
  }

  void _showVoiceSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // White background for dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Voice',
                style: TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'ElzaRound',
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Choose your preferred voice',
                style: TextStyle(
                  color: Color(0xFF666666), // Gray secondary text
                  fontSize: 14,
                  fontFamily: 'ElzaRound',
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  _voiceOptions.length,
                  (index) => RadioListTile<String>(
                    title: Text(
                      _voiceDisplayNames[index],
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A), // Dark text
                        fontFamily: 'ElzaRound',
                      ),
                    ),
                    value: _voiceOptions[index],
                    groupValue: _selectedVoice,
                    onChanged: (value) {
                      setState(() {
                        _selectedVoice = value!;
                      });
                      Navigator.of(context).pop();
                      
                      // Play a sample to let the user hear the selected voice
                      _playVoiceSample();
                    },
                    activeColor: const Color(0xFFed3272), // Brand pink
                    fillColor: MaterialStateProperty.resolveWith<Color>((
                      Set<MaterialState> states,
                    ) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFFed3272); // Brand pink
                      }
                      return const Color(0xFF666666); // Gray text
                    }),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFFed3272), // Brand pink
                  fontFamily: 'ElzaRound',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _playVoiceSample() async {
    const sampleText =
        "Hello, I'm Melinda. I'll help with your sugar addiction recovery.";
    await _convertTextToSpeech(sampleText);
  }

  void _showVoiceOnlyMode() {
    _audioPlayer.stop();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) => VoiceOnlyModeScreen(
          onSpeechRecognized: (text) {
            Navigator.of(context).pop();
            if (text.isNotEmpty) {
              _messageController.text = text;
              _sendMessage(text);
            }
          },
          onClose: () {
            // Stop any current audio playback before closing
            _audioPlayer.stop();
            Navigator.of(context).pop();
          },
          selectedVoice: _selectedVoice,
        ),
      ),
    );
  }

  Future<void> _generateFollowUpQuestions(String botResponse) async {
    // Skip if we're already generating questions
    if (_isGeneratingQuestions) return;
    
    // Cancel any existing debounce timer
    _apiCallDebounceTimer?.cancel();
    
    // Set up a new debounce timer
    _apiCallDebounceTimer = Timer(_throttleDuration, () async {
      // Double-check mounted before proceeding with any async work
      if (!mounted) return;
      
      // Set flag to avoid multiple simultaneous requests
      setState(() {
        _isGeneratingQuestions = true;
      });
  
      try {
        // Only generate follow-up questions if we have at least one message exchange
        if (_messages.length >= 2) {
          // Determine the language used in the conversation
          // Get the last few messages to analyze language
          final recentMessages = _getLimitedConversationHistory();
          
          // Prepare a prompt for generating follow-up questions in the same language as the conversation
          final prompt = '''
Based on this conversation fragment, suggest 3-5 follow-up questions that the USER might want to ask MELINDA next.
IMPORTANT: 
1. Generate questions from the USER'S perspective asking questions TO Melinda (e.g. "How can I reduce sugar cravings?" not "Do you have sugar cravings?")
2. Use the SAME LANGUAGE as the conversation. Match the language that the user is using.
3. Questions should be specific to the context of the conversation, relevant to sugar addiction recovery, and helpful for the user to learn more.
4. Each question should be direct and related to what was just discussed.

Format your response as a JSON object with this exact format:
{"questions": ["question 1", "question 2", "question 3"]}

CONVERSATION (most recent at bottom):
$recentMessages
''';
  
          // Make an API call to generate the questions using Groq API
          final groqApiKey = EnvConfig.groqApiKey;
          if (groqApiKey == null || groqApiKey.isEmpty) {
            throw Exception('Groq API key is missing');
          }

          final response = await http.post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $groqApiKey',
            },
            body: jsonEncode({
              'model': 'meta-llama/llama-4-maverick-17b-128e-instruct',
              'messages': [
                {
                  'role': 'system',
                  'content': "You generate follow-up questions that a USER would ask MELINDA about sugar addiction recovery. Generate questions FROM THE USER'S PERSPECTIVE (questions the user would ask Melinda, not the other way around). Match the user's language. Output JSON only.",
                },
                {
                  'role': 'user',
                  'content': prompt,
                },
              ],
              'temperature': 0.7,
            }),
          );

          if (response.statusCode != 200) {
            throw Exception('Groq API error: ${response.statusCode}');
          }

          // Extract the bot response
          final responseJson = jsonDecode(response.body);
          final rawResponseText = responseJson['choices']?[0]?['message']?['content'] ?? "[]";
          // Sanitize the response text before processing
          final responseText = TextSanitizer.sanitizeForDisplay(rawResponseText);
  
          // Parse the JSON response
          try {
            // Clean the response text by removing markdown code blocks if present
            String cleanedResponse = responseText;
            if (responseText.startsWith('```json') || responseText.startsWith('```')) {
              // Remove beginning markdown
              cleanedResponse = cleanedResponse.replaceFirst(RegExp(r'^```json\n?|^```\n?'), '');
              // Remove trailing markdown
              cleanedResponse = cleanedResponse.replaceFirst(RegExp(r'\n?```$'), '');
            }
            
            // Ensure response is valid JSON by trimming whitespace
            cleanedResponse = cleanedResponse.trim();
            
            final dynamic parsedJson = jsonDecode(cleanedResponse);

            if (parsedJson is Map &&
                parsedJson.containsKey('questions') &&
                parsedJson['questions'] is List) {
              final questionsList = List<String>.from(parsedJson['questions'])
                  .map((q) => TextSanitizer.sanitizeForDisplay(q))
                  .toList();
  
              if (questionsList.isNotEmpty && mounted) {
                setState(() {
                  _suggestedFollowUpQuestions = questionsList;
                });
                return;
              }
            } else if (parsedJson is List) {
              final questionsList = List<String>.from(parsedJson)
                  .map((q) => TextSanitizer.sanitizeForDisplay(q))
                  .toList();
  
              if (questionsList.isNotEmpty && mounted) {
                setState(() {
                  _suggestedFollowUpQuestions = questionsList;
                });
                return;
              }
            }
          } catch (e) {
            print('Error parsing follow-up questions JSON: $e');
            print('Raw response: $responseText');
          }
        }
  
        // Fallback to default questions if we couldn't generate or parse new ones
        // Ensure context is available for AppLocalizations
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          if (localizations != null) {
            setState(() {
              _suggestedFollowUpQuestions = [
                localizations.translate('chatbot_followUp_q1'),
                localizations.translate('chatbot_followUp_q2'),
                localizations.translate('chatbot_followUp_q3'),
                localizations.translate('chatbot_followUp_q4'),
                localizations.translate('chatbot_followUp_q5'),
              ];
            });
          } else {
            // Fallback if localizations is not available
            setState(() {
              _suggestedFollowUpQuestions = [
                'Why do I crave sugar so much?',
                'How can I stop a sugar craving right now?',
                'What happens to my body when I quit sugar?',
                'Why is sugar so addictive?',
                'How long until my cravings will stop?',
              ];
            });
          }
        }
      } catch (e) {
        print('Error generating follow-up questions: $e');
        // In case of error, keep the existing questions
      } finally {
        // Extra safety check before setState in finally block
        if (mounted && _isGeneratingQuestions != null) {
          setState(() {
            _isGeneratingQuestions = false;
          });
        }
      }
    });
  }

  // Helper method to get the last few messages of conversation history
  String _getLimitedConversationHistory() {
    // Take last 4 messages (2 exchanges) or less if not available
    final recentMessages =
        _messages.length <= 4
            ? _messages
            : _messages.sublist(_messages.length - 4);

    return recentMessages
        .map((msg) {
          final role = msg.isUser ? "User" : "Melinda";
          return "$role: ${msg.text}";
        })
        .join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    // Déterminer si nous sommes sur Android pour ajouter du padding supplémentaire
    final bool isAndroid = Platform.isAndroid;
    final double bottomPadding = isAndroid ? 16.0 : 0.0;
    
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB), // Subtle neutral white background (preferred)
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xFF1A1A1A), // Dark icon for light background
          onPressed: () {
            MixpanelService.trackButtonTap('Chatbot Back Tap');
            // Stop any current audio playback before navigating back
            _audioPlayer.stop();
            Navigator.of(context).pop();
          },
        ),
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            final titleText = localizations?.translate('chatbot_title') ?? 'Chat with Melinda';
            
            return Text(
              titleText,
              style: const TextStyle(
                color: Color(0xFF1A1A1A), // Dark text for light background
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'ElzaRound',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        centerTitle: true,
        actions: [
          // Health icon
          IconButton(
            icon: const Icon(
              Icons.favorite,
              color: Color(0xFFed3272), // Brand pink for accent
              size: 28,
            ),
            onPressed: () {
              MixpanelService.trackButtonTap('Chatbot Medical Info Tap');
              _openMedicalInfo();
            },
            tooltip: AppLocalizations.of(context)!.translate('chatbot_healthInfoTooltip'),
          ),
          IconButton(
            icon: Icon(
              _isVoiceMode ? Icons.record_voice_over : Icons.voice_over_off,
              color: _isVoiceMode ? const Color(0xFFed3272) : const Color(0xFF1A1A1A), // Brand pink when active, dark when inactive
            ),
            onPressed: () {
              MixpanelService.trackButtonTap('Chatbot Voice Mode Toggle Tap');
              // Stop any currently playing audio when toggling voice mode
              _audioPlayer.stop();
              setState(() {
                _isPlaying = false;
                _isVoiceMode = !_isVoiceMode;
              });
              
              if (_isVoiceMode) {
                _showVoiceSelectionDialog();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.mic_external_on, color: Color(0xFF1A1A1A)), // Dark icon for light background
            onPressed: () {
              MixpanelService.trackButtonTap('Chatbot Voice Only Mode Tap');
              _showVoiceOnlyMode();
            },
          ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // Dark icons for light background
          statusBarBrightness: Brightness.light, // For iOS
        ),
      ),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                                                  SizedBox(
                            height: 320,
                            width: 320,
                            child: Lottie.asset(
                              'assets/images/lotties/chatbot-orb-2.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                        const SizedBox(height: 20),
                        const Text(
                          'Chat messages are cleared each time you\nleave this view to ensure your privacy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF666666), // Gray text for secondary information
                            fontSize: 14,
                            fontFamily: 'ElzaRound',
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isTyping) {
                            return _buildTypingIndicator();
                          }
                          final message = _messages[index];
                          return _buildMessageBubble(message);
                        },
                      ),
                      if (_isPlaying)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white, // White background for contrast
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFed3272), width: 1), // Brand pink border
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.volume_up,
                                  color: Color(0xFFed3272), // Brand pink icon
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Playing',
                                  style: TextStyle(
                                    color: Color(0xFF1A1A1A), // Dark text
                                    fontSize: 12,
                                    fontFamily: 'ElzaRound',
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    MixpanelService.trackButtonTap('Chatbot Audio Close Tap');
                                    _audioPlayer.stop();
                                    setState(() {
                                      _isPlaying = false;
                                    });
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    color: Color(0xFF666666), // Gray close button
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          // Predefined follow-up questions with expandable ones
          if (_messages.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              // Fixed height with reasonable default values
              height: _getExpandedQuestionsHeight(),
              child:
                  _isGeneratingQuestions
                      ? _buildLoadingQuestions()
                      : ListView.builder(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                itemCount: _suggestedFollowUpQuestions.length,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index) {
                  final isExpanded = _expandedQuestions[index] ?? false;
                  return Container(
                    width: isExpanded ? 250 : 160,
                    height: isExpanded ? 120 : 40, // Increased height from 90 to 120 for expanded state
                    margin: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        MixpanelService.trackButtonTap('Chatbot Follow Up Question Tap');
                        // Toggle expanded state
                        setState(() {
                          _expandedQuestions.forEach((key, value) {
                            _expandedQuestions[key] = false; // Collapse all others
                          });
                          _expandedQuestions[index] = !isExpanded;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: Colors.white, // White background for contrast
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE0E0E0), width: 1), // Light gray border
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        // Use ClipRRect to ensure content doesn't overflow visually while allowing scrolling
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            physics: isExpanded ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Question text and expansion icon
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _suggestedFollowUpQuestions[index],
                                          style: const TextStyle(
                                            color: Color(0xFF1A1A1A), // Dark text for readability
                                            fontSize: 12,
                                            fontFamily: 'ElzaRound',
                                            height: 1.2,
                                          ),
                                          maxLines: isExpanded ? null : 1, // null allows unlimited lines when expanded
                                          overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis, // Show full text when expanded
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        color: const Color(0xFFed3272), // Brand pink for accent
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                                // Send button (only when expanded)
                                if (isExpanded)
                                  const SizedBox(height: 8), // Consistent spacing
                                if (isExpanded) 
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        MixpanelService.trackButtonTap('Chatbot Follow Up Send Tap');
                                        _sendMessage(_suggestedFollowUpQuestions[index]);
                                        setState(() {
                                          _expandedQuestions[index] = false;
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.send,
                                        size: 12,
                                        color: Color(0xFFed3272), // Brand pink
                                      ),
                                      label: const Text(
                                        'Send',
                                        style: TextStyle(
                                          color: Color(0xFFed3272), // Brand pink
                                          fontSize: 11,
                                          fontFamily: 'ElzaRound',
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        minimumSize: Size.zero,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Privacy notice
          if (_messages.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Chat messages are cleared each time you leave this view to ensure your privacy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF666666), // Gray text for secondary information
                  fontSize: 14,
                  fontFamily: 'ElzaRound',
                ),
              ),
            ),

          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFed3272)), // Brand pink
                strokeWidth: 2,
              ),
            ),

          // Message input area
          Container(
            decoration: BoxDecoration(
              color: Colors.white, // White background for input area
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 16.0 + bottomPadding, // Ajoute du padding supplémentaire pour Android
            ),
            child: Row(
              children: [
                // Voice input button
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? const Color(0xFFed3272) : const Color(0xFF666666), // Brand pink when listening, gray otherwise
                  ),
                  onPressed: () {
                    MixpanelService.trackButtonTap('Chatbot Non-Voice Mode Mic Tap');
                    _startListening();
                  },
                ),
                
                // Text input field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A), // Dark text
                      fontFamily: 'ElzaRound',
                    ),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)?.translate('chatbot_inputHint') ?? 'Type your message...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF666666), // Gray hint text
                        fontFamily: 'ElzaRound',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFed3272), width: 2), // Brand pink focus border
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFBFBFB), // Same as main background
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                    ),
                    onSubmitted: (text) {
                      if (text.isNotEmpty) {
                        _sendMessage(text);
                      }
                    },
                  ),
                ),
                
                // Send button
                IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFFed3272), // Brand pink
                  ),
                  onPressed: () {
                    MixpanelService.trackButtonTap('Chatbot Send Tap');
                    if (_messageController.text.isNotEmpty) {
                      _sendMessage(_messageController.text);
                    }
                  },
                ),
              ],
            ),
          ),
          
          // Padding supplémentaire pour Android pour éviter la superposition avec la barre de navigation
          if (isAndroid)
            SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    
    if (message.isInitial) {
      return Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 160,
            height: 160,
            margin: const EdgeInsets.only(bottom: 16),
            child: Lottie.asset(
              'assets/images/lotties/chatbot-orb-2.json',
              fit: BoxFit.contain,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white, // White background for initial message
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1), // Light gray border
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TextSanitizer.sanitizeForDisplay(message.text),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A), // Dark text for readability
                    fontSize: 16,
                    fontFamily: 'ElzaRound',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      MixpanelService.trackButtonTap('Chatbot Play Message Tap');
                      _convertTextToSpeech(message.text);
                    },
                    child: _buildPlayButton(message.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) 
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white, // White background for avatar
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1), // Light border
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.smart_toy_outlined,
                  color: message.isError ? Colors.red : const Color(0xFFed3272), // Brand pink for bot icon
                  size: 20,
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isUser
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFed3272), // Brand pink
                          Color(0xFFfd5d32), // Brand orange
                        ],
                      ).colors.first.withOpacity(0.1) // Light tint of gradient
                    : message.isError 
                        ? Colors.red.withOpacity(0.1) 
                        : Colors.white, // White for bot messages
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isUser
                      ? const Color(0xFFed3272).withOpacity(0.3) // Brand pink border
                      : message.isError 
                          ? Colors.red.withOpacity(0.5)
                          : const Color(0xFFE0E0E0), // Light gray border
                  width: 1,
                ),
                boxShadow: !isUser && !message.isError ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ] : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TextSanitizer.sanitizeForDisplay(message.text),
                    style: TextStyle(
                      color: message.isError ? Colors.red : const Color(0xFF1A1A1A), // Dark text for readability
                      fontSize: 16,
                      fontFamily: 'ElzaRound',
                    ),
                  ),
                                  if (!isUser && !message.isError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        MixpanelService.trackButtonTap('Chatbot Play Message Tap');
                        _convertTextToSpeech(message.text);
                      },
                      child: _buildPlayButton(message.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser)
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient( // Use gradient for user avatar
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFed3272), // Brand pink
                    Color(0xFFfd5d32), // Brand orange
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFed3272).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.person_outline,
                  color: Colors.white, // White icon on gradient
                  size: 20,
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildLoadingQuestions() {
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFF0F0F0), // Light gray base for shimmer
          highlightColor: Colors.white, // White highlight
          child: Wrap(
            spacing: 8.0, // Space between items
            runSpacing: 4.0, // Space between rows
            children: List.generate(
              3,
              (index) => Container(
                width: 80, // Much smaller width
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar for bot
            Container(
              width: 40,
              height: 40,
            margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
              color: Colors.white, // White background for avatar
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1), // Light border
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                Icons.smart_toy_outlined,
                  color: Color(0xFFed3272), // Brand pink for bot icon
                  size: 20,
                ),
              ),
            ),
          // Typing indicator bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white, // White background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE0E0E0), // Light gray border
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                _buildTypingDot(150),
                _buildTypingDot(300),
              ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int delay) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        builder: (context, double value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, -3 * sin(value * 3.14)),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFed3272), // Brand pink for typing dots
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayButton(String messageText) {
    if (_isThinking) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.pending,
            color: Color(0xFFed3272), // Brand pink
            size: 16,
          ),
          const SizedBox(width: 4),
          const Text(
            'Melinda is thinking...',
            style: TextStyle(
              color: Color(0xFFed3272), // Brand pink
              fontSize: 12,
              fontFamily: 'ElzaRound',
            ),
          ),
        ],
      );
    } else if (_isPreparingAudio) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_empty,
            color: Color(0xFFed3272), // Brand pink
            size: 16,
          ),
          const SizedBox(width: 4),
          const Text(
            'Processing...',
            style: TextStyle(
              color: Color(0xFFed3272), // Brand pink
              fontSize: 12,
              fontFamily: 'ElzaRound',
            ),
          ),
        ],
      );
    } else if (_isPlaying) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.pause,
            color: Color(0xFFed3272), // Brand pink
            size: 16,
          ),
          const SizedBox(width: 4),
          const Text(
            'Pause',
            style: TextStyle(
              color: Color(0xFFed3272), // Brand pink
              fontSize: 12,
              fontFamily: 'ElzaRound',
            ),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.volume_up,
            color: Color(0xFFed3272), // Brand pink
            size: 16,
          ),
          const SizedBox(width: 4),
          const Text(
            'Play message',
            style: TextStyle(
              color: Color(0xFFed3272), // Brand pink
              fontSize: 12,
              fontFamily: 'ElzaRound',
            ),
          ),
        ],
      );
    }
  }

  // Helper method to calculate height based on expanded states
  double _getExpandedQuestionsHeight() {
    bool anyExpanded = _expandedQuestions.values.any((expanded) => expanded);
    // Sur Android, augmenter la hauteur pour éviter la superposition
    return anyExpanded 
        ? (Platform.isAndroid ? 140.0 : 130.0) 
        : (Platform.isAndroid ? 66.0 : 56.0);
  }

  // Method to show paywall when quota exceeded
  Future<void> _showPaywall() async {
    try {
      // Create a handler for paywall presentation
      PaywallPresentationHandler handler = PaywallPresentationHandler();
      
      handler.onPresent((paywallInfo) async {
        String? name = await paywallInfo.name;
        debugPrint("Chatbot Paywall presented: ${name ?? 'Unknown'}");
        MixpanelService.trackEvent('Chatbot Quota Paywall Presented', 
          properties: {'paywall_name': name ?? 'Unknown'}
        );
      });

      handler.onDismiss((paywallInfo, paywallResult) async {
        String? name = await paywallInfo.name;
        String resultString = paywallResult?.toString() ?? 'null';
        debugPrint("Chatbot Paywall dismissed: ${name ?? 'Unknown'}, Result: $resultString");
        
        MixpanelService.trackEvent('Chatbot Quota Paywall Dismissed', 
          properties: {
            'paywall_name': name,
            'result': resultString,
            'result_contains_purchased': resultString.contains('PurchasedPaywallResult'),
            'timestamp': DateTime.now().toIso8601String()
          }
        );
      });

      handler.onError((error) {
        debugPrint('Chatbot Paywall error: $error');
        MixpanelService.trackEvent('Chatbot Quota Paywall Error', 
          properties: {'error': error.toString()}
        );
      });

      // Register and show the standard paywall placement
      await Superwall.shared.registerPlacement(
        "INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE",
        handler: handler,
        feature: () async {
          // This runs on successful purchase
          MixpanelService.trackEvent('Chatbot Quota Paywall Purchase Success', 
            properties: {
              'placement': 'INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE',
              'source': 'chatbot_quota_exceeded'
            }
          );
          
          // Reset quotas on successful purchase
          await _quotaService.resetAllQuotas();
          
          debugPrint('✅ Purchase successful via chatbot quota paywall!');
        }
      );
    } catch (e) {
      debugPrint('Error showing paywall: $e');
    }
  }

  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('ChatBot Screen Help & Info Tap');
    
    final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppWebView,
        );
      } else {
        debugPrint('Could not launch help & info URL');
      }
    } catch (e) {
      debugPrint('Error launching help & info URL: $e');
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final bool isInitial;

  ChatMessage({
    required String text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isInitial = false,
  }) : text = TextSanitizer.sanitizeForDisplay(text);
}

class VoiceOnlyModeScreen extends StatefulWidget {
  final Function(String) onSpeechRecognized;
  final VoidCallback onClose;
  final String selectedVoice;

  const VoiceOnlyModeScreen({
    Key? key,
    required this.onSpeechRecognized,
    required this.onClose,
    required this.selectedVoice,
  }) : super(key: key);

  @override
  State<VoiceOnlyModeScreen> createState() => _VoiceOnlyModeScreenState();
}

class _VoiceOnlyModeScreenState extends State<VoiceOnlyModeScreen>
    with SingleTickerProviderStateMixin {
  final _audioRecorder = record.AudioRecorder();
  final _audioPlayer = AudioPlayer();
  String? _recordingPath;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isThinking = false;
  bool _isPlaying = false;
  bool _isPreparingAudio = false; // New state to track audio preparation
  String _responseText = '';
  late AnimationController _animationController;
  bool _isResponseHandled = false;
  
  // Voice options for the selection dialog
  final List<String> _voiceOptions = [
    'alloy',
    'echo',
    'fable',
    'onyx',
    'nova',
    'shimmer'
  ];
  
  final List<String> _voiceDisplayNames = [
    'Alloy',
    'Echo',
    'Fable',
    'Onyx (Deep Male)',
    'Nova',
    'Shimmer'
  ];
  
  // Current selected voice (initialized from parent)
  String _selectedVoice = 'nova';
  
  @override
  void initState() {
    super.initState();
    
    // Track Mixpanel page view for Chatbot Voice Mode
    MixpanelService.trackPageView('Page View Chatbot Voice Mode');
    
    // Initialize with the voice passed from parent
    _selectedVoice = widget.selectedVoice;
    
    // Initialize animation controller for the pulsating effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Configure audio player with better error handling and session management
    _audioPlayer.setReleaseMode(ReleaseMode.stop);  // Ensure resources are released
    
    // Add onPlayerStateChanged to monitor playback more closely with detailed state changes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      print('Player state changed to: $state');
      if (state == PlayerState.completed) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
    
    // Initialize audio player listener - just update the playing state but DON'T return to chat screen
    _audioPlayer.onPlayerComplete.listen((event) {
      print('Audio playback completed in voice-only mode');
      setState(() {
        _isPlaying = false;
      });
      
      // REMOVED: Don't automatically return to chat screen anymore
    });
    
    // Automatically start listening when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
    
    // Force status bar icons to dark mode for light background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for light background
      statusBarBrightness: Brightness.light, // For iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark, // Dark nav bar icons
    ));
    
    // Make app fullscreen and immersive
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    
    // Properly stop and dispose audio resources to prevent leaks
    _audioRecorder.dispose();
    
    // Make sure to stop any ongoing playback first
    _audioPlayer.stop();
    
    // Release resources to avoid memory leaks
    _audioPlayer.release();
    
    // Restore default status bar for light theme
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Keep dark icons for light theme
      statusBarBrightness: Brightness.light, // For iOS
    ));
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    
    super.dispose();
  }
  
  Future<void> _startListening() async {
    // Track Mixpanel mic button tap for Chatbot Voice Mode
    MixpanelService.trackButtonTap('Chatbot Voice mode Mic Tap');
    if (_isListening) {
      // Stop recording
      await _stopListening();
      return;
    }
    
    // Check microphone permission
    if (await _audioRecorder.hasPermission()) {
      // Get the temporary directory for storing recordings
      final directory = await getTemporaryDirectory();
      _recordingPath = '${directory.path}/jarvis_recording.m4a';
      
      // Start recording for speech-to-text transcription with RecordConfig for version 6.0.0
      await _audioRecorder.start(
        const record.RecordConfig(
          encoder: record.AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );
      
      setState(() {
        _isListening = true;
      });
    }
  }
  
  Future<void> _stopListening() async {
    if (!_isListening) return;
    
    // Stop recording
    final path = await _audioRecorder.stop();
    
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _isProcessing = true;
    });
    
    if (path != null) {
      try {
        // Get the recorded audio file
        final file = File(path);
        final bytes = await file.readAsBytes();
        
        // Convert the audio to text using Groq ASR API
        final transcription = await _convertSpeechToText(bytes);
        print('Transcription result: $transcription');
        
        if (transcription.isNotEmpty) {
          // Set thinking state before generating response
          if (!mounted) return;
          setState(() {
            _responseText = transcription;
            _isProcessing = false;
            _isThinking = true;
          });
          
          // Generate the response while in "thinking" state
          final response = await _generateChatResponse(transcription);
          
          // Now ready to convert to speech
          if (!mounted) return;
          setState(() {
            _isThinking = false;
            _isPreparingAudio = true; // Set preparing audio state before converting to speech
          });
          
          // Convert the response to speech
          await _convertTextToSpeech(response);
        } else {
          print('Transcription was empty, not processing further');
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _isThinking = false;
            _isPreparingAudio = false; // Reset preparing flag
          });
        }
      } catch (e) {
        print('Error processing speech to text: $e');
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _isThinking = false;
          _isPreparingAudio = false; // Reset preparing flag
        });
      }
    }
  }
  
  Future<String> _convertSpeechToText(Uint8List audioBytes) async {
    try {
      final groqApiKey = EnvConfig.groqApiKey;
      if (groqApiKey == null || groqApiKey.isEmpty) {
        print('Groq API key is missing');
        return '';
      }

      // Groq ASR API endpoint
      final url = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
      
      // Create a multipart request
      final request = http.MultipartRequest('POST', url);
      
      // Add headers and API key
      request.headers.addAll({'Authorization': 'Bearer $groqApiKey'});
      
      // Add the audio file
      request.files.add(
        http.MultipartFile.fromBytes('file', audioBytes, filename: 'audio.m4a'),
      );
      
      // Use Groq's fast whisper model (turbo for lowest latency, fallback to v3)
      request.fields['model'] = 'whisper-large-v3-turbo';
      
      // Send the request
      final response = await request.send();
      
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final json = jsonDecode(responseBody);
        final text = json['text'] as String?;
        if (text != null && text.isNotEmpty) {
          // Sanitize the transcription result before returning
          return TextSanitizer.sanitizeForDisplay(text);
        }
        // If turbo model fails, try v3 model
        request.fields['model'] = 'whisper-large-v3';
        final retryResponse = await request.send();
        if (retryResponse.statusCode == 200) {
          final retryBody = await retryResponse.stream.bytesToString();
          final retryJson = jsonDecode(retryBody);
          final retryText = retryJson['text'] as String?;
          if (retryText != null && retryText.isNotEmpty) {
            return TextSanitizer.sanitizeForDisplay(retryText);
          }
        }
        return '';
      } else {
        print('Error in Groq speech-to-text: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      print('Error in Groq speech-to-text: $e');
      return '';
    }
  }
  
  Future<String> _generateChatResponse(String userInput) async {
    try {
      // Try to get the user's personal data from SharedPreferences and services
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_first_name') ?? '';
      
      // Get streak data
      final streakService = StreakService();
      final streakData = streakService.currentStreak;
      final streakDays = streakData.days;
      final streakStartDate = streakData.startTime;
      
      // Get achievement data
      final achievementsService = AchievementsService();
      final highestAchievement =
          achievementsService.getHighestUnlockedAchievement();
      final nextAchievementIndex =
          highestAchievement == null
              ? 0
              : achievementsService.achievements.indexWhere(
                    (a) => a.id == highestAchievement.id,
                  ) +
                  1;
      final nextAchievement =
          nextAchievementIndex < achievementsService.achievements.length
          ? achievementsService.achievements[nextAchievementIndex] 
          : null;
      
      // Get goal date (90 days from streak start)
      final goalDateTimestamp = prefs.getInt('target_quit_timestamp');
      final goalDate =
          goalDateTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(goalDateTimestamp) 
              : (streakStartDate != null
                  ? streakStartDate.add(const Duration(days: 90))
                  : null);
      
      // Get reason to quit
      final reasonToQuit = prefs.getString('reason_to_quit') ?? '';
      
      // Get challenge progress
      final challengeStarted = prefs.getBool('challenge_started') ?? false;
      final challengeCurrentDay = prefs.getInt('challenge_current_day') ?? 0;
      final challengePercentage =
          challengeStarted && challengeCurrentDay > 0
          ? challengeCurrentDay / 28 
          : 0.0;
      
      // Get temptation status
      final isTempted = prefs.getBool('is_tempted') ?? false;
      
      // Get consumption tracking data from SharedPreferences
      final consumptionLevel = prefs.getString('consumption_level');
      final sugaryTreatsPerWeek = prefs.getInt('sugar_treats_per_week');
      final treatSize = prefs.getString('treat_size');
      final caloriesPerWeek = prefs.getDouble('calories_per_week');
      final caloriesPerQuarter = prefs.getDouble('calories_per_quarter');
      final caloriesPerYear = prefs.getDouble('calories_per_year');

      // Create a map to hold questionnaire answers from SharedPreferences
      final Map<int, String> questionnaireAnswers = {};

      // Try to load questionnaire data, symptoms, and goals from Firebase
      List<String> symptoms = [];
      List<String> goals = [];
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final questionnaireRepository = QuestionnaireRepository();
        try {
          // Try to get questionnaire answers from Firebase
          final questionnaireData = await questionnaireRepository
              .getQuestionnaireAnswers(currentUser.uid);
          if (questionnaireData != null) {
            questionnaireData.answers.forEach((key, value) {
              final questionNumber = int.tryParse(key.replaceAll('q', ''));
              if (questionNumber != null) {
                questionnaireAnswers[questionNumber] = value;
              }
            });
          }

          // Try to get symptoms from Firebase
          symptoms = await questionnaireRepository.getSymptoms(currentUser.uid);

          // Try to get goals from Firebase
          goals = await questionnaireRepository.getGoals(currentUser.uid);
        } catch (e) {
          print('Error fetching questionnaire data: $e');
        }
      }

      // Get the system prompt using the helper method with the new data
      final systemPrompt = MelindaPromptHelper.getSystemPrompt(
        userName: userName,
        streakDays: streakDays,
        streakStartDate: streakStartDate,
        goalDate: goalDate,
        reasonToQuit: reasonToQuit,
        isTempted: isTempted,
        highestAchievement: highestAchievement,
        nextAchievement: nextAchievement,
        challengeStarted: challengeStarted,
        challengeCurrentDay: challengeCurrentDay,
        challengePercentage: challengePercentage,
        isVoiceResponse: true, // This signals to make responses more voice-friendly
        questionnaireAnswers:
            questionnaireAnswers.isNotEmpty ? questionnaireAnswers : null,
        symptoms: symptoms.isNotEmpty ? symptoms : null,
        goals: goals.isNotEmpty ? goals : null,
        consumptionLevel: consumptionLevel,
        sugaryTreatsPerWeek: sugaryTreatsPerWeek,
        treatSize: treatSize,
        caloriesPerWeek: caloriesPerWeek,
        caloriesPerQuarter: caloriesPerQuarter,
        caloriesPerYear: caloriesPerYear,
        userLanguageCode: prefs.getString('language_code') ?? 'en', // Pass language code
      );
      
      // Initialize Groq API key, handling null safely
      final groqApiKey = EnvConfig.groqApiKey;
      if (groqApiKey == null || groqApiKey.isEmpty) {
        throw Exception('Groq API key is missing or empty');
      }
      
      // Generate a chat response using Groq API
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqApiKey',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-maverick-17b-128e-instruct', // Groq's fast and capable model
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': userInput,
            },
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
      }

      // Extract the bot response
      final responseJson = jsonDecode(response.body);
      final rawResponse = responseJson['choices']?[0]?['message']?['content'] ??
          "I'm sorry, I couldn't generate a response.";
      // Sanitize the response before returning
      return TextSanitizer.sanitizeForDisplay(rawResponse);
    } catch (e) {
      print('Error generating response: $e');
      return "I'm sorry, I encountered an error while processing your request. Please try again.";
    }
  }
  
  Future<void> _convertTextToSpeech(String text) async {
    if (text.isEmpty) return;
    
    // If already playing, stop playback
    if (_isPlaying) {
      await _audioPlayer.stop();
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _isPreparingAudio = false; // Reset preparing flag
      });
      return;
    }
    
    // Set preparing flag to true immediately when user taps on "Play message"
    if (!mounted) return;
    setState(() {
      _isPreparingAudio = true;
    });
    
    try {
      // Set thinking off, but don't set _isPlaying yet
      if (!mounted) return;
      setState(() {
        _isThinking = false;
      });
      
      // Limit text length for TTS to 4000 characters (OpenAI TTS limit)
      final limitedText = text.length > 4000 
          ? TextSanitizer.safeSubstring(text, 0, 4000) 
          : text;
      
      // OpenAI TTS API endpoint (Groq TTS requires terms acceptance)
      final url = Uri.parse('https://api.openai.com/v1/audio/speech');
      
      // Request payload
      final payload = jsonEncode({
        'model': 'tts-1-hd',
        'input': limitedText,
        'voice': _selectedVoice,
      });
      
      // Make the TTS API request
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${EnvConfig.openaiApiKey}',
          'Content-Type': 'application/json',
        },
        body: payload,
      );
      
      if (response.statusCode == 200) {
        // Get the temporary directory
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/jarvis_response.mp3';
        
        // Write the audio data to a file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Verify file was written correctly
        final fileSize = file.lengthSync();
        print('Audio file created at: $filePath with size: $fileSize bytes');
        
        if (fileSize == 0) {
          throw Exception('Audio file is empty');
        }
        
        // Reset player before new playback
        await _audioPlayer.stop();
        
        // Set volume to maximum
        await _audioPlayer.setVolume(1.0);
        
        // Use try-catch for playback to handle potential interruptions
        try {
          // Play the audio and wait for it to start
          await _audioPlayer.play(DeviceFileSource(filePath));
          print('Audio playback started');
          
          // NOW set _isPlaying to true AFTER audio playback has started
          if (!mounted) return;
          setState(() {
            _isPlaying = true;
            _isPreparingAudio = false; // Reset preparing flag now that we're playing
          });
        } catch (playbackError) {
          print('Playback error: $playbackError');
          if (!mounted) return;
          setState(() {
            _isPlaying = false;
            _isPreparingAudio = false; // Reset preparing flag on error
          });
        }
      } else {
        print(
          'Error converting text to speech: ${response.statusCode} - ${utf8.decode(response.bodyBytes, allowMalformed: true)}',
        );
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _isPreparingAudio = false; // Reset preparing flag
        });
      }
    } catch (e) {
      print('Error in text-to-speech: $e');
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _isPlaying = false;
        _isPreparingAudio = false; // Reset preparing flag on error
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for light background
        statusBarBrightness: Brightness.light, // For iOS
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark, // Dark nav bar icons
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB), // Subtle neutral white background (preferred)
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // Dark icons for light background
            statusBarBrightness: Brightness.light, // For iOS
          ),
          actions: [
            // Add voice selection button
            IconButton(
              icon: const Icon(Icons.record_voice_over, color: Color(0xFFed3272)), // Brand pink
              tooltip: AppLocalizations.of(context)!.translate('chatbot_changeVoice'),
              onPressed: _showVoiceSelectionDialog,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Color(0xFF666666)), // Gray for secondary action
              onPressed: () {
                // Show info dialog
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                    backgroundColor: Colors.white, // White background for dialog
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    title: const Text(
                      'Voice Chat Mode',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A), // Dark text
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'ElzaRound',
                      ),
                    ),
                    content: const Text(
                      'Speak to Melinda by tapping the microphone. Your voice will be transcribed and Melinda will respond with voice. Press X to return to text chat.',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A), // Dark text
                        fontSize: 16,
                        fontFamily: 'ElzaRound',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Got it',
                          style: TextStyle(
                            color: Color(0xFFed3272), // Brand pink
                            fontFamily: 'ElzaRound',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)), // Dark close button
              onPressed: () {
                // Stop any current audio playback before returning to chat screen
                _audioPlayer.stop();
                setState(() {
                  _isPlaying = false;
                  _isPreparingAudio = false;
                });
                widget.onSpeechRecognized(_responseText);
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Instructional text for voice mode
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Text(
                  AppLocalizations.of(context)?.translate('chatbot_voiceOnly_instruction') ?? 'Speak to Melinda using voice',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF666666), // Gray secondary text
                    fontSize: 16,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              // Voice visualization - animated orb that responds to voice
              SizedBox(
                width: 300,
                height: 300,
                child: Lottie.asset(
                  'assets/images/lotties/chatbot-orb-2.json',
                  animate: _isListening || _isPlaying || _isThinking || _isPreparingAudio,
                  repeat: true,
                  fit: BoxFit.contain,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Status text - updated to include thinking phase
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  String statusText;
                  
                  if (_isListening) {
                    statusText = localizations?.translate('chatbot_voiceOnly_statusListening') ?? 'Listening...';
                  } else if (_isProcessing) {
                    statusText = localizations?.translate('chatbot_voiceOnly_statusProcessing') ?? 'Processing...';
                  } else if (_isThinking) {
                    statusText = localizations?.translate('chatbot_voiceOnly_statusThinking') ?? 'Thinking...';
                  } else if (_isPreparingAudio) {
                    statusText = localizations?.translate('chatbot_voiceOnly_statusPreparingAudio') ?? 'Preparing audio...';
                  } else if (_isPlaying) {
                    statusText = localizations?.translate('chatbot_voiceOnly_statusSpeaking') ?? 'Speaking...';
                  } else {
                    statusText = localizations?.translate('chatbot_voiceOnly_statusTapToSpeak') ?? 'Tap to speak';
                  }
                  
                  return Text(
                    statusText,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A), // Dark primary text
                      fontSize: 20,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 10),
              
              // Voice indicator 
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.record_voice_over,
                    color: Color(0xFFed3272), // Brand pink
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Voice: ${_getVoiceDisplayName()}',
                    style: const TextStyle(
                      color: Color(0xFFed3272), // Brand pink
                      fontSize: 14,
                fontFamily: 'ElzaRound',
              ),
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _isProcessing || _isPlaying ? null : _startListening,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: _isListening 
                        ? null 
                        : const LinearGradient( // Use gradient when not listening
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFed3272), // Brand pink
                              Color(0xFFfd5d32), // Brand orange
                            ],
                          ),
                      color: _isListening ? const Color(0xFFed3272) : null, // Brand pink when listening
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFed3272).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white, // White icon on colored background
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show voice selection dialog
  void _showVoiceSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // White background for dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Voice',
                style: TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'ElzaRound',
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Choose your preferred voice',
                style: TextStyle(
                  color: Color(0xFF666666), // Gray secondary text
                  fontSize: 14,
                  fontFamily: 'ElzaRound',
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  _voiceOptions.length,
                  (index) => RadioListTile<String>(
                    title: Text(
                      _voiceDisplayNames[index],
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A), // Dark text
                        fontFamily: 'ElzaRound',
                      ),
                    ),
                    value: _voiceOptions[index],
                    groupValue: _selectedVoice,
                    onChanged: (value) {
                      setState(() {
                        _selectedVoice = value!;
                      });
                      Navigator.of(context).pop();
                      
                      // Play a sample to let the user hear the selected voice
                      _playVoiceSample();
                    },
                    activeColor: const Color(0xFFed3272), // Brand pink
                    fillColor: MaterialStateProperty.resolveWith<Color>((
                      Set<MaterialState> states,
                    ) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFFed3272); // Brand pink
                      }
                      return const Color(0xFF666666); // Gray text
                    }),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFFed3272), // Brand pink
                  fontFamily: 'ElzaRound',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Play a sample of the selected voice
  Future<void> _playVoiceSample() async {
    const sampleText = "Hello, I'm Melinda. I'll help with your sugar addiction recovery.";
    await _convertTextToSpeech(sampleText);
  }

  // Helper method to get the display name for the selected voice
  String _getVoiceDisplayName() {
    final index = _voiceOptions.indexOf(_selectedVoice);
    if (index != -1) {
      return _voiceDisplayNames[index];
    }
    return 'Alloy'; // Default
  }
} 