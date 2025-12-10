import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'home_screen.dart';
import 'dart:math';
import 'home_rewire_brain.dart';
import 'profile/user_profile_screen.dart';
import 'main_scaffold.dart';
import 'journal_feelings.dart';
import 'breathing_exercise_screen.dart';
import 'pledge_screen.dart';
import 'meditation_screen.dart';
import 'podcast_screen.dart';
import '../../../learn/presentation/screens/articles_list_screen.dart';
import 'food_scan/food_scan_screen.dart';
import 'rate_my_plate/rate_my_plate_scan_screen.dart';
import 'chatbot/chatbot_screen.dart';
import '../../../community/presentation/screens/community_screen.dart';
import '../../../../core/challenge/challenge_service.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_journal_entry.dart';
import 'panic_button/what_happening_screen.dart';
import 'self_reflection.dart';

class Challenge28DaysScreen extends StatefulWidget {
  const Challenge28DaysScreen({super.key});

  @override
  State<Challenge28DaysScreen> createState() => _Challenge28DaysScreenState();
}

class _Challenge28DaysScreenState extends State<Challenge28DaysScreen> {
  final ChallengeService _challengeService = ChallengeService();
  bool _challengeStarted = false;
  int _currentDay = 0;
  String _taskStatus = 'incomplete';
  String _taskMessage = '';
  String _currentTaskType = ChallengeService.taskTypeJournal; // Default to journal
  List<bool> _dayStatusList = List.generate(28, (_) => false);
  
  @override
  void initState() {
    super.initState();
    
    // Track page view
    MixpanelService.trackEvent('Challenge 28 Days Screen: Page Viewed');
    
    // Initialize the challenges
    _initializeChallenges();
    
    // Force status bar icons to dark mode for light background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for light background
      statusBarBrightness: Brightness.light, // For iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    
    // Make app edge-to-edge with white status bar icons
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }
  
  @override
  void dispose() {
    // Restore default UI settings when leaving screen
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }
  
  Future<void> _loadChallengeState() async {
    final challengeData = await _challengeService.getChallengeData();
    
    if (!mounted) return;
    setState(() {
      _challengeStarted = challengeData['started'] as bool;
      _currentDay = _challengeStarted ? (challengeData['currentDay'] as int) : 0;
      _dayStatusList = challengeData['dayStatusList'] as List<bool>;
    });
    
    if (_challengeStarted) {
      await _updateDailyTask();
    }
  }
  
  void _initializeChallenges() {
    // Load the challenge state
    _loadChallengeState();
  }
  
  Future<void> _updateDailyTask() async {
    if (_currentDay > 0 && _currentDay <= 28) {
      // Get task type for current day
      final taskType = await _challengeService.getTaskTypeForDay(_currentDay);
      
      // Get task description KEY from service
      final taskDescriptionKey = _challengeService.getTaskDescription(taskType);
      
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      
      if (!mounted) return;
      setState(() {
        _taskMessage = l10n.translate(taskDescriptionKey); // Translate the key
        _currentTaskType = taskType;
        
        // Check if today's task is complete
        if (_currentDay > 0 && _currentDay <= 28) {
          _taskStatus = _dayStatusList[_currentDay - 1] ? 'complete' : 'incomplete';
        } else {
          _taskStatus = 'incomplete';
        }
      });
    }
  }
  
  void _startChallenge() async {
    // Track challenge start
    MixpanelService.trackEvent(
      'Challenge 28 Days Screen: Start Challenge Button Tap',
      properties: {
        'challenge_day': 1,
        'action': 'challenge_started',
      },
    );
    
    // Optimistically update UI immediately
    if (mounted) {
      setState(() {
        _challengeStarted = true;
        _currentDay = 1;
      });
    }
    await _updateDailyTask();
    
    if (!mounted) return;
    
    // Perform storage/network work in background, then refresh
    await _challengeService.startChallenge();
    final challengeData = await _challengeService.getChallengeData();
    
    if (!mounted) return;
    
    setState(() {
      _dayStatusList = challengeData['dayStatusList'] as List<bool>;
    });
    
    await _updateDailyTask();
  }
  
