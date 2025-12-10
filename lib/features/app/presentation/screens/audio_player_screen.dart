import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:audio_session/audio_session.dart' as audiosession;
import 'package:wakelock_plus/wakelock_plus.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String title;
  final String audioPath;
  final bool isLocalFile;
  
  const AudioPlayerScreen({
    super.key,
    required this.title,
    required this.audioPath,
    this.isLocalFile = false,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
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
    MixpanelService.trackPageView('Audio Player Screen', additionalProps: {
      'audio_title': widget.title,
      'audio_path': widget.audioPath,
    });

    // Set status bar icons to light
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
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

  Future<void> _setupAudioPlayer() async {
    try {
      // Configure audio player
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Set volume to maximum
      await _audioPlayer.setVolume(1.0);
      debugPrint('Audio player configured with loop mode and max volume');

      // Listen to states: playing, paused, stopped
      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) async {
        debugPrint('Player state changed to: $state');
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
         debugPrint('Duration changed: $newDuration');
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
         debugPrint('Audio playback completed');
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
      debugPrint("Error setting up audio player: $e");
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
      debugPrint('Attempting to play audio from: ${widget.audioPath}');
      // Ensure volume is at maximum
      await _audioPlayer.setVolume(1.0);
      // Stop any existing audio before playing
      await _audioPlayer.stop();
      
      // Play the audio from either local file or asset
      if (widget.isLocalFile) {
        await _audioPlayer.play(DeviceFileSource(widget.audioPath));
        debugPrint('Playing from local file: ${widget.audioPath}');
      } else {
        await _audioPlayer.play(AssetSource(widget.audioPath));
        debugPrint('Playing from asset: ${widget.audioPath}');
      }
      
      // For NSDR audio, skip the first 4 seconds
      if (widget.audioPath.contains('NSDR.mp3')) {
        await _audioPlayer.seek(const Duration(seconds: 4));
        debugPrint('Skipped first 4 seconds for NSDR audio');
      }
      
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
       debugPrint('Audio paused');
    } catch (e) {
      debugPrint("Error pausing audio: $e");
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
       debugPrint('Audio resumed');
    } catch (e) {
      debugPrint("Error resuming audio: $e");
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

  // Method to open help/info URL
  Future<void> _openHelpInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Audio Player Screen');

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

    // Define the gradient - using a calming purple/blue gradient for audio
    const purpleBlueGradient = LinearGradient(
      colors: [Color(0xFF667eea), Color(0xFF764ba2)], // Purple to Blue
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      // Use Container with gradient for background
      body: Container(
        decoration: const BoxDecoration(
          gradient: purpleBlueGradient,
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
                        // Track back button tap
                        MixpanelService.trackButtonTap('Back', screenName: 'Audio Player Screen');
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
                  // Background Decorative Elements
                  Positioned(
                    top: 100,
                    left: 20,
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Container(
                        width: 60,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
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
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.1),
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
                           color: Colors.white.withOpacity(0.1),
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
                        // Dynamic Title
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.translate('audio_by_stoppr'),
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
                          color: const Color(0xFF667eea), // Matching gradient color
                          size: 100,
                        ),
                        iconSize: 120,
                        onPressed: () {
                          if (_isPlaying) {
                            MixpanelService.trackButtonTap('Pause Audio: ${widget.title}', screenName: 'Audio Player Screen');
                            _pause();
                          } else {
                             MixpanelService.trackButtonTap('Play Audio: ${widget.title}', screenName: 'Audio Player Screen');
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