import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audio_session/audio_session.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
// Summary: Add Crashlytics context key so native video crashes are attributed to this screen.
import 'package:stoppr/core/analytics/crashlytics_service.dart';
import 'package:stoppr/core/services/video_player_defensive_service.dart';
import 'package:stoppr/main.dart';
import 'package:stoppr/features/onboarding/presentation/screens/widgets/onboarding_language_selector.dart';


class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late VideoPlayerController _controller;
  late Timer _videoTimer;
  Locale _selectedLocale = const Locale('en');
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    CrashlyticsService.setCustomKey('video_init_context', 'OnboardingScreen');
    _initializeAudioSession();
    _initializeVideo();
  }

  Future<void> _initializeAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.ambient,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.movie,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = await VideoPlayerDefensiveService.initializeWithDefensiveMeasures(
        videoPath: 'assets/videos/onboarding-1-video.mp4',
        isNetworkUrl: false,
        context: 'OnboardingScreen',
      );
      
      _controller.setLooping(false); // No looping as we'll navigate away
      _controller.setVolume(0.0); // Mute the video
      
      // Ensure the first frame is shown and start playing
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        _controller.play();
        
        // Set a timer to navigate to next screen after 3 seconds
        _videoTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            widget.onComplete();
          }
        });
      }
    } catch (e) {
      debugPrint('OnboardingScreen video initialization error: $e');
      // Continue with the flow even if video fails
      if (mounted) {
        _videoTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            widget.onComplete();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    if (_isVideoInitialized) {
      _controller.dispose();
    }
    if (_videoTimer.isActive) {
      _videoTimer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isVideoInitialized && _controller.value.isInitialized
          ? Stack(
              children: [
                // Video background
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
                // Candy image overlay with responsive positioning and sizing
                Positioned(
                  right: MediaQuery.of(context).size.width * -0.05, // Adjusted right position
                  bottom: MediaQuery.of(context).size.height * 0.22, // Keep the same vertical position
                  width: MediaQuery.of(context).size.width * 0.30, // Reduced from 0.5 to 0.35 (35% of screen width)
                  height: MediaQuery.of(context).size.width * 0.30, // Maintain aspect ratio with reduced size
                  child: Image(
                    image: AssetImage('assets/images/onboarding/candy_screen_0.png'),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => SizedBox(width: MediaQuery.of(context).size.width * 0.30, height: MediaQuery.of(context).size.width * 0.30),
                  ),
                ),
                // Language Selection Dropdown and Welcome Text
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20, // Position below status bar
                  left: 20,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const OnboardingLanguageSelector(),
                      const SizedBox(height: 20),
                      if (AppLocalizations.of(context) != null)
                        Text(
                          AppLocalizations.of(context)!.translate('onboarding_welcome_message'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
    );
  }
}
