import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for haptic feedback
import 'package:stoppr/features/onboarding/domain/models/question_model.dart';
import 'package:stoppr/features/onboarding/presentation/screens/question_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_screen4.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_screen5_radar.dart';
import 'package:stoppr/features/onboarding/presentation/screens/weeks_progression_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/profile_info_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/symptoms_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/consumption_summary_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/sugar_progress_break_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/main.dart'; // Import for MyApp.setLocale
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:stoppr/features/onboarding/presentation/screens/widgets/onboarding_sound_toggle.dart';
import 'package:stoppr/features/onboarding/presentation/screens/widgets/onboarding_language_selector.dart';
import 'package:flutter_animate/flutter_animate.dart';

class QuestionnaireScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final int currentQuestionIndex;
  
  const QuestionnaireScreen({
    super.key,
    this.onComplete,
    this.onSkip,
    this.currentQuestionIndex = 0,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> with TickerProviderStateMixin {
  late final PageController _controller;
  late int _currentPage;
  int? _selectedOption;
  Set<int> _selectedOptions = {};
  
  // Animation controller for fade transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Removed legacy bouncing arrows animation in favor of unified triple-arrow indicator
  
  // Add user information variables
  String? firstName;
  String? age;
  
  // Add map to track all answers
  Map<int, String> userAnswers = {};
  String? selectedGender;
  
  // Add the progress service
  final OnboardingProgressService _progressService = OnboardingProgressService();

  // Add language selector state variables
  Locale _selectedLocale = const Locale('en'); // Initialize directly
  bool _isInitialLoad = true;
  bool _attRequested = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.currentQuestionIndex;
    _controller = PageController(initialPage: widget.currentQuestionIndex);
    
    // Force status bar icons to white mode with explicit settings
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // iOS uses opposite naming
    ));
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    
    _fadeAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(_animationController);
    
    // Removed legacy bounce animation setup
    
    // Load saved progress if available
    _loadSavedProgress();
    
    // Ensure the page is at the correct index after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) {
        _controller.jumpToPage(_currentPage);
      }
      // Track initial page view for question 1 (or restored question) since onPageChanged
      // does not fire on first build when starting at the initial index.
      // Page structure: 0-3=Questions 1-4, 4=Break, 5=Consumption Summary, 6-13=Questions 6-13, 14=Profile Info
      if ((_currentPage < 4) || (_currentPage > 5 && _currentPage < QuestionnaireData.questions.length + 2)) {
        int questionIndex;
        if (_currentPage < 4) {
          questionIndex = _currentPage; // Questions 1-4 (indices 0-3)
        } else {
          questionIndex = _currentPage - 2; // Questions 6-13 (indices 6-13, map to question indices 4-11)
        }
        if (questionIndex >= 0 && questionIndex < QuestionnaireData.questions.length) {
          final question = QuestionnaireData.questions[questionIndex];
          final englishQuestionTitle = question.englishQuestion;
          final eventName = 'Onboarding Questionnaire ' + englishQuestionTitle;
          debugPrint('[Mixpanel] Event (initial): ' + eventName);
          MixpanelService.trackEvent(eventName);
        }
      }
    });
  }

  Future<void> _requestTrackingIfNeeded() async {
    if (_attRequested) return;
    _attRequested = true;
    if (!Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future.delayed(const Duration(milliseconds: 250));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }

      final updated = await AppTrackingTransparency.trackingAuthorizationStatus;
      final bool enabled = updated == TrackingStatus.authorized;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fb_advertiser_tracking_enabled', enabled);

      try {
        final facebookAppEvents = FacebookAppEvents();
        await facebookAppEvents.setAdvertiserTracking(enabled: enabled);
        debugPrint('ATT applied on Q1. AdvertiserTracking enabled=$enabled');
      } catch (e) {
        debugPrint('Error applying advertiser tracking on Q1: $e');
      }
    } catch (e) {
      debugPrint('ATT request error on Q1: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = Localizations.localeOf(context);

    if (_selectedLocale != newLocale || _isInitialLoad) {
      _selectedLocale = newLocale;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // This setState ensures the widget rebuilds with the correct
            // AppLocalizations instance and reflects the _selectedLocale.
          });
        }
      });
      _isInitialLoad = false;
    }
  }
  
  // Load saved answers and current question
  Future<void> _loadSavedProgress() async {
    try {
      final savedAnswers = await _progressService.getQuestionnaireAnswers();
      if (savedAnswers.isNotEmpty) {
        setState(() {
          userAnswers = savedAnswers;
        });
      }
      
      // Only update current page if widget didn't specify a specific index
      if (widget.currentQuestionIndex == 0) {
        final savedIndex = await _progressService.getQuestionnaireIndex();
        if (savedIndex > 0) {
          setState(() {
            _currentPage = savedIndex;
          });
          
          // Jump to the saved page
          if (_controller.hasClients) {
            _controller.jumpToPage(_currentPage);
          }
        }
      }
      
      // Save that we're in the specific questionnaire question
      final questionNumber = _currentPage + 1; // Convert 0-based to 1-based
      await _progressService.saveCurrentQuestionnaireScreen(questionNumber);
    } catch (e) {
      debugPrint('Error loading questionnaire progress: $e');
    }
  }
  
  // Save progress after each question is answered
  Future<void> _saveProgress() async {
    try {
      await _progressService.saveQuestionnaireProgress(_currentPage, userAnswers);
      
      // Also save the current questionnaire screen with question number
      if (_currentPage < QuestionnaireData.questions.length) {
        final questionNumber = _currentPage + 1; // Convert 0-based to 1-based
        await _progressService.saveCurrentQuestionnaireScreen(questionNumber);
      }
    } catch (e) {
      debugPrint('Error saving questionnaire progress: $e');
    }
  }

  // Add method to handle skip test functionality
  void _handleSkipTest() {
    // Add haptic feedback for skip test button
    HapticFeedback.lightImpact();
    
    // Get the English title of the current question
    String englishTitle = '';
    if (_currentPage < QuestionnaireData.questions.length) {
      englishTitle = QuestionnaireData.questions[_currentPage].englishQuestion;
    }
    final eventName = 'Onboarding ' + englishTitle + ' Skip Test Tap';
    MixpanelService.trackEvent(eventName);
    debugPrint('Mixpanel Event: $eventName');
    
    // Show confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              color: Colors.white, // Clean white background
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title and Message
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.translate('questionnaire_skipConfirmation_title'),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A), // Dark text for white background
                          fontFamily: 'ElzaRound',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.translate('questionnaire_skipConfirmation_message'),
                        style: const TextStyle(
                          color: Color(0xFF666666), // Gray text for subtitle
                          fontFamily: 'ElzaRound',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Modern button layout
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                  child: Column(
                    children: [
                      // Skip button - secondary gray background
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            
                            // Always navigate to ProfileInfoScreen when skipping
                            Navigator.of(context).pushReplacement(
                              FadePageRoute(
                                child: ProfileInfoScreen(
                                  firstName: firstName,
                                  age: age,
                                  gender: selectedGender,
                                  questionnaireAnswers: userAnswers,
                                  onComplete: widget.onComplete,
                                  hideHeader: true, // Hide header when coming from skip test
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.translate('questionnaire_skipConfirmation_skip'),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontFamily: 'ElzaRound',
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Cancel button - primary CTA with brand gradient
                      Container(
                        width: double.infinity,
                        height: 48, // Same height as Skip button
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFed3272),
                              Color(0xFFfd5d32),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.translate('questionnaire_skipConfirmation_cancel'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'ElzaRound',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Custom fade transition when navigating between pages
  Future<void> _animateToPage(int page) async {
    // Fade out
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
    _animationController.forward();
    
    // Wait for fade out to complete
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Jump to page
    _controller.jumpToPage(page);
    
    // Fade in
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.reset();
    _animationController.forward();
  }

  void _handleOptionSelected(int index) {
    debugPrint('_handleOptionSelected called with index=$index, currentPage=$_currentPage');
    
    // Add haptic feedback for option selection
    HapticFeedback.lightImpact();
    
    // Make sure we're on a question page that can actually have options selected
    // Don't allow option selection on break (index 4), consumption summary (index 5),
    // or profile info screen
    if (_currentPage == 4 || _currentPage == 5 ||
        _currentPage > QuestionnaireData.questions.length + 1) {
      debugPrint('Preventing option selection on non-question screen or profile page');
      return; 
    }
    
    // Map current page to the actual question index in the data list
    int adjustedIndex;
    if (_currentPage < 4) {
      adjustedIndex = _currentPage; // questions before break screen
    } else { // _currentPage > 5
      adjustedIndex = _currentPage - 2; // questions after consumption summary
    }
    
    if (adjustedIndex < 0 || adjustedIndex >= QuestionnaireData.questions.length) {
      debugPrint('Error: adjustedIndex $adjustedIndex out of range');
      return;
    }
    
    // Get the current question directly by index
    final QuestionModel currentQuestion = QuestionnaireData.questions[adjustedIndex];
    final int questionIndex = adjustedIndex;
    
    // Exit if this is a multi-select question (handled in onTap directly)
    if (currentQuestion.isMultiSelect) {
        debugPrint('Skipping _handleOptionSelected for multi-select question ID: ${currentQuestion.id}');
        return;
    }
    
    // Get the English version of the selected answer for storage
    final String selectedAnswerEnglish = currentQuestion.optionsEnglish[index];
    
    debugPrint('Selected answer (English for storage): $selectedAnswerEnglish for question ID: ${currentQuestion.id}');
    
    setState(() {
      _selectedOption = index;
      _selectedOptions.clear(); // Clear multi-select when single is chosen
      userAnswers[questionIndex] = selectedAnswerEnglish; // Store English text
      
      // If this is the gender question (id = 13), save it separately (still English)
      if (currentQuestion.id == 13) { 
        selectedGender = selectedAnswerEnglish; // Store English text for gender
        debugPrint('Selected gender in handleOptionSelected (English): $selectedGender');
      }
    });
    
    // Track question answer in Mixpanel (will send English text)
    _trackQuestionAnswerInMixpanel(currentQuestion.id, currentQuestion.questionText, selectedAnswerEnglish);
    
    // Save progress immediately after selection
    _saveProgress();
    
    // Special handling for question 4 (navigating to consumption summary)
    if (_currentPage == 3) {
      debugPrint('Question 4 selected, navigating to consumption summary next');
      // NOTE: Delay and navigation removed, handled by Continue button now
      return;
    }
    
    // Regular option navigation with longer delay to show help text
    // NOTE: Delay and navigation removed, handled by Continue button now
    // debugPrint('Regular option selection, navigating forward after delay');
    // Future.delayed(const Duration(milliseconds: 1200), () {
    //   _navigateToNextQuestion();
    // });
  }

  // Track question answer in Mixpanel
  void _trackQuestionAnswerInMixpanel(int questionId, String questionText, String answer) {
    // Get the English question title regardless of UI locale
    String englishQuestionTitle = questionText;
    try {
      final QuestionModel model = QuestionnaireData.questions.firstWhere((q) => q.id == questionId);
      englishQuestionTitle = model.englishQuestion;
    } catch (e) {
      // Fallback to provided questionText if id not found
      debugPrint('Fallback to provided questionText for analytics: $e');
    }
    final String eventName = 'Onboarding Question Answered: $englishQuestionTitle';
    debugPrint('[Mixpanel] Answer Event: $eventName');
    MixpanelService.trackEvent(
      eventName,
      properties: {
        'question_id': questionId,
        'answer': answer,
      },
    );
  }
  
  // Add a method to track all questionnaire answers together when complete
  void _trackCompleteQuestionnaire() {
    // Create a map of question IDs to answers for tracking
    final Map<String, dynamic> questionAnswers = {};
    
    // Add each answer to the properties
    userAnswers.forEach((questionIndex, answer) {
      // ** Get the actual QuestionModel using the index **
      QuestionModel? questionData;
      try {
          // Adjust index for consumption summary screen - Fix the mapping here
          int modelIndex = (questionIndex >= 4) ? questionIndex - 1 : questionIndex;
          if (modelIndex >= 0 && modelIndex < QuestionnaireData.questions.length) {
             questionData = QuestionnaireData.questions[modelIndex];
          }
      } catch (e) {
         debugPrint('Error finding question model for index $questionIndex: $e');
      }

      if (questionData != null) {
        final questionId = questionData.id; // Use the actual ID from the model
        // If this is a real question and not consumption data (keys >= 100)
        if (questionId < 100) {
            // Use a readable format for the question name
            final questionKey = 'Q${questionId}_${questionData.questionText.replaceAll(' ', '_').replaceAll('?', '').toLowerCase()}';
            questionAnswers[questionKey] = answer; // Answer is already string (joined for multi-select)
            
            // Also add with just the ID as key for easier analysis
            questionAnswers['q$questionId'] = answer;
        }
      } else {
         debugPrint('Skipping tracking for answer at index $questionIndex, no matching question model found.');
      }
    });
    
    // Track the complete questionnaire submission
    MixpanelService.trackEvent(
      'Onboarding Questionnaire Completed',
      properties: questionAnswers
    );
  }

  void _navigateToNextQuestion() async {
    debugPrint('_navigateToNextQuestion called, current page: $_currentPage');
    
    // Get current question info BEFORE incrementing _currentPage
    int currentQuestionIndex = _currentPage;
    bool wasMultiSelect = false;
    QuestionModel? questionBeforeNav;
    if (_currentPage == 4) {
        // Break screen, not a question
    } else if (_currentPage == 5) {
        // Consumption summary, not a question
    } else if (_currentPage <= QuestionnaireData.questions.length + 1) {
        // Adjust index based on position relative to break screen and consumption summary
        int adjustedIndex;
        if (_currentPage < 4) {
            // Questions before break screen (0-3)
            adjustedIndex = _currentPage;
        } else if (_currentPage > 5) {
            // Questions after consumption summary (6+)
            adjustedIndex = _currentPage - 2;
        } else {
            adjustedIndex = _currentPage; // Shouldn't reach here
        }
        
        if (adjustedIndex < QuestionnaireData.questions.length) {
           questionBeforeNav = QuestionnaireData.questions[adjustedIndex];
           wasMultiSelect = questionBeforeNav.isMultiSelect;
           currentQuestionIndex = adjustedIndex; // Ensure we use the correct index for userAnswers
        }
    }

    // Add check: For multi-select, ensure at least one option is selected
    // We also track the answer here *before* clearing state
    if (wasMultiSelect && questionBeforeNav != null) {
        String multiAnswer = userAnswers[currentQuestionIndex] ?? ''; // Get the stored comma-separated string
        if (multiAnswer.isNotEmpty) {
            debugPrint('Tracking multi-select answer for Q${questionBeforeNav.id} before navigating.');
            _trackQuestionAnswerInMixpanel(questionBeforeNav.id, questionBeforeNav.questionText, multiAnswer);
        } else {
             // Optional: Track event even if no option was selected? Or maybe track a "skipped" event?
             debugPrint('Multi-select question Q${questionBeforeNav.id} was proceeded from without any selection.');
             // Example: Track a skip event if desired
             // MixpanelService.trackEvent('question_skipped', properties: {
             //   'question_id': questionBeforeNav.id,
             //   'question_text': questionBeforeNav.questionText,
             // });
        }

        // Existing check for empty selection (currently allows proceeding)
        if (_selectedOptions.isEmpty) {
            debugPrint('Proceeding from multi-select question Q${questionBeforeNav.id} with no options selected.');
        }
    }

    // Handle last question - navigate to profile info
    if (_currentPage >= QuestionnaireData.questions.length + 1) { 
      // Note: With break screen, last question is now at index QuestionnaireData.questions.length + 1
      debugPrint('Navigating from last question (page $_currentPage) to Profile Info');
      setState(() {
        _currentPage++; // Increment to profile info page index
        _selectedOption = null; // Reset single selection
        _selectedOptions.clear(); // Reset multi-selection
      });
      
      // Track completion of questionnaire in Mixpanel
      _trackCompleteQuestionnaire();
      
      _animateToPage(_currentPage);
      
      // Save progress and screen
      _saveProgress();
      await _progressService.saveCurrentScreen(OnboardingScreen.profileInfoScreen);
      return;
    }
    
    // Normal question navigation
    setState(() {
      _currentPage++;
      _selectedOption = null; // Reset selected option
      _selectedOptions.clear(); // Reset multi-select options
    });
    
    _animateToPage(_currentPage);
    
    // Save progress after moving to next question
    _saveProgress();
    
    // Save the appropriate screen based on where we are now
    if (_currentPage == 4) {
      // On break screen
      // No specific onboarding screen enum for this, just track progress
    } else if (_currentPage == 5) {
      // On consumption summary screen
      await _progressService.saveCurrentScreen(OnboardingScreen.consumptionSummaryScreen);
    } else if (_currentPage == QuestionnaireData.questions.length + 2) {
      // On profile info screen (already handled above)
      await _progressService.saveCurrentScreen(OnboardingScreen.profileInfoScreen);
    } else if (_currentPage < 4 || (_currentPage > 5 && _currentPage < QuestionnaireData.questions.length + 2)) {
      // Still in questionnaire, save numbered screen
      int questionNumber;
      if (_currentPage < 4) {
        questionNumber = _currentPage + 1; // Questions 1-4
      } else {
        questionNumber = _currentPage - 1; // Questions 5-13 (index 6-14, adjusted by -1)
      }
      await _progressService.saveCurrentQuestionnaireScreen(questionNumber);
    }
  }

  void _navigateToPreviousQuestion() {
    if (_currentPage > 0) {
      // Normal previous navigation
      setState(() {
        _currentPage--;
        _selectedOption = null; // Reset selected option
        _selectedOptions.clear(); // Reset multi-select options
      });
      
      _animateToPage(_currentPage);
    } else {
      // If we're at the first question, navigate back to weeks progression screen
      Navigator.of(context).pushReplacement(
        FadePageRoute(
          child: const WeeksProgressionScreen(),
        ),
      );
    }
  }

  void _updateUserInfo({String? newFirstName, String? newAge}) {
    setState(() {
      if (newFirstName != null) firstName = newFirstName;
      if (newAge != null) age = newAge;
    });
  }

  @override
  void dispose() {
    // Restore default status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    _controller.dispose();
    _animationController.dispose();
    // No bounce animation to dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent backward navigation - always go back to weeks progression screen
      onWillPop: () async {
        // Navigate back to weeks progression screen
        Navigator.of(context).pushReplacement(
          FadePageRoute(
            child: const WeeksProgressionScreen(),
          ),
        );
        return false;
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // Dark icons for white background
          statusBarBrightness: Brightness.light, // For iOS
        ),
        child: Scaffold(
          body: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: SafeArea(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Fixed progress bar row
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
                    child: Row(
                      children: [
                        // Show progress bar for all screens
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: (_currentPage + 1) / 16, // Update for 14 questions + consumption summary + profile info
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE0E0E0), // Light gray for white background
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFed3272)), // Brand pink
                            ),
                          ),
                        ),
                        // Removed sound toggle from header; it will appear next to the question title
                      ],
                    ),
                  ),
                  
                  // Language selector positioned to the right, below the progress bar
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OnboardingLanguageSelector(),
                      ],
                    ),
                  ),
                  
                  // Content area - only this part will change/animate
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: PageView.builder(
                            controller: _controller,
                            physics: const NeverScrollableScrollPhysics(), // Disable manual scrolling
                            itemCount: QuestionnaireData.questions.length + 3, // Add 1 for break screen, 1 for consumption summary and 1 for profile info
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                                _selectedOption = null;
                              });
                              // Track Mixpanel page view for question pages only
                              // Page structure: 0-3=Questions 1-4, 4=Break, 5=Consumption Summary, 6-13=Questions 6-13, 14=Profile Info
                              if ((index < 4) || (index > 5 && index < QuestionnaireData.questions.length + 2)) {
                                int questionIndex;
                                if (index < 4) {
                                  questionIndex = index; // Questions 1-4 (indices 0-3)
                                } else {
                                  questionIndex = index - 2; // Questions 6-13 (indices 6-13, map to question indices 4-11)
                                }
                                if (questionIndex >= 0 && questionIndex < QuestionnaireData.questions.length) {
                                  final question = QuestionnaireData.questions[questionIndex];
                                  final englishQuestionTitle = question.englishQuestion;
                                  final eventName = 'Onboarding Questionnaire $englishQuestionTitle';
                                  debugPrint('[Mixpanel] Event: $eventName');
                                  MixpanelService.trackEvent(eventName);
                                }
                              }
                            },
                            itemBuilder: (context, index) {
                              debugPrint('Building page for index: $index, Questions length: ${QuestionnaireData.questions.length}');
                              if (index == 0 && !_attRequested) {
                                // Trigger ATT exactly when Q1 is shown
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _requestTrackingIfNeeded();
                                });
                              }
                              
                              // Show break screen after question 3 (index 4)
                              if (index == 4) {
                                debugPrint('Showing SugarProgressBreakScreen after question 3');
                                return SugarProgressBreakScreen(
                                  onNext: _navigateToNextQuestion,
                                  onPrevious: _navigateToPreviousQuestion,
                                );
                              }
                              
                              // Show consumption summary as question 5 (index 5, was 4)
                              if (index == 5) {
                                debugPrint('Showing ConsumptionSummaryScreen as question 5');
                                try {
                                  return ConsumptionSummaryScreen(
                                    userAnswers: userAnswers,
                                    onNext: _navigateToNextQuestion,
                                    onPrevious: _navigateToPreviousQuestion,
                                  );
                                } catch (e) {
                                  debugPrint('Error creating ConsumptionSummaryScreen: $e');
                                  // Return a fallback widget until we fix the issue
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(AppLocalizations.of(context)!.translate('questionnaire_errorLoadingSummary')),
                                        const SizedBox(height: 20),
                                        ElevatedButton(
                                          onPressed: _navigateToNextQuestion,
                                          child: Text(AppLocalizations.of(context)!.translate('questionnaire_continueToNextButton')),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              }
                              
                              // Show profile info screen after the last question (index adjusted by +1)
                              if (index == QuestionnaireData.questions.length + 2) {
                                debugPrint('Showing ProfileInfoScreen');
                                return ProfileInfoScreen(
                                  onComplete: () {
                                    if (widget.onComplete != null) {
                                      widget.onComplete!();
                                    }
                                  },
                                  onPrevious: _navigateToPreviousQuestion,
                                  onUpdateInfo: _updateUserInfo,
                                  firstName: firstName,
                                  age: age,
                                  gender: selectedGender,
                                  hideHeader: true,
                                  questionnaireAnswers: userAnswers,
                                );
                              }
                              
                              // For questions after consumption summary, adjust the index
                              if (index > 5 && index < QuestionnaireData.questions.length + 2) {
                                final questionIndex = index - 2; // Adjust index to get correct question
                                final question = QuestionnaireData.questions[questionIndex];
                                debugPrint('Showing question with id: ${question.id}');
                                return _buildQuestionContent(
                                  question.id, // Use question's actual ID instead of calculating it
                                  question.questionText,
                                  question.options,
                                );
                              }
                              
                              // For questions before break screen (0-3), use normal index
                              if (index < 4) {
                                final question = QuestionnaireData.questions[index];
                                debugPrint('Showing question with id: ${question.id}');
                                return _buildQuestionContent(
                                  question.id,
                                  question.questionText,
                                  question.options,
                                );
                              }
                              
                              // Should not reach here
                              return const SizedBox();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Show triple arrows only when a selected option reveals a help text
  bool _shouldShowQuestionArrows(QuestionModel? currentQuestion, List<String> optionKeys) {
    if (currentQuestion == null) return false;
    // For multi-select, show if any selected option has a help text key
    if (currentQuestion.isMultiSelect) {
      for (final idx in _selectedOptions) {
        if (idx >= 0 && idx < optionKeys.length) {
          final String optionKey = optionKeys[idx];
          if (currentQuestion.optionHelpTexts[optionKey] != null) {
            return true;
          }
        }
      }
      return false;
    }
    // For single-select, show if the selected option has a help text key
    if (_selectedOption == null) return false;
    final int idx = _selectedOption!;
    if (idx < 0 || idx >= optionKeys.length) return false;
    final String optionKey = optionKeys[idx];
    return currentQuestion.optionHelpTexts[optionKey] != null;
  }

  Widget _buildQuestionContent(int questionId, String questionKey, List<String> optionKeys) {
    // Find the QuestionModel to check isMultiSelect using a safer method
    QuestionModel? currentQuestion;
    try {
      currentQuestion = QuestionnaireData.questions.firstWhere((q) => q.id == questionId);
    } catch (e) {
      currentQuestion = null; // Set to null if not found
      debugPrint('Question with ID $questionId not found in QuestionnaireData.questions');
    }

    // Special handling for "How did you know about Stoppr?" question (id 12)
    if (questionId == 12 && currentQuestion != null) { 
      return _buildHowDidYouKnowContent(questionId, 
        AppLocalizations.of(context)!.translate(currentQuestion.questionText), // Translate question text key
        currentQuestion.options.map((key) => AppLocalizations.of(context)!.translate(key)).toList() // Translate option keys
      );
    }
    
    String displayQuestion = AppLocalizations.of(context)!.translate(questionKey);
    // Add multi-select hint for all multi-select questions
    if (currentQuestion != null && currentQuestion.isMultiSelect) {
        displayQuestion += '\n${AppLocalizations.of(context)!.translate('questionnaire_multipleAnswersHint')}';
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        
        // Question title with sound toggle on the left
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const OnboardingSoundToggle(diameter: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.translate('questionnaire_questionNumber').replaceFirst('{questionId}', questionId.toString()),
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A), // Dark text for white background
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44), // balance row width roughly with toggle size
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Question text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: Text(
              displayQuestion,
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666), // Dark gray for white background
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Options list
        Expanded(
          child: Stack(
            children: [
              Theme(
                data: Theme.of(context).copyWith(
                  scrollbarTheme: ScrollbarThemeData(
                    thumbColor: MaterialStateProperty.all(const Color(0xFFed3272)), // Brand pink
                    thickness: MaterialStateProperty.all(12.0),
                    radius: const Radius.circular(10),
                    thumbVisibility: MaterialStateProperty.all(true),
                    mainAxisMargin: 2.0,
                    crossAxisMargin: 2.0,
                  ),
                ),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(
                        optionKeys.length,
                        (index) => _buildOptionItem(optionKeys[index], index, currentQuestion), // Pass currentQuestion
                      ),
                    ),
                  ),
                ),
              ),
              
              // Unified triple-arrow indicator (same look/animation as Symptoms screen)
              if (MediaQuery.of(context).size.width < 768 && _shouldShowQuestionArrows(currentQuestion, optionKeys))
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black,
                          size: 40,
                        ),
                        SizedBox(height: 6),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black,
                          size: 40,
                        ),
                        SizedBox(height: 6),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black,
                          size: 40,
                        ),
                      ],
                    )
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .moveY(
                          begin: -8,
                          end: 8,
                          duration: 1.5.seconds,
                          curve: Curves.easeInOut,
                        )
                        .fadeIn(duration: 600.ms),
                  ),
                ),
            ],
          ),
        ),
        
        // Continue button (visible always, enabled when option selected)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Container(

            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFed3272), // Strong pink/magenta
                  Color(0xFFfd5d32), // Vivid orange - same as onboarding_screen4
                ],
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: ElevatedButton(
              onPressed: () { 
                // Add haptic feedback for continue button
                HapticFeedback.lightImpact();
                
                // Check if multi-select requires at least one option
                bool canProceed = true;
                if (currentQuestion != null && currentQuestion.isMultiSelect && _selectedOptions.isEmpty) {
                   // Decide behavior: allow proceeding (current) or block/show message?
                   // Let's allow proceeding for now.
                   debugPrint('Continue tapped on multi-select question ID ${currentQuestion.id} with no selections.');
                   // canProceed = false; // Uncomment to block if needed
                }

                if (canProceed) {
                   _navigateToNextQuestion();
                } else {
                   // Optional: Show snackbar/message "Please select at least one option"
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                minimumSize: const Size(double.infinity, 44),
              ),
              child: Text(
                AppLocalizations.of(context)!.translate('questionnaire_continueButton'),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        
        // Skip test button
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0), // Reduced padding
            child: GestureDetector(
              onTap: _handleSkipTest, // Update to use the local handler
              child: Text(
                AppLocalizations.of(context)!.translate('questionnaire_skipTestButton'),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFed3272), // Brand pink like skip button in onboarding_screen3
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // Special content builder for "How did you know about Stoppr?" question
  Widget _buildHowDidYouKnowContent(int questionId, String translatedQuestion, List<String> translatedOptions) {
    // Get the current question model to access its option keys
    final QuestionModel currentQuestion = QuestionnaireData.questions.firstWhere((q) => q.id == questionId);

    // Map of SVG icons to options - KEYS MUST BE THE LOCALIZATION KEYS
    final Map<String, String> optionIcons = {
      'q12_option_tiktok': 'assets/images/svg/tiktok.svg',
      'q12_option_instagram': 'assets/images/svg/instagram.svg',
      'q12_option_google': 'assets/images/svg/google.svg',
      'q12_option_youtube': 'assets/images/svg/youtube.svg',
      'q12_option_reddit': 'assets/images/svg/reddit.svg',
      'q12_option_friendFamily': 'assets/images/svg/friends-or-family.svg',
      'q12_option_other': 'assets/images/svg/other.svg',
    };
    
    return Column(
      children: [
        const SizedBox(height: 16),
        
        // Question title
        Center(
          child: Text(
            AppLocalizations.of(context)!.translate('questionnaire_questionNumber').replaceFirst('{questionId}', questionId.toString()),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A), // Dark text for white background
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Question text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: Text(
              translatedQuestion, // Already translated
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666), // Dark gray for white background
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Options list with SVG icons
        Expanded(
          child: Stack(
            children: [
              Theme(
                data: Theme.of(context).copyWith(
                  scrollbarTheme: ScrollbarThemeData(
                    thumbColor: MaterialStateProperty.all(const Color(0xFFed3272)), // Brand pink
                    thickness: MaterialStateProperty.all(12.0),
                    radius: const Radius.circular(10),
                    thumbVisibility: MaterialStateProperty.all(true),
                    mainAxisMargin: 2.0,
                    crossAxisMargin: 2.0,
                  ),
                ),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(
                        translatedOptions.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(
                            left: 24.0, 
                            right: 24.0, 
                            bottom: 16.0
                          ),
                          child: GestureDetector(
                            onTap: () {
                              // Add haptic feedback for social media option tap
                              HapticFeedback.lightImpact();
                              
                              // For question 12, handle option selection directly here
                              final String selectedAnswerEnglish = currentQuestion.optionsEnglish[index];
                              debugPrint('Selected answer (English for storage): $selectedAnswerEnglish for question ID: ${currentQuestion.id}');
                              
                              setState(() {
                                _selectedOption = index;
                                _selectedOptions.clear(); // Clear multi-select when single is chosen
                                
                                // Find the correct question index for storage
                                int storageIndex = -1;
                                for (int i = 0; i < QuestionnaireData.questions.length; i++) {
                                  if (QuestionnaireData.questions[i].id == 12) {
                                    storageIndex = i;
                                    break;
                                  }
                                }
                                
                                if (storageIndex != -1) {
                                  userAnswers[storageIndex] = selectedAnswerEnglish; // Store English text
                                }
                              });
                              
                              // Track question answer in Mixpanel
                              _trackQuestionAnswerInMixpanel(currentQuestion.id, currentQuestion.questionText, selectedAnswerEnglish);
                              
                              // Save progress immediately after selection
                              _saveProgress();
                            },
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: _selectedOption == index
                                    ? const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFFed3272), // Strong pink/magenta
                                          Color(0xFFfd5d32), // Vivid orange - same as onboarding_screen4
                                        ],
                                      )
                                    : null,
                                color: _selectedOption == index ? null : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _selectedOption == index
                                      ? Colors.transparent // No border for gradient
                                      : const Color(0xFFE0E0E0), // Light gray for unselected
                                  width: _selectedOption == index ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    // SVG icon (shown only if mapped; no fallback)
                                    if (optionIcons[currentQuestion.options[index]] != null)
                                      SvgPicture.asset(
                                        optionIcons[currentQuestion.options[index]]!,
                                        width: 24,
                                        height: 24,
                                        // Make Friend or Family icon visible based on selection state
                                        colorFilter: currentQuestion.options[index] == 'q12_option_friendFamily' 
                                            ? ColorFilter.mode(
                                                _selectedOption == index ? Colors.white : const Color(0xFF1A1A1A), // White when selected, dark when not
                                                BlendMode.srcIn,
                                              )
                                            : null,
                                      ),
                                    const SizedBox(width: 16),
                                    // Option text
                                    Expanded(
                                      child: Text(
                                        translatedOptions[index], // Already translated
                                        style: const TextStyle(
                                          fontFamily: 'ElzaRound',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1A1A1A), // Dark text for white background
                                        ),
                                      ),
                                    ),
                                    // Checkmark icon if selected
                                    if (_selectedOption == index)
                                                            const Icon(
                        Icons.check_circle,
                        color: Colors.white, // White checkmark on gradient background
                        size: 24,
                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Unified triple-arrow indicator (same look/animation as Symptoms screen)
              if (MediaQuery.of(context).size.width < 768)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black,
                          size: 40,
                        ),
                        SizedBox(height: 6),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black,
                          size: 40,
                        ),
                        SizedBox(height: 6),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.black,
                          size: 40,
                        ),
                      ],
                    )
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .moveY(
                          begin: -8,
                          end: 8,
                          duration: 1.5.seconds,
                          curve: Curves.easeInOut,
                        )
                        .fadeIn(duration: 600.ms),
                  ),
                ),
            ],
          ),
        ),
        
        // Continue button (visible always, enabled when option selected)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Container(

            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFed3272), // Strong pink/magenta
                  Color(0xFFfd5d32), // Vivid orange - same as onboarding_screen4
                ],
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: ElevatedButton(
              onPressed: () { // Always enabled and always navigates
                 // Add haptic feedback for continue button
                 HapticFeedback.lightImpact();
                 _navigateToNextQuestion();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                minimumSize: const Size(double.infinity, 44),
              ),
              child: Text(
                AppLocalizations.of(context)!.translate('questionnaire_continueButton'),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        
        // Skip test button
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0), // Reduced padding
            child: GestureDetector(
              onTap: _handleSkipTest,
              child: Text(
                AppLocalizations.of(context)!.translate('questionnaire_skipTestButton'),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFed3272), // Brand pink like skip button in onboarding_screen3
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildOptionItem(String optionKey, int index, QuestionModel? currentQuestion) {
    // Determine if the option is selected
    final bool isSelected = currentQuestion?.isMultiSelect ?? false
      ? _selectedOptions.contains(index) 
      : _selectedOption == index;
    
    String translatedOptionText = AppLocalizations.of(context)!.translate(optionKey);

    // Get the help text (only show if selected and not the social media question)
    String? helpTextKey;
    String? translatedHelpText;
    if (isSelected && currentQuestion != null && currentQuestion.id != 12) { 
       helpTextKey = currentQuestion.optionHelpTexts[optionKey]; // optionKey is already the key for helpTexts map
       if (helpTextKey != null) {
         translatedHelpText = AppLocalizations.of(context)!.translate(helpTextKey);
       }
    }
    
    return Padding(
      padding: const EdgeInsets.only(
        left: 24.0, 
        right: 24.0, 
        bottom: 16.0
      ),
      child: GestureDetector(
        onTap: () {
          debugPrint('Tapped option $index ($translatedOptionText) on page $_currentPage');
          
          // Add haptic feedback for option tap
          HapticFeedback.lightImpact();
          
          // Ensure we have a valid question
          if (currentQuestion == null) {
              debugPrint('Error: Cannot handle tap, currentQuestion is null.');
              return;
          }

          final currentQuestionIndex = index; // Use calculated index

          if (currentQuestion.isMultiSelect) {
            debugPrint('Multi-select question detected (ID: ${currentQuestion.id}), toggling option $index');
            setState(() {
              if (_selectedOptions.contains(index)) {
                _selectedOptions.remove(index);
              } else {
                _selectedOptions.add(index);
              }
              _selectedOption = null; // Clear single select state

              // Update userAnswers for multi-select
              List<String> selectedAnswersEnglish = _selectedOptions
                  .map((i) => currentQuestion?.optionsEnglish[i] ?? 'Error: English option not found') 
                  .where((option) => option != 'Error: English option not found')
                  .toList();
              userAnswers[currentQuestionIndex] = selectedAnswersEnglish.join(', '); // Join English answers
              debugPrint('Updated multi-select answers for index $currentQuestionIndex (English): ${userAnswers[currentQuestionIndex]}');
            });
             _saveProgress(); // Save progress immediately
            // Don't navigate immediately for multi-select, wait for "Continue"
            
          } else if (currentQuestion != null && currentQuestion.id == 13) { // Handle gender question (ID 13)
             debugPrint('Gender question detected (ID: ${currentQuestion.id}), special handling');
            setState(() {
              _selectedOption = index;
              _selectedOptions.clear(); // Clear multi-select state
              selectedGender = currentQuestion.optionsEnglish[index]; // Store English text for gender
              userAnswers[currentQuestionIndex] = currentQuestion.optionsEnglish[index]; // Store English text
            });
            
            // Debug selected gender
            debugPrint('Selected gender directly (English): $selectedGender');
            
            // Track gender selection in Mixpanel (will send English text)
            _trackQuestionAnswerInMixpanel(currentQuestion.id, currentQuestion.questionText, selectedGender ?? 'Unknown');
            
            // Save progress 
            _saveProgress();
             // Don't auto-navigate, wait for continue
             
          } else {
            // Normal single-select behavior
            _handleOptionSelected(index);
             // Don't auto-navigate, wait for continue
          }
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: isSelected 
                ? const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272), // Strong pink/magenta
                      Color(0xFFfd5d32), // Vivid orange - same as onboarding_screen4
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? Colors.transparent // No border for gradient
                  : const Color(0xFFE0E0E0), // Light gray for unselected
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 16.0,
                ),
                child: Row(
                  children: [
                    // Numbered circle - changes to orange when selected
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : const Color(0xFFF5F5F5), // White circle on gradient, light gray when unselected
                        border: isSelected ? Border.all(color: const Color(0xFFed3272).withOpacity(0.3), width: 1.5) : null, // Subtle pink border when selected
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (index + 1).toString(),
                          style: TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFFed3272) : const Color(0xFF1A1A1A), // Pink number on white circle, dark on gray
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Option text
                    Expanded(
                      child: Text(
                        translatedOptionText, // Use translated text
                        style: TextStyle(
                          fontFamily: 'ElzaRound',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF1A1A1A), // White on gradient, dark on white
                        ),
                      ),
                    ),
                    // Checkmark icon if selected
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white, // White checkmark for better visibility
                        size: 24,
                      ),
                  ],
                ),
              ),
              
              // Help text - clean text with subtle background for separation
              if (translatedHelpText != null && isSelected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  margin: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9F7), // Light neutral off-white for premium feel
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    translatedHelpText, // Use translated help text
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 14,
                      fontWeight: FontWeight.w600, // Bolder text
                      color: Color(0xFF1A1A1A), // Dark text for better readability on light background
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 