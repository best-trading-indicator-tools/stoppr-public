import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Summary: Add Crashlytics context key so native video crashes are attributed to this screen.
import 'package:stoppr/core/analytics/crashlytics_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'home_screen.dart';
import 'main_scaffold.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/video_player_defensive_service.dart';

class MeditateScreen extends StatefulWidget {
  const MeditateScreen({super.key});

  @override
  State<MeditateScreen> createState() => _MeditateScreenState();
}

class _MeditateScreenState extends State<MeditateScreen> {
  late VideoPlayerController _controller;
  bool _isVideoInitialized = false;
  int _currentQuoteIndex = 0;
  Timer? _quoteTimer;
  VoidCallback? _videoPositionListener; // Store the listener callback
  static const _quoteChangeDuration = Duration(seconds: 5);
  
  // List of meditation quote KEYS
  final List<String> _quotes = [
    "meditateScreen_quote1",
    "meditateScreen_quote2",
    "meditateScreen_quote3",
    "meditateScreen_quote4",
    "meditateScreen_quote5",
  ];

  @override
  void initState() {
    super.initState();
    CrashlyticsService.setCustomKey('video_init_context', 'MeditateScreen');
    _initializeVideo();
    _startQuoteTimer();
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Meditate Screen');
    
    // Force status bar icons to white mode with stronger settings
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // iOS uses opposite naming
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    
    // Make app fullscreen and immersive
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }

  void _startQuoteTimer() {
    // Cancel any existing timer
    _quoteTimer?.cancel();
    
    // Create a new timer that advances quotes automatically
    _quoteTimer = Timer.periodic(_quoteChangeDuration, (timer) {
      _showNextQuote();
    });
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = await VideoPlayerDefensiveService.initializeWithDefensiveMeasures(
        videoPath: 'assets/videos/welcome_video_V2.mp4',
        isNetworkUrl: false,
        context: 'MeditateScreen',
      );
      
      _controller.setLooping(true);
      _controller.setVolume(0.0); // Mute the video as requested
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _controller.play();
          
          // Store the listener callback in a field so we can remove it later
          _videoPositionListener = () {
            if (_controller.value.isInitialized && 
                _controller.value.position >= const Duration(seconds: 3)) {
              _controller.seekTo(Duration.zero);
            }
          };
          
          // Add the listener using the stored callback
          _controller.addListener(_videoPositionListener!);
        });
      }
    } catch (e) {
      debugPrint('Error loading video: $e');
    }
  }

  @override
  void dispose() {
    // Remove the listener before disposing the controller
    if (_isVideoInitialized && _videoPositionListener != null) {
      _controller.removeListener(_videoPositionListener!);
    }
    if (_isVideoInitialized) {
      _controller.dispose();
    }
    _quoteTimer?.cancel();
    
    // Restore default status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    
    super.dispose();
  }

  void _showNextQuote() {
    if (mounted) {
      setState(() {
        _currentQuoteIndex = (_currentQuoteIndex + 1) % _quotes.length;
      });
    }
  }

  void _onTapScreen() {
    // Show next quote immediately
    _showNextQuote();
    
    // Reset the timer to give full duration for the new quote
    _startQuoteTimer();
  }

  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Meditate Screen');
    
    final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppWebView,
        );
      } else {
        debugPrint('Could not launch help & info URL');
      }
    } catch (e) {
      debugPrint('Error launching help & info URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        backgroundColor: const Color(0xFF09050C),
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            l10n.translate('meditateScreen_appBarTitle'),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            // Help & Info icon
            IconButton(
              icon: const Icon(
                Icons.help_outline,
                color: Colors.white,
                size: 28,
              ),
              onPressed: _openMedicalInfo,
              tooltip: l10n.translate('pledgeScreen_tooltip_help'),
            ),
          ],
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        body: Stack(
          children: [
            // Video background
            if (_isVideoInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: Stack(
                      children: [
                        VideoPlayer(_controller),
                        // Purple overlay with 20% opacity
                        Container(
                          color: const Color(0xFF240067).withOpacity(0.2),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                color: const Color(0xFF09050C),
              ),
              
            // Circular animation overlay
            Center(
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
              
            // Clickable area to advance to next quote
            GestureDetector(
              onTap: _onTapScreen,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        l10n.translate(_quotes[_currentQuoteIndex]),
                        key: ValueKey<int>(_currentQuoteIndex),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Bottom button to return to home screen
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 250,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        TopToBottomPageRoute(
                          child: const MainScaffold(initialIndex: 0),
                          settings: const RouteSettings(name: '/home'),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFed3272), // Brand pink
                            Color(0xFFfd5d32), // Brand orange
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        l10n.translate('meditateScreen_button_finishReflecting'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                          fontSize: 19,
                          color: Colors.white,
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