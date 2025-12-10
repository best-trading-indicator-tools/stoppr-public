import 'dart:convert';
import 'package:stoppr/core/utils/text_sanitizer.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/features/learn/domain/models/learn_video_lesson.dart';
import 'package:stoppr/features/learn/presentation/cubit/learn_video_cubit.dart';
import 'package:stoppr/features/learn/presentation/widgets/learn_info_bottom_sheet_widget.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;
import 'package:stoppr/core/services/video_player_defensive_service.dart';
import 'package:stoppr/core/analytics/crashlytics_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

// Summary: Hardened back handling to prevent LateInitializationError by
// safely guarding access to the late VideoPlayerController in _onWillPop.
// This ensures back presses before initialization (or during init errors)
// do not access the controller and instead allow the pop gracefully.

class FullScreenVideoPlayerScreen extends StatefulWidget {
  final LearnVideoLesson lesson;

  const FullScreenVideoPlayerScreen({super.key, required this.lesson});

  @override
  State<FullScreenVideoPlayerScreen> createState() =>
      _FullScreenVideoPlayerScreenState();
}

class _FullScreenVideoPlayerScreenState
    extends State<FullScreenVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _lessonInitiallyCompleted = false;
  bool _isMuted = false;
  bool _showCaptions = true; // Default to captions on
  String _currentCaption = '';
  List<_SubtitleEntry> _subtitles = [];
  bool _hasPoppedAfterCompletion = false; // Prevent multiple pops
  bool _showControls = true;
  bool _showIcons = true;
  Timer? _hideControlsTimer;
  double? _lastSeekPosition;
  
  // Android-specific defensive measures
  bool _isInitializing = false;
  bool _hasInitializationError = false;
  Timer? _initializationTimeout;
  
  // iOS 18+ specific: Additional render guard to prevent platform view race
  bool _isReadyToRender = false;

  @override
  void initState() {
    super.initState();
    CrashlyticsService.setCustomKey('video_init_context', 'FullScreenVideoPlayer-${widget.lesson.title}');
    _lessonInitiallyCompleted = widget.lesson.isCompleted;
    _initAudioSession();

    // Enable edge-to-edge to keep system bars visible while letting content extend behind them
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Then set the desired overlay style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // For iOS
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Universal defensive video controller initialization
    _initializeVideoControllerUniversal();
  }

  Future<void> _initializeVideoControllerUniversal() async {
    if (_isInitializing) return;
    
    _isInitializing = true;
    _hasInitializationError = false;
    
    // Universal timeout for initialization (both platforms)
    _initializationTimeout = Timer(const Duration(seconds: 10), () {
      if (_isInitializing && mounted) {
        debugPrint('Video initialization timeout on ${Platform.operatingSystem}');
        _handleInitializationError('Initialization timeout');
      }
    });

    try {
      String videoUrl = widget.lesson.videoAssetPath;
      bool isMuxStream = widget.lesson.videoAssetPath.contains('stream.mux.com');

      if (isMuxStream) {
        Uri uri = Uri.parse(videoUrl);
        if (!uri.queryParameters.containsKey('default_subtitles_lang')) {
          videoUrl = Uri.parse(videoUrl)
              .replace(queryParameters: {
                ...uri.queryParameters,
                'default_subtitles_lang': 'en',
              })
              .toString();
          debugPrint('Modified Mux URL for subtitles: $videoUrl');
        }
      }

      // Create controller using defensive service
      final headers = videoUrl.startsWith('http') ? _getPlatformHeaders() : null;
      _controller = await VideoPlayerDefensiveService.initializeWithDefensiveMeasures(
        videoPath: videoUrl,
        isNetworkUrl: videoUrl.startsWith('http'),
        httpHeaders: headers,
        formatHint: videoUrl.startsWith('http') ? VideoFormat.hls : null,
        context: 'FullScreenVideoPlayer-${widget.lesson.title}',
      );
      
      if (mounted && !_hasInitializationError) {
        _isInitializing = false;
        _initializationTimeout?.cancel();
        
        // iOS 18+: Add extra safety delay before rendering VideoPlayer widget
        // to ensure platform view is fully registered
        final isIOS18 = Platform.isIOS && await VideoPlayerDefensiveService.isIOS18OrLater;
        if (isIOS18) {
          // First setState to show loading is done but widget not rendered yet
          setState(() {});
          
          // Additional safety delay before rendering (100ms is sufficient here)
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (!mounted) return;
          
          setState(() {
            _isReadyToRender = true;
          });
        } else {
          // Non-iOS 18: Safe to render immediately
          setState(() {
            _isReadyToRender = true;
          });
        }
        
        _controller.play();
        _controller.setVolume(_isMuted ? 0.0 : 1.0);
        
        // Setup platform-appropriate video listener
        _setupVideoListener();
        _loadSubtitles(videoUrl, isMuxStream);
        
        MixpanelService.trackEvent('Learn ${widget.lesson.title} - Start Played', 
          properties: {
            'lesson_id': widget.lesson.id, 
            'lesson_title': widget.lesson.title,
            'platform': Platform.operatingSystem,
          });
        
        debugPrint("Video initialized successfully on ${Platform.operatingSystem}");
      }
      
    } catch (e, stackTrace) {
      debugPrint('Video initialization error on ${Platform.operatingSystem}: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Error tracking via Crashlytics
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          e,
          stackTrace,
          reason: 'Video Player Init Error',
          information: [
            'context: FullScreenVideoPlayer-${widget.lesson.title}',
            'lesson_id: ${widget.lesson.id}',
            'lesson_title: ${widget.lesson.title}',
            'platform: ${Platform.operatingSystem}',
          ],
        );
      }
      
      _handleInitializationError(e.toString());
    }
  }

  Map<String, String>? _getPlatformHeaders() {
    if (Platform.isAndroid) {
      return {
        'User-Agent': 'StopprApp/Android',
        'Cache-Control': 'no-cache',
      };
    } else if (Platform.isIOS) {
      return {
        'User-Agent': 'StopprApp/iOS',
      };
    }
    return null;
  }

  void _setupVideoListener() {
    _controller.addListener(() async {
      if (!mounted || !_controller.value.isInitialized || _hasInitializationError) return;
      
      try {
        // Check for video errors with Samsung-specific tracking
        if (_controller.value.hasError) {
          final errorDescription = _controller.value.errorDescription ?? 'Unknown playback error';
          debugPrint('Video playback error on ${Platform.operatingSystem}: $errorDescription');
          
          // Enhanced playback error tracking (without blocking Samsung check)
          if (!kDebugMode) {
            FirebaseCrashlytics.instance.recordError(
              errorDescription,
              StackTrace.current,
              reason: 'Video Player Playback Error',
              information: [
                'context: FullScreenVideoPlayer-${widget.lesson.title}',
                'lesson_id: ${widget.lesson.id}',
                'lesson_title: ${widget.lesson.title}',
                'platform: ${Platform.operatingSystem}',
              ],
            );
          }
          
          // Handle Samsung-specific error logging asynchronously
          _handleSamsungPlaybackError('FullScreenVideoPlayer-${widget.lesson.title}', errorDescription);
          
          _handleInitializationError(errorDescription);
          return;
        }

        // Update manual subtitles based on current position
        if (_subtitles.isNotEmpty) {
          _updateManualSubtitles();
        }
        
        // Debug print caption text changes
        final currentCaptionText = _controller.value.caption.text;
        if (currentCaptionText.isNotEmpty) {
          debugPrint("Caption Update: '$currentCaptionText'");
        }

        final bool isVideoFinished = _controller.value.position >= _controller.value.duration;
        if (isVideoFinished && !_controller.value.isPlaying && !_hasPoppedAfterCompletion) {
          MixpanelService.trackEvent('Learn Video ${widget.lesson.title} - Finished', 
            properties: {
              'lesson_id': widget.lesson.id, 
              'lesson_title': widget.lesson.title,
              'platform': Platform.operatingSystem,
            });
          _hasPoppedAfterCompletion = true;
          
          final currentLessonStateInCubit = context.read<LearnVideoCubit>().state.maybeWhen(
                loaded: (lessons, _, __) => lessons.firstWhere((l) => l.id == widget.lesson.id, orElse: () => widget.lesson),
                orElse: () => widget.lesson,
              );
          if (!currentLessonStateInCubit.isCompleted) {
            context.read<LearnVideoCubit>().markLessonCompleted(widget.lesson.id);
          }
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
        
        // Track play/pause events
        if (mounted && (_controller.value.isPlaying != _wasPlayingBeforeListener)) {
          setState(() {});
          if (_controller.value.isPlaying && !_wasPlayingBeforeListener) {
            _startHideControlsTimer();
            MixpanelService.trackEvent('Learn ${widget.lesson.title} - Played', 
              properties: {
                'lesson_id': widget.lesson.id, 
                'lesson_title': widget.lesson.title,
                'platform': Platform.operatingSystem,
              });
          } else if (!_controller.value.isPlaying && _wasPlayingBeforeListener) {
            MixpanelService.trackEvent('Learn ${widget.lesson.title} - Paused', 
              properties: {
                'lesson_id': widget.lesson.id, 
                'lesson_title': widget.lesson.title,
                'platform': Platform.operatingSystem,
              });
          }
        }
        _wasPlayingBeforeListener = _controller.value.isPlaying;
        
      } catch (e, stackTrace) {
        debugPrint('Video listener error on ${Platform.operatingSystem}: $e');
        debugPrint('Stack trace: $stackTrace');
        
        // Handle Samsung-specific listener error logging asynchronously
        _handleSamsungListenerError('FullScreenVideoPlayer-${widget.lesson.title}', e, stackTrace);
        
        // Don't propagate listener errors to avoid cascade failures
      }
    });
  }

  void _handleInitializationError(String error) {
    if (mounted) {
      setState(() {
        _hasInitializationError = true;
        _isInitializing = false;
      });
      _initializationTimeout?.cancel();
      
      debugPrint('Video initialization failed on ${Platform.operatingSystem}: $error');
      
      // Enhanced error tracking (without blocking Samsung check)
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          error,
          StackTrace.current,
          reason: 'Learn Video Error',
          information: [
            'lesson_id: ${widget.lesson.id}',
            'platform: ${Platform.operatingSystem}',
            'error_type: ${Platform.isAndroid ? 'android_platform_view' : 'ios_avplayer'}',
          ],
        );
      }
      
      // Handle Samsung-specific error logging asynchronously
      _handleSamsungInitError(error);
    }
  }
  
  /// Handle Samsung-specific playback error logging asynchronously
  Future<void> _handleSamsungPlaybackError(String context, String errorDescription) async {
    try {
      final isSamsung = await VideoPlayerDefensiveService.isSamsungDevice;
      
      if (isSamsung) {
        CrashlyticsService.setCustomKey('samsung_playback_error', true);
        CrashlyticsService.setCustomKey('playback_error_context', context);
        CrashlyticsService.setCustomKey('playback_lesson_id', widget.lesson.id);
        
        CrashlyticsService.logException(
          Exception('Samsung Video Playback Error: $errorDescription'),
          StackTrace.current,
          reason: 'Samsung Video Playback Error - ${widget.lesson.title}',
        );
      }
    } catch (e) {
      debugPrint('Error handling Samsung playback error: $e');
    }
  }
  
  /// Handle Samsung-specific listener error logging asynchronously
  Future<void> _handleSamsungListenerError(String context, Object error, StackTrace stackTrace) async {
    try {
      final isSamsung = await VideoPlayerDefensiveService.isSamsungDevice;
      
      if (isSamsung) {
        CrashlyticsService.logException(
          error,
          stackTrace,
          reason: 'Samsung Video Listener Error - ${widget.lesson.title}',
        );
      }
    } catch (e) {
      debugPrint('Error handling Samsung listener error: $e');
    }
  }
  
  /// Handle Samsung-specific initialization error logging asynchronously
  Future<void> _handleSamsungInitError(String error) async {
    try {
      final isSamsung = await VideoPlayerDefensiveService.isSamsungDevice;
      
      if (isSamsung) {
        CrashlyticsService.setCustomKey('samsung_video_error', true);
        CrashlyticsService.setCustomKey('video_init_context', 'FullScreenVideoPlayer-${widget.lesson.title}');
        CrashlyticsService.setCustomKey('lesson_id', widget.lesson.id);
        
        CrashlyticsService.logException(
          Exception('Samsung Video Init Error: $error'),
          StackTrace.current,
          reason: 'Samsung Video Init Error - ${widget.lesson.title}',
        );
      }
    } catch (e) {
      debugPrint('Error handling Samsung init error: $e');
    }
  }

  void _loadSubtitles(String videoUrl, bool isMuxStream) {
    // Load subtitles
    // First try to load local translated subtitles if available
    final hasLocalSubtitles = _loadLocalTranslatedSubtitles();
    
    // Only fetch Mux subtitles if no local subtitles are available
    if (isMuxStream && !hasLocalSubtitles) {
      // For Mux streams, fetch subtitles from Mux only as fallback
      _fetchMuxSubtitles(videoUrl);
      debugPrint('No local subtitles found, attempting to fetch Mux subtitles for Mux stream using URL: $videoUrl');
    } else if (hasLocalSubtitles) {
      debugPrint('Local translated subtitles loaded successfully, skipping Mux subtitle fetch');
    }
  }
  
  bool _loadLocalTranslatedSubtitles() {
    try {
      // Get current app language
      final localizations = AppLocalizations.of(context);
      final currentLanguageCode = localizations?.locale.languageCode ?? 'en';
      debugPrint('Current app language: $currentLanguageCode');
      
      // Get subtitle path for current language (with fallback to English)
      final subtitlePath = widget.lesson.getSubtitlePath(currentLanguageCode);
      
      if (subtitlePath != null && subtitlePath.isNotEmpty) {
        debugPrint('Loading translated subtitles from: $subtitlePath');
        _loadLocalSubtitles(subtitlePath);
        return true; // Successfully loaded local subtitles
      } else {
        debugPrint('No translated subtitles available for language: $currentLanguageCode');
        return false;
      }
    } catch (e) {
      debugPrint('Error determining subtitle path: $e');
      
      // Fallback to deprecated subtitle path if available
      if (widget.lesson.subtitleAssetPath != null && widget.lesson.subtitleAssetPath!.isNotEmpty) {
        debugPrint('Falling back to deprecated subtitle path: ${widget.lesson.subtitleAssetPath}');
        _loadLocalSubtitles(widget.lesson.subtitleAssetPath!);
        return true; // Successfully loaded fallback subtitles
      }
      
      return false; // No subtitles loaded
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showIcons = false;
          _showControls = false;
        });
      }
    });
  }

  void _showControlsOnTap() {
    setState(() {
      _showControls = true;
      _showIcons = true;
    });
    _startHideControlsTimer();
  }

  Future<void> _loadLocalSubtitles(String assetPath) async {
    try {
      debugPrint('Loading local subtitles from: $assetPath');
      final srtContent = await rootBundle.loadString(assetPath);
      _parseSRT(srtContent);
    } catch (e) {
      debugPrint('Error loading local subtitles: $e');
    }
  }

  void _parseSRT(String srtContent) {
    final lines = srtContent.replaceAll('\r\n', '\n').split('\n');
    final entries = <_SubtitleEntry>[];
    int i = 0;

    while (i < lines.length) {
      final String currentIndexLine = lines[i].trim();
      // Try to parse as an integer for the subtitle index
      if (int.tryParse(currentIndexLine) != null) {
        i++; // Move to the next line, expecting a timestamp
        if (i < lines.length) {
          final String timestampLine = lines[i].trim();
          if (timestampLine.contains('-->')) {
            final times = timestampLine.split('-->');
            if (times.length == 2) {
              final start = _parseSrtTime(times[0].trim());
              final end = _parseSrtTime(times[1].trim());
              
              i++; // Move to the next line, expecting the first line of subtitle text
              final textLines = <String>[];
              // Read text lines until an empty line is encountered
              while (i < lines.length && lines[i].trim().isNotEmpty) {
                textLines.add(lines[i].trim());
                i++;
              }
              
              if (textLines.isNotEmpty) {
                entries.add(_SubtitleEntry(
                  start: start,
                  end: end,
                  text: textLines.join('\n'),
                ));
              }
              // 'i' is now at the empty line after the text block or at the end of lines
            } else {
              i++; // Malformed timestamp line, advance to the next line
            }
          } else {
            i++; // Expected a timestamp line but didn't find one, advance
          }
        }
      } else {
        i++; // Current line is not a subtitle index, advance
      }
      // If 'i' hasn't advanced (e.g. stuck on a blank line not after text), ensure it does.
      // This also helps skip multiple blank lines between entries if any.
      // However, the text reading loop already advances 'i' to the blank line after text.
      // And if a line is skipped (not an index, or malformed timestamp), 'i' is also incremented.
      // So, an explicit check for blank lines to increment 'i' might be redundant if lines[i] can be empty from trim()
      // Let's ensure 'i' advances if it's on a blank line and hasn't been advanced by other logic, primarily for lines between entries.
      if (i < lines.length && lines[i].trim().isEmpty) {
          i++; // Skip blank lines between entries
      }
    }
    
    setState(() {
      _subtitles = entries;
    });
    
    // More detailed debug print
    if (_subtitles.isNotEmpty) {
      debugPrint('Parsed ${_subtitles.length} SRT subtitle entries. First entry: "${_subtitles.first.text.replaceAll("\n", " | ")}" @ ${_subtitles.first.start}');
    } else {
      debugPrint('Parsed 0 SRT subtitle entries.');
    }
  }

  Duration _parseSrtTime(String time) {
    // Parse SRT timestamp (e.g., "00:00:03,000")
    final parts = time.split(':');
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final secondsParts = parts[2].split(',');
    final seconds = int.tryParse(secondsParts[0]) ?? 0;
    final milliseconds = int.tryParse(secondsParts.length > 1 ? secondsParts[1] : '0') ?? 0;
    
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  Future<void> _fetchMuxSubtitles(String manifestUrl) async {
    try {
      // First, fetch the HLS manifest to find subtitle tracks
      // The manifestUrl passed here should already include ?default_subtitles_lang=en if it's a Mux stream
      debugPrint('Fetching HLS manifest from: $manifestUrl');
      
      final manifestResponse = await http.get(Uri.parse(manifestUrl));
      debugPrint('HLS Manifest Response Status: ${manifestResponse.statusCode}');
      
      if (manifestResponse.statusCode == 200) {
        final manifestContent = manifestResponse.body;
        debugPrint('Successfully fetched HLS manifest. Content snippet: ${manifestContent.substring(0, manifestContent.length > 200 ? 200 : manifestContent.length)}...');
        
        // Parse the manifest to find subtitle tracks
        // Look for lines that contain subtitles/captions information
        final lines = manifestContent.split('\n');
        String? subtitleMediaPlaylistUrl; // URL to the m3u8 playlist for subtitles
        
        for (int i = 0; i < lines.length; i++) {
          // Look for EXT-X-MEDIA tags with TYPE=SUBTITLES
          if (lines[i].contains('EXT-X-MEDIA') && lines[i].contains('TYPE=SUBTITLES')) {
            debugPrint('Found EXT-X-MEDIA subtitle line: ${lines[i]}');
            
            // Extract the URI from the line
            final uriMatch = RegExp(r'URI="([^"]+)"').firstMatch(lines[i]);
            if (uriMatch != null) {
              subtitleMediaPlaylistUrl = uriMatch.group(1);
              
              // If it's a relative URL, make it absolute
              if (subtitleMediaPlaylistUrl != null && !subtitleMediaPlaylistUrl.startsWith('http')) {
                final baseUrl = manifestUrl.substring(0, manifestUrl.lastIndexOf('/'));
                subtitleMediaPlaylistUrl = '$baseUrl/$subtitleMediaPlaylistUrl';
              }
              
              debugPrint('Found subtitle media playlist URL: $subtitleMediaPlaylistUrl');
              break; // Assuming one primary subtitle track for now
            }
          }
        }
        
        if (subtitleMediaPlaylistUrl != null) {
          // Now fetch the actual subtitle media playlist file
          debugPrint('Fetching subtitle media playlist from: $subtitleMediaPlaylistUrl');
          final subtitleManifestResponse = await http.get(Uri.parse(subtitleMediaPlaylistUrl));
          debugPrint('Subtitle Media Playlist Response Status: ${subtitleManifestResponse.statusCode}');
          
          if (subtitleManifestResponse.statusCode == 200) {
            final subtitleManifestContent = subtitleManifestResponse.body;
            debugPrint('Successfully fetched subtitle media playlist. Content snippet: ${subtitleManifestContent.substring(0, subtitleManifestContent.length > 200 ? 200 : subtitleManifestContent.length)}...');

            // Check if this is an M3U8 playlist or direct VTT (Mux usually uses M3U8 for subs)
            // Parse the URL and check the path component for the file extension
            final subtitlePlaylistPath = Uri.parse(subtitleMediaPlaylistUrl).path;
            if (subtitlePlaylistPath.endsWith('.m3u8')) {
              debugPrint('Subtitle URL path ($subtitlePlaylistPath) is an M3U8 playlist. Parsing it to find VTT files.');
              final subtitleLines = subtitleManifestContent.split('\n');
              final vttPaths = <String>[];
              for (final line in subtitleLines) {
                if (line.isNotEmpty && !line.startsWith('#')) {
                  vttPaths.add(line.trim());
                }
              }

              if (vttPaths.isNotEmpty) {
                final vttContents = <String>[];
                for (final vttPath in vttPaths) {
                  Uri vttUri;
                  if (vttPath.startsWith('http')) {
                    vttUri = Uri.parse(vttPath);
                  } else {
                    final baseSubtitleManifestUrl = Uri.parse(subtitleMediaPlaylistUrl);
                    vttUri = baseSubtitleManifestUrl.resolve(vttPath);
                  }
                  debugPrint('Fetching VTT segment from: $vttUri');
                  final vttFileResponse = await http.get(vttUri);
                  debugPrint('VTT Segment Response Status: ${vttFileResponse.statusCode}');
                  if (vttFileResponse.statusCode == 200) {
                    vttContents.add(vttFileResponse.body);
                  } else {
                    debugPrint('Failed to fetch VTT segment: ${vttFileResponse.statusCode}. Body: ${vttFileResponse.body}');
                  }
                }
                if (vttContents.isNotEmpty) {
                  final combinedVtt = vttContents.join('\n');
                  debugPrint('Successfully fetched and combined ${vttContents.length} VTT segments.');
                  _parseVTT(combinedVtt);
                } else {
                  debugPrint('No VTT segments fetched successfully. Trying fallback.');
                  _tryFallbackVttUrls(manifestUrl);
                }
              } else {
                debugPrint('No VTT file paths found in subtitle media playlist. Trying fallback.');
                _tryFallbackVttUrls(manifestUrl);
              }
            } else if (subtitlePlaylistPath.endsWith('.vtt')) {
              // It was a direct VTT link (less common for Mux HLS master manifest)
              debugPrint('Subtitle URL path ($subtitlePlaylistPath) seems to be a direct VTT file.');
              _parseVTT(subtitleManifestContent);
            } else {
              debugPrint('Subtitle URL path ($subtitlePlaylistPath) is neither .m3u8 nor .vtt. Content: $subtitleManifestContent');
              _tryFallbackVttUrls(manifestUrl);
            }
          } else {
            debugPrint('Failed to fetch subtitle media playlist: ${subtitleManifestResponse.statusCode}. Body: ${subtitleManifestResponse.body}');
            _tryFallbackVttUrls(manifestUrl); // Pass original main manifest URL
          }
        } else {
          debugPrint('No subtitle media playlist (EXT-X-MEDIA with TYPE=SUBTITLES and URI) found in HLS manifest. Trying fallback.');
          _tryFallbackVttUrls(manifestUrl); // Pass original main manifest URL
        }
      } else {
        debugPrint('Failed to fetch HLS manifest: ${manifestResponse.statusCode}. Body: ${manifestResponse.body}');
        // Optionally, you could still try fallbacks if the main manifest fails, though less likely to succeed.
         _tryFallbackVttUrls(manifestUrl); // Attempt fallbacks even if main manifest fails.
      }
    } catch (e, s) {
      debugPrint('Error fetching or parsing Mux subtitles: $e');
      debugPrint('Stack trace: $s');
      // Attempt fallback if any error occurs during the primary fetching process
      _tryFallbackVttUrls(manifestUrl); // Pass original main manifest URL
    }
  }

  // Helper method for fallback VTT URL attempts
  Future<void> _tryFallbackVttUrls(String mainManifestUrl) async {
    debugPrint('Executing fallback VTT URL attempts based on main manifest: $mainManifestUrl');
    
    // Ensure mainManifestUrl is a valid URL before trying to parse it.
    Uri? parsedMainManifestUri = Uri.tryParse(mainManifestUrl);
    if (parsedMainManifestUri == null || parsedMainManifestUri.pathSegments.isEmpty) {
      debugPrint('Invalid mainManifestUrl for fallback: $mainManifestUrl');
      return;
    }

    final pathSegments = parsedMainManifestUri.pathSegments;
    // Expecting path like: /<PLAYBACK_ID>.m3u8 or /<PLAYBACK_ID>/rendition.m3u8 etc.
    // We need to extract the PLAYBACK_ID.
    // Let's assume PLAYBACK_ID is the first segment if it's just stream.mux.com/PLAYBACK_ID.m3u8
    // or the segment before the last if it's a more complex path.
    // For a typical Mux URL like "https://stream.mux.com/PLAYBACK_ID.m3u8", pathSegments would be ["PLAYBACK_ID.m3u8"]
    // For "https://stream.mux.com/PLAYBACK_ID/renditions/rendition.m3u8", it'd be ["PLAYBACK_ID", "renditions", "rendition.m3u8"]
    String playbackId;
    if (pathSegments.isNotEmpty) {
        // Take the first segment and remove .m3u8 if present.
        // This is a common case for direct Mux URLs like https://stream.mux.com/Abc123xyz.m3u8
        playbackId = pathSegments.first.replaceAll('.m3u8', '');
         // If pathSegments.first was something like "Abc123xyz/renditions/1080p.m3u8", this might be wrong.
         // A more robust way for Mux URLs:
         // Example: https://stream.mux.com/J5gOhGoWriYLFjSMIfWuzJmog6wIKYAIeptbtiH7FY00.m3u8
         // pathSegments will be ["J5gOhGoWriYLFjSMIfWuzJmog6wIKYAIeptbtiH7FY00.m3u8"]
         // Example: https://stream.mux.com/J5gOhGoWriYLFjSMIfWuzJmog6wIKYAIeptbtiH7FY00/subtitles_en.vtt (hypothetical)
         // pathSegments: ["J5gOhGoWriYLFjSMIfWuzJmog6wIKYAIeptbtiH7FY00", "subtitles_en.vtt"]
         // We need the segment that is the playback ID.
         // It's usually the first segment after "stream.mux.com/"
         // Let's re-evaluate based on typical Mux structure.
         // The mainManifestUrl might already have query params like ?default_subtitles_lang=en
         // We only care about the path part for playback ID.
         
         List<String> actualPathSegments = Uri.parse(mainManifestUrl).pathSegments;
         if (actualPathSegments.isNotEmpty) {
            playbackId = actualPathSegments.first.replaceAll('.m3u8', '');
             debugPrint('Extracted Playback ID for fallback: $playbackId');
         } else {
             debugPrint('Could not extract Playback ID from $mainManifestUrl for fallback.');
             return;
         }
    } else {
        debugPrint('Cannot determine playbackId from mainManifestUrl for fallback: $mainManifestUrl');
        return;
    }


    // Mux direct VTT URLs are typically: https://stream.mux.com/{PLAYBACK_ID}/text/{TRACK_ID}.vtt
    // Common track IDs might be 'en', 'English', 'en-US', 'text-en', 'vtt-en', 'default', 'subtitles'; 

    final possibleTrackIds = ['en', 'English', 'en-US', 'text-en', 'vtt-en', 'default', 'subtitles']; 

    for (final trackId in possibleTrackIds) {
      final vttUrl = 'https://stream.mux.com/$playbackId/text/$trackId.vtt';
      debugPrint('Trying VTT URL (fallback): $vttUrl');

      try {
        final response = await http.get(Uri.parse(vttUrl));
        debugPrint('Fallback attempt for $vttUrl - Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final vttContent = utf8.decode(
            response.bodyBytes,
            allowMalformed: true,
          );
          debugPrint('Successfully fetched subtitles from fallback: $vttUrl. Content snippet: ${vttContent.substring(0, vttContent.length > 100 ? 100 : vttContent.length)}...');
          _parseVTT(vttContent);
          return; // Exit after successful fetch
        } else {
          // Log small portion of body for non-200 for debugging, if any.
           if (response.bodyBytes.isNotEmpty) {
            final safeBody = utf8.decode(
              response.bodyBytes,
              allowMalformed: true,
            );
            debugPrint('Fallback $vttUrl failed with status ${response.statusCode}. Body snippet: ${safeBody.substring(0, safeBody.length > 100 ? 100 : safeBody.length)}...');
          } else {
            debugPrint('Fallback $vttUrl failed with status ${response.statusCode}. Empty body.');
          }
        }
      } catch (e, s) {
        debugPrint('Error during fallback attempt for $vttUrl: $e');
        debugPrint('Stack trace for fallback error: $s');
        // Continue to the next fallback URL
      }
    }
    debugPrint('All fallback VTT URLs failed for playback ID: $playbackId.');
  }

  void _parseVTT(String vttContent) {
    final lines = vttContent.split('\n');
    final entries = <_SubtitleEntry>[];
    
    for (int i = 0; i < lines.length; i++) {
      // Look for timestamp lines (e.g., "00:00:00.000 --> 00:00:03.000")
      if (lines[i].contains('-->')) {
        final times = lines[i].split('-->');
        if (times.length == 2) {
          final start = _parseTime(times[0].trim());
          final end = _parseTime(times[1].trim());
          
          // Get the subtitle text (next non-empty lines until we hit another timestamp or empty line)
          final textLines = <String>[];
          int j = i + 1;
          while (j < lines.length && lines[j].isNotEmpty && !lines[j].contains('-->')) {
            textLines.add(lines[j]);
            j++;
          }
          
          if (textLines.isNotEmpty) {
            final rawText = textLines.join('\n');
            final safeText = TextSanitizer.sanitizeForDisplay(rawText);
            entries.add(_SubtitleEntry(
              start: start,
              end: end,
              text: safeText,
            ));
          }
        }
      }
    }
    
    setState(() {
      _subtitles = entries;
    });
    
    debugPrint('Parsed ${_subtitles.length} subtitle entries');
  }

  Duration _parseTime(String time) {
    // Parse VTT timestamp (e.g., "00:00:03.000" or "00:03.000")
    final parts = time.split(':');
    if (parts.length == 3) {
      // HH:MM:SS.mmm
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final secondsParts = parts[2].split('.');
      final seconds = int.tryParse(secondsParts[0]) ?? 0;
      final milliseconds = int.tryParse(secondsParts.length > 1 ? secondsParts[1] : '0') ?? 0;
      
      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    } else if (parts.length == 2) {
      // MM:SS.mmm
      final minutes = int.tryParse(parts[0]) ?? 0;
      final secondsParts = parts[1].split('.');
      final seconds = int.tryParse(secondsParts[0]) ?? 0;
      final milliseconds = int.tryParse(secondsParts.length > 1 ? secondsParts[1] : '0') ?? 0;
      
      return Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    }
    
    return Duration.zero;
  }

  void _updateManualSubtitles() {
    if (_subtitles.isEmpty) return;
    
    final currentPosition = _controller.value.position;
    String newCaption = '';
    
    for (final subtitle in _subtitles) {
      if (currentPosition >= subtitle.start && currentPosition <= subtitle.end) {
        newCaption = subtitle.text;
        break;
      }
    }
    
    if (newCaption != _currentCaption) {
      setState(() {
        _currentCaption = newCaption;
      });
    }
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.movie,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
    ));
    // Activate the audio session before playing video.
    await session.setActive(true);
  }

  bool _wasPlayingBeforeListener = false;

  @override
  void dispose() {
    // Android-specific: Clean up defensive timers
    _initializationTimeout?.cancel();
    _hideControlsTimer?.cancel();
    
    // Safely dispose controller with error handling
    try {
      if (_controller.value.isInitialized) {
        _controller.dispose();
      }
    } catch (e) {
      debugPrint('Error disposing video controller: $e');
      // Continue with disposal even if controller disposal fails
    }
    
    // Restore system UI to a more standard appearance
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); 
    // Restore a default system UI overlay style, typically light icons for dark themes or vice-versa
    // Or, if your app has a very consistent style, match that. Let's use light icons for now.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Or your app's default status bar color
      statusBarIconBrightness: Brightness.light, // Change if your app usually has light backgrounds
      statusBarBrightness: Brightness.dark, // For iOS
      systemNavigationBarColor: Colors.transparent, // Or your app's default
      systemNavigationBarIconBrightness: Brightness.light, // Or your app's default
    ));
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }

  void _seekRelative(Duration offset) {
    final newPosition = _controller.value.position + offset;
    _controller.seekTo(
      newPosition < Duration.zero ? Duration.zero : newPosition,
    );
  }

  Future<bool> _onWillPop() async {
    // If widget is unmounted, allow pop
    if (!mounted) return true;

    // If we're initializing or failed to initialize, allow pop without
    // touching the late controller to avoid LateInitializationError.
    if (_isInitializing || _hasInitializationError) return true;

    // Safely access the late controller; if not yet set, allow pop.
    late final VideoPlayerController controller;
    try {
      controller = _controller;
    } catch (_) {
      return true;
    }

    if (!controller.value.isInitialized) return true;

    final bool isVideoFinished =
        controller.value.position >= controller.value.duration;
    final lessonStateFromCubit = context.read<LearnVideoCubit>().state.maybeWhen(
          loaded: (lessons, _, __) => lessons.firstWhere((l) => l.id == widget.lesson.id, orElse: () => widget.lesson),
          orElse: () => widget.lesson,
        );
    final bool isLessonMarkedCompleted = lessonStateFromCubit.isCompleted;

    if (!isVideoFinished && !isLessonMarkedCompleted) {
      final localizations = AppLocalizations.of(context);
      await showLearnInfoBottomSheet(
        context,
        icon: Image.asset('assets/images/learn/finish_lessons_popup.png', height: 48, width: 48),
        title: localizations?.translate('videoPlayer_finishLessonTitle') ?? 'Finish your lesson',
        message: localizations?.translate('videoPlayer_finishLessonMessage') ?? 'You haven\'t finished this lesson yet. Are you sure you want to close it?',
        primaryButtonText: localizations?.translate('videoPlayer_continueListening') ?? 'Continue listening',
        onPrimaryButtonPressed: () {
          Navigator.of(context).pop();
        },
        secondaryButtonText: localizations?.translate('videoPlayer_closeLesson') ?? 'Close lesson',
        onSecondaryButtonPressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
        primaryButtonColor: const Color(0xFFF0F0F0),
        primaryButtonTextColor: Colors.black87,
        secondaryButtonTextColor: Colors.grey.shade700, 
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Force status bar icons to white - call this directly in build method
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Also add a post-frame callback to ensure it's applied after rendering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
    });

    // Debug print in build method
    //if (_controller.value.isInitialized) {
     //debugPrint("Build method: Caption text: '${_controller.value.caption.text}', showCaptions: $_showCaptions");
    //}

    // Apply AnnotatedRegion to enforce the style throughout the widget's lifecycle
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // For iOS
        systemNavigationBarColor: Colors.black, // To keep nav bar consistent with player
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          // Add a transparent AppBar with zero height to force status bar styling
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(0), // Zero height app bar
            child: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light, // White icons for Android
                statusBarBrightness: Brightness.dark, // White icons for iOS
                systemNavigationBarColor: Colors.black,
                systemNavigationBarIconBrightness: Brightness.light,
              ),
            ),
          ),
          body: SafeArea(
            top: false, // Allow video to extend into the status bar area for true fullscreen
            bottom: false, // Allow content to extend to bottom for fullscreen video feel
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showControlsOnTap,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (_hasInitializationError)
                    _buildErrorWidget()
                  else if (_isInitializing)
                    const Center(child: CircularProgressIndicator(color: Colors.white))
                  else if (_controller.value.isInitialized && _isReadyToRender)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    )
                  else
                    const Center(child: CircularProgressIndicator(color: Colors.white)),
                  // Display manual subtitles or video_player subtitles
                  if (!_isInitializing && !_hasInitializationError && _controller.value.isInitialized && _showCaptions)
                    // Prioritize _currentCaption (from manual fetch/load)
                    if (_currentCaption.isNotEmpty)
                      Positioned(
                        bottom: 120,
                        left: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              _currentCaption, // Use manually loaded/fetched caption
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.0,
                              ),
                            ),
                          ),
                        ),
                      )
                    // Fallback to video_player's native caption if _currentCaption is empty
                    // and native caption has content.
                    else if (!_isInitializing && !_hasInitializationError && _controller.value.caption.text.isNotEmpty)
                      Positioned(
                        bottom: 120,
                        left: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              !_isInitializing && !_hasInitializationError ? _controller.value.caption.text : '', // Use native caption as fallback
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                  if (_showIcons) _buildTopIcons(),
                  Visibility(
                    visible: _showControls,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: _buildBottomControls(),
                  ),
                  if (_showIcons) _buildVolumeIcon(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopIcons() {
    return Stack(
      children: [
        Positioned(
          top: MediaQuery.of(context).padding.top + 38,
          left: 8,
          child: IconButton(
            icon: Image.asset('assets/images/learn/x_icon.png', color: Colors.white, width: 22, height: 22),
            onPressed: () async {
              final canPop = await _onWillPop();
              if (canPop && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 38,
          right: 12,
          child: Row(
            children: [
              IconButton(
                icon: _showCaptions 
                    ? Image.asset('assets/images/learn/subtitles_on_icon.png', color: Colors.white, width: 30, height: 30)
                    : Image.asset('assets/images/learn/subtitles_off_icon.png', color: Colors.white, width: 30, height: 30),
                onPressed: () {
                  setState(() {
                    _showCaptions = !_showCaptions;
                    debugPrint("Subtitles icon tapped. _showCaptions is now: $_showCaptions");
                    debugPrint("Manual caption: '$_currentCaption'");
                    debugPrint("Number of subtitle entries: \\${_subtitles.length}");
                  });
                  MixpanelService.trackEvent(
                    _showCaptions
                      ? 'Learn ${widget.lesson.title} - Subtitles On'
                      : 'Learn ${widget.lesson.title} - Subtitles Off',
                    properties: {'lesson_id': widget.lesson.id, 'lesson_title': widget.lesson.title},
                  );
                },
              ),
              const SizedBox(width: 8), // Spacing between icons
              IconButton(
                icon: Image.asset('assets/images/learn/question_mark.png', color: Colors.white, width: 30, height: 30),
                onPressed: () async {
                  MixpanelService.trackButtonTap(
                    'Learn Video Help',
                    screenName: 'FullScreenVideoPlayerScreen',
                    additionalProps: {'lesson_id': widget.lesson.id},
                  );
                  final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
                  try {
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.inAppWebView);
                    } else {
                      debugPrint('Could not launch help URL');
                      if (mounted) {
                        final localizations = AppLocalizations.of(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(localizations?.translate('videoPlayer_helpError') ?? 'Unable to open help')),
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint('Error launching help URL: $e');
                    if (mounted) {
                      final localizations = AppLocalizations.of(context);
                      final errorMessage = localizations?.translate('videoPlayer_helpErrorWithDetails')?.replaceAll('{error}', e.toString()) ?? 'Error opening help: $e';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorMessage)),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Stack(
      children: [
        Positioned(
          bottom: -36,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 50.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                                  IconButton(
                    icon: Icon(
                      (!_isInitializing && !_hasInitializationError && _controller.value.isPlaying) ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 35,
                    ),
                    onPressed: () {
                      if (!_isInitializing && !_hasInitializationError) {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                          _showControls = true;
                          _startHideControlsTimer();
                        });
                      }
                    },
                  ),
                IconButton(
                  icon: Image.asset('assets/images/learn/back10.png', width: 30, height: 30, color: Colors.white),
                  onPressed: () => _seekRelative(const Duration(seconds: -10)),
                ),
                const SizedBox(width: 8),
                                  Expanded(
                    child: (!_isInitializing && !_hasInitializationError) 
                      ? ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller,
                      builder: (context, value, child) {
                        final duration = value.duration.inMilliseconds;
                        final position = value.position.inMilliseconds;
                        final progress = (duration > 0) ? (position / duration).clamp(0.0, 1.0) : 0.0;
                      return Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                  : Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ),
                const SizedBox(width: 8),
                (!_isInitializing && !_hasInitializationError) 
                  ? ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller,
                      builder: (context, value, child) {
                        final remaining = value.duration - value.position;
                        // Ensure displayDuration is not negative
                        final displayDuration = (remaining < Duration.zero || remaining.isNegative) 
                                                ? Duration.zero 
                                                : remaining;
                        
                        // If video is finished, show -0:00 or equivalent
                        if (value.position >= value.duration && value.duration > Duration.zero) {
                            return Text(
                                "-${_formatDuration(Duration.zero)}",
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                            );
                        }
                        return Text(
                          "-${_formatDuration(displayDuration)}",
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        );
                      },
                    )
                  : const Text(
                      "--:--",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)?.translate('videoPlayer_initializationFailed') ?? 'Video initialization failed',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.translate('videoPlayer_pleaseTryAgain') ?? 'Please try again',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasInitializationError = false;
                });
                _initializeVideoControllerUniversal();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(AppLocalizations.of(context)?.translate('videoPlayer_retry') ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeIcon() {
    return Positioned(
      bottom: 80, // Positioned above the control bar
      right: 15,
      child: IconButton(
        icon: Image.asset(
          _isMuted
              ? 'assets/images/learn/soundoff.png'
              : 'assets/images/learn/soundon.png',
          width: 30,
          height: 30,
          color: Colors.white,
        ),
        onPressed: () {
          if (!_isInitializing && !_hasInitializationError) {
            setState(() {
              _isMuted = !_isMuted;
              _controller.setVolume(_isMuted ? 0.0 : 1.0);
            });
            MixpanelService.trackEvent(
              _isMuted
                ? 'Learn ${widget.lesson.title} - Muted'
                : 'Learn ${widget.lesson.title} - Unmuted',
              properties: {'lesson_id': widget.lesson.id, 'lesson_title': widget.lesson.title},
            );
          }
        },
      ),
    );
  }
}

class _SubtitleEntry {
  final Duration start;
  final Duration end;
  final String text;

  _SubtitleEntry({
    required this.start,
    required this.end,
    required this.text,
  });
} 