  void _completeTask() async {
    if (_currentDay > 0 && _currentDay <= 28 && _taskStatus != 'complete') {
      // Track task completion
      MixpanelService.trackEvent(
        'Challenge 28 Days Screen: Mark Complete Button Tap',
        properties: {
          'challenge_day': _currentDay,
          'task_type': _currentTaskType,
          'action': 'task_marked_complete',
        },
      );
      
      await _challengeService.completeTask(_currentDay);
      
      // Refresh challenge data and update UI (day will advance on next calendar day)
      final challengeData = await _challengeService.getChallengeData();
      if (!mounted) return;
      setState(() {
        _dayStatusList = challengeData['dayStatusList'] as List<bool>;
        _currentDay = challengeData['currentDay'] as int;
      });
      await _updateDailyTask();
    }
  }
  
  void _doTask() {
    if (_currentDay > 0 && _currentDay <= 28) {
      // Track do task button tap
      MixpanelService.trackEvent(
        'Challenge 28 Days Screen: Do Task Button Tap',
        properties: {
          'challenge_day': _currentDay,
          'task_type': _currentTaskType,
          'action': 'navigate_to_task',
        },
      );
      
      switch (_currentTaskType) {
        case ChallengeService.taskTypeJournal:
          // Navigate to Journal screen
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const JournalFeelingsScreen(),
              settings: const RouteSettings(name: '/journal'),
            ),
          );
          break;
        case ChallengeService.taskTypeBreathing:
          // Navigate to Breathing exercise screen
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const BreathingExerciseScreen(),
              settings: const RouteSettings(name: '/breathing'),
            ),
          );
          break;
        case ChallengeService.taskTypePledge:
          // Navigate to Pledge screen
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const PledgeScreen(),
              settings: const RouteSettings(name: '/pledge'),
            ),
          );
          break;
        case ChallengeService.taskTypeMeditation:
          // Navigate to Meditation screen
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const MeditationScreen(),
              settings: const RouteSettings(name: '/meditation'),
            ),
          );
          break;
        case ChallengeService.taskTypePodcast:
          // Navigate to Podcast screen
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const PodcastScreen(),
              settings: const RouteSettings(name: '/podcast'),
            ),
          );
          break;
        case ChallengeService.taskTypeArticles:
          // Navigate to Articles screen
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const ArticlesListScreen(),
              settings: const RouteSettings(name: '/articles'),
            ),
          );
          break;
        case ChallengeService.taskTypeFoodScan:
          // Navigate to Food Scan screen
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const FoodScanScreen(),
              settings: const RouteSettings(name: '/food-scan'),
            ),
          );
          break;
        case ChallengeService.taskTypeRateMyPlate:
          // Navigate to Rate My Plate screen
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const RateMyPlateScanScreen(),
              settings: const RouteSettings(name: '/rate-my-plate'),
            ),
          );
          break;
        case ChallengeService.taskTypeChatbot:
          // Navigate to Chatbot screen
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const ChatbotScreen(),
              settings: const RouteSettings(name: '/chatbot'),
            ),
          );
          break;
        case ChallengeService.taskTypeCommunityPost:
          // Navigate to Community screen
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const CommunityScreen(),
              settings: const RouteSettings(name: '/community'),
            ),
          );
          break;
        case ChallengeService.taskTypeSelfReflection:
          // Navigate to Self Reflection screen
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const SelfReflectionScreen(),
              settings: const RouteSettings(name: '/self-reflection'),
            ),
          );
          break;
        default:
          // Default case
          Navigator.of(context).push(
            BottomToTopPageRoute(
              child: const JournalFeelingsScreen(),
              settings: const RouteSettings(name: '/journal'),
            ),
          );
          break;
      }
    }
  }
  
  void _showResetConfirmation() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // White background per brand guide
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), // iOS-style rounded corners
          ),
          title: Text(
            l10n.translate('challengeScreen_dialog_resetChallenge_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for white background
              fontSize: 20, // Increased from 17
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            l10n.translate('challengeScreen_dialog_resetChallenge_content'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for white background
              fontSize: 16, // Increased from 15
              fontFamily: 'ElzaRound',
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button - secondary style with brand border
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFed3272),
                        side: const BorderSide(
                          color: Color(0xFFed3272), // Brand pink border
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        l10n.translate('common_cancel'),
                        style: const TextStyle(
                          color: Color(0xFFed3272), // Brand pink text
                          fontSize: 16,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Reset button - red background, white text
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetChallengeToDay1();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30), // iOS red
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        l10n.translate('homeScreen_reset'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          actionsPadding: EdgeInsets.zero, // Remove default padding
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        );
      },
    );
  }
  
  Future<void> _resetChallengeToDay1() async {
    // Track challenge reset
    MixpanelService.trackEvent(
      'Challenge 28 Days Screen: Reset Challenge Button Tap',
      properties: {
        'previous_day': _currentDay,
        'action': 'challenge_reset',
      },
    );
    
    await _challengeService.resetChallenge();
    
    // Reload challenge data
    final challengeData = await _challengeService.getChallengeData();
    
    if (!mounted) return;
    setState(() {
      _challengeStarted = true;
      _currentDay = 1;
      _dayStatusList = challengeData['dayStatusList'] as List<bool>;
    });
    
    await _updateDailyTask();
  }
  
  void _navigateBackToHome() {
    // Track close/back navigation
    MixpanelService.trackEvent(
      'Challenge 28 Days Screen: Close Button Tap',
      properties: {
        'challenge_day': _currentDay,
        'challenge_started': _challengeStarted,
        'action': 'navigate_back_to_home',
      },
    );
    
    Navigator.of(context).pushReplacement(
      TopToBottomPageRoute(
        child: const MainScaffold(initialIndex: 0),
        settings: const RouteSettings(name: '/home'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Get bottom padding to account for navigation bar
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
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
        backgroundColor: const Color(0xFFFDF8FA), // Soft pink-tinted white background for eye comfort
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // Dark icons for light background
            statusBarBrightness: Brightness.light, // For iOS
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Main scrollable content
              SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 220), // Increase to ensure content doesn't sit under the floating day indicators
                  child: Column(
                    children: [
                      // Top Bar with Back button, Logo, and Day counter
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back button
                            IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)), // Dark icon for light background
                              onPressed: _navigateBackToHome,
                            ),
                            
                            // STOPPR logo
                            const Text(
                              "STOPPR",
                              style: TextStyle(
                                color: Color(0xFF1A1A1A), // Dark text for light background
                                fontSize: 24,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            
                            // Day counter
                            Text(
                              _challengeStarted 
                                ? l10n.translate('challengeScreen_dayCounterFormat').replaceAll('{currentDay}', _currentDay.toString()) 
                                : l10n.translate('challengeScreen_dayCounterFormat').replaceAll('{currentDay}', '0'),
                              style: const TextStyle(
                                color: Color(0xFF666666), // Gray text for light background
                                fontSize: 16,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 28-Day Challenge title
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          "28-Day Challenge",
                          style: TextStyle(
                            color: Color(0xFF1A1A1A), // Dark text for light background
                            fontSize: 32,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      // Challenge content based on state
                      _challengeStarted ? _buildActiveChallengeContent() : _buildStartChallengeContent(),
                    ],
                  ),
                ),
              ),
              
              // Day indicators positioned higher
              Positioned(
                // Position day indicators just above the footer (panic button + spacing + text)
                // Keep them close to the panic button so they never overlap upper CTAs
                bottom: (28 + 48 + 32 + 12).toDouble() + bottomPadding,
                left: 0,
                right: 0,
                child: Container(
                  color: const Color(0xFFFDF8FA), // Match main background color
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: SizedBox(
                      height: 32,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: List.generate(28, (index) {
                            final day = index + 1;
                            final bool isCurrent = _currentDay == day;
                            final bool isCompleted = _dayStatusList[index];

                            return Container(
                              width: 32,
                              height: 32,
                              margin: EdgeInsets.only(
                                left: index == 0 ? 16.0 : 4.0,
                                right: 4.0,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isCurrent 
                                  ? const LinearGradient(
                                      colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    )
                                  : null,
                                color: isCurrent 
                                  ? null
                                  : isCompleted 
                                    ? const Color(0xFFed3272).withOpacity(0.2)
                                    : Colors.white,
                                border: Border.all(
                                  color: isCurrent || isCompleted
                                    ? const Color(0xFFed3272)
                                    : const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    color: isCurrent 
                                      ? Colors.white 
                                      : isCompleted
                                        ? const Color(0xFFed3272)
                                        : const Color(0xFF666666),
                                    fontSize: 14,
                                    fontFamily: 'ElzaRound',
                                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Bottom section with Panic button and Relapsed text - positioned above navigation bar
              Positioned(
                bottom: 36, // Create more headroom between days and panic button
                left: 0,
                right: 0,
                child: Container(
                  color: const Color(0xFFFDF8FA), // Match main background color
                  padding: EdgeInsets.zero, // Removed bottom padding
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Panic button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0), // Reduced from 5.0
                        child: GestureDetector(
                          onTap: () {
                            // Track panic button tap
                            MixpanelService.trackEvent(
                              'Challenge 28 Days Screen: Panic Button Tap',
                              properties: {
                                'challenge_day': _currentDay,
                                'challenge_started': _challengeStarted,
                                'action': 'panic_button_pressed',
                              },
                            );
                            
                            Navigator.of(context).push(
                              BottomToTopPageRoute(
                                child: const WhatHappeningScreen(),
                                settings: const RouteSettings(name: '/panic_what_happening'),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            height: 44, // Reduced from 50
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFFed3272), // Brand pink
                                  Color(0xFFfd5d32), // Brand orange
                                ],
                              ),
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFed3272).withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 3,
                                ),
                                BoxShadow(
                                  color: const Color(0xFFfd5d32).withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  l10n.translate('homeScreen_panicButton'),
                                  style: const TextStyle(
                                    color: Colors.white, // White text on gradient button
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'ElzaRound',
                                    height: 0.9,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Reduced spacing to make footer more compact
                      const SizedBox(height: 12), // Reduced from 20
                      
                      // I Relapsed text
                      GestureDetector(
                        onTap: () {
                          // Track relapsed text tap
                          MixpanelService.trackEvent(
                            'Challenge 28 Days Screen: I Relapsed Text Tap',
                            properties: {
                              'challenge_day': _currentDay,
                              'challenge_started': _challengeStarted,
                              'action': 'relapsed_text_tapped',
                            },
                          );
                          _showResetConfirmation();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5.0), // Reduced from 10.0
                          child: Text(
                            l10n.translate('challengeScreen_text_relapsedReset'),
                            style: const TextStyle(
                              color: Color(0xFFFF3B30), // Keep iOS red for relapsed text
                              fontSize: 18,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
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
      ),
    );
  }
  
  Widget _buildStartChallengeContent() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Text(
              l10n.translate('challengeScreen_initialScreen_text'),
              style: const TextStyle(
                color: Color(0xFF1A1A1A), // Dark text for light background
                fontSize: 18,
                fontFamily: 'ElzaRound',
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            width: MediaQuery.of(context).size.width * 0.8,
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
            child: ElevatedButton(
              onPressed: _startChallenge,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  l10n.translate('challengeScreen_button_startChallenge'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                    color: Colors.white, // White text on gradient
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
          
        ],
      ),
    );
  }
  
  Widget _buildActiveChallengeContent() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              l10n.translate('challengeScreen_todaysTaskLabel'),
              style: const TextStyle(
                color: Color(0xFFed3272), // Brand pink for better hierarchy
                fontSize: 14,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0, // More spaced out for modern look
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32), // More space
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _taskMessage,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text
                  fontSize: 26, // Reduced from 36 to 26 for better readability
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w500, // Even lighter weight
                  height: 1.4, // Better line height for readability
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32), // Reduced spacing for better balance
            
            // Task action buttons
            _taskStatus == 'complete'
              ? Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    l10n.translate('challengeScreen_taskCompleteMessage'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Do Task button
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Container(
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
                          clipBehavior: Clip.antiAlias,
                          child: ElevatedButton(
                            onPressed: _doTask,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size(150, 50),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                l10n.translate('challengeScreen_button_doTask'),
                                style: const TextStyle(
                                  fontSize: 18, // Increased from 18
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white, // White text on gradient
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Mark Complete button
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: ElevatedButton(
                          onPressed: _completeTask,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white, // White background for secondary button
                            foregroundColor: const Color(0xFFed3272), // Brand pink text
                            minimumSize: const Size(150, 56),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            side: const BorderSide(
                              color: Color(0xFFed3272), // Brand pink border
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0),
                              child: Text(
                                l10n.translate('challengeScreen_button_markComplete'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFed3272), // Brand pink text
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                softWrap: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            
            
          ],
        ),
      ),
    );
  }
} 