import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/streak/streak_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_screen.dart';
import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/navigation/page_transitions.dart';
import '../../../../../core/streak/sharing_service.dart';
import 'dart:developer' as developer;
import '../../../../../core/localization/app_localizations.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class ProgressCardScreen extends StatefulWidget {
  const ProgressCardScreen({super.key});

  @override
  State<ProgressCardScreen> createState() => _ProgressCardScreenState();
}

class _ProgressCardScreenState extends State<ProgressCardScreen> {
  final StreakService _streakService = StreakService();
  String? _firstName;
  String _currentDate = '';
  int _streakDays = 0;
  bool _isLoading = true;
  bool _showShareNotification = false;
  bool _showScreenshotInfoBanner = false;

  @override
  void initState() {
    super.initState();
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Progress Card Screen');
    
    // Force status bar icons to dark mode for light background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for light background
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    
    // Make app fullscreen and immersive
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
    
    // Load user data
    _loadUserData();
  }

  @override
  void dispose() {
    // Restore default status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      // Try to get name from SharedPreferences first
      final prefs = await SharedPreferences.getInstance();
      final savedFirstName = prefs.getString('user_first_name');
      
      String? firstName;
      if (savedFirstName != null && savedFirstName.isNotEmpty) {
        firstName = savedFirstName;
      } else {
        // Fallback to Firebase Auth if name not in SharedPreferences
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser?.displayName != null) {
          firstName = currentUser!.displayName!.split(' ')[0];
        }
      }
      
      // Get current date in MM/DD format
      final now = DateTime.now();
      final formattedDate = DateFormat('MM/dd').format(now);
      
      // Get streak data
      final streak = _streakService.currentStreak;
      
      // If the streak has a start time, calculate free since date
      String streakStartDate = formattedDate;
      if (streak.startTime != null) {
        streakStartDate = DateFormat('MM/dd').format(streak.startTime!);
      }
      
      if (mounted) {
        setState(() {
          _firstName = firstName;
          _currentDate = streakStartDate;
          _streakDays = streak.days;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Share streak progress with share_plus
  Future<void> _shareProgress() async {
    // Show info banner immediately
    setState(() {
      _showShareNotification = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showShareNotification = false;
        });
      }
    });
    debugPrint('PRINT: [_shareProgress] Starting in progress_card.dart');
    try {
      MixpanelService.trackEvent('Share Progress Card', properties: {
        'streak_days': _streakDays,
        'free_since': _currentDate,
      });
      String message;
      debugPrint('PRINT: [_shareProgress] About to call SharingService.instance.generateShareLink()');
      final link = await SharingService.instance.generateShareLink() ?? 'https://stoppr.app';
      debugPrint('PRINT: [_shareProgress] Generated link: $link');
      String? subject;
      final sanitizedFirst = _firstName != null && _firstName!.isNotEmpty
          ? TextSanitizer.sanitizeForDisplay(_firstName!)
          : null;
      final namePrefix = sanitizedFirst != null && sanitizedFirst.isNotEmpty 
          ? '$sanitizedFirst is' 
          : 'I\'m';
      const String iosAppLink = 'https://apps.apple.com/us/app/stop-sugar-now-stoppr/id6742406521?platform=iphone';
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        message = '$namePrefix on a \'$_streakDays\' day streak with Stoppr! 🎉\n\nAdd my live streak widget to your home screen and keep me accountable:\n$link\n\nDownload Stoppr: $iosAppLink';
        subject = 'My Stoppr Progress';
      } else {
        message = '$namePrefix on a \'$_streakDays\' day streak with Stoppr! 🎉\n\nAdd my live streak widget to your home screen and keep me accountable:\n$link\n\nDownload Stoppr on iOS: $iosAppLink\n(Coming soon to Android!)';
        subject = 'My Stoppr Progress';
      }
      debugPrint('PRINT: [_shareProgress] Message to share: "$message"');
      debugPrint('PRINT: [_shareProgress] Subject to share: "$subject"');
      debugPrint('PRINT: [_shareProgress] Attempting to call Share.share...');
      await Share.share(
        message,
        subject: subject,
      );
      debugPrint('PRINT: [_shareProgress] Share.share call completed.');
    } catch (e, s) {
      debugPrint('PRINT: Error in _shareProgress: $e\nStackTrace: $s');
    }
  }
  
  void _showScreenshotInstructions() {
    setState(() {
      _showScreenshotInfoBanner = true;
    });
    // Hide the banner after a few seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showScreenshotInfoBanner = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for light background
        statusBarBrightness: Brightness.light, // iOS
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF8FA), // Brand soft pink-tinted white background
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)), // Dark icon
            onPressed: () => Navigator.pushReplacement(
              context,
              TopToBottomPageRoute(
                child: const UserProfileScreen(),
                settings: const RouteSettings(name: '/profile'),
              ),
            ),
          ),
          title: Text(
            AppLocalizations.of(context)!.translate('progressCard_title'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for light background
              fontSize: 20,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  if (_showShareNotification)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 46.0,
                      left: 40.0,
                      right: 40.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFF1A051D),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                AppLocalizations.of(context)!.translate('progressCard_shareStarting'),
                                style: const TextStyle(
                                  color: Color(0xFF1A051D),
                                  fontSize: 14,
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_showScreenshotInfoBanner)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + kToolbarHeight + 16.0, // Position below AppBar
                      left: 40.0, // Narrower width
                      right: 40.0, // Narrower width
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // Ensure Row doesn't stretch unnecessarily
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              color: Color(0xFF1A051D), // Dark icon color
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Flexible( // Added Flexible to prevent text overflow issues
                              child: Text(
                                AppLocalizations.of(context)!.translate('progressCard_screenshotInstructions'),
                                style: TextStyle(
                                  color: Color(0xFF1A051D), // Dark text color
                                  fontSize: 14, // Slightly adjusted size for better fit
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SafeArea(
                    child: Center(
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          // Card
                          _buildCard(),
                          const Spacer(flex: 1), // Adjusted spacer to make room for the new text

                          // Explanation text for sharing
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 8.0),
                            child: Text(
                              AppLocalizations.of(context)!.translate('progressCard_widgetInstructions'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF666666), // Gray text for light background
                                fontSize: 13,
                                fontFamily: 'ElzaRound',
                                height: 1.3,
                              ),
                            ),
                          ),
                          const Spacer(flex: 1), // Adjusted spacer
                          
                          // Share buttons at bottom
                          Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: _shareProgress,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent, // Kept transparent as per original
                                      borderRadius: BorderRadius.circular(25),
                                      // Optional: Add a border if needed to differentiate touch area
                                      // border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.share,
                                          color: Color(0xFF1A1A1A), // Dark icon
                                          size: 24,
                                          weight: 700,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          AppLocalizations.of(context)!.translate('progressCard_shareToFriends'),
                                          style: TextStyle(
                                            color: Color(0xFF1A1A1A), // Dark text
                                            fontSize: 18,
                                            fontFamily: 'ElzaRound',
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20), // Spacer between buttons
                                GestureDetector(
                                  onTap: _showScreenshotInstructions,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent, // Kept transparent
                                      borderRadius: BorderRadius.circular(25),
                                      // Optional: Add a border
                                      // border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.photo_camera_outlined, // Changed icon
                                          color: Color(0xFF1A1A1A), // Dark icon
                                          size: 24,
                                          weight: 700,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          AppLocalizations.of(context)!.translate('progressCard_toSocials'),
                                          style: TextStyle(
                                            color: Color(0xFF1A1A1A), // Dark text
                                            fontSize: 18,
                                            fontFamily: 'ElzaRound',
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildCard() {
    return Container(
      width: 288, // Exact width from original design
      height: 362, // Exact height from original design
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3), // Increased shadow for dark background
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Pink to orange gradient section
          Expanded(
            flex: 7, // 70% of the space
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFed3272), // Strong pink/magenta
                    Color(0xFFfd5d32), // Vivid orange
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // "STPR" logo with transparent background and white border
                  Positioned(
                    top: 16,
                    left: 24,
                    child: Container(
                      width: 49,
                      height: 49,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white,
                          width: 2.0,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'ST\nPR',
                          style: TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  
                  // Bookmark SVG icon
                  Positioned(
                    top: 24,
                    right: 24,
                    child: SvgPicture.asset(
                      'assets/images/svg/onboarding-4-bookmark.svg',
                      width: 30,
                      height: 23,
                    ),
                  ),
                  
                  // Active Streak text
                  Positioned(
                    bottom: 34,
                    left: 16,
                    child: Text(
                      AppLocalizations.of(context)!.translate('onboarding4_activeStreak'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  
                  // Days count
                  Positioned(
                    bottom: 4,
                    left: 16,
                    child: Text(
                      '$_streakDays ${AppLocalizations.of(context)!.translate('onboarding4_daysUnit')}',
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // White section - white background section  
          Expanded(
            flex: 3, // 30% of the space
            child: Container(
              width: double.infinity,
              color: Colors.white, // White background
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Empty container to maintain spacing when no name
                    if (!(_firstName != null && _firstName!.isNotEmpty))
                      const SizedBox(width: 0),
                    
                    // Name section - only show if we have a firstName
                    if (_firstName != null && _firstName!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Name',
                            style: TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 14,
                              color: Color(0xFF666666), // Gray text for white background
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            TextSanitizer.sanitizeForDisplay(_firstName!),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 21,
                              color: Color(0xFF1A1A1A), // Dark text for white background
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    
                    // Free since section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.translate('onboarding4_freeSince'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 13,
                            color: Color(0xFF666666), // Gray text for white background
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentDate,
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 19,
                            color: Color(0xFF1A1A1A), // Dark text for white background
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 