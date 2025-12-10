import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:audio_session/audio_session.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/services/app_update_service.dart';
import 'package:stoppr/core/services/video_player_defensive_service.dart';
import 'package:stoppr/core/analytics/crashlytics_service.dart';
import 'package:stoppr/core/installation/installation_tracker_service.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:stoppr/features/app/presentation/screens/pledge_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/what_happening_screen.dart';
import 'package:stoppr/features/app/presentation/screens/meditation_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/redownload_feedback_screen.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class WelcomeVideoScreen extends StatefulWidget {
  final Widget nextScreen;
  
  const WelcomeVideoScreen({
    super.key, 
    required this.nextScreen,
  });

  @override
  State<WelcomeVideoScreen> createState() => _WelcomeVideoScreenState();
}

class _WelcomeVideoScreenState extends State<WelcomeVideoScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late Timer _videoTimer;
  late AnimationController _textAnimationController;
  late String _selectedVideoFileName;
  
  // Add flag to prevent double navigation
  bool _hasNavigated = false;
  
  // Add video error handling
  bool _hasVideoError = false;
  bool _isVideoInitialized = false;
  
  // Supporting text fields
  final String _starsImage = 'assets/images/onboarding/stars_wings.png';
  bool _showSupportingText = false;
  double _supportingText1Progress = 0.0;
  double _supportingText2Progress = 0.0;
  Timer? _text1Timer;
  Timer? _text2Timer;
  
  // App update banner fields
  final AppUpdateService _updateService = AppUpdateService();
  bool _showUpdateBanner = false;
  AppUpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    CrashlyticsService.setCustomKey('video_init_context', 'WelcomeVideoScreen');
    
    // Force status bar icons to white mode with stronger settings
    _setSystemUIOverlayStyle();
    
    _initializeAudioSession();
    _initializeAnimations();
    _initializeVideo();
    _checkForAppUpdate();
  }
  
  void _setSystemUIOverlayStyle() {
    final overlayStyle = const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    );
    
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
    
    // Additional Android-specific handling
    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );
    }
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
  
  
  void _initializeAnimations() {
    _textAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Start text animation sequence after a delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showSupportingText = true;
        });
        _startTypingAnimation();
      }
    });
  }
  
  void _startTypingAnimation() {
    // Text 1 typing animation
    _text1Timer = Timer.periodic(const Duration(milliseconds: 65), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_supportingText1Progress < 1.0) {
        setState(() {
          _supportingText1Progress += 0.05;
          if (_supportingText1Progress > 1.0) {
            _supportingText1Progress = 1.0;
          }
        });
      } else {
        timer.cancel();
        
        // Start text 2 animation after a small delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          
          _text2Timer = Timer.periodic(const Duration(milliseconds: 65), (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }
            
            if (_supportingText2Progress < 1.0) {
              setState(() {
                // Use translated string length for progress calculation
                _supportingText2Progress += 0.04; 
                if (_supportingText2Progress > 1.0) {
                  _supportingText2Progress = 1.0;
                }
              });
            } else {
              timer.cancel();
            }
          });
        });
      }
    });
  }

  void _initializeVideo() {
    _initializeVideoUniversal();
  }

  Future<void> _initializeVideoUniversal() async {
    try {
      const String selectedVideoPath = 'assets/videos/daily_widget.mp4';
      _selectedVideoFileName = 'daily_widget.mp4';

      _controller = await VideoPlayerDefensiveService.initializeWithDefensiveMeasures(
        videoPath: selectedVideoPath,
        isNetworkUrl: false,
        context: 'WelcomeVideoScreen',
      );
      
      _controller.setLooping(false); // No looping as we'll navigate away
      _controller.setVolume(0.0); // Mute the video
      
      // Add error listener after initialization
      _controller.addListener(_videoListener);
      
      // Ensure the first frame is shown and start playing
      if (mounted && !_hasVideoError) {
        setState(() {
          _isVideoInitialized = true;
        });
        debugPrint('[WelcomeVideoScreen] Video initialized on ${Platform.operatingSystem}, starting playback - file: $_selectedVideoFileName');
        _controller.play();
        
        // Set a timer to navigate to next screen after 5 seconds
        _videoTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && !_hasNavigated) {
            debugPrint('[WelcomeVideoScreen] Video timer finished, navigating to next screen');
            _navigateToNextScreen();
          }
        });
      }
      
    } catch (e, stackTrace) {
      debugPrint('[WelcomeVideoScreen] Video initialization error on ${Platform.operatingSystem}: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Simple error logging
      debugPrint('[WelcomeVideoScreen] Video Error: ${e.toString()} - file: $_selectedVideoFileName');
      
      _handleVideoError();
    }
  }
  
  void _videoListener() {
    try {
      if (_controller.value.hasError) {
        final errorDescription = _controller.value.errorDescription ?? 'Unknown playback error';
        debugPrint('[WelcomeVideoScreen] Video playback error on ${Platform.operatingSystem}: $errorDescription');
        
        // Enhanced playback error logging
        debugPrint('[WelcomeVideoScreen] Video playback error: $errorDescription - file: $_selectedVideoFileName');
        
        // Handle Samsung-specific error logging asynchronously
        _handleSamsungPlaybackError('WelcomeVideoScreen', errorDescription);
        
        _handleVideoError();
      } else if (_controller.value.position >= _controller.value.duration && 
                 _controller.value.duration > Duration.zero &&
                 !_hasNavigated && !_hasVideoError) {
        debugPrint('[WelcomeVideoScreen] Video completed, navigating');
        _navigateToNextScreen();
      }
    } catch (e, stackTrace) {
      debugPrint('[WelcomeVideoScreen] Video listener error on ${Platform.operatingSystem}: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Handle Samsung-specific listener error logging asynchronously
      _handleSamsungListenerError('WelcomeVideoScreen', e, stackTrace);
    }
  }
  
  /// Handle Samsung-specific playback error logging asynchronously
  Future<void> _handleSamsungPlaybackError(String context, String errorDescription) async {
    try {
      final isSamsung = await VideoPlayerDefensiveService.isSamsungDevice;
      
      if (isSamsung) {
        CrashlyticsService.setCustomKey('samsung_playback_error', true);
        CrashlyticsService.setCustomKey('playback_error_context', context);
        
        CrashlyticsService.logException(
          Exception('Samsung Welcome Video Playback Error: $errorDescription'),
          StackTrace.current,
          reason: 'Samsung Welcome Video Playback Error',
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
          reason: 'Samsung Welcome Video Listener Error',
        );
      }
    } catch (e) {
      debugPrint('Error handling Samsung listener error: $e');
    }
  }
  
  void _handleVideoError() {
    if (mounted && !_hasVideoError) {
      setState(() {
        _hasVideoError = true;
      });
      
      debugPrint('[WelcomeVideoScreen] Video error encountered, continuing without fallback image');
      
      // Still navigate after 5 seconds even if video fails
      _videoTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && !_hasNavigated) {
          debugPrint('[WelcomeVideoScreen] Fallback timer finished, navigating to next screen');
          _navigateToNextScreen();
        }
      });
    }
  }

  void _navigateToNextScreen() async {
    // Prevent double navigation
    if (_hasNavigated) return;
    _hasNavigated = true;
    
    // DEFENSIVE: Pause video before navigation to prevent Metal texture access during disposal
    // Fixes rare iOS crash: EXC_BAD_ACCESS in render_pass_mtl.mm
    if (_isVideoInitialized && !_hasVideoError) {
      _controller.pause();
      debugPrint('[WelcomeVideo] Paused video before navigation to prevent texture access');
      
      // Log for crash monitoring
      CrashlyticsService.setCustomKey('video_paused_before_nav', true);
      CrashlyticsService.setCustomKey('video_position_at_nav', _controller.value.position.inSeconds);
      CrashlyticsService.setCustomKey('navigation_timestamp', DateTime.now().toIso8601String());
    }
    
    // Check if there's a pending navigation from a widget deep link
    final prefs = await SharedPreferences.getInstance();
    final hasPendingHomeNavigation = prefs.getBool('pending_home_navigation') ?? false;
    final pendingWidgetTarget = prefs.getString('pending_widget_deeplink');
    
    // Check if redownload feedback form should be shown
    final installationTracker = InstallationTrackerService();
    final shouldShowFeedback = await installationTracker.shouldShowFeedbackForm();
    
    // DEBUG: Always show feedback form in debug mode for testing
    final debugShowFeedback = kDebugMode && false; // Set to true to enable
    
    if (shouldShowFeedback || debugShowFeedback) {
      // Show redownload feedback form first
      debugPrint('🔄 Showing redownload feedback form');
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return RedownloadFeedbackScreen(
              onComplete: () {
                // After feedback, navigate to next screen
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => widget.nextScreen,
                  ),
                );
              },
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: Duration.zero,
        ),
      ).then((_) {
        if (mounted && _isVideoInitialized && !_hasVideoError) {
          _controller.dispose();
        }
      });
      return;
    }
    
    if (hasPendingHomeNavigation || pendingWidgetTarget != null) {
      // Clear the force flag so subsequent launches don't keep the video unnecessarily
      await prefs.remove('force_keep_welcome_video');
      await prefs.remove('pending_home_navigation');
      if (pendingWidgetTarget != null) {
        await prefs.remove('pending_widget_deeplink');
      }

      // Choose target based on pending widget deep link
      Widget target;
      switch (pendingWidgetTarget) {
        case 'pledge':
          target = const PledgeScreen();
          break;
        case 'panic':
          target = const WhatHappeningScreen();
          break;
        case 'meditation':
          target = const MeditationScreen();
          break;
        case 'home':
        default:
          target = const MainScaffold(initialIndex: 0);
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => target,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Keep video visible under the fade
            return Stack(
              children: [
                // Keep showing the video during transition
                if (animation.value < 0.99 && _isVideoInitialized && !_hasVideoError)
                  Container(
                    color: Colors.black,
                    child: VideoPlayer(_controller),
                  ),
                // Fade in the new screen
                FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              ],
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: Duration.zero,
        ),
      ).then((_) {
        // Dispose the video controller after navigation completes
        if (mounted && _isVideoInitialized && !_hasVideoError) {
          _controller.dispose();
        }
      });
    } else {
      // Normal navigation to the configured next screen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return widget.nextScreen;
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Keep video visible under the fade
            return Stack(
              children: [
                // Keep showing the video during transition
              if (animation.value < 0.99 && _isVideoInitialized && !_hasVideoError)
                Container(
                  color: Colors.black,
                  child: VideoPlayer(_controller),
                ),
              // Fade in the new screen
              FadeTransition(
                opacity: animation,
                child: child,
              ),
            ],
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: Duration.zero,
      ),
    ).then((_) {
      // Dispose the video controller after navigation completes
      if (mounted && _isVideoInitialized && !_hasVideoError) {
        _controller.dispose();
      }
            });
    }

  }
  
  // Check for app updates
  Future<void> _checkForAppUpdate() async {
    try {
      // FOR DEBUGGING: Always show banner in debug mode
      if (kDebugMode) {
        setState(() {
          _showUpdateBanner = true;
          _updateInfo = const AppUpdateInfo(
            hasUpdate: true,
            latestVersion: '2.1.0',
            currentVersion: '2.0.0',
            storeUrl: 'https://apps.apple.com/us/app/stoppr-stop-sugar-now/id6742406521?platform=iphone',
          );
        });
        return;
      }
      
      final updateInfo = await _updateService.checkForUpdate();
      if (mounted && updateInfo.hasUpdate) {
        setState(() {
          _showUpdateBanner = true;
          _updateInfo = updateInfo;
        });
      }
    } catch (e) {
      debugPrint('Error checking for app update: $e');
    }
  }
  
  // Handle reload button tap
  Future<void> _handleReload() async {
    if (_updateInfo?.storeUrl != null) {
      try {
        final url = Uri.parse(_updateInfo!.storeUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('Error opening store URL: $e');
      }
    }
  }
  
  // Handle later button tap
  Future<void> _handleLater() async {
    if (_updateInfo?.latestVersion != null) {
      await _updateService.dismissVersion(_updateInfo!.latestVersion!);
    }
    setState(() {
      _showUpdateBanner = false;
    });
  }

  @override
  void dispose() {
    // Remove listener before disposing
    try {
      if (_isVideoInitialized && !_hasVideoError) {
        _controller.removeListener(_videoListener);
        _controller.dispose();
      }
    } catch (e) {
      debugPrint('[WelcomeVideoScreen] Error disposing video controller: $e');
      // Continue with disposal even if controller disposal fails
    }
    
    _textAnimationController.dispose();
    _text1Timer?.cancel();
    _text2Timer?.cancel();
    if (_videoTimer.isActive) {
      _videoTimer.cancel();
    }
    super.dispose();
  }

  // Build the update banner widget
  Widget _buildUpdateBanner() {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.download_done,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.translate('appUpdate_banner_title'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('appUpdate_banner_message'),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _handleReload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300], // Light gray color
                  foregroundColor: Colors.black87, // Text color for light gray background
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  l10n.translate('appUpdate_banner_reload'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _handleLater,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  l10n.translate('appUpdate_banner_later'),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Refresh overlay style on each build to ensure it applies correctly
    if (Platform.isAndroid) {
      _setSystemUIOverlayStyle();
    }
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        // Remove any AppBar that might be overriding our settings
        extendBodyBehindAppBar: true,
        extendBody: true,
        backgroundColor: Colors.black,
        body: _isVideoInitialized 
            ? _buildVideoUI()
            : _buildLoadingUI(),
      ),
    );
  }
  
  Widget _buildVideoUI() {
    return Stack(
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
        _buildOverlayContent(),
      ],
    );
  }
  
  
  
  Widget _buildLoadingUI() {
    return Stack(
      children: [
        // Black background while loading
        Container(color: Colors.black),
        _buildOverlayContent(),
        // Loading indicator
        const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      ],
    );
  }
  
  Widget _buildOverlayContent() {
    return Stack(
      children: [
        // App update banner
        // if (_showUpdateBanner)
        //   Positioned(
        //     top: MediaQuery.of(context).padding.top + 8,
        //     left: 0,
        //     right: 0,
        //     child: _buildUpdateBanner(),
        //   ),
        // Text overlay in center
        Transform.translate(
          offset: const Offset(0, -60), // Move text 60 points upward
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // const Text(
                //   'STOPPR',
                //   style: TextStyle(
                //     color: Colors.white,
                //     fontSize: 40,
                //     fontFamily: 'ElzaRound',
                //     fontWeight: FontWeight.bold,
                //     letterSpacing: 1.5,
                //   ),
                // ),
                // const SizedBox(height: 12),
                const SizedBox(height: 20),
                // // Stars image appears only on iOS (temporarily disabled)
                // Image.asset(
                //   _starsImage,
                //   width: MediaQuery.of(context).size.width * 0.3,
                //   fit: BoxFit.contain,
                // ),
                ],
            ),
          ),
        ),

        // Bottom progressive text area on white background with refined typography
        if (_showSupportingText)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 10,
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    
                    Text(
                      TextSanitizer.safeSubstring(
                        AppLocalizations.of(context)!
                            .translate('welcomeVideo_text1'),
                        0,
                        (AppLocalizations.of(context)!
                                    .translate('welcomeVideo_text1')
                                    .length *
                                _supportingText1Progress)
                            .round()
                            .clamp(
                              0,
                              AppLocalizations.of(context)!
                                  .translate('welcomeVideo_text1')
                                  .length,
                            ),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      TextSanitizer.safeSubstring(
                        AppLocalizations.of(context)!
                            .translate('welcomeVideo_text2'),
                        0,
                        (AppLocalizations.of(context)!
                                    .translate('welcomeVideo_text2')
                                    .length *
                                _supportingText2Progress)
                            .round()
                            .clamp(
                              0,
                              AppLocalizations.of(context)!
                                  .translate('welcomeVideo_text2')
                                  .length,
                            ),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
} 