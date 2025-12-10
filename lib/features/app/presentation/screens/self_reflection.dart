import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui; // Import for ImageFilter
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:camera/camera.dart';
import 'home_screen.dart';
// import 'relapsed_screen.dart.old'; // Removed
// import 'thinking_relapsing_screen.dart.old'; // Removed
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import 'main_scaffold.dart';
import '../../../../main.dart'; // Import to access global cameras list
import '../../../../permissions/permission_service.dart'; // Import the permission service
import '../../../../core/localization/app_localizations.dart'; // Added import
import 'panic_button/breathing_animation_screen.dart'; // Added import for BreathingAnimationScreen
import '../../../../core/utils/text_sanitizer.dart';

class SelfReflectionScreen extends StatefulWidget {
  const SelfReflectionScreen({super.key});

  @override
  State<SelfReflectionScreen> createState() => _SelfReflectionScreenState();
}

class _SelfReflectionScreenState extends State<SelfReflectionScreen> with SingleTickerProviderStateMixin {
  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  Timer? _typingTimer;
  String? _firstName;
  String? _userGender; // Add variable to store user gender
  String _displayedText = "";
  int _currentCharIndex = 0;
  bool _isTypingComplete = false;
  
  // Camera-related properties
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  final PermissionService _permissionService = PermissionService();
  
  // Multiple sets of messages for random selection - NOW KEYS
  final List<List<String>> _allMessageSets = List.generate(13, (setIndex) => 
    List.generate(8, (msgIndex) => "panic_messageSet${setIndex + 1}_text${msgIndex + 1}")
  );
  
  // Currently active set of message KEYS
  late List<String> _baseMessages;
  
  // Generated messages with personalization
  late List<String> _messages;
  
  // Base side effects list without gender-specific items
  final List<Map<String, String>> _baseSideEffects = [
    // Titles and descriptions are now KEYS
    {
      'titleKey': 'panic_sideEffect_weightGain_title',
      'descriptionKey': 'panic_sideEffect_weightGain_description',
      // Icon remains as is
    },
    {
      'titleKey': 'panic_sideEffect_acne_title',
      'descriptionKey': 'panic_sideEffect_acne_description',
    },
    {
      'titleKey': 'panic_sideEffect_energyCrash_title',
      'descriptionKey': 'panic_sideEffect_energyCrash_description',
    },
    {
      'titleKey': 'panic_sideEffect_intensifiedCravings_title',
      'descriptionKey': 'panic_sideEffect_intensifiedCravings_description',
    },
    {
      'titleKey': 'panic_sideEffect_moodSwings_title',
      'descriptionKey': 'panic_sideEffect_moodSwings_description',
    },
    {
      'titleKey': 'panic_sideEffect_poorSleep_title',
      'descriptionKey': 'panic_sideEffect_poorSleep_description',
    },
    {
      'titleKey': 'panic_sideEffect_brainFog_title',
      'descriptionKey': 'panic_sideEffect_brainFog_description',
    },
    {
      'titleKey': 'panic_sideEffect_prematureAging_title',
      'descriptionKey': 'panic_sideEffect_prematureAging_description',
    },
    {
      'titleKey': 'panic_sideEffect_inflammation_title',
      'descriptionKey': 'panic_sideEffect_inflammation_description',
    },
    {
      'titleKey': 'panic_sideEffect_bloodSugarSpikes_title',
      'descriptionKey': 'panic_sideEffect_bloodSugarSpikes_description',
    },
  ];
  
  // Male-specific side effects - NOW KEYS
  final List<Map<String, String>> _maleOnlySideEffects = [
    {
      'titleKey': 'panic_sideEffect_male_lowTestosterone_title',
      'descriptionKey': 'panic_sideEffect_male_lowTestosterone_description',
    },
    {
      'titleKey': 'panic_sideEffect_male_erectileIssues_title',
      'descriptionKey': 'panic_sideEffect_male_erectileIssues_description',
    },
    {
      'titleKey': 'panic_sideEffect_male_fertilityProblems_title',
      'descriptionKey': 'panic_sideEffect_male_fertilityProblems_description',
    },
  ];
  
  // Female-specific side effects - NOW KEYS
  final List<Map<String, String>> _femaleOnlySideEffects = [
    {
      'titleKey': 'panic_sideEffect_female_hormonalImbalance_title',
      'descriptionKey': 'panic_sideEffect_female_hormonalImbalance_description',
    },
    {
      'titleKey': 'panic_sideEffect_female_menstrualProblems_title',
      'descriptionKey': 'panic_sideEffect_female_menstrualProblems_description',
    },
    {
      'titleKey': 'panic_sideEffect_female_fertilityIssues_title',
      'descriptionKey': 'panic_sideEffect_female_fertilityIssues_description',
    },
  ];
  
  // Final side effects list that will be displayed (will hold objects with IconData and localized Strings)
  late List<Map<String, dynamic>> _displayableSideEffects;

  // Add a flag for TestFlight mode
  bool _isTestFlight = false;
  // Add roast sentences for TestFlight mode
  static const List<String> _roastSentences = [
    "Like chocolate in the sun, that willpower just melts away.",
    "Breaking news: Self-control still missing in action.",
    "Plot twist: These cravings have better drama than a soap opera.",
    "Even the phone is judging you right now.",
    "TikTok called, they want their drama back.",
    "Loading... buffering... oh wait, that's just the self-control.",
    "Netflix has fewer plot twists than this relapse history.",
    "If only cravings burned calories - hello six-pack!",
    "Mirror mirror on the wall, who's the snackiest of them all?",
    "Time for another treat? The universe just facepalmed.",
    "Opened the app, but willpower's still on vacation.",
    "That fitness tracker is getting second-hand embarrassment.",
    "This sugar-free journey? More twists than a rollercoaster.",
    "January: Resolution strong. February: Resolution gone.",
    "Phone batteries last longer than these streaks.",
    "These cravings are more persistent than spam callers.",
    "KitKat has fewer breaks than this streak.",
    "Monday: Diet begins. Tuesday: Diet who?",
    "Houston, we have a self-control problem.",
    "Rocky had fewer comebacks than these cravings.",
    "Paying for that gym membership? Same energy as this willpower.",
    "GPS has fewer detours than this sugar-free journey.",
    "Weather forecasts are more reliable than this self-control.",
    "Soap operas are more predictable than these cravings.",
    "Diet soda: present but unsatisfying - just like willpower.",
    "Teenagers remember homework better than this streak remembers consistency.",
    "New Year's parties last longer than this self-control.",
    "Phone notifications are less frequent than these cravings.",
    "Hunger strikes, diet plan surrenders.",
    "Windows updates crash less than this journey restarts.",
    "If cravings were a sport, you'd be an Olympic gold medalist.",
    "Your sweet tooth has its own gym membership.",
    "Even autocorrect can't fix these cravings.",
    "If willpower was WiFi, you'd be stuck on 1 bar.",
    "Your cravings have more plot armor than a TV main character.",
    "If only you could unsubscribe from sugar cravings.",
    "Your snack breaks have snack breaks.",
    "If self-control was a currency, you'd be bankrupt.",
    "Even your shadow is running from these cravings.",
    "If there was a loyalty card for relapses, you'd have a free dessert by now.",
    "Your cravings are more dramatic than reality TV.",
    "If sugar was a friend, it would be the toxic one.",
    "Your willpower is on a coffee break... permanently.",
    "If cravings were emails, your inbox would be full.",
    "Your sweet tooth is running the show.",
    "If only you could block cravings like spam calls.",
    "Your diet plan is on the endangered species list.",
    "If self-control was a phone battery, you'd need a charger.",
    "Your cravings are more persistent than software updates.",
    "If willpower was a Netflix series, it would've been cancelled after one season.",
    "Your snack stash has its own zip code.",
    "If cravings were rain, you'd need an umbrella every day.",
    "Your cheat days have unionized.",
    "If only you could mute your sweet tooth.",
    "Your cravings are trending—#NoFilter.",
    "If willpower was a password, you'd have forgotten it.",
    "Your snack game is undefeated.",
    "If cravings were a playlist, you'd be on repeat.",
    "Your sweet tooth is writing its own autobiography.",
    "If only you could put your cravings on airplane mode.",
    "Your willpower is buffering... please wait.",
    "If cravings were a movie, you'd be the star.",
    "Your snack drawer is a national landmark.",
    "If self-control was a weather forecast, expect scattered cravings.",
    "Your sweet tooth is the boss level.",
    "If cravings were a marathon, you'd be the pacer.",
    "Your willpower is on a sabbatical.",
    "If only you could uninstall cravings.",
    "Your snack attacks are breaking records.",
    "If willpower was a superhero, it needs a reboot.",
    "Your cravings are writing their own sequel.",
    "If only you could ghost your sweet tooth.",
    "Your snack choices are making headlines.",
    "If cravings were a meme, you'd be viral.",
    "Your willpower is on silent mode.",
    "If only you could swipe left on sugar.",
    "Your cravings are the plot twist no one asked for.",
    "If self-control was a vacation, you'd be out of office.",
    "Your sweet tooth is running for president.",
    "If cravings were a group chat, you'd be the admin.",
    "Your snack breaks are on a world tour.",
    "If willpower was a game, you'd be stuck on level one.",
    "Your cravings are writing their own fan fiction.",
    "If only you could put your sweet tooth in time-out.",
    "Your snack stash is legendary.",
    "If cravings were a trend, you'd be the influencer.",
    "Your willpower is on a coffee run.",
    "If only you could unsubscribe from cheat days.",
    "Your cravings are the main character.",
    "If self-control was a playlist, you'd be on shuffle.",
    "Your sweet tooth is the plot device.",
    "If cravings were a challenge, you'd be the champion.",
    "Your snack breaks are breaking the internet.",
    "If willpower was a currency, you'd be in debt.",
    "Your cravings are the season finale.",
    "If only you could put your sweet tooth on do not disturb.",
    "Your snack game is next level.",
    "If cravings were a sport, you'd be the MVP.",
    "Your willpower is on vacation.",
    "If only you could block cheat days.",
    "Your cravings are the plot twist of the year.",
    "If self-control was a trend, you'd be retro.",
    "Your sweet tooth is the director.",
    "If cravings were a playlist, you'd be the DJ.",
    "Your snack breaks are the highlight reel.",
    "If willpower was a story, you'd be in the prologue.",
    "Your cravings are the cliffhanger.",
    "If only you could mute cheat days.",
    "Your snack stash is the treasure chest.",
    "If cravings were a movie, you'd be the sequel.",
    "Your willpower is the plot hole.",
    "If only you could fast-forward cravings.",
    "Your cravings are the encore.",
    "If self-control was a meme, you'd be the punchline.",
    "Your sweet tooth is the narrator.",
    "If cravings were a challenge, you'd be undefeated.",
    "Your snack breaks are the blooper reel.",
    "If willpower was a password, you'd need a reset.",
    "Your cravings are the main event.",
    "If only you could put your sweet tooth on pause.",
    "Your snack game is legendary.",
    "If cravings were a trend, you'd be the trendsetter.",
    "Your willpower is on airplane mode.",
    "If only you could block snack time.",
    "Your cravings are the plot twist of the century.",
    "If self-control was a playlist, you'd be on repeat.",
    "Your sweet tooth is the main character.",
    "If cravings were a sport, you'd be the all-star.",
    "Your snack breaks are the afterparty.",
    "If willpower was a story, you'd be the footnote.",
    "Your cravings are the grand finale.",
    "If only you could mute snack time.",
    "Your snack stash is the legend.",
    "If cravings were a movie, you'd be the trilogy.",
    "Your willpower is the deleted scene.",
    "If only you could fast-forward snack time.",
    "Your cravings are the encore performance.",
    "If self-control was a meme, you'd be the template.",
    "Your sweet tooth is the plot twist.",
    "If cravings were a challenge, you'd be the record holder.",
    "Your snack breaks are the director's cut.",
    "If willpower was a password, you'd be locked out.",
    "Your cravings are the headline.",
    "If only you could put your sweet tooth on snooze.",
    "Your snack game is the gold standard.",
    "If cravings were a trend, you'd be the icon.",
    "Your willpower is on silent.",
    "If only you could block snack cravings.",
    "Your cravings are the plot twist of the decade.",
    "If self-control was a playlist, you'd be the hidden track.",
    "Your sweet tooth is the legend.",
    "If cravings were a sport, you'd be the hall of famer.",
    "Your snack breaks are the encore.",
    "If willpower was a story, you'd be the epilogue.",
    "Your cravings are the final boss.",
    "If only you could mute snack cravings.",
    "Your snack stash is the myth.",
    "If cravings were a movie, you'd be the blockbuster.",
    "Your willpower is the outtake.",
    "If only you could fast-forward snack cravings.",
    "Your cravings are the standing ovation.",
    "If self-control was a meme, you'd be the classic.",
    "Your sweet tooth is the twist ending.",
    "If cravings were a challenge, you'd be the undefeated champ.",
    "Your snack breaks are the after credits.",
    "If willpower was a password, you'd be the hint.",
    "Your cravings are the headline act.",
    "If only you could put your sweet tooth on airplane mode.",
    "Your snack game is the legend continues.",
    "If cravings were a trend, you'd be the legend.",
    "Your willpower is on do not disturb.",
    "If only you could block snack attacks.",
    "Your cravings are the plot twist of the millennium.",
    "If self-control was a playlist, you'd be the bonus track.",
    "Your sweet tooth is the legend lives on.",
    "If cravings were a sport, you'd be the all-time great.",
    "Your snack breaks are the encore performance.",
    "If willpower was a story, you'd be the legend.",
    "Your cravings are the final act.",
    "If only you could mute snack attacks.",
    "Your snack stash is the legend grows.",
    "If cravings were a movie, you'd be the legend returns.",
    "Your willpower is the lost episode.",
    "If only you could fast-forward snack attacks.",
    "Your cravings are the curtain call.",
    "If self-control was a meme, you'd be the legend.",
    "Your sweet tooth is the legend reborn.",
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize side effects list (will be populated in _loadUserInfo -> _updateSideEffects)
    _displayableSideEffects = []; // Initialize to empty
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Page View Self-Reflection');
    
    // Select a random message set
    _selectRandomMessageSet();
    
    // Initialize messages array with placeholder
    _messages = List.from(_baseMessages);
    
    // Load the user's first name and gender
    _loadUserInfo();
    
    // Initialize camera
    _initializeCamera();
    
    // Force status bar icons to dark mode for light background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for light background
      statusBarBrightness: Brightness.light, // For iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    
    // Make app fullscreen and immersive
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );

    // Check for TestFlight mode
    MixpanelService.isTestFlight().then((isTestFlight) {
      if (mounted) {
        setState(() {
          _isTestFlight = isTestFlight;
        });
        if (_isTestFlight) {
          // Use roast sentences in TestFlight mode, shuffled
          final shuffledRoasts = List<String>.from(_roastSentences);
          shuffledRoasts.shuffle();
          _messages = shuffledRoasts;
          _startTypingAnimation();
        }
      }
    });
  }
  
  // Select a random message set from the available sets
  void _selectRandomMessageSet() {
    final random = Random();
    final randomIndex = random.nextInt(_allMessageSets.length);
    _baseMessages = _allMessageSets[randomIndex];
  }
  
  // Load the user's information from SharedPreferences
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString('user_first_name');
    final gender = prefs.getString('user_gender');
    
    if (mounted) {
      final l10n = AppLocalizations.of(context)!; 
      setState(() {
        _firstName = firstName;
        _userGender = gender;
        
        _updateSideEffects(l10n);
        _updatePersonalizedMessages(l10n);
      });
      // Start typing animation now that messages and l10n are ready
      _startTypingAnimation(); 
    }
  }
  
  // Update side effects based on user gender
  void _updateSideEffects(AppLocalizations l10n) { // Pass l10n
    final List<Map<String, dynamic>> updatedSideEffects = [];

    for (var effectKeyMap in _baseSideEffects) {
      updatedSideEffects.add({
        'title': l10n.translate(effectKeyMap['titleKey']!),
        'description': l10n.translate(effectKeyMap['descriptionKey']!),
        'icon': (_baseSideEffectsData.firstWhere((d) => d['titleKey'] == effectKeyMap['titleKey'], orElse: () => {})['icon'] ?? Icons.error)
      });
    }

    if (_userGender?.toLowerCase() == 'male') {
      for (var effectKeyMap in _maleOnlySideEffects) {
         updatedSideEffects.add({
           'title': l10n.translate(effectKeyMap['titleKey']!),
           'description': l10n.translate(effectKeyMap['descriptionKey']!),
           'icon': (_maleOnlySideEffectsData.firstWhere((d) => d['titleKey'] == effectKeyMap['titleKey'], orElse: () => {})['icon'] ?? Icons.error)
         });
      }
    } else if (_userGender?.toLowerCase() == 'female') {
      for (var effectKeyMap in _femaleOnlySideEffects) {
         updatedSideEffects.add({
           'title': l10n.translate(effectKeyMap['titleKey']!),
           'description': l10n.translate(effectKeyMap['descriptionKey']!),
           'icon': (_femaleOnlySideEffectsData.firstWhere((d) => d['titleKey'] == effectKeyMap['titleKey'], orElse: () => {})['icon'] ?? Icons.error)
         });
      }
    }
    
    setState(() {
      _displayableSideEffects = updatedSideEffects;
    });
  }
  
  // Helper to map original icon data since it's not part of the key map
  static final List<Map<String, dynamic>> _baseSideEffectsData = [
    {'titleKey': 'panic_sideEffect_weightGain_title', 'icon': Icons.monitor_weight},
    {'titleKey': 'panic_sideEffect_acne_title', 'icon': Icons.face},
    {'titleKey': 'panic_sideEffect_energyCrash_title', 'icon': Icons.battery_alert},
    {'titleKey': 'panic_sideEffect_intensifiedCravings_title', 'icon': Icons.no_food},
    {'titleKey': 'panic_sideEffect_moodSwings_title', 'icon': Icons.mood_bad},
    {'titleKey': 'panic_sideEffect_poorSleep_title', 'icon': Icons.bedtime},
    {'titleKey': 'panic_sideEffect_brainFog_title', 'icon': Icons.psychology},
    {'titleKey': 'panic_sideEffect_prematureAging_title', 'icon': Icons.access_time},
    {'titleKey': 'panic_sideEffect_inflammation_title', 'icon': Icons.whatshot},
    {'titleKey': 'panic_sideEffect_bloodSugarSpikes_title', 'icon': Icons.show_chart},
  ];
  static final List<Map<String, dynamic>> _maleOnlySideEffectsData = [
    {'titleKey': 'panic_sideEffect_male_lowTestosterone_title', 'icon': Icons.fitness_center},
    {'titleKey': 'panic_sideEffect_male_erectileIssues_title', 'icon': Icons.trending_down},
    {'titleKey': 'panic_sideEffect_male_fertilityProblems_title', 'icon': Icons.family_restroom},
  ];
  static final List<Map<String, dynamic>> _femaleOnlySideEffectsData = [
    {'titleKey': 'panic_sideEffect_female_hormonalImbalance_title', 'icon': Icons.balance},
    {'titleKey': 'panic_sideEffect_female_menstrualProblems_title', 'icon': Icons.calendar_today},
    {'titleKey': 'panic_sideEffect_female_fertilityIssues_title', 'icon': Icons.family_restroom},
  ];

  // Update messages with the user's first name
  void _updatePersonalizedMessages(AppLocalizations l10n) { // Pass l10n
    _messages = _baseMessages.map((messageKey) { // message is now a key
      String translatedMessage = l10n.translate(messageKey);
      if (_firstName != null && _firstName!.isNotEmpty) {
        // Sanitize firstName before using it in text replacement
        final sanitizedFirstName = TextSanitizer.sanitizeForDisplay(_firstName!.toUpperCase());
        return translatedMessage.replaceAll('{firstName}', sanitizedFirstName);
      } else {
        return translatedMessage.replaceAll(', {firstName}', '').replaceAll('{firstName}', l10n.translate('common_you_placeholder')); // Use a placeholder key
      }
    }).toList();
    
    // Restart typing animation with the new messages
    _startTypingAnimation();
  }

  void _startTypingAnimation() {
    // Reset typing state
    _isTypingComplete = false;
    _currentCharIndex = 0;
    _displayedText = "";
    
    // Cancel previous timers if any
    _typingTimer?.cancel();
    _messageTimer?.cancel();
    
    // Start typing the first message
    _typeCurrentMessage();
  }
  
  void _typeCurrentMessage() {
    final l10n = AppLocalizations.of(context)!; // Get l10n here
    final currentMessageKey = _messages[_currentMessageIndex]; // _messages now holds keys
    // The actual text to display character by character will be the key itself,
    // but the final translation happens in the Text widget in build method.
    // For the typing effect, we use the key or a placeholder if it has {firstName}.
    String textForTypingEffect = currentMessageKey;
    if (_firstName != null && _firstName!.isNotEmpty) {
      // Sanitize firstName before using it in text replacement
      final sanitizedFirstName = TextSanitizer.sanitizeForDisplay(_firstName!.toUpperCase());
      textForTypingEffect = textForTypingEffect.replaceAll('{firstName}', sanitizedFirstName);
    } else {
      textForTypingEffect = textForTypingEffect.replaceAll(', {firstName}', '').replaceAll('{firstName}', l10n.translate('common_you_placeholder'));
    }

    _typingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_currentCharIndex < textForTypingEffect.length) {
        setState(() {
          _displayedText = textForTypingEffect.substring(0, _currentCharIndex + 1);
          _currentCharIndex++;
        });
      } else {
        timer.cancel();
        _isTypingComplete = true;
        
        // After completing typing, wait before showing next message
        _messageTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _currentMessageIndex = (_currentMessageIndex + 1) % _messages.length;
              _startTypingAnimation();
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _typingTimer?.cancel();
    
    // Dispose of camera controller if initialized
    _cameraController?.dispose();
    
    // Restore default status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for light background
      statusBarBrightness: Brightness.light, // For iOS
    ));
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Added l10n
    // Calculate bottom padding to ensure content isn't hidden behind buttons
    final bottomButtonsHeight = 140.0 + MediaQuery.of(context).padding.bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for light background
        statusBarBrightness: Brightness.light, // For iOS
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF8FA), // Soft pink-tinted white background per brand guidelines
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)), // Dark icon for light background
            onPressed: () => Navigator.of(context).pushReplacement(
              TopToBottomPageRoute(
                child: const MainScaffold(initialIndex: 0),
                settings: const RouteSettings(name: '/home'),
              ),
            ),
          ),
          title: const Text(
            'STOPPR',
            style: TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for light background
              fontSize: 32, // Bigger size
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
          actions: [
            // Help & Info icon
            IconButton(
              icon: const Icon(
                Icons.help_outline,
                color: Color(0xFF1A1A1A), // Dark icon for light background
                size: 28,
              ),
              onPressed: _openMedicalInfo,
              tooltip: l10n.translate('pledgeScreen_tooltip_help'), // Reused tooltip
            ),
          ],
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // Dark icons for light background
            statusBarBrightness: Brightness.light, // For iOS
          ),
        ),
        body: Stack(
          children: [
            // Scrollable content
            SafeArea(
              bottom: false, // Important: don't add safe area at bottom to allow sticky buttons
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: bottomButtonsHeight, // Add padding to prevent content from going behind sticky buttons
                ),
                children: [
                  const SizedBox(height: 20),
                  // Title
                  Text(
                    l10n.translate('selfReflectionScreen_title'), // Using localization key
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A), // Dark text for light background
                      fontSize: 20,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Camera preview with text overlay
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    width: double.infinity,
                    height: MediaQuery.of(context).size.width * 1.5 / 1.5, // Reduced height ratio 4:3 instead of 16:9
                    decoration: BoxDecoration(
                      color: Colors.white, // White background for card per brand guidelines
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFed3272).withOpacity(0.2), // Brand pink border
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildCameraPreview(),
                          // Motivational or roast text with blurry background at bottom
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 16,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12.0),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                                                                      child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7), // Slightly stronger overlay for better text contrast
                                      ),
                                    child: Text(
                                      _isTestFlight
                                        ? (_isTypingComplete ? _messages[_currentMessageIndex] : _displayedText)
                                        : (_isTypingComplete ? l10n.translate(_messages[_currentMessageIndex]).replaceAll('{firstName}', TextSanitizer.sanitizeForDisplay(_firstName ?? l10n.translate('common_you_placeholder'))) : _displayedText),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontFamily: 'ElzaRound',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Side effects section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child:                         Text(
                          l10n.translate('panicButtonScreen_sideEffectsTitle'), // Localized
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A), // Dark text for light background
                            fontSize: 16,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white, // White background for card per brand guidelines
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFed3272).withOpacity(0.2), // Brand pink border
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: _displayableSideEffects.map((effect) => _buildSideEffectRow(
                            title: effect['title']! as String,
                            description: effect['description']! as String,
                            icon: effect['icon']! as IconData,
                          )).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Sticky buttons at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20, 
                  16, 
                  20, 
                  MediaQuery.of(context).padding.bottom + 20
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF8FA), // Match main background
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        MixpanelService.trackButtonTap('Button Tap Self-Reflection I\'m thinking of relapsing', screenName: 'Self Reflection Screen');
                        Navigator.of(context).pushReplacement(
                          BottomToTopPageRoute(
                            child: const BreathingAnimationScreen(),
                            settings: const RouteSettings(name: '/panic_breathing'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ).copyWith(
                        backgroundColor: MaterialStateProperty.resolveWith((states) {
                          return Colors.transparent;
                        }),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFed3272), // Brand pink
                              Color(0xFFfd5d32), // Brand orange
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    l10n.translate('selfReflectionScreen_thinkingOfRelapsingButton'),
                                    style: const TextStyle(
                                      color: Colors.white, // White text on gradient button
                                      fontFamily: 'ElzaRound',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build camera preview or fallback image widget
  Widget _buildCameraPreview() {
    final l10n = AppLocalizations.of(context)!; // Added l10n here
    // In TestFlight mode, always use the camera (not the cinnamonbun image)
    if (_isTestFlight) {
      if (_isCameraInitialized && _isCameraPermissionGranted && _cameraController != null) {
        return Transform.scale(
          scale: 1.1,
          child: Center(
            child: CameraPreview(_cameraController!),
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isCameraPermissionGranted)
              const Text(
                'Camera permission denied. TikTok will be disappointed.',
                style: TextStyle(color: Color(0xFF1A1A1A)), // Dark text for light background
              )
            else
              const CircularProgressIndicator(color: Color(0xFFed3272)), // Brand pink loading indicator
            const SizedBox(height: 8),
            const Text(
              'Loading front camera for your roast...',
              style: TextStyle(color: Color(0xFF666666)), // Secondary gray text
            ),
          ],
        ),
      );
    }
    // If on simulator or debug mode, show the pizza image
    if (kDebugMode) {
      return Image(
        image: AssetImage('assets/images/cinnamonbun.jpg'),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey),
      );
    }
    
    // If camera is initialized, show camera preview
    if (_isCameraInitialized && _isCameraPermissionGranted && _cameraController != null) {
      return Transform.scale(
        scale: 1.1, // Slightly zoom in to better fill the container
        child: Center(
          child: CameraPreview(_cameraController!),
        ),
      );
    }
    
    // Otherwise show a loading indicator or permission message
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_isCameraPermissionGranted)
            Text(
              l10n.translate('panicButtonScreen_camera_permissionDenied'), // Localized
              style: const TextStyle(color: Color(0xFF1A1A1A)), // Dark text for light background
            )
          else
            const CircularProgressIndicator(color: Color(0xFFed3272)), // Brand pink loading indicator
          const SizedBox(height: 8),
          Text(
            l10n.translate('panicButtonScreen_camera_loading'), // Localized
            style: const TextStyle(color: Color(0xFF666666)), // Secondary gray text
          ),
        ],
      ),
    );
  }
  
  Widget _buildSideEffectRow({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFFed3272), // Brand pink for icons
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A), // Dark text for light background
                    fontSize: 16,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF666666), // Secondary gray text
                    fontSize: 14,
                    fontFamily: 'ElzaRound',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Button Tap Self-Reflection Help & Info', screenName: 'Self Reflection Screen');
    
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

  // Initialize camera
  Future<void> _initializeCamera() async {
    // Skip camera initialization if on simulator or debug mode
    if (kDebugMode) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = true; // Consider it initialized to show fallback
        });
      }
      return;
    }
    
    // Check camera permission
    bool hasPermission = await _permissionService.isCameraGranted();
    
    if (!hasPermission) {
      // Track when the permission dialog is about to be shown
      MixpanelService.trackEvent('Panic ButtonFront Camera Permission Launched');
      MixpanelService.setUserProfileProperty('Panic Button Front Camera Permission Status', 'Not Granted');
      // Request permission
      hasPermission = await _permissionService.requestCameraPermission();
    }
    
    if (mounted) {
      setState(() {
        _isCameraPermissionGranted = hasPermission;
      });
    }
    
    if (!hasPermission || cameras.isEmpty) {
      MixpanelService.setUserProfileProperty('Panic Button Front Camera Permission Status', 'Denied');
      debugPrint('Camera permission denied or no cameras available');
      return;
    }
    
    // If permission was granted (either initially or after request)
    MixpanelService.trackEvent('Panic Button Front Camera Permission Accepted');
    MixpanelService.setUserProfileProperty('Panic Button Front Camera Permission Status', 'Accepted');
    
    try {
      // Find front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Medium quality for better performance
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<List<Map<String, dynamic>>>('_displayableSideEffects', _displayableSideEffects));
  }
} 