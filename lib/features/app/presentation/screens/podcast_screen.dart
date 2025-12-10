import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/services/remote_audio_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:audio_session/audio_session.dart' as audiosession;
import 'package:wakelock_plus/wakelock_plus.dart';

// Renamed class
class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState(); // Renamed state class
}

// Renamed state class
class _PodcastScreenState extends State<PodcastScreen> {
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

  // Audio download state
  String? _audioFilePath;
  bool _isDownloading = true;
  bool _downloadFailed = false;

  @override
  void initState() {
    super.initState();
    _initializeAudioSession();
    _downloadAudio();
    _startTimer();

    // Track page view with Mixpanel - Updated screen name
    MixpanelService.trackPageView('Podcast Screen');

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
      debugPrint('Audio session initialized with playback category and activated');
    } catch (e) {
      debugPrint('Error setting up audio session: $e');
    }
  }

  Future<void> _downloadAudio() async {
    try {
      debugPrint('Downloading podcast audio from Firebase Storage...');
      final audioPath = await RemoteAudioService.getAudioPath('podcast');
      
      if (mounted) {
        setState(() {
          _audioFilePath = audioPath;
          _isDownloading = false;
          _downloadFailed = audioPath == null;
        });
        
        if (audioPath != null) {
          // Add a short delay before setting up audio to ensure UI is ready
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _setupAudioPlayer();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error downloading podcast audio: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadFailed = true;
        });
      }
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
      if (_audioFilePath == null) {
        debugPrint('Cannot play: audio file path is null');
        return;
      }
      
      debugPrint('Attempting to play audio from: $_audioFilePath');
      // Ensure volume is at maximum
      await _audioPlayer.setVolume(1.0);
      // Stop any existing audio before playing
      await _audioPlayer.stop();
      // Play the audio from downloaded file
      await _audioPlayer.play(DeviceFileSource(_audioFilePath!));
      await WakelockPlus.enable();
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
       debugPrint('Audio playing command executed');
    } catch (e) {
      debugPrint("Error playing audio: $e");
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
    // Track button tap with Mixpanel - Updated screen name
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Podcast Screen');

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

    // Define the gradient
    const orangeYellowGradient = LinearGradient(
      colors: [Color(0xFFFFA726), Color(0xFFFFE082)], // Orange to Light Yellow/Orange
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      // Use Container with gradient for background
      body: Container(
        decoration: const BoxDecoration(
          gradient: orangeYellowGradient,
        ),
        child: Column( // Use Column to structure AppBar and Body
          children: [
            // Custom AppBar Area (using SafeArea and Padding)
            SafeArea(
              bottom: false, // Don't include bottom padding in safe area
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 16.0), // Adjust padding as needed
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () {
                        // Track back button tap - Updated screen name
                        MixpanelService.trackButtonTap('Back', screenName: 'Podcast Screen');
                        Navigator.of(context).pop();
                      },
                      tooltip: AppLocalizations.of(context)!.translate('common_back'),
                    ),
                    // Help & Info icon button
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.question_mark_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        onPressed: _openHelpInfo,
                        tooltip: AppLocalizations.of(context)!.translate('pledgeScreen_tooltip_help'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        alignment: Alignment.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Body Content (Expanded to fill remaining space)
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background Decorative Elements (adjusted colors if needed)
                  Positioned(
                    top: 100,
                    left: 20,
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Container(
                        width: 60,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.3), // Adjusted color
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
                              Colors.yellowAccent.withOpacity(0.5), // Adjusted color
                              Colors.orange.withOpacity(0.5),      // Adjusted color
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
                           color: Colors.yellow.withOpacity(0.2), // Adjusted color
                           borderRadius: BorderRadius.circular(20),
                         ),
                       ),
                     ),
                  ),
                  // Title and Subtitle positioned above the timer
                  Align(
                    alignment: const Alignment(0.0, -0.6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Updated Title
                        Text(
                          AppLocalizations.of(context)!.translate('podcast_title'),
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
                    alignment: const Alignment(0.0, -0.3),
                    child: Text(
                      _formatDuration(_position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Play/Pause Button
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
                          // Updated icon color to contrast with orange/yellow
                          color: const Color(0xFFE65100), // Dark Orange
                          size: 100,
                        ),
                        iconSize: 120,
                        onPressed: () {
                          if (_isPlaying) {
                            // Updated Mixpanel event
                            MixpanelService.trackButtonTap('Pause Podcast', screenName: 'Podcast Screen');
                            _pause();
                          } else {
                            // Updated Mixpanel event
                             MixpanelService.trackButtonTap('Play Podcast', screenName: 'Podcast Screen');
                            _resume();
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
            ),
          ],
        ),
      ),
    );
  }
} 