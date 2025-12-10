import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:stoppr/core/services/video_player_defensive_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_notifications_permission.dart';

class MockupObAccountabilityScreen extends StatefulWidget {
  const MockupObAccountabilityScreen({super.key});

  @override
  State<MockupObAccountabilityScreen> createState() => _MockupObAccountabilityScreenState();
}

class _MockupObAccountabilityScreenState extends State<MockupObAccountabilityScreen> {
  VideoPlayerController? _bgController;
  bool _isBgVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Track page view
    MixpanelService.trackPageView('Onboarding Mockup Accountability Screen');
    
    // Status bar style for white BG
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    _initializeBackgroundVideo();
  }

  @override
  void dispose() {
    if (_isBgVideoInitialized) {
      _bgController?.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeBackgroundVideo() async {
    try {
      final controller = await VideoPlayerDefensiveService
          .initializeWithDefensiveMeasures(
        videoPath: 'assets/videos/mockup_accountability.mp4',
        isNetworkUrl: false,
        context: 'MockupObAccountabilityScreen-Background',
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
      debugPrint('MockupObAccountabilityScreen: Background video init error: $e');
    }
  }

  void _navigateNext() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            const OnboardingNotificationsPermissionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // White background outside the mockup
            Container(color: Colors.white),
            
            // Title at top
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 24,
              right: 24,
              child: Text(
                l10n.translate('accountability_mockup_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  height: 1.2,
                ),
              ),
            ),
            
            // Centered looping video of the phone mockup (positioned much lower for proper title spacing)
            if (_isBgVideoInitialized && _bgController != null)
              Align(
                alignment: const Alignment(0.0, 0.48),
                child: FractionallySizedBox(
                  widthFactor: 0.88, // Same sizing as onboarding_screen2
                  child: AspectRatio(
                    aspectRatio: _bgController!.value.aspectRatio,
                    child: VideoPlayer(_bgController!),
                  ),
                ),
              ),
            
            // Continue button at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                height: 110,
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: GestureDetector(
                      onTap: _navigateNext,
                      child: Container(
                        width: double.infinity,
                        height: 60,
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.translate('common_continue'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }
}

