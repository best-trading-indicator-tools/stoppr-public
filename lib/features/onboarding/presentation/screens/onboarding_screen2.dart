import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/main.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart'; // Import MainScaffold
import 'package:stoppr/core/analytics/mixpanel_service.dart'; // Import MixpanelService
import 'package:video_player/video_player.dart';
import 'package:stoppr/core/services/video_player_defensive_service.dart';
import 'dart:io'; // Import for Platform check
import 'package:flutter/services.dart'; // Import for SystemChrome and haptic feedback
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import 'package:stoppr/permissions/permission_service.dart';
import 'package:stoppr/core/subscription/subscription_service.dart';
import 'package:stoppr/core/services/onboarding_audio_service.dart';
import 'package:stoppr/features/onboarding/presentation/screens/widgets/onboarding_sound_toggle.dart';
import 'package:stoppr/features/onboarding/presentation/screens/widgets/onboarding_language_selector.dart';


class OnboardingScreen2 extends StatefulWidget {
  final VoidCallback onStartQuiz;
  
  const OnboardingScreen2({
    super.key, 
    required this.onStartQuiz,
  });

  @override
  State<OnboardingScreen2> createState() => _OnboardingScreen2State();
}

class _OnboardingScreen2State extends State<OnboardingScreen2>
    with SingleTickerProviderStateMixin {
  late Locale _selectedLocale;
  bool _isInitialLoad = true; // Flag for initial load logic
  final NotificationService _notificationService = NotificationService();
  final PermissionService _permissionService = PermissionService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  AnimationController? _audioIconController;
  Animation<double>? _audioIconScale;

  // Background phone-mockup video controller
  VideoPlayerController? _bgController;
  bool _isBgVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedLocale = const Locale('en');
    MixpanelService.trackPageView('Onboarding Card Start Quiz View');
    // Auto-start onboarding music by default (respects saved pref; default ON)
    OnboardingAudioService.instance
        .startWithAssetIfEnabled('sounds/onboarding_528HZ.mp3')
        .then((_) {
      if (mounted) setState(() {});
    });
    // Prepare pulsing animation for the audio icon
    _audioIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _audioIconScale = Tween<double>(begin: 1.0, end: 1.30).animate(
      CurvedAnimation(parent: _audioIconController!, curve: Curves.easeInOut),
    );
    _audioIconController!.repeat(reverse: true);
    
    // System UI styling handled in MainActivity.kt
    
    // Add a delay before initializing notifications to ensure UI is ready
    // Notifications permission prompt moved to OnboardingNotificationsPermissionScreen

    // Initialize background mockup video
    _initializeBackgroundVideo();
  }

  @override
  void dispose() {
    if (_isBgVideoInitialized) {
      _bgController?.dispose();
    }
    _audioIconController?.dispose();
    super.dispose();
  }

  // Ensure audio stops on Flutter hot reload (debug-only lifecycle hook)
  @override
  void reassemble() {
    super.reassemble();
    OnboardingAudioService.instance.stop();
  }

  

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = Localizations.localeOf(context);

    if (_selectedLocale != newLocale || _isInitialLoad) {
      _selectedLocale = newLocale;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Check if the widget is still in the tree
          setState(() {
            // This setState ensures the widget rebuilds with the correct
            // AppLocalizations instance and reflects the _selectedLocale.
          });
        }
      });
      _isInitialLoad = false; // Clear the flag after the first effective update
    }
  }

  // Initialize notification service using centralized method
  Future<void> _initializeNotifications() async {
    debugPrint('OnboardingScreen2: Initializing notifications via centralized method...');
    
    try {
      final isGranted = await _notificationService.initializeOnboardingNotifications(
        context: 'onboarding_screen2',
      );
      
      debugPrint('OnboardingScreen2: Notification initialization result: $isGranted');
    } catch (e) {
      debugPrint('OnboardingScreen2: Error during notification initialization: $e');
    }
  }

  Future<void> _initializeBackgroundVideo() async {
    try {
      final controller = await VideoPlayerDefensiveService
          .initializeWithDefensiveMeasures(
        videoPath: 'assets/videos/onboarding_mockup.mp4',
        isNetworkUrl: false,
        context: 'OnboardingScreen2-Background',
      );

      controller.setLooping(true);
      controller.setVolume(0.0);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _bgController = controller;
        _isBgVideoInitialized = true;
      });

      // Start playback after setState to ensure widget tree has the controller
      controller.play();
    } catch (e) {
      debugPrint('OnboardingScreen2: Background video init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    debugPrint("Status bar height: $topPadding");
    
    return Scaffold(
      body: Stack( // Outer Stack for the debug button
        children: [
          Stack(
            fit: StackFit.expand,
            children: [
              // White background outside the mockup
              Container(color: Colors.white),
              // Centered looping video of the phone mockup, sized down so
              // the full phone (with surroundings) is visible and positioned
              // above the sticky footer.
              if (_isBgVideoInitialized && _bgController != null)
                Align(
                  alignment: const Alignment(0.0, -0.35),
                  child: FractionallySizedBox(
                    widthFactor: 0.75,
                    child: AspectRatio(
                      aspectRatio: _bgController!.value.aspectRatio,
                      child: VideoPlayer(_bgController!),
                    ),
                  ),
                ),
              
              // Content
              Positioned.fill(
                child: Column(
                children: [
                    const SizedBox(height: 50),
                  
                  // Stoppr title and subtitle
                  const SizedBox.shrink(),
                  
                    const Spacer(flex: 5),
                  
                  // White card at bottom
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 24.0,
                        right: 24.0,
                        top: 12.0,
                        bottom: 20.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.translate('onboarding2_findOutProblem'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                              letterSpacing: 0,
                              color: Color(0xFF181830),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/images/svg/stars-onboarding-screen-2.svg',
                                height: 19,
                              ),
                              const SizedBox(height: 14),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                            text: AppLocalizations.of(context)!.translate('onboarding2_satisfactionJoin'),
                                            style: const TextStyle(
                                              fontFamily: 'ElzaRound',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              height: 1.0,
                                              letterSpacing: -0.01 * 18,
                                              color: Color(0xFF1A051D),
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' ${AppLocalizations.of(context)!.translate('onboarding2_satisfactionPercentage')}',
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                              fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                        letterSpacing: -0.01 * 18,
                                        color: Color(0xFF1A051D),
                                      ),
                                    ),
                                    TextSpan(
                                            text: ' ${AppLocalizations.of(context)!.translate('onboarding2_satisfactionWomen')}',
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        height: 1.0,
                                        letterSpacing: -0.01 * 18,
                                        color: Color(0xFF1A051D),
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      AppLocalizations.of(context)!.translate('onboarding2_satisfactionText'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        height: 1.0,
                                        letterSpacing: -0.01 * 18,
                                        color: Color(0xFF1A051D),
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFFed3272), // Strong pink/magenta
                                  Color(0xFFfd5d32), // Vivid orange
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                // Add haptic feedback for start quiz button
                                HapticFeedback.lightImpact();
                                widget.onStartQuiz();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.translate('common_continue'),
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound',
                                      fontSize: 19,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                      height: 0.9,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SvgPicture.asset(
                                    'assets/images/svg/start-quiz-arrow.svg',
                                    height: 16,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ],
          ),
          // Top overlays on the right: sound toggle + language selector
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OnboardingSoundToggle(
                  diameter: 40,
                  eventName: 'Onboarding Card Start Quiz View: Sound Button Tap',
                ),
                const SizedBox(width: 8),
                const OnboardingLanguageSelector(),
              ],
            ),
          ),
          // Debug/TestFlight button to navigate to MainScaffold
          FutureBuilder<bool>(
            future: MixpanelService.isTestFlight(),
            builder: (context, snapshot) {
              final showHomeIcon = kDebugMode || (snapshot.data == true);
              if (!showHomeIcon) return const SizedBox.shrink();
              return Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.home, color: Colors.white, size: 24),
                    tooltip: 'Go to Home (Debug)',
                    onPressed: () async {
                      // Ensure auth is established before navigation
                      final FirebaseAuth auth = FirebaseAuth.instance;
                      if (auth.currentUser == null) {
                        debugPrint('Debug: No user authenticated, signing in anonymously...');
                        try {
                          await auth.signInAnonymously();
                          debugPrint('Debug: Anonymous auth successful: ${auth.currentUser?.uid}');
                        } catch (e) {
                          debugPrint('Debug: Anonymous auth failed: $e');
                        }
                      } else {
                        debugPrint('Debug: Using existing auth: ${auth.currentUser?.uid}');
                      }
                      
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MainScaffold.createRoute(initialIndex: 0),
                        (Route<dynamic> route) => false, // Remove all previous routes
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // Debug sign out button - only visible in debug mode
          if (kDebugMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 72, // Position it next to the home button
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white, size: 24),
                  tooltip: 'Sign Out (Debug)',
                  onPressed: () async {
                    try {
                      // Import Firebase Auth
                      final FirebaseAuth _auth = FirebaseAuth.instance;
                      
                      // Sign out from Firebase
                      await _auth.signOut();
                      
                      // Clear SharedPreferences
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      
                      debugPrint('✅ User signed out successfully');
                      
                      // Show confirmation
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context)!.translate('successMessage_signedOut')),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('❌ Error signing out: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.translate('errorMessage_signOut').replaceFirst('{error}', e.toString())),
                          backgroundColor: Colors.red,
                        ),
                      );
                      }
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
} 