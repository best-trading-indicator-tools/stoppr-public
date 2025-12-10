// Summary: After successful payment, show an in-app rating prompt on this
// congratulations screen. Reuses InAppReviewService, triggered post-frame with
// a short delay, without changing the UI.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'congratulations_screen_2.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/core/services/onboarding_audio_service.dart';
import 'package:stoppr/core/services/in_app_review_service.dart';

class CongratulationsScreen1 extends StatefulWidget {
  const CongratulationsScreen1({super.key});

  @override
  State<CongratulationsScreen1> createState() => _CongratulationsScreen1State();
}

class _CongratulationsScreen1State extends State<CongratulationsScreen1> {
  String? _firstName;
  final StreakService _streakService = StreakService();
  final InAppReviewService _reviewService = InAppReviewService();

  @override
  void initState() {
    super.initState();
    _loadUserFirstName();
    _resetStreakAndSetFlag();
    _initFirstUseDateIfMissing();
    // Stop onboarding music when landing on congratulations
    OnboardingAudioService.instance.stop();
    
    // Apply system UI settings to ensure white status bar icons
    _setSystemUIOverlayStyle();
    
    // Track page view
    MixpanelService.trackPageView('Onboarding Congratulations Screen 1');

    // Prompt for app rating/review shortly after landing here (post-payment)
    _requestInAppReview();
  }
  
  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for Android
      statusBarBrightness: Brightness.light, // Dark icons for iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    
    // Add Android-specific immersive mode setting
    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );
    }
  }

  Future<void> _loadUserFirstName() async {
    try {
      // Try to get name from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedFirstName = prefs.getString('user_first_name');
      
      if (savedFirstName != null && savedFirstName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _firstName = savedFirstName;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user first name: $e');
    }
  }

  Future<void> _resetStreakAndSetFlag() async {
    try {
      await _streakService.initialize();
      await _streakService.resetStreakCounter();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('coming_from_congratulations', true);
      debugPrint('Streak reset and coming_from_congratulations flag set.');
    } catch (e) {
      debugPrint('Error resetting streak or setting flag: $e');
    }
  }

  // Initialize first app use date if not already set. This must never overwrite.
  Future<void> _initFirstUseDateIfMissing() async {
    try {
      const key = 'first_app_use_date_iso';
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(key);
      if (existing == null || existing.isEmpty) {
        final nowIso = DateTime.now().toIso8601String();
        await prefs.setString(key, nowIso);
        debugPrint('Initialized $key to $nowIso');
      } else {
        debugPrint('$key already set: $existing');
      }
    } catch (e) {
      debugPrint('Error initializing first app use date: $e');
    }
  }

  void _requestInAppReview() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        // Rating prompt disabled per request:
        // _reviewService.requestReviewIfAppropriate(
        //   screenName: 'CongratulationsScreen1',
        //   bypassSubscriptionCheck: true,
        // );
      });
    });
  }

  void _navigateToNextScreen() {
    Navigator.of(context).pushReplacement(
      FadePageRoute(
        child: const CongratulationsScreen2(),
      ),
    );
  }

  void _skipToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      FadePageRoute(
        child: const MainScaffold(initialIndex: 0, fromCongratulations: true),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Skip button in the top-right corner
          TextButton(
            onPressed: _skipToHome,
            child: const Text(
              'SKIP',
              style: TextStyle(
                color: Color(0xFFed3272),
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: GestureDetector(
        onTap: _navigateToNextScreen,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFBFBFB),
                    Color(0xFFFBFBFB),
                  ],
                ),
              ),
            ),
            
            // Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top padding to move content down from AppBar
                const SizedBox(height: 20),
                
                // Title with name if available
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    _firstName != null 
                        ? 'Whenever you need us,\nwe\'re right here, $_firstName.'
                        : 'Whenever you need us,\nwe\'re right here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      height: 1.3,
                    ),
                  ),
                ),
                
                // Expanded space to push content to top and bottom
                const Spacer(),
                
                // Rocket Lottie animation centered
                SizedBox(
                  height: screenSize.height * 0.4,
                  child: Lottie.asset(
                    'assets/images/lotties/Rocket.json',
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
                
                // Expanded space to push bottom content
                const Spacer(),
                
                // Tap to continue text at bottom
                Padding(
                  padding: EdgeInsets.only(bottom: Platform.isAndroid ? 70.0 : 40.0),
                  child: const Text(
                    'TAP TO CONTINUE',
                    style: TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                      letterSpacing: 1.5,
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