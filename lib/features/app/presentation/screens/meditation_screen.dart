import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:audio_session/audio_session.dart' as audiosession;
import 'package:wakelock_plus/wakelock_plus.dart';

class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Timer? _timer;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;
  audiosession.AudioSession? _audioSession;

  // TODO: Replace with the actual sound file name if different
  final String soundAssetPath = 'sounds/meditation_sound_1.mp3'; // AssetSource expects path without 'assets/' prefix

  @override
  void initState() {
    super.initState();
    _initializeAudioSession();
    // Add a short delay before setting up audio to ensure UI is ready
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _setupAudioPlayer();
      }
    });
    _startTimer();

    // Track page view with Mixpanel
    MixpanelService.trackPageView('Meditation Screen');

    // Set status bar icons to light
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // For Android (dark icons on light background)
      statusBarBrightness: Brightness.dark,      // For iOS (light icons on dark background)
    ));
  }

  Future<void> _initializeAudioSession() async {
    try {
      _audioSession = await audiosession.AudioSession.instance;
      await _audioSession?.configure(const audiosession.AudioSessionConfiguration(
        avAudioSessionCategory: audiosession.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: audiosession.AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: audiosession.AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: audiosession.AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: audiosession.AndroidAudioAttributes(
          contentType: audiosession.AndroidAudioContentType.music,
          usage: audiosession.AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: audiosession.AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      await _audioSession?.setActive(true);
      print('Audio session initialized with playback category and activated');
    } catch (e) {
      print('Error setting up audio session: $e');
    }
  }

  Future<void> _setupAudioPlayer() async {
    try {
      // Configure audio player
      await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
      // Set volume to maximum
      await _audioPlayer.setVolume(1.0);
      print('Audio player configured with loop mode and max volume');

      // Listen to states: playing, paused, stopped
      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) async {
        print('Player state changed to: $state');
        final isNowPlaying = state == PlayerState.playing;
        if (isNowPlaying) {
          await WakelockPlus.enable();
        } else {
          await WakelockPlus.disable();
        }
        if (mounted) {
          setState(() {
            _isPlaying = isNowPlaying;
          });
        }
      });

      // Listen to audio duration
       _durationSubscription = _audioPlayer.onDurationChanged.listen((newDuration) {
         print('Duration changed: $newDuration');
         if (mounted) {
           setState(() {
             _duration = newDuration;
           });
         }
       });

      // Listen to audio position
      _positionSubscription = _audioPlayer.onPositionChanged.listen((newPosition) {
        if (mounted) {
          setState(() {
            _position = newPosition;
          });
        }
      });

      // Listen for when audio completes (might be useful if not looping)
       _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
         print('Audio playback completed');
         if (mounted && !_audioPlayer.releaseMode.name.contains('loop')) { // only reset if not looping
           setState(() {
             _position = Duration.zero;
             _isPlaying = false;
           });
         }
       });

      // Preload and play the audio
       await _play();

    } catch (e) {
      print("Error setting up audio player: $e");
      // Handle error appropriately, maybe show a message to the user
    }
  }

  void _startTimer() {
    // Update the UI timer display every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
       // This might not be strictly necessary if onPositionChanged updates frequently enough,
       // but can serve as a fallback or ensure UI updates even if position stream pauses.
       // We just need to call setState to rebuild with the latest _position.
       if (mounted && _isPlaying) {
         setState(() {}); 
       }
    });
  }
  
  Future<void> _play() async {
    try {
      print('Attempting to play audio from: $soundAssetPath');
      // Ensure volume is at maximum
      await _audioPlayer.setVolume(1.0);
      // Stop any existing audio before playing
      await _audioPlayer.stop();
      // Play the audio
      await _audioPlayer.play(AssetSource(soundAssetPath));
      await WakelockPlus.enable();
      if (mounted) {
        setState(() {
          _isPlaying = true; 
        });
      }
       print('Audio playing command executed');
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  Future<void> _pause() async {
    try {
      await _audioPlayer.pause();
      await WakelockPlus.disable();
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
       print('Audio paused');
    } catch (e) {
      print("Error pausing audio: $e");
    }
  }

  Future<void> _resume() async {
    try {
      await _audioPlayer.resume();
      await WakelockPlus.enable();
       if (mounted) {
         setState(() {
           _isPlaying = true;
         });
       }
       print('Audio resumed');
    } catch (e) {
      print("Error resuming audio: $e");
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _audioSession?.setActive(false);
    _timer?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose(); // Release the audio player resources
    super.dispose();
  }
  
  // Method to open help/info URL (copied from BreathingExerciseScreen)
  Future<void> _openHelpInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Meditation Screen');

    // Notion page URL
    final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4'); 
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppWebView, 
        );
      } else {
        debugPrint('Could not launch help & info URL');
        // Optionally show a snackbar or dialog to the user
      }
    } catch (e) {
      debugPrint('Error launching help & info URL: $e');
      // Optionally show a snackbar or dialog to the user
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // Ensure status bar style is reapplied if the screen is rebuilt
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, 
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      // Updated Background Color
      backgroundColor: const Color(0xFF2E1A47), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Back button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            // Track back button tap
            MixpanelService.trackButtonTap('Back', screenName: 'Meditation Screen');
            Navigator.of(context).pop();
          },
          tooltip: AppLocalizations.of(context)!.translate('common_back'),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        actions: [
          // Updated Help & Info icon button to match outline style
          Padding(
            padding: const EdgeInsets.only(right: 16.0), // Adjusted padding slightly
            child: Container(
              width: 22, // Make circle smaller
              height: 22,
              decoration: BoxDecoration(
                // Remove background color
                shape: BoxShape.circle,
                // Add white border
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.question_mark_rounded, // Or Icons.help_outline if preferred
                  color: Colors.white, // Icon color is white
                  size: 16, // Make icon smaller
                ),
                onPressed: _openHelpInfo,
                tooltip: AppLocalizations.of(context)!.translate('pledgeScreen_tooltip_help'),
                padding: EdgeInsets.zero, // Remove default padding
                constraints: const BoxConstraints(), // Remove default constraints
                alignment: Alignment.center, // Ensure icon is centered
              ),
            ),
          ),
        ],
      ),
      // Add Stack to layer background elements
      body: Stack(
        alignment: Alignment.center, // Default alignment for children
        children: [
          // Background Decorative Elements (remain positioned)
          Positioned(
            top: 100,
            left: 20,
            child: Transform.rotate(
              angle: -0.5,
              child: Container(
                width: 60,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: 30,
            child: Transform.rotate(
              angle: 0.2,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purpleAccent.withOpacity(0.5),
                      Colors.deepPurple.withOpacity(0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.rectangle,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(25),
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 150,
            right: 50,
             child: Transform.rotate(
               angle: -0.8,
               child: Container(
                 width: 40,
                 height: 80,
                 decoration: BoxDecoration(
                   color: Colors.purple.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(20),
                 ),
               ),
             ),
          ),
          // Title and Subtitle positioned above the timer
          Align(
            // Adjust the Y value to position it above the timer (which is at -0.4)
            alignment: const Alignment(0.0, -0.6), 
            child: Column(
              mainAxisSize: MainAxisSize.min, // Column takes minimum space
              children: [
                Text(
                  AppLocalizations.of(context)!.translate('meditation_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.translate('sounds_by_stoppr'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Timer positioned slightly above the center button
          Align(
            // Adjust the Y value (-0.2 means 20% up from center)
            alignment: const Alignment(0.0, -0.3), // Moving timer down slightly
            child: Text(
              _formatDuration(_position),
              style: const TextStyle(
                color: Colors.white,
                // fontSize: 60, // Make timer larger
                fontSize: 30, // Decreased font size by 2x
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Play/Pause Button - Now truly centered using Align
          // The Align widget defaults to Alignment.center if not specified,
          // or we can be explicit:
          Align(
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: const Color(0xFF2E1A47), // Use background color for icon
                  size: 100, // Make icon larger
                ),
                iconSize: 120, // Make button larger
                onPressed: () {
                  if (_isPlaying) {
                    MixpanelService.trackButtonTap('Pause Meditation', screenName: 'Meditation Screen');
                    _pause();
                  } else {
                     MixpanelService.trackButtonTap('Play Meditation', screenName: 'Meditation Screen');
                    _resume(); // Use resume if already loaded, otherwise _play handles loading
                  }
                },
                tooltip: _isPlaying
                    ? AppLocalizations.of(context)!.translate('common_pause')
                    : AppLocalizations.of(context)!.translate('common_play'),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 