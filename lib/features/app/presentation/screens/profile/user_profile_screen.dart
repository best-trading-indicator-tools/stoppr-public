import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/streak/streak_service.dart';
import '../../../../../core/relapse/relapse_service.dart';
import '../../../../../core/navigation/page_transitions.dart';
import 'progress_card.dart';
import 'give_feedback.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_screen.dart';
import '../home_rewire_brain.dart';
import '../challenge_28_days_screen.dart';
import '../main_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/chat/crisp_service.dart';
import '../../../../../core/localization/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/streak/app_open_streak_service.dart';
import '../../../../../core/karma/karma_service.dart';
import '../app_open_streak_screen.dart';
import 'dart:async';
import 'package:stoppr/features/nutrition/presentation/screens/edit_weight_screen.dart';
import 'package:stoppr/features/nutrition/presentation/screens/edit_height_screen.dart';
import 'package:stoppr/features/nutrition/presentation/screens/nutrition_goals_screen.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';
import 'package:stoppr/features/app/presentation/screens/profile/settings/user_settings.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final StreakService _streakService = StreakService();
  final RelapseService _relapseService = RelapseService();
  final AppOpenStreakService _appOpenStreakService = AppOpenStreakService();
  final KarmaService _karmaService = KarmaService();
  String? _firstName;
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0 = Today, 1 = This Week, 2 = This Month
  List<DateTime> _relapses = [];
  int _relapseCount = 0;
  int _appOpenStreakDays = 0;
  int _karma = 0;
  bool _hasLoadedDependencies = false;
  String _appVersion = '';
  
  // Store the stream subscription to cancel it on dispose
  StreamSubscription? _appOpenStreakSubscription;
  
  @override
  void initState() {
    super.initState();
    
    // Schedule _loadUserData and _loadRelapses to run after the first frame.
    // This ensures that the context used for localization is fully up-to-date.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadUserData();
        _loadRelapses();
        _loadAppVersion();
      }
    });
    
    // Force status bar icons to dark mode with explicit settings
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    
    // Make app fullscreen and immersive
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
    
    // Load app open streak
    final streak = _appOpenStreakService.currentStreak;
    _appOpenStreakDays = streak.consecutiveDays;
    _appOpenStreakSubscription = _appOpenStreakService.streakStream.listen((streakData) {
      if (mounted) {
        setState(() {
          _appOpenStreakDays = streakData.consecutiveDays;
        });
      }
    });
    
    // Initialize karma service
    _karmaService.initialize();
    _karma = _karmaService.currentKarma;
    _karmaService.karmaStream.listen((karma) {
      if (mounted) {
        setState(() {
          _karma = karma;
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only reload user data after the initial load to prevent excessive calls
    if (_hasLoadedDependencies) {
      // Reload user data when dependencies change (e.g., when navigating back)
      // Use a post-frame callback to ensure context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadUserData();
        }
      });
    } else {
      _hasLoadedDependencies = true;
    }
  }
  
  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version; // Removed build number
      if (mounted) {
        setState(() {
          _appVersion = version;
        });
      }
    } catch (e) {
      debugPrint('Error loading app version: $e');
    }
  }

  @override
  void dispose() {
    // Cancel the stream subscription to prevent memory leaks
    _appOpenStreakSubscription?.cancel();
    
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
      
      if (savedFirstName != null && savedFirstName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _firstName = savedFirstName;
            _isLoading = false;
          });
        }
        return; // Exit if we found a name
      }
      
      // Fallback to Firebase Auth if name not in SharedPreferences
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
        final displayNameParts = currentUser.displayName!.split(' ');
        if (displayNameParts.isNotEmpty) {
          if (mounted) {
            setState(() {
              _firstName = displayNameParts[0]; // Get first name from display name
              _isLoading = false;
            });
          }
          return; // Exit if we got a name from Firebase
        }
      }
      
      // If no name from SharedPreferences or Firebase, or Firebase name was empty, use fallback.
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _firstName = l10n.translate('profile_you_fallback');
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _firstName = l10n.translate('profile_you_fallback'); // Fallback to a default name
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadRelapses() async {
    final relapses = await _getRelapsesForSelectedPeriod();
    
    if (mounted) {
      setState(() {
        _relapses = relapses;
        _relapseCount = relapses.length;
      });
    }
  }
  
  Future<List<DateTime>> _getRelapsesForSelectedPeriod() async {
    switch (_selectedTabIndex) {
      case 0: // Today
        return await _relapseService.getTodayRelapses();
      case 1: // This Week
        return await _relapseService.getThisWeekRelapses();
      case 2: // This Month
        return await _relapseService.getThisMonthRelapses();
      default:
        return await _relapseService.getTodayRelapses();
    }
  }
  
  void _onTabSelected(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
    _loadRelapses();
  }
  
  // Helper to get days remaining until goal
  Future<int> _getDaysUntilGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final targetQuitTimestamp = prefs.getInt('target_quit_timestamp');
    DateTime? endDate;
    if (targetQuitTimestamp != null) {
      endDate = DateTime.fromMillisecondsSinceEpoch(targetQuitTimestamp);
    } else if (_streakService.currentStreak.startTime != null) {
      endDate = _streakService.currentStreak.startTime!.add(const Duration(days: 90));
    } else {
      endDate = DateTime.now().add(const Duration(days: 90));
    }
    final now = DateTime.now();
    final days = endDate.difference(now).inDays + 1;
    return days > 0 ? days : 0;
  }
  

  
  void _showKarmaScreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Makes the route transparent
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) => KarmaScreen(karma: _karma),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
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
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF1A1A1A),
            ),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                TopToBottomPageRoute(
                  child: const MainScaffold(initialIndex: 0),
                  settings: const RouteSettings(name: '/home'),
                ),
              );
            },
          ),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          title: Text(
            l10n.translate('profile_title_you'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 24,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  BottomToTopPageRoute(
                    child: const UserSettingsScreen(),
                    settings: const RouteSettings(name: '/user_settings'),
                  ),
                );
              },
              child: Text(
                l10n.translate('profile_settings_button'),
                style: const TextStyle(
                  color: Color(0xFFed3272),
                  fontSize: 16,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 100.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 8),
                            // Profile image placeholder with gradient border
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFed3272).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.person,
                                    color: Color(0xFFed3272),
                                    size: 64,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // User's name with enhanced styling
                            _firstName != null && _firstName!.isNotEmpty
                              ? Column(
                                  children: [
                                    Text(
                                      TextSanitizer.sanitizeForDisplay(_firstName!),
                                      style: const TextStyle(
                                        color: Color(0xFF1A1A1A),
                                        fontSize: 28,
                                        fontFamily: 'ElzaRound',
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 40,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                            // App open streak row with enhanced styling
                            if (!_isLoading)
                              Container(
                                margin: const EdgeInsets.only(top: 20.0, bottom: 8.0),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 24,
                                  runSpacing: 12,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        // Track button tap with Mixpanel
                                        MixpanelService.trackEvent('App Open Streak Icon Tap');
                                        Navigator.of(context).push(
                                          PageRouteBuilder(
                                            opaque: false, // Makes the route transparent
                                            barrierColor: Colors.transparent,
                                            pageBuilder: (context, animation, secondaryAnimation) => const AppOpenStreakScreen(),
                                            transitionDuration: const Duration(milliseconds: 300),
                                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                              return FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/images/home/flame.svg',
                                            width: 24,
                                            height: 24,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$_appOpenStreakDays',
                                            style: const TextStyle(
                                              color: Color(0xFFfd5d32),
                                              fontSize: 18,
                                              fontFamily: 'ElzaRound',
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            l10n.translate('profile_loginStreak'),
                                            style: const TextStyle(
                                              color: Color(0xFFfd5d32),
                                              fontSize: 16,
                                              fontFamily: 'ElzaRound',
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _showKarmaScreen,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/images/profile/diamond.svg',
                                            width: 24,
                                            height: 24,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$_karma',
                                            style: const TextStyle(
                                              color: Color(0xFFed3272),
                                              fontSize: 18,
                                              fontFamily: 'ElzaRound',
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'KARMA',
                                            style: const TextStyle(
                                              color: Color(0xFFed3272),
                                              fontSize: 16,
                                              fontFamily: 'ElzaRound',
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),
                            
                            // Progress Card Button
                            Center(
                              child: Container(
                                height: 48, // Smaller height
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                                    stops: [0.0, 1.0],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      BottomToTopPageRoute(
                                        child: const ProgressCardScreen(),
                                        settings: const RouteSettings(name: '/progress_card'),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.credit_card_outlined,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.translate('profile_progress_card_button'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Combined stats card with divider
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    // LEFT: Best Record
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Large transparent trophy in background
                                            Icon(
                                              Icons.emoji_events,
                                              size: 180,
                                              color: const Color(0xFFed3272).withOpacity(0.1),
                                            ),
                                            // Foreground content centered
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                FutureBuilder<int>(
                                                  future: Future.value(_streakService.currentStreak.days),
                                                  builder: (context, snapshot) {
                                                    final streakDays = snapshot.data ?? 0;
                                                    return Text(
                                                      '$streakDays',
                                                      style: const TextStyle(
                                                        color: Color(0xFFed3272),
                                                        fontSize: 56,
                                                        fontFamily: 'ElzaRound',
                                                        fontWeight: FontWeight.w900,
                                                        letterSpacing: -1,
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'BEST RECORD',
                                                  style: const TextStyle(
                                                    color: Color(0xFFed3272),
                                                    fontSize: 18,
                                                    fontFamily: 'ElzaRound',
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Divider
                                    Container(
                                      width: 1,
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      color: const Color(0xFFE0E0E0),
                                    ),
                                    // RIGHT: Til Sober
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Large transparent battery in background
                                            Icon(
                                              Icons.battery_charging_full,
                                              size: 180,
                                              color: const Color(0xFFfd5d32).withOpacity(0.1),
                                            ),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Number (gradient)
                                                FutureBuilder<int>(
                                                  future: _getDaysUntilGoal(),
                                                  builder: (context, snapshot) {
                                                    final daysRemaining = snapshot.data ?? 0;
                                                    return Text(
                                                      '$daysRemaining',
                                                      style: const TextStyle(
                                                        color: Color(0xFFfd5d32),
                                                        fontSize: 56,
                                                        fontFamily: 'ElzaRound',
                                                        fontWeight: FontWeight.w900,
                                                        letterSpacing: -1,
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                                // Label
                                                const Text(
                                                  'TIL SOBER',
                                                  style: TextStyle(
                                                    color: Color(0xFFfd5d32),
                                                    fontSize: 18,
                                                    fontFamily: 'ElzaRound',
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                                        // STOPPR UGC Promo Section - Compact design
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                                    Text(
                    'STOPPR',
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 24,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.translate('ugc_promo_subtitle'),
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 14,
                                      fontFamily: 'ElzaRound',
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(28),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () async {
                                        final url = Uri.parse('https://www.stoppr.app/ugc');
                                        MixpanelService.trackButtonTap(
                                          'Onboarding Progress Card Creation Screen: Button Tap',
                                          screenName: 'User Profile Screen',
                                          additionalProps: {'button': 'STOPPR UGC Promo'},
                                        );
                                        
                                        // Check if URL can be launched
                                        if (!await canLaunchUrl(url)) {
                                          debugPrint('Could not launch $url: Scheme not supported or invalid.');
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(l10n.translate('profile_error_cannotOpenLink')),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                        
                                        // Launch URL with error handling
                                        try {
                                          if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
                                            debugPrint('Failed to launch $url via SFSafariViewController (returned false).');
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(l10n.translate('profile_error_failedToOpenLink')),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        } on PlatformException catch (e) {
                                          debugPrint('PlatformException launching $url: ${e.code} - ${e.message}');
                                          
                                          // Track the specific error for debugging
                                          MixpanelService.trackEvent('URL Launch Error', properties: {
                                            'url': url.toString(),
                                            'error_code': e.code,
                                            'error_message': e.message ?? 'Unknown error',
                                            'screen': 'User Profile Screen',
                                          });
                                          
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(l10n.translate('profile_error_networkIssue')),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          debugPrint('Unexpected error launching $url: $e');
                                          
                                          // Track unexpected errors
                                          MixpanelService.trackEvent('URL Launch Unexpected Error', properties: {
                                            'url': url.toString(),
                                            'error': e.toString(),
                                            'screen': 'User Profile Screen',
                                          });
                                          
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(l10n.translate('profile_error_genericError')),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: Text(
                                        l10n.translate('ugc_promo_button'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            
                            // Relapses section - Enhanced design
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [

                                                // Tab selector - Enhanced
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: Row(
                                    children: [
                                      _buildTabButton(l10n.translate('profile_tab_today'), 0),
                                      _buildTabButton(l10n.translate('profile_tab_this_week'), 1),
                                      _buildTabButton(l10n.translate('profile_tab_this_month'), 2),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                
                                // Total Relapses display - Enhanced
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '$_relapseCount',
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A1A),
                                          fontSize: 52,
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w800,
                                          height: 1.0,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _selectedTabIndex == 0
                                          ? l10n.translate('profile_relapses_today_title')
                                          : _selectedTabIndex == 1
                                              ? l10n.translate('profile_relapses_this_week_title')
                                              : l10n.translate('profile_relapses_this_month_title'),
                                        style: const TextStyle(
                                          color: Color(0xFF666666),
                                          fontSize: 18,
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                
                                // Graph - Always display even with no data
                                SizedBox(
                                  height: 200,
                                  child: FutureBuilder<Map<int, int>>(
                                    future: _relapseService.getChartDataForPeriod(
                                      _selectedTabIndex == 0
                                          ? TimePeriod.today
                                          : _selectedTabIndex == 1
                                              ? TimePeriod.week
                                              : TimePeriod.month,
                                    ),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      
                                      final Map<int, int> dataCounts = snapshot.data ?? {};
                                      
                                      // If no data, create an empty chart
                                      if (dataCounts.isEmpty) {
                                        // Create an empty dataset with zeros for visualization
                                        final int maxDataPoints = _selectedTabIndex == 0 
                                            ? 24  // Hours in a day
                                            : _selectedTabIndex == 1
                                                ? 7   // Days in a week
                                                : 12; // Months in a year
                                                
                                        for (int i = 0; i < maxDataPoints; i++) {
                                          dataCounts[i] = 0;
                                        }
                                      }
                                      
                                      return LineChart(
                                        LineChartData(
                                          gridData: const FlGridData(show: true),
                                          titlesData: FlTitlesData(
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 30,
                                                interval: _selectedTabIndex == 0 
                                                    ? 3  // Every 3 hours
                                                    : 1, // Every day or month
                                                getTitlesWidget: (value, meta) {
                                                  // For Daily view - hours (0-23)
                                                  if (_selectedTabIndex == 0) {
                                                    if (value % 3 == 0) {
                                                      return SideTitleWidget(
                                                        meta: meta,
                                                        child: Text(
                                                          '${value.toInt()}:00',
                                                          style: const TextStyle(
                                                            color: Colors.white70,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  } 
                                                  // For Weekly view - days (Mon-Sun)
                                                  else if (_selectedTabIndex == 1) {
                                                    final days = [
                                                      l10n.translate('common_day_monday_short'),
                                                      l10n.translate('common_day_tuesday_short'),
                                                      l10n.translate('common_day_wednesday_short'),
                                                      l10n.translate('common_day_thursday_short'),
                                                      l10n.translate('common_day_friday_short'),
                                                      l10n.translate('common_day_saturday_short'),
                                                      l10n.translate('common_day_sunday_short')
                                                    ];
                                                    final int dayIndex = value.toInt();
                                                    
                                                    if (dayIndex >= 0 && dayIndex < days.length) {
                                                      return SideTitleWidget(
                                                        meta: meta,
                                                        child: Text(
                                                          days[dayIndex],
                                                          style: const TextStyle(
                                                            color: Colors.white70,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  } 
                                                  // For Monthly view - months (Jan-Dec)
                                                  else if (_selectedTabIndex == 2) {
                                                    final months = [
                                                      l10n.translate('common_month_jan_short'),
                                                      l10n.translate('common_month_feb_short'),
                                                      l10n.translate('common_month_mar_short'),
                                                      l10n.translate('common_month_apr_short'),
                                                      l10n.translate('common_month_may_short'),
                                                      l10n.translate('common_month_jun_short'),
                                                      l10n.translate('common_month_jul_short'),
                                                      l10n.translate('common_month_aug_short'),
                                                      l10n.translate('common_month_sep_short'),
                                                      l10n.translate('common_month_oct_short'),
                                                      l10n.translate('common_month_nov_short'),
                                                      l10n.translate('common_month_dec_short')
                                                    ];
                                                    final int monthIndex = value.toInt();
                                                    
                                                    if (monthIndex >= 0 && monthIndex < months.length) {
                                                      return SideTitleWidget(
                                                        meta: meta,
                                                        child: Text(
                                                          months[monthIndex],
                                                          style: const TextStyle(
                                                            color: Colors.white70,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                  return const SizedBox.shrink();
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                interval: 1,
                                                getTitlesWidget: (value, meta) {
                                                  return SideTitleWidget(
                                                    meta: meta,
                                                    child: Text(
                                                      value.toInt().toString(),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            
                                            topTitles: const AxisTitles(
                                              sideTitles: SideTitles(showTitles: false),
                                            ),
                                            rightTitles: const AxisTitles(
                                              sideTitles: SideTitles(showTitles: false),
                                            ),
                                          ),
                                          borderData: FlBorderData(show: false),
                                          lineBarsData: [
                                            LineChartBarData(
                                              spots: dataCounts.entries
                                                  .map((entry) => FlSpot(
                                                        entry.key.toDouble(),
                                                        entry.value.toDouble(),
                                                      ))
                                                  .toList(),
                                              isCurved: true,
                                              color: Colors.blue,
                                              barWidth: 4,
                                              isStrokeCapRound: true,
                                              dotData: const FlDotData(show: true),
                                              belowBarData: BarAreaData(
                                                show: true,
                                                color: Colors.blue.withOpacity(0.3),
                                              ),
                                            ),
                                          ],
                                          minY: 0,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                
                                const SizedBox(height: 40),
                                
                                // Support section
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.translate('profile_support_title'),
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A1A),
                                          fontSize: 22,
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      // Give Feedback button - Enhanced
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          onTap: () {
                                            final CrispService crispService = CrispService();
                                            
                                            try {
                                              // Get current user email if available
                                              final currentUser = FirebaseAuth.instance.currentUser;
                                              if (currentUser != null && currentUser.email != null) {
                                                crispService.setUserInformation(
                                                  email: currentUser.email!,
                                                  firstName: TextSanitizer.sanitizeForDisplay(_firstName ?? l10n.translate('profile_you_fallback')),
                                                );
                                              }
                                              
                                              // Open Crisp chat
                                              crispService.openChat(context);
                                            } catch (e) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('${l10n.translate('settings_crispErrorPrefix')}$e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                                                                      leading: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFed3272).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(24),
                                            ),
                                            child: const Icon(
                                              Icons.feedback_rounded,
                                              color: Color(0xFFed3272),
                                              size: 24,
                                            ),
                                          ),
                                          title: Text(
                                            l10n.translate('profile_give_feedback_button'),
                                            style: const TextStyle(
                                              color: Color(0xFF1A1A1A),
                                              fontSize: 18,
                                              fontFamily: 'ElzaRound',
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          trailing: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE0E0E0).withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Color(0xFF666666),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Contact us button - Enhanced
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          onTap: () async {
                                            final CrispService crispService = CrispService();
                                            
                                            try {
                                              // Get current user email if available
                                              final currentUser = FirebaseAuth.instance.currentUser;
                                              if (currentUser != null && currentUser.email != null) {
                                                crispService.setUserInformation(
                                                  email: currentUser.email!,
                                                  firstName: TextSanitizer.sanitizeForDisplay(_firstName ?? l10n.translate('profile_you_fallback')),
                                                );
                                              }
                                              
                                              // Open Crisp chat
                                              crispService.openChat(context);
                                            } catch (e) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('${l10n.translate('settings_crispErrorPrefix')}$e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                          leading: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFfd5d32).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(24),
                                            ),
                                            child: const Icon(
                                              Icons.contact_support_rounded,
                                              color: Color(0xFFfd5d32),
                                              size: 24,
                                            ),
                                          ),
                                          title: Text(
                                            l10n.translate('profile_contact_us_button'),
                                            style: const TextStyle(
                                              color: Color(0xFF1A1A1A),
                                              fontSize: 18,
                                              fontFamily: 'ElzaRound',
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          trailing: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Icon(
                                              Icons.chevron_right_rounded,
                                              color: Colors.white.withOpacity(0.6),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 32),
                                
                                // App version display - below contact us section
                                if (_appVersion.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: Text(
                                        l10n.translate('profile_app_version')
                                            .replaceAll('{version}', _appVersion),
                                        style: const TextStyle(
                                          color: Color(0xFF666666),
                                          fontSize: 12,
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                
                                const SizedBox(height: 32),
                              ],
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
  
  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected 
              ? const Color(0xFFfae6ec) // Light pink accent for selected
              : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected 
              ? Border.all(
                  color: const Color(0xFFed3272),
                  width: 1.5,
                )
              : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected 
                  ? const Color(0xFFed3272) // Brand pink for selected
                  : const Color(0xFF666666), // Gray for unselected
                fontSize: 15,
                fontFamily: 'ElzaRound',
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
} 

class HealthMenuScreen extends StatelessWidget {
  const HealthMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('profile_health_title'),
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 24,
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HealthTile(
            icon: Icons.monitor_weight,
            title: l10n.translate('profile_health_set_weight'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditWeightScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _HealthTile(
            icon: Icons.height,
            title: l10n.translate('profile_health_set_height'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditHeightScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _HealthTile(
            icon: Icons.local_fire_department,
            title: l10n.translate('profile_health_set_calorie_goals'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NutritionGoalsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFed3272).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon, 
            color: const Color(0xFFed3272),
            size: 24,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right, 
          color: Color(0xFF666666),
          size: 24,
        ),
      ),
    );
  }
}

class KarmaScreen extends StatefulWidget {
  final int karma;
  
  const KarmaScreen({super.key, required this.karma});

  @override
  State<KarmaScreen> createState() => _KarmaScreenState();
}

class _KarmaScreenState extends State<KarmaScreen> {
  @override
  void initState() {
    super.initState();
    
    // Set status bar to dark icons for pink-tinted background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for light background
      statusBarBrightness: Brightness.light, // For iOS
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB), // Subtle neutral white background
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // Detect taps anywhere
        onTap: () {
          Navigator.of(context).pop();
        },
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with close button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          color: Color(0xFF1A1A1A), // Dark icon for background
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Large diamond icon
                    SvgPicture.asset(
                      'assets/images/profile/diamond.svg',
                      width: 160,
                      height: 160,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Karma count and title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFed3272), // Brand pink
                          Color(0xFFfd5d32), // Brand orange
                        ],
                      ).createShader(bounds),
                      child: Text(
                        '${widget.karma} Karma',
                        style: const TextStyle(
                          color: Colors.white, // Required for shader mask
                          fontSize: 36,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Description
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Gain karma for every good post & reply you make on STOPPR.',
                        style: TextStyle(
                          color: Color(0xFF1A1A1A), // Dark text for background
                          fontSize: 16,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Additional motivational content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Text(
                            widget.karma == 0 
                              ? 'Start building your karma today by engaging with the community!'
                              : widget.karma == 1
                                ? 'You\'ve earned your first karma point! Keep contributing to the community.'
                                : 'You\'ve earned ${widget.karma} karma points! Your positive contributions make STOPPR better for everyone.',
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A), // Dark text for background
                              fontSize: 16,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Building positive community connections is key to recovery. Every interaction counts!',
                            style: TextStyle(
                              color: Color(0xFF666666), // Gray secondary text
                              fontSize: 14,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}