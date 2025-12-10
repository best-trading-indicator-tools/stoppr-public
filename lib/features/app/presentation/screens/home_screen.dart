import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/daily_check_in_widget.dart';
import '../widgets/streak_counter_widget.dart';
import '../widgets/brain_rewiring_widget.dart';
import '../widgets/challenge_progress_widget.dart';
import '../widgets/goal_date_widget.dart';
import '../widgets/temptation_status_widget.dart';
import '../widgets/reason_to_quit_widget.dart';
import '../widgets/weekly_tracker_widget.dart';
import 'pledge_screen.dart';
import 'meditate_screen.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/streak/streak_service.dart';
import '../../../../core/streak/achievements_service.dart';
import '../../../../core/pledges/pledge_service.dart';
import '../widgets/pledge_check_in_widget.dart';
import '../widgets/todo_challenge_widget.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'home_rewire_brain.dart';
import 'challenge_28_days_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_edit_streak.dart';
import 'home_achievements.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile/user_profile_screen.dart';
import 'main_scaffold.dart';
import '../../../../core/relapse/relapse_service.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import 'chatbot/chatbot_screen.dart';
import 'breathing_exercise_screen.dart';
import 'home_success_stories_screen.dart';
import 'food_scan/food_scan_screen.dart';
import '../../../../core/pmf_survey/pmf_survey_manager.dart';
import 'rate_my_plate/rate_my_plate_scan_screen.dart';
import 'tree_of_life_screen.dart';
import 'package:stoppr/features/recipes/presentation/screens/recipes_list_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/localization/app_localizations.dart';
import 'panic_button/breathing_animation_screen.dart';
import 'relapsed_flow/relapse_why_screen.dart';
import 'package:stoppr/app/theme/colors.dart';
import 'dart:io' show Platform;
import 'self_reflection.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide LogLevel;
import 'panic_button/what_happening_screen.dart';
import 'podcast_screen.dart';
import 'meditation_screen.dart';
import '../../../onboarding/presentation/screens/congratulations/congratulations_screen_1.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/streak/app_open_streak_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stoppr/core/services/onboarding_audio_service.dart';
import 'app_open_streak_screen.dart';
import 'audio_library_screen.dart';
import '../../../learn/presentation/screens/articles_list_screen.dart';
import '../../../nutrition/presentation/screens/calorie_tracker_dashboard.dart';
import '../../../fasting/presentation/screens/fasting_dashboard_screen.dart';
import 'package:stoppr/features/app/presentation/screens/leaderboard_screen.dart';
import 'package:stoppr/features/accountability/presentation/screens/accountability_partner_screen.dart';
import 'package:stoppr/core/subscription/post_purchase_handler.dart';
import 'package:stoppr/core/services/app_update_service.dart';

// Home Screen Color Constants
class HomeScreenColors {
  static const Color mainBackground = Color(0xFFFAFAFA);
  static const Color sectionBackground = Color(0xFFF5F5F5); // Light gray for sections
  static const Color sectionBorder = Color(0xFF888888);
  static const Color sectionDivider = Color(0xFF888888);
  static const Color sectionShadow = Color(0x40000000); // Black with 0.25 opacity
  static const Color primaryText = Color(0xFF1A1A1A);
  static const Color secondaryText = Color(0xFF555555);
  static const Color buttonBackground = Color(0xFFF0F0F0); // Light gray for button visibility
}

class BackgroundRipple extends StatefulWidget {
  final double size;
  
  const BackgroundRipple({
    super.key,
    required this.size,
  });

  @override
  State<BackgroundRipple> createState() => _BackgroundRippleState();
}

class _BackgroundRippleState extends State<BackgroundRipple> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    // Safety stop: ensure onboarding music is stopped on Home
    OnboardingAudioService.instance.stop();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: RipplePainter(
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class RipplePainter extends CustomPainter {
  final double progress;
  
  RipplePainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    
    // Create a more subtle gray gradient for the circles
    for (int i = 0; i < 5; i++) {
      final radius = maxRadius * (0.6 + (i * 0.1));
      final opacity = 0.3 - (i * 0.05);
      
      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity.clamp(0.05, 0.3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15.0 - (i * 2.0);
      
      canvas.drawCircle(center, radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class HomeScreen extends StatefulWidget {
  final bool showCheckInOnLoad;
  final Function(bool)? onOverlayVisibilityChanged;
  
  const HomeScreen({
    super.key, 
    this.showCheckInOnLoad = false,
    this.onOverlayVisibilityChanged,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  bool _showCheckIn = false;
  bool _showInfoBubble = false;
  String _infoBubbleMessage = '';
  Timer? _infoBubbleTimer;
  bool _infoBubbleTop = false;
  bool _infoBubbleSingleLine = false;
  double? _infoBubbleCustomTop;
  int _usersStillGoing = 19560; // Base number as shown in screenshots
  String? _todaysMood;
  int _selectedNavIndex = 0; // Track selected nav item
  String _currentQuote = ""; // Will be localized
  bool _showPledgeCheckIn = false;
  bool _isTestFlight = false;
  bool _isStandardPaywallRegistered = false; // Track if standard paywall is already registered
  bool _isTrialGiftMode = false; // Shows trial gift banner copy and action
  
  // PMF Survey Manager
  final PMFSurveyManager _pmfSurveyManager = PMFSurveyManager();
  
  // Collection of motivational quote KEYS
  final List<String> _quotes = [
    "homeScreen_quote_1",
    "homeScreen_quote_2",
    "homeScreen_quote_3",
    "homeScreen_quote_4",
    "homeScreen_quote_5",
    "homeScreen_quote_6",
    "homeScreen_quote_7",
    "homeScreen_quote_8",
    "homeScreen_quote_9",
    "homeScreen_quote_10",
    "homeScreen_quote_11",
    "homeScreen_quote_12",
    "homeScreen_quote_13",
    "homeScreen_quote_14",
    "homeScreen_quote_15",
    "homeScreen_quote_16",
    "homeScreen_quote_17",
    "homeScreen_quote_18",
    "homeScreen_quote_19",
    "homeScreen_quote_20",
    "homeScreen_quote_21",
    "homeScreen_quote_22",
    "homeScreen_quote_23",
    "homeScreen_quote_24",
    "homeScreen_quote_25",
    "homeScreen_quote_26",
    "homeScreen_quote_27",
    "homeScreen_quote_28",
    "homeScreen_quote_29",
    "homeScreen_quote_30",
    "homeScreen_quote_31",
    "homeScreen_quote_32",
    "homeScreen_quote_33",
    "homeScreen_quote_34",
    "homeScreen_quote_35",
    "homeScreen_quote_36",
    "homeScreen_quote_37",
    "homeScreen_quote_38",
    "homeScreen_quote_39",
    "homeScreen_quote_40"
  ];
  
  // Services
  final StreakService _streakService = StreakService();
  final PledgeService _pledgeService = PledgeService();
  final AchievementsService _achievementsService = AchievementsService();
  final AppOpenStreakService _appOpenStreakService = AppOpenStreakService();
  
  // For storing the current achievement rosace
  String _currentRosaceImage = 'assets/images/rosaces/achievements_seed.json'; // Use achievements seed as default
  
  // Constants for user growth calculation
  static const String _lastUserCountKey = 'last_user_count';
  static const String _firstUserCountKey = 'first_user_count';
  static const String _lastLaunchDateKey = 'last_launch_date';
  static const String _lastQuoteDateKey = 'last_quote_date';
  static const String _currentQuoteKey = 'current_quote';
  static const String _lastCheckInCompletionDateKey = 'last_check_in_completion_date';
  static const int _minDailyGrowth = 50;
  static const int _maxDailyGrowth = 200;

  // Add a key to access the check-in widget
  final GlobalKey<DailyCheckInWidgetState> _checkInKey = GlobalKey<DailyCheckInWidgetState>();
  final GlobalKey<PledgeCheckInWidgetState> _pledgeCheckInKey = GlobalKey<PledgeCheckInWidgetState>();

  // Subscription expiration tracking
  bool _showSubscriptionExpirationBanner = false;
  int _daysUntilExpiration = 0;
  bool _isLoadingSubscriptionStatus = true;
  Timer? _subscriptionBannerTimer;
  
  // App update tracking
  final AppUpdateService _updateService = AppUpdateService();
  bool _showAppUpdateBanner = false;
  AppUpdateInfo? _updateInfo;
  bool _isLoadingAppUpdate = true;
  
  // App open streak tracking
  int _appOpenStreakDays = 0;
  AppOpenStreakData? _appOpenStreakData;

  // Add a StreamSubscription for app open streak
  StreamSubscription? _appOpenStreakSubscription;

  @override
  void initState() {
    super.initState();
    
    // Force status bar icons to dark mode for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for white background
      statusBarBrightness: Brightness.light, // For iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    
    _initializeCheckInLogic();
    
    // Initialize services in correct order
    _initializeServices();
    
    // Check for pending pledge check-ins
    _checkPendingPledgeCheckIn();
    
    // Track app open for PMF survey
    _pmfSurveyManager.trackAppOpen();
    
    // Check for any pending notification payloads
    _checkPendingNotifications();
    
    // Ensure overlay is updated based on initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateCheckInOverlay();
        _maybeShowRelapseToast();
      }
    });
    
    MixpanelService.isTestFlight().then((isTestFlight) {
      if (mounted) {
        setState(() {
          _isTestFlight = isTestFlight;
        });
      }
    });
  }

  // Initialize services in the correct order
  Future<void> _initializeServices() async {
    try {
      // Initialize streak service first
      await _streakService.initialize();
      
      // Initialize app open streak service and record app open
      await _appOpenStreakService.initialize();
      try {
        await _appOpenStreakService.recordAppOpen();
      } catch (e) {
        debugPrint('Error recording app open: $e');
      }
      
      // Get the current streak after initialization
      final currentStreak = _appOpenStreakService.currentStreak;
      if (mounted) {
        setState(() {
          _appOpenStreakDays = currentStreak.consecutiveDays;
          _appOpenStreakData = currentStreak;
        });
      }
      
      // Listen to app open streak updates
      _appOpenStreakSubscription = _appOpenStreakService.streakStream.listen((streakData) {
        if (mounted) {
          setState(() {
            _appOpenStreakDays = streakData.consecutiveDays;
            _appOpenStreakData = streakData;
          });
        }
      });
      
      // Remove redundant synchronous loading of initial streak data
      // Then load achievements which depend on streak data
      await _loadAchievementRosace();
      
      // Load daily quote
      await _loadDailyQuote();
      
      // Subscribe to achievements updates
      _achievementsService.achievementsStream.listen((_) {
        _updateRosaceFromAchievements();
      });
      
      // Check subscription status for expiration banner
      await _checkSubscriptionStatus();
      
      // Check for app updates
      await _checkForAppUpdate();
    } catch (e) {
      debugPrint('Error initializing services: $e');
      // Continue with app initialization even if some services fail
      // This ensures the app doesn't crash on startup
    }
  }

  // Key to locate the streak counter area for aligning info bubble
  final GlobalKey _streakSectionKey = GlobalKey();

  // Check subscription status using RevenueCat
  Future<void> _checkSubscriptionStatus() async {
    // Prevent concurrent executions
    if (_isLoadingSubscriptionStatus == false) {
      return;
    }
    
    try {
      if (mounted) {
        setState(() {
          _isLoadingSubscriptionStatus = true;
        });
      }
      
      final customerInfo = await Purchases.getCustomerInfo();
      
      // Check if user has active subscription but has cancelled auto-renewal
      bool hasActiveSubscription = customerInfo.activeSubscriptions.isNotEmpty || 
                                  customerInfo.entitlements.active.isNotEmpty;
      
      // DEBUG: Always show trial gift banner on each HomeScreen load for testing
      if (kDebugMode) {
        if (mounted) {
          setState(() {
            _isTrialGiftMode = true;
            _showSubscriptionExpirationBanner = true;
            _daysUntilExpiration = 3;
            _isLoadingSubscriptionStatus = false;
          });
        }
        _subscriptionBannerTimer?.cancel();
        _subscriptionBannerTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _showSubscriptionExpirationBanner = false;
            });
          }
        });
        return;
      }
      
      if (hasActiveSubscription) {
        // Check if auto-renewal is off by looking at management URLs or expiration dates
        String? expirationDateStr;
        
        // Try to get expiration date from entitlements
        if (customerInfo.entitlements.active.isNotEmpty) {
          final entitlement = customerInfo.entitlements.active.values.first;
          expirationDateStr = entitlement.expirationDate;
          
          // Check if the subscription will renew
          // If willRenew is false, the user has cancelled auto-renewal
          if (expirationDateStr != null && entitlement.willRenew == false) {
            final expirationDate = DateTime.parse(expirationDateStr);
            final now = DateTime.now();
            final difference = expirationDate.difference(now);
            
            // Only for trial users who cancelled: show banner days 0-3 before end
            final String productId = entitlement.productIdentifier.toLowerCase();
            final bool isTrial = productId.contains('trial');

            if (isTrial && difference.inDays >= 0 && difference.inDays <= 3) {
              // Daily cap: only once per day
              final prefs = await SharedPreferences.getInstance();
              final String today = DateFormat('yyyy-MM-dd').format(now);
              final String lastShown =
                  prefs.getString('trial_gift_banner_last_shown') ?? '';
              if (lastShown != today) {
                await prefs.setString('trial_gift_banner_last_shown', today);
                if (mounted) {
                  setState(() {
                    _isTrialGiftMode = true;
                    _showSubscriptionExpirationBanner = true;
                    _daysUntilExpiration = difference.inDays;
                  });
                }
                _subscriptionBannerTimer?.cancel();
                _subscriptionBannerTimer = Timer(const Duration(seconds: 10), () {
                  if (mounted) {
                    setState(() {
                      _showSubscriptionExpirationBanner = false;
                    });
                  }
                });
              }
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _isLoadingSubscriptionStatus = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
      if (mounted) {
        setState(() {
          _isLoadingSubscriptionStatus = false;
          _showSubscriptionExpirationBanner = false;
        });
      }
    }
  }

  // Check for app updates
  Future<void> _checkForAppUpdate() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingAppUpdate = true;
        });
      }
      
      // DEBUG: Uncomment to always show banner in debug mode
      // if (kDebugMode) {
      //   if (mounted) {
      //     setState(() {
      //       _showAppUpdateBanner = true;
      //       _updateInfo = const AppUpdateInfo(
      //         hasUpdate: true,
      //         latestVersion: '2.1.0',
      //         currentVersion: '2.0.0',
      //         storeUrl: 'https://apps.apple.com/us/app/stoppr-stop-sugar-now/id6742406521?platform=iphone',
      //       );
      //       _isLoadingAppUpdate = false;
      //     });
      //   }
      //   return;
      // }
      
      final updateInfo = await _updateService.checkForUpdate();
      if (mounted && updateInfo.hasUpdate) {
        setState(() {
          _showAppUpdateBanner = true;
          _updateInfo = updateInfo;
          _isLoadingAppUpdate = false;
        });
        
        // Track app update available event
        MixpanelService.trackEvent('App Update Available', properties: {
          'current_version': updateInfo.currentVersion,
          'latest_version': updateInfo.latestVersion,
        });
        
        // Schedule push notification for 8:41 PM (bypasses daily cap)
        if (updateInfo.latestVersion != null) {
          await NotificationService().scheduleAppUpdateNotification(
            version: updateInfo.latestVersion!,
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingAppUpdate = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking for app update: $e');
      if (mounted) {
        setState(() {
          _isLoadingAppUpdate = false;
          _showAppUpdateBanner = false;
        });
      }
    }
  }

  // Handle update button tap
  Future<void> _handleUpdateApp() async {
    if (_updateInfo?.storeUrl != null) {
      try {
        // Track button tap
        MixpanelService.trackButtonTap('Update App', screenName: 'Home Screen', additionalProps: {
          'version': _updateInfo!.latestVersion,
        });
        
        final url = Uri.parse(_updateInfo!.storeUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('Error opening store URL: $e');
      }
    }
  }
  
  // Handle later button tap on app update banner
  Future<void> _handleUpdateLater() async {
    // Track button tap
    MixpanelService.trackButtonTap('Update Later', screenName: 'Home Screen');
    
    if (_updateInfo?.latestVersion != null) {
      await _updateService.dismissVersion(_updateInfo!.latestVersion!);
    }
    if (mounted) {
      setState(() {
        _showAppUpdateBanner = false;
      });
    }
  }

  Future<void> _loadUserCountAndShowWidget() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUserCount = prefs.getInt(_lastUserCountKey) ?? _usersStillGoing;
    
    if (mounted) {
      setState(() {
        _usersStillGoing = lastUserCount;
        _showCheckIn = true;
        _updateCheckInOverlay();
      });
    }
  }

  // Helper function to load user count without triggering the check-in UI
  Future<void> _loadUserCountWithoutShowingCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUserCount = prefs.getInt(_lastUserCountKey) ?? _usersStillGoing;
    if (mounted) {
      setState(() {
        _usersStillGoing = lastUserCount;
      });
    }
  }

  @override
  void dispose() {
    // Remove any overlay entries when widget is disposed
    _removeCheckInOverlay();
    _infoBubbleTimer?.cancel();
    _subscriptionBannerTimer?.cancel(); // Cancel subscription banner timer
    _appOpenStreakSubscription?.cancel(); // Cancel app open streak subscription
    super.dispose();
  }

  // Determine if the daily check-in should be shown
  Future<void> _initializeCheckInLogic() async {
    // Removed debug-only always-show behavior for daily check-in
    
    // 0. Check if check-in was already completed today
    final prefs = await SharedPreferences.getInstance();
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String? lastCompletionDate = prefs.getString(_lastCheckInCompletionDateKey);

    if (lastCompletionDate == today) {
      debugPrint("Daily check-in already completed today.");
      await _loadUserCountWithoutShowingCheckIn(); // Just load the count
      return; // Stop here
    }

    // Check if coming from congratulations screen
    final fromCongratulations = prefs.getBool('coming_from_congratulations') ?? false;
    if (fromCongratulations) {
      await prefs.setBool('coming_from_congratulations', false); // Clear the flag
      debugPrint("Coming from congratulations, daily check-in suppressed.");
      await _loadUserCountWithoutShowingCheckIn(); // Load count without showing check-in
      // Ensure the pledge check-in is still checked if needed
      _checkPendingPledgeCheckIn();
      return; // Stop here
    }

    // 1. Check the direct flag from the widget (e.g., for dev/testing)
    if (widget.showCheckInOnLoad) {
      debugPrint("Explicitly showing check-in via showCheckInOnLoad flag.");
      await _loadUserCountAndShowWidget();
      return; // Stop here if explicitly told to show
    }

    // 2. Check if it's the first launch of the day and not coming from congratulations
    final shouldShowForFirstLaunch = await _checkIfFirstLaunchOfDay();
    if (shouldShowForFirstLaunch) {
      // User count is already set within _checkIfFirstLaunchOfDay if true
      await _loadUserCountAndShowWidget(); // Now just needs to set _showCheckIn = true and update overlay
    }
  }

  // Renamed and modified to return a boolean
  Future<bool> _checkIfFirstLaunchOfDay() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String? lastLaunchDate = prefs.getString(_lastLaunchDateKey);

    // Check if we're coming from the congratulations screen
    // This check is now primarily handled in _initializeCheckInLogic
    // final fromCongratulations = prefs.getBool('coming_from_congratulations') ?? false;

    // If we're coming from congratulations, clear the flag and DO NOT show check-in
    // if (fromCongratulations) {
    //   await prefs.setBool('coming_from_congratulations', false);
    //   debugPrint("Coming from congratulations, check-in suppressed."); // Added log
    //   // Ensure user count is loaded even if check-in isn't shown
    //   final lastUserCount = prefs.getInt(_lastUserCountKey) ?? _usersStillGoing;
    //    if (mounted) {
    //       setState(() {
    //          _usersStillGoing = lastUserCount;
    //       });
    //    }
    //   return false; // Explicitly return false
    // }

    // Store the first-ever user count if not already saved
    if (!prefs.containsKey(_firstUserCountKey)) {
      await prefs.setInt(_firstUserCountKey, _usersStillGoing);
    }

    final lastUserCount = prefs.getInt(_lastUserCountKey) ?? _usersStillGoing;

    // Check if it's the first launch of the day
    if (lastLaunchDate != today) {
      debugPrint("First launch of the day detected."); // Added log
      // Generate a random number for user growth (between 50-200 more than yesterday)
      final int growth = Random().nextInt(_maxDailyGrowth - _minDailyGrowth + 1) + _minDailyGrowth;
      final newUserCount = lastUserCount + growth;

      // Update the user count state (do this here before returning true)
      if (mounted) {
        setState(() {
          _usersStillGoing = newUserCount;
        });
        debugPrint("Updated user count to: $_usersStillGoing"); // Added log
      }

      // Save today's date and updated user count
      await prefs.setString(_lastLaunchDateKey, today);
      await prefs.setInt(_lastUserCountKey, newUserCount);

      return true; // Indicate that check-in should be shown
    } else {
      // If not first launch today, still use the last saved count for display
      // but don't trigger the check-in based on this condition alone.
      debugPrint("Not the first launch of the day."); // Added log
      if (mounted) {
         setState(() {
            _usersStillGoing = lastUserCount;
         });
         debugPrint("Set user count to last saved: $_usersStillGoing"); // Added log
      }
      return false; // Indicate check-in should NOT be shown based on first launch
    }
  }

  void _onStillGoingStrong() {
    // Don't close the widget yet - it will close after mood selection
    // This method is now just a placeholder but might be used for analytics in the future
  }

  Future<void> _onRelapsed() async {
    // Only log the relapse, don't hide the check-in widget yet
    // The widget will be closed after the user selects a mood
    
    // Log the relapse using RelapseService
    final relapseService = RelapseService();
    relapseService.logRelapse();
    
    // Reset the streak
    await _streakService.resetStreakCounter();
    
    // Reset the rosace image to default and update UI
    if (mounted) {
      setState(() {
        _currentRosaceImage = 'assets/images/rosaces/achievements_seed.json'; // Reset to default rosace
      });
      // Save the default rosace image for persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_rosace', _currentRosaceImage);
      
      // Reset tree of life state when streak is reset due to relapse
      await prefs.setBool('tree_has_been_planted', false);
      debugPrint("Streak, stone, and tree reset due to relapse from daily check-in.");
    }
  }
  
  void _onMoodSelected(String mood) async {
    // Save the selected mood
    final prefs = await SharedPreferences.getInstance();
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString('mood_$today', mood);
    
    if (mounted) {
      setState(() {
        _todaysMood = mood;
        _showCheckIn = false;
        _updateCheckInOverlay();
      });
    }
    
    // After the daily check-in is dismissed, check if we need to show pledge check-in
    _checkPendingPledgeCheckIn();
    
    // You could also log this to analytics, update user profile, etc.
    debugPrint('User mood today: $mood');
  }
  
  void _onReflect() {
    // Here you could navigate to a reflection screen or journal entry
    // For now, just close the check-in widget
    if (mounted) {
      setState(() {
        _showCheckIn = false;
        _updateCheckInOverlay();
      });
    }
    
    // After the daily check-in is dismissed, check if we need to show pledge check-in
    _checkPendingPledgeCheckIn();
    
    // You could show a dialog with reflection prompts or navigate to a reflection screen
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // White background for dialog
          title: Text(
            l10n.translate('homeScreen_dailyReflectionTitle'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for white dialog
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            l10n.translate('homeScreen_dailyReflectionContent'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for white dialog
              fontFamily: 'ElzaRound',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                l10n.translate('common_close'),
                style: const TextStyle(
                  color: Color(0xFFed3272), // Brand pink for button text
                  fontFamily: 'ElzaRound',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Function to animate out and then hide the check-in widget
  void _dismissCheckInWithAnimation() {
    // Access the widget using key and call animateOut
    final checkInState = _checkInKey.currentState;
    if (checkInState != null) {
      checkInState.animateOut();
    } else {
      // Fallback if key doesn't work
      if (mounted) {
        setState(() {
          _showCheckIn = false;
        });
      }
    }
    
    // After the daily check-in is dismissed, check if we need to show pledge check-in
    _checkPendingPledgeCheckIn();
  }

  // Show info bubble for 3 seconds
  void _showInfoBubbleMessage(String message, {bool top = false, bool singleLine = false, double? customTop}) {
    if (mounted) {
      setState(() {
        _showInfoBubble = true;
        _infoBubbleMessage = message;
        _infoBubbleTop = top;
        _infoBubbleSingleLine = singleLine;
        _infoBubbleCustomTop = customTop;
      });
    }
    
    _infoBubbleTimer?.cancel();
    _infoBubbleTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showInfoBubble = false;
          _infoBubbleCustomTop = null;
        });
      }
    });
  }

  // Check if can pledge
  Future<bool> _canPledge() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPledgeTimestamp = prefs.getInt('pledge_timestamp');
    if (!mounted) return false; // Added mounted check
    final l10n = AppLocalizations.of(context)!;
    
    if (lastPledgeTimestamp != null) {
      final lastPledgeTime = DateTime.fromMillisecondsSinceEpoch(lastPledgeTimestamp);
      final now = DateTime.now();
      final difference = now.difference(lastPledgeTime);
      
      if (difference.inHours < 24) {
        final nextPledgeTime = lastPledgeTime.add(const Duration(hours: 24));
        final remaining = nextPledgeTime.difference(now);
        
        String timeMessage;
        if (remaining.inHours > 0) {
          final minutes = remaining.inMinutes % 60;
          if (minutes > 0) {
            timeMessage = '${remaining.inHours}h ${minutes}m';
          } else {
            timeMessage = '${remaining.inHours} hours';
          }
        } else {
          timeMessage = '${remaining.inMinutes} minutes';
        }
        
        _showInfoBubbleMessage(l10n.translate('homeScreen_canPledgeAgainIn').replaceAll('{time}', timeMessage));
        return false;
      }
    }
    
    return true;
  }

  void _resetStreakCounter() {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Reset', screenName: 'Home Screen');
    // Show confirmation dialog instead of immediately resetting
    _showResetConfirmationDialog();
  }

  // Show reset confirmation dialog
  void _showResetConfirmationDialog() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white, // White background for dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.translate('homeScreen_resetConfirmTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A), // Dark text for white dialog
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'ElzaRound',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.translate('homeScreen_resetConfirmMessage'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A), // Dark text for white dialog
                    fontSize: 15,
                    height: 1.4,
                    fontFamily: 'ElzaRound',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Skip button (CTA gradient per brand guide)
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (!mounted) return;
                            Navigator.of(context).pop(); // Just dismiss dialog, do nothing
                          },
                          child: Ink(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Center(
                                child: Text(
                                  l10n.translate('common_skip'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'ElzaRound',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Confirm button (light gray background, black text)
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (!mounted) return;
                            Navigator.of(context).pop(); // Dismiss dialog
                            // Start relapsed flow instead of immediate reset
                            Navigator.of(context).push(
                              FadePageRoute(
                                child: const RelapseWhyScreen(),
                                settings: const RouteSettings(name: '/relapse/why'),
                              ),
                            );
                          },
                          child: Text(
                            l10n.translate('common_confirm'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Perform the actual streak reset
  void _performStreakReset() async {
    // Reset streak and simply refresh home screen state
    await _streakService.resetStreakCounter();
    
    // Reset tree of life state when streak is reset
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tree_has_been_planted', false);
    debugPrint("Tree of life state reset due to streak reset");
    
    _showResetSuccessDialog();
  }

  // Show reset success dialog
  void _showResetSuccessDialog() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white, // White background for dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.translate('homeScreen_resetSuccessTitle'),
                  style: const TextStyle(
                    color: const Color(0xFF1A1A1A), // Dark text for white dialog
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'ElzaRound',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.translate('homeScreen_resetSuccessMessage'),
                  style: const TextStyle(
                    color: const Color(0xFF1A1A1A), // Dark text for white dialog
                    fontSize: 15,
                    height: 1.4,
                    fontFamily: 'ElzaRound',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (!mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      l10n.translate('common_gotIt'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _on28DayChallengePressed() {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('28 Day Challenge', screenName: 'Home Screen');
    debugPrint('Navigating to 28-day challenge screen');
    Navigator.of(context).pushReplacement(
      BottomToTopPageRoute(
        child: const MainScaffold(initialIndex: 2),
        settings: const RouteSettings(name: '/challenge_28_days'),
      ),
    );
  }

  void _showMoreOptions() {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('More', screenName: 'Home Screen');
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    if (!mounted) return; // Added mounted check
    final l10n = AppLocalizations.of(context)!; 
    
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    
    // Calculate position to show the menu below the More button
    // Approximate the More button position
    final moreButtonPosition = Offset(size.width - 80, offset.dy + 530); 
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        moreButtonPosition.dx, 
        moreButtonPosition.dy, 
        moreButtonPosition.dx + 200, 
        moreButtonPosition.dy + 10
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white, // White background for popup menu
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      items: [
        PopupMenuItem(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 10), () {
              // Track menu item tap with Mixpanel
              MixpanelService.trackEvent('Edit Streak Date Button Tap');
              if (!mounted) return; // Added mounted check
              Navigator.of(context).pushReplacement(
                FadePageRoute(
                  child: const HomeEditStreakScreen(),
                  settings: const RouteSettings(name: '/home_edit_streak'),
                ),
              );
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.translate('homeScreen_editStreakDate'),
                style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound'), // Dark text for white menu
              ),
              const Icon(Icons.calendar_month, color: Color(0xFF1A1A1A)), // Dark icon for white menu
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 10), () {
              // Track menu item tap with Mixpanel
              MixpanelService.trackEvent('Join Chat Button Tap');
              launchUrl(Uri.parse('https://t.me/+SKqx1P0D3iljZGRh'), mode: LaunchMode.externalApplication);
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.translate('homeScreen_joinChat'),
                style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound'), // Dark text for white menu
              ),
              const Icon(Icons.chat, color: Color(0xFF1A1A1A)), // Dark icon for white menu
            ],
          ),
        ),
      ],
    );
  }

  // Load or set a daily quote
  Future<void> _loadDailyQuote() async {
    // Select a random quote from the list
    // This is now handled directly in the build method to ensure l10n is available
    // final random = Random();
    // final quoteKey = _quotes[random.nextInt(_quotes.length)];
    
    // if (mounted) {
    //   final l10n = AppLocalizations.of(context)!;
    //   setState(() {
    //     _currentQuote = l10n.translate(quoteKey);
    //   });
    // }
  }

  // Maintenance: Removed debug-only forced pledge check-in display.
  // Check if there's a pending pledge check-in
  Future<void> _checkPendingPledgeCheckIn() async {
    // If daily check-in is already showing, don't show pledge check-in yet
    if (_showCheckIn) {
      return;
    }
    
    // Check if there's a pending pledge check-in that needs to be displayed
    bool hasPendingCheckIn = await _pledgeService.hasPendingCheckIn();
    
    if (hasPendingCheckIn && mounted) {
      setState(() {
        _showPledgeCheckIn = true;
      });
      
      // Notify parent about overlay visibility
      widget.onOverlayVisibilityChanged?.call(true);
    }
    
    // TEMPORARY test code removed
  }

  // Show post-relapse toast when returning from signature screen
  Future<void> _maybeShowRelapseToast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool show = prefs.getBool('relapse_show_toast') ?? false;
      if (!show) return;
      await prefs.setBool('relapse_show_toast', false);
      final l10n = AppLocalizations.of(context)!;
      final int days = prefs.getInt('relapse_goal_days') ?? 0;
      final String msg = l10n.translate('relapse_challenge_toast').replaceAll('{days}', days.toString());
      // Try to align the info bubble near the streak counter
      double? customTop;
      try {
        final contextObj = _streakSectionKey.currentContext;
        if (contextObj != null) {
          final box = contextObj.findRenderObject() as RenderBox?;
          if (box != null) {
            final position = box.localToGlobal(Offset.zero);
            // Place bubble slightly above the streak section
            customTop = position.dy - 12;
          }
        }
      } catch (_) {}
      _showInfoBubbleMessage(msg, top: true, singleLine: false, customTop: customTop);
      _infoBubbleTimer?.cancel();
      _infoBubbleTimer = Timer(const Duration(seconds: 7), () {
        if (mounted) {
          setState(() => _showInfoBubble = false);
        }
      });
    } catch (e) {
      debugPrint('Error showing relapse toast: $e');
    }
  }
  
  // Handle pledge check-in submission
  void _handlePledgeCheckInSubmit(bool successful, String feeling, String? notes) {
    _pledgeService.savePledgeCheckIn(
      wasSuccessful: successful,
      feeling: feeling,
      notes: notes,
    );
    if (!mounted) return; // Added mounted check
    final l10n = AppLocalizations.of(context)!; 
    
    if (mounted) {
      setState(() {
        _showPledgeCheckIn = false;
      });
    }
    
    // Notify parent about overlay visibility change
    widget.onOverlayVisibilityChanged?.call(false);
    
    // Show feedback near the streak Lottie area (above)
    String msg = l10n.translate('homeScreen_pledgeCheckInSaved');
    double? customTop;
    try {
      final contextObj = _streakSectionKey.currentContext;
      if (contextObj != null) {
        final box = contextObj.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          customTop = position.dy - 12;
        }
      }
    } catch (_) {}
    _showInfoBubbleMessage(msg, top: true, singleLine: true, customTop: customTop);
    
    // Check if we should show PMF survey after pledge
    _checkPMFSurvey();
  }
  
  // Handle closing the pledge check-in without submitting
  void _closePledgeCheckIn() {
    // Update the state after animation completes
    if (mounted) {
      setState(() {
        _showPledgeCheckIn = false;
      });
    }
    if (!mounted) return; // Added mounted check
    final l10n = AppLocalizations.of(context)!; 
    
    // Notify parent about overlay visibility change
    widget.onOverlayVisibilityChanged?.call(false);
    
    // Show a reminder message
    _showInfoBubbleMessage(l10n.translate('homeScreen_canCheckInLater'));
    
    // Check if we should show PMF survey after pledge
    _checkPMFSurvey();
  }

  // Method to display pending changelog
  Future<void> _checkPendingChangelog() async {
    // Only check for pending changelog if no other UI elements are active
    if (_showCheckIn || _showPledgeCheckIn) {
      return;
    }
    if (!mounted) return; // Added mounted check
    final l10n = AppLocalizations.of(context)!; 
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingChangelog = prefs.getString('pending_changelog');
      
      // If we have a pending changelog and the widget is still mounted, display it
      if (pendingChangelog != null && pendingChangelog.isNotEmpty && mounted) {
        // Clear the pending changelog immediately to prevent showing it multiple times
        await prefs.remove('pending_changelog');
        
        // Show the changelog dialog
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Changelog',
          pageBuilder: (context, _, __) {
            return Center(
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 500.0,
                    maxHeight: 600.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'What\'s New',
                              style: TextStyle(
                                fontSize: 20.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                if (!mounted) return; // Added mounted check
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Markdown(
                            data: pendingChangelog,
                            selectable: true,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            onPressed: () {
                              if (!mounted) return; // Added mounted check
                              Navigator.of(context).pop();
                            },
                            child: Text(l10n.translate('common_gotIt')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
        );
        
        debugPrint('Displayed pending changelog dialog');
      }
    } catch (e) {
      debugPrint('Error checking for pending changelog: $e');
    }
  }

  // Update PMF survey check to also check for pending changelog
  Future<void> _checkPMFSurvey() async {
    // Wait a short moment to prevent UI conflicts
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Only proceed if the widget is still mounted
    if (!mounted) return;
    
    // First check for pending changelog as it has higher priority
    final prefs = await SharedPreferences.getInstance();
    final pendingChangelog = prefs.getString('pending_changelog');
    
    // If we have a pending changelog, show it and don't show PMF survey
    if (pendingChangelog != null && pendingChangelog.isNotEmpty) {
      _checkPendingChangelog();
      return;
    }
    
    // Only check for PMF survey if no changelog is pending
    final shouldShow = await _pmfSurveyManager.shouldShowSurvey(
      isCheckInActive: _showCheckIn,
      isPledgeActive: _showPledgeCheckIn,
      isRelapsing: false,
      isOnboarding: false
    );
    
    // If we should show it and the widget is still mounted, show it
    if (shouldShow && mounted) {
      await _pmfSurveyManager.showSurveyPrompt(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; 
    // Randomly select a quote key each time build is called if _currentQuote is empty
    // This ensures a new quote can be displayed on screen changes or refreshes if desired,
    // and that l10n is available.
    if (_currentQuote.isEmpty && _quotes.isNotEmpty) {
      try {
        final random = Random();
        final quoteKey = _quotes[random.nextInt(_quotes.length)];
        final translatedQuote = l10n.translate(quoteKey);
        _currentQuote = translatedQuote.isNotEmpty ? translatedQuote : "Stay strong today.";
      } catch (e) {
        debugPrint('Error loading quote: $e');
        _currentQuote = "Stay strong today."; // Fallback quote
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white background
        statusBarBrightness: Brightness.light, // For iOS
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Make scaffold transparent to show background image 
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leadingWidth: 0,
          toolbarHeight: 0,
          leading: null,
          titleSpacing: 0,
          title: const SizedBox.shrink(),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        body: SafeArea(
          top: false, // Allow background to go under status bar
          child: Stack(
            children: [
              // Subtle neutral white background for post-onboarding screens
              Container(color: HomeScreenColors.mainBackground), // Much lighter background for contrast with sections
              
              // Scrollable main content
              Positioned.fill(
                bottom: 0, // Remove bottom padding since navigation is handled by MainScaffold
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Space for the banner to not overlap content initially
                      // if (_showSubscriptionExpirationBanner || _showInfoBubble) 
                      //   SizedBox(height: MediaQuery.of(context).padding.top + 80),
                      // STOPPR text and trophy icon in same row
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 45.0), // Increased top padding from 4.0 to 45.0 
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.translate('appTitle'),
                              style: const TextStyle(
                                color: HomeScreenColors.primaryText, // Dark text for white background
                                fontSize: 28,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.7,
                              ),
                            ),
                            Row(
                              children: [
                                // Flame icon + counter for app open streak
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
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SvgPicture.asset(
                                          'assets/images/home/flame.svg',
                                          width: 18,
                                          height: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_appOpenStreakDays',
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 14,
                                            fontFamily: 'ElzaRound',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Debug button to clear SharedPreferences (only in debug mode)
                                if (kDebugMode) ...[
                                  GestureDetector(
                                    onTap: () async {
                                      // Clear SharedPreferences for testing
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.remove('has_seen_todo_challenge');
                                      await prefs.remove('todo_completed_items');
                                      // Clear debug food logs
                                      await prefs.remove('debug_food_logs');
                                      debugPrint('Debug: Cleared todo challenge and debug food logs preferences');
                                      
                                      // Navigate to another tab and back to refresh the home screen
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (context) => const MainScaffold(initialIndex: 1),
                                        ),
                                      );
                                      
                                      // After a short delay, navigate back to home
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        if (mounted) {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(
                                              builder: (context) => const MainScaffold(initialIndex: 0),
                                            ),
                                          );
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.clear_all,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                
                                // Tree of Life icon
                                GestureDetector(
                                  onTap: () {
                                    MixpanelService.trackButtonTap(
                                      'Tree of Life Icon',
                                      screenName: 'Home Screen',
                                    );
                                    if (!mounted) return;
                                    Navigator.of(context).push(
                                      BottomToTopPageRoute(
                                        child: const TreeOfLifeScreen(),
                                        settings: const RouteSettings(name: '/tree_of_life'),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.eco,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // Trophy icon for achievements
                                GestureDetector(
                                  onTap: () {
                                    // Track button tap with Mixpanel
                                    MixpanelService.trackEvent('Trophy Icon Tap');
                                    if (!mounted) return; // Added mounted check
                                    Navigator.of(context).pushReplacement(
                                      BottomToTopPageRoute(
                                        child: const HomeAchievementsScreen(),
                                        settings: const RouteSettings(name: '/home_achievements'),
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.emoji_events,
                                    color: HomeScreenColors.primaryText, // Dark icon for white background
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Weekly tracker widget
                      if (_appOpenStreakData != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: WeeklyTrackerWidget(
                            streakData: _appOpenStreakData!,
                          ),
                        ),
                      
                      // Stone with Lottie background 
                      SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Achievement Lottie animation
                            Container(
                              width: 180,
                              height: 180,
                              child: _buildAchievementAnimation(),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20), // Added space to position the text lower
                      
                      // "You've been sugar free for" text - moved lower
                      Text(
                        l10n.translate('homeScreen_sugarFreeFor'),
                        style: const TextStyle(
                          color: HomeScreenColors.secondaryText, // Darker gray text for better visibility
                          fontSize: 16,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      // Negative space to bring streak counter closer
                      Transform.translate(
                        offset: const Offset(0, -40),
                        child: Column(
                          children: [
                            Container(
                              key: _streakSectionKey,
                              child: StreakCounterWidget(
                                onReset: _resetStreakCounter,
                                actionButtons: [
                                  ActionButton(
                                    icon: Icons.pan_tool,
                                    label: l10n.translate('homeScreen_pledge'),
                                    onTap: _onPledgePressed,
                                  ),
                                  ActionButton(
                                    icon: Icons.restaurant_menu,
                                    label: l10n.translate('calorieTracker_title'),
                                    onTap: _onCalorieTrackerPressed,
                                  ),
                                  ActionButton(
                                    icon: Icons.refresh,
                                    label: l10n.translate('homeScreen_reset'),
                                    onTap: _resetStreakCounter,
                                  ),
                                  ActionButton(
                                    icon: Icons.more_horiz,
                                    label: l10n.translate('homeScreen_more'),
                                    onTap: _showMoreOptions,
                                  ),
                                ],
                              ),
                            ),
                            
                            // Add the new separate widgets
                            const BrainRewiringWidget(),
                            const SizedBox(height: 16),
                            const ChallengeProgressWidget(),
                            const SizedBox(height: 16),
                            // Todo Challenge Widget
                            const TodoChallengeWidget(),
                            const SizedBox(height: 16),
                            // Two new widgets side by side - adjusted spacing
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0), // Add horizontal padding to the row
                              child: Row(
                                children: [
                                  // Wrap each widget in Flexible to prevent overflow
                                  Flexible(
                                    flex: 1,
                                    child: const GoalDateWidget(),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    flex: 1,
                                    child: const TemptationStatusWidget(),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Add the reason to quit widget below
                            const ReasonToQuitWidget(),
                            
                            // Main section with options
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
                              decoration: BoxDecoration(
                                color: HomeScreenColors.sectionBackground, // Much darker gray - REALLY visible now!
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: HomeScreenColors.sectionBorder, // VERY dark border - impossible to miss!
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: HomeScreenColors.sectionShadow, // VERY strong shadow - sections will pop!
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.translate('homeScreen_mainSectionTitle'),
                                    style: const TextStyle(
                                      color: HomeScreenColors.secondaryText, // Darker gray text for better visibility
                                      fontSize: 14,
                                      fontFamily: 'ElzaRound',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Add Streak to Home option
                                  _buildMainOption(
                                    icon: Icons.widgets_outlined,
                                    label: l10n.translate('homeScreen_addWidgetsToHome'),
                                    onTap: _showAddWidgetInstructions,
                                  ),

                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!

                                  // Accountability Partner option
                                  _buildMainOption(
                                    icon: Icons.people_outline,
                                    label: l10n.translate('accountability_partner_title'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Accountability Partner', screenName: 'Home Screen');
                                      if (!mounted) return;
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const AccountabilityPartnerScreen(),
                                          settings: const RouteSettings(name: '/accountability_partner'),
                                        ),
                                      );
                                    },
                                  ),

                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!

                                  // Calorie Tracker option
                                  _buildMainOption(
                                    icon: Icons.restaurant_menu,
                                    label: l10n.translate('calorieTracker_title'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Calories Tracker', screenName: 'Home Screen');
                                      if (!mounted) return;
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const CalorieTrackerDashboard(),
                                          settings: const RouteSettings(name: '/calorie_tracker'),
                                        ),
                                      );
                                    },
                                  ),

                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!

                                  // Food Scan option
                                  _buildMainOption(
                                    icon: Icons.camera_alt_outlined,
                                    label: l10n.translate('homeScreen_scanYourCraving'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Scan your craving', screenName: 'Home Screen');
                                      if (!mounted) return; // Added mounted check
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const FoodScanScreen(),
                                          settings: const RouteSettings(name: '/food_scan'),
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!

                                  // Fasting option
                                  _buildMainOption(
                                    icon: Icons.timer_outlined,
                                    label: l10n.translate('fasting_title'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Fasting', screenName: 'Home Screen');
                                      if (!mounted) return;
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const FastingDashboardScreen(),
                                          settings: const RouteSettings(name: '/fasting_dashboard'),
                                        ),
                                      );
                                    },
                                  ),

                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!

                                  // Healthy Recipes option
                                  _buildMainOption(
                                    icon: Icons.restaurant,
                                    label: l10n.translate('recipes_title'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Healthy Recipes', screenName: 'Home Screen');
                                      if (!mounted) return;
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const RecipesListScreen(),
                                          settings: const RouteSettings(name: '/recipes'),
                                        ),
                                      );
                                    },
                                  ),

                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!

                                  // Rate My Plate option
                                  _buildMainOption(
                                    icon: Icons.rate_review_outlined,
                                    label: l10n.translate('homeScreen_rateMyPlate'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Rate My Plate', screenName: 'Home Screen');
                                      // Navigate to Rate My Plate scan screen
                                      if (!mounted) return; // Added mounted check
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const RateMyPlateScanScreen(),
                                          settings: const RouteSettings(name: '/rate_my_plate_scan'),
                                        ),
                                      );
                                    },
                                  ),

                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!

                                  // Positive Affirmations option
                                  _buildMainOption(
                                    icon: Icons.self_improvement, // Icon for Positive Affirmations
                                    label: l10n.translate('homeScreen_selfReflection'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Button Tap Home Positive Affirmations', screenName: 'Home Screen');
                                      if (!mounted) return; // Added mounted check
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const SelfReflectionScreen(), // Navigate to SelfReflectionScreen
                                          settings: const RouteSettings(name: '/self_reflection'),
                                        ),
                                      );
                                    },
                                  ),

                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!

                                  // Talk with Jarvis option
                                  _buildMainOption(
                                    icon: Icons.smart_toy_outlined,
                                    label: l10n.translate('homeScreen_talkToJarvis'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Talk to Jarvis', screenName: 'Home Screen');
                                      if (!mounted) return; // Added mounted check
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const ChatbotScreen(),
                                          settings: const RouteSettings(name: '/chatbot'),
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!
                                  
                                  // Chat option
                                  _buildMainOption(
                                    icon: Icons.forum_outlined,
                                    label: l10n.translate('homeScreen_chat'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Chat', screenName: 'Home Screen');
                                      _showJoinGroupChatDialog();
                                    },
                                  ),
                                  
                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!
                                  
                                  // Leaderboard option
                                  _buildMainOption(
                                    icon: Icons.leaderboard_outlined,
                                    label: l10n.translate('homeLearn_leaderboard'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Leaderboard', screenName: 'Home Screen');
                                      if (!mounted) return;
                                      Navigator.of(context).pushReplacement(
                                        BottomToTopPageRoute(
                                          child: const LeaderboardScreen(),
                                          settings: const RouteSettings(name: '/leaderboard'),
                                        ),
                                      );
                                    },
                                  ),

                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!

                                  //const Divider(color: Color(0xFF1F2A4C), height: 32),
                                  
                                  // Achievements option
                                  _buildMainOption(
                                    icon: Icons.military_tech_outlined,
                                    label: l10n.translate('homeScreen_achievements'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Achievements', screenName: 'Home Screen');
                                      if (!mounted) return; // Added mounted check
                                      Navigator.of(context).pushReplacement(
                                        BottomToTopPageRoute(
                                          child: const HomeAchievementsScreen(),
                                          settings: const RouteSettings(name: '/home_achievements'),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            
                            // Mindfulness section
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
                              decoration: BoxDecoration(
                                color: HomeScreenColors.sectionBackground, // Much darker gray - REALLY visible now!
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: HomeScreenColors.sectionBorder, // VERY dark border - impossible to miss!
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: HomeScreenColors.sectionShadow, // VERY strong shadow - sections will pop!
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.translate('homeScreen_mindfulnessSectionTitle'),
                                    style: const TextStyle(
                                      color: HomeScreenColors.secondaryText, // Darker gray text for better visibility
                                      fontSize: 14,
                                      fontFamily: 'ElzaRound',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Breathing Exercise option
                                  _buildMainOption(
                                    icon: Icons.air_rounded,
                                    label: l10n.translate('homeScreen_breathingExercise'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Breathing Exercise', screenName: 'Home Screen');
                                      if (!mounted) return; // Added mounted check
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const BreathingAnimationScreen(),
                                          settings: const RouteSettings(name: '/breathing_exercise'),
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!
                                  
                                  // Success Stories option
                                  _buildMainOption(
                                    icon: Icons.emoji_emotions_outlined,
                                    label: l10n.translate('homeScreen_successStories'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Success Stories', screenName: 'Home Screen');
                                      if (!mounted) return; // Added mounted check
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const HomeSuccessStoriesScreen(),
                                          settings: const RouteSettings(name: '/success_stories'),
                                        ),
                                      );
                                    },
                                  ),
                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!
                                  // Meditation Session option
                                  _buildMainOption(
                                    icon: Icons.self_improvement_outlined,
                                    label: l10n.translate('homeScreen_meditationSession'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Meditation Session', screenName: 'Home Screen');
                                      if (!mounted) return;
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const MeditationScreen(),
                                          settings: const RouteSettings(name: '/meditation'),
                                        ),
                                      );
                                    },
                                  ),
                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!
                                  // Podcast option
                                  _buildMainOption(
                                    icon: Icons.podcasts,
                                    label: l10n.translate('homeScreen_podcast'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Podcast', screenName: 'Home Screen');
                                      if (!mounted) return;
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const PodcastScreen(),
                                          settings: const RouteSettings(name: '/podcast'),
                                        ),
                                      );
                                    },
                                  ),
                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!
                                  // Audio option
                                  _buildMainOption(
                                    icon: Icons.audiotrack,
                                    label: l10n.translate('homeScreen_audio'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Audio', screenName: 'Home Screen');
                                      if (!mounted) return;
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const AudioLibraryScreen(),
                                          settings: const RouteSettings(name: '/audio_library'),
                                        ),
                                      );
                                    },
                                  ),
                                  Divider(color: HomeScreenColors.sectionDivider, height: 32), // VERY dark divider - super visible!
                                  // Articles option
                                  _buildMainOption(
                                    icon: Icons.article_outlined,
                                    label: l10n.translate('homeScreen_articles'),
                                    onTap: () {
                                      MixpanelService.trackButtonTap('Articles', screenName: 'Home Screen');
                                      if (!mounted) return;
                                      Navigator.of(context).push(
                                        BottomToTopPageRoute(
                                          child: const ArticlesListScreen(),
                                          settings: const RouteSettings(name: '/articles_list'),
                                        ),
                                      );
                                    },
                                  ),

                                  
                                ],
                              ),
                            ),
                            
                            // Misc section
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
                              decoration: BoxDecoration(
                                color: HomeScreenColors.sectionBackground, // Much darker gray - REALLY visible now!
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: HomeScreenColors.sectionBorder, // VERY dark border - impossible to miss!
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: HomeScreenColors.sectionShadow, // VERY strong shadow - sections will pop!
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.translate('homeScreen_miscSectionTitle'),
                                    style: const TextStyle(
                                      color: HomeScreenColors.secondaryText, // Darker gray text for better visibility
                                      fontSize: 14,
                                      fontFamily: 'ElzaRound',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildMainOption(
                                    icon: Icons.videogame_asset_outlined,
                                    label: l10n.translate('homeScreen_games'),
                                    onTap: () async {
                                      final Uri url = Uri.parse('https://10836.play.gamezop.com');
                                      if (await canLaunchUrl(url)) {
                                        try {
                                          await launchUrl(
                                            url,
                                            mode: LaunchMode.inAppWebView,
                                          );
                                        } on PlatformException catch (e) {
                                          debugPrint('PlatformException launching games URL: \\${e.message}');
                                          try {
                                            await launchUrl(url, mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            debugPrint('Fallback external launch failed: \\${e.toString()}');
                                          }
                                        } catch (e) {
                                          debugPrint('Error launching games URL: \\${e.toString()}');
                                          try {
                                            await launchUrl(url, mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            debugPrint('Fallback external launch failed: \\${e.toString()}');
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Move the quote container higher with better visibility
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
         
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Quote mark icon
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: Text(
                                      "❝",
                                      style: const TextStyle(
                                        color: HomeScreenColors.secondaryText, // Darker gray for better visibility
                                        fontSize: 36,
                                      ),
                                    ),
                                  ),
                                  // Quote text
                                  Text(
                                    _currentQuote, // Already translated or fetched if logic requires
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: HomeScreenColors.primaryText, // Dark text for white background
                                      fontSize: 16,
                                      fontFamily: 'ElzaRound',
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Add padding at the bottom to ensure scrolling past the panic button
                      const SizedBox(height: 70),
                    ],
                  ),
                ),
              ),
              
              // Sticky bottom section containing panic button and menu
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: HomeScreenColors.mainBackground, // Match improved main background
                  padding: const EdgeInsets.only(bottom: 5), // Reduced padding from 80 to 20
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Panic button
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 20.0, 
                          right: 20.0, 
                          top: 5.0, 
                          bottom: 5.0
                        ),
                        child: GestureDetector(
                          onTap: _onPanicButtonPressed,
                          child: Container(
                            width: 375,
                            height: 50,
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFFed3272), // Brand pink
                                  Color(0xFFfd5d32), // Brand orange
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  l10n.translate('homeScreen_panicButton'),
                                  style: TextStyle(
                                    color: Colors.white, // CTA button white text
                                    fontSize: 19, // CTA button font size
                                    fontWeight: FontWeight.w600, // CTA button font weight
                                    fontFamily: 'ElzaRound',
                                    height: 0.9,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1.0, 1.0),
                            end: const Offset(1.03, 1.03), // Gentle pulsing
                            duration: 2.5.seconds,
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Add a gesture detector overlay for tapping outside the check-in widget
              if (_showCheckIn)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismissCheckInWithAnimation,
                    child: Container(
                      color: Colors.transparent,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
              
              // Pledge Check-in Widget
              if (_showPledgeCheckIn && !_showCheckIn)
                Positioned.fill(
                  child: PledgeCheckInWidget(
                    key: _pledgeCheckInKey,
                    onSubmit: (successful, feeling, notes) {
                      _handlePledgeCheckInSubmit(successful, feeling, notes);
                    },
                    onClose: _closePledgeCheckIn,
                  ),
                ),
              

                
              // Info bubble
              if (_showInfoBubble)
                Positioned(
                  top: _infoBubbleTop
                      ? (_infoBubbleCustomTop ?? (MediaQuery.of(context).padding.top + 96))
                      : null,
                  bottom: _infoBubbleTop ? null : 120,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white, // Clean white background per brand guide
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFed3272).withOpacity(0.2), // Brand pink border
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFfae6ec).withOpacity(0.8), // Light pink accent
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.schedule,
                            color: Color(0xFFed3272), // Brand pink icon
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _infoBubbleMessage,
                            maxLines: _infoBubbleSingleLine ? 1 : 3,
                            softWrap: true,
                            overflow: _infoBubbleSingleLine ? TextOverflow.ellipsis : TextOverflow.visible,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A), // Dark text on white background
                              fontSize: 16,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Subscription expiration banner
              if (_showSubscriptionExpirationBanner && !_isLoadingSubscriptionStatus)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 110,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () async {
                      MixpanelService.trackButtonTap('Subscription Expiration Banner', screenName: 'Home Screen');
                      
                      if (_isTrialGiftMode) {
                        await _triggerTrialGiftPaywall();
                      } else {
                        // For non-trial users, use existing behavior (platform subscription management)
                        try {
                          if (Platform.isIOS) {
                            // Open iOS subscription management page
                            final url = Uri.parse('https://apps.apple.com/account/subscriptions');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } else {
                              // Fallback to Settings app
                              await launchUrl(
                                Uri.parse('app-settings:'),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          } else if (Platform.isAndroid) {
                            // Open Google Play subscription management page
                            // First try the direct Play Store subscription URL
                            final packageName = 'com.stoppr.sugar.app'; // Your app's package name
                            final url = Uri.parse('https://play.google.com/store/account/subscriptions?package=$packageName');
                            
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } else {
                              // Fallback to general Play Store subscriptions page
                              final fallbackUrl = Uri.parse('https://play.google.com/store/account/subscriptions');
                              await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
                            }
                          }
                        } catch (e) {
                          debugPrint('Error opening subscription management: $e');
                          // Fallback to opening the paywall if we can't open subscription management
                          try {
                            await Superwall.shared.handleDeepLink(Uri.parse('stoppr://paywall'));
                          } catch (paywallError) {
                            debugPrint('Error opening paywall as fallback: $paywallError');
                          }
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFed3272), // Brand pink
                            Color(0xFFfd5d32), // Brand orange
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                                              child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FutureBuilder<bool>(
                                future: _isUserOnTrial(),
                                builder: (context, snapshot) {
                                  // Treat cancelled-trial gift mode as trial for copy selection
                                  final isTrialUser = (snapshot.data ?? false) || _isTrialGiftMode;
                                  String message;
                                  
                                  if (isTrialUser) {
                                    if (_isTrialGiftMode) {
                                      if (_daysUntilExpiration == 0) {
                                        message = l10n.translate('trial_surprise_today_banner_click');
                                      } else if (_daysUntilExpiration == 1) {
                                        message = l10n.translate('trial_treat_tomorrow_banner_click');
                                      } else if (_daysUntilExpiration == 2) {
                                        message = l10n.translate('trial_gift_in_2_days_banner_click');
                                      } else {
                                        message = l10n.translate('trial_gift_in_3_days_banner_click');
                                      }
                                    } else {
                                      if (_daysUntilExpiration == 0) {
                                        message = l10n.translate('trial_expires_today_banner');
                                      } else if (_daysUntilExpiration == 1) {
                                        message = l10n.translate('trial_expires_in_days_banner_one');
                                      } else if (_daysUntilExpiration >= 2 && _daysUntilExpiration <= 4 && l10n.locale.languageCode == 'cs') {
                                        message = l10n.translate('trial_expires_in_days_banner_few').replaceAll('%s', _daysUntilExpiration.toString());
                                      } else {
                                        message = l10n.translate('trial_expires_in_days_banner_other').replaceAll('%s', _daysUntilExpiration.toString());
                                      }
                                    }
                                  } else {
                                    // Use regular subscription messages
                                    if (_daysUntilExpiration == 0) {
                                      message = l10n.translate('subscription_expires_today_banner');
                                    } else if (_daysUntilExpiration == 1) {
                                      message = l10n.translate('subscription_expires_in_days_banner_one');
                                    } else if (_daysUntilExpiration >= 2 && _daysUntilExpiration <= 4 && l10n.locale.languageCode == 'cs') {
                                      message = l10n.translate('subscription_expires_in_days_banner_few').replaceAll('%s', _daysUntilExpiration.toString());
                                    } else {
                                      message = l10n.translate('subscription_expires_in_days_banner_other').replaceAll('%s', _daysUntilExpiration.toString());
                                    }
                                  }
                                  
                                  return Text(
                                    message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontFamily: 'ElzaRound',
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 3,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 24,
                            ),
                          ],
                        ),
                    ),
                  ),
                ),

              // App update banner - shows on every home screen load until dismissed (but never overlaps with trial banner)
              if (_showAppUpdateBanner && !_isLoadingAppUpdate && !_showSubscriptionExpirationBanner)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 55,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: _handleUpdateApp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4CAF50), // Green
                            Color(0xFF66BB6A), // Light green
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.system_update,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.translate('appUpdate_banner_title'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontFamily: 'ElzaRound',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.translate('appUpdate_banner_message')
                                      .replaceAll('{version}', _updateInfo?.latestVersion ?? ''),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontFamily: 'ElzaRound',
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _handleUpdateLater,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use post-frame callback to prevent setState during build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateCheckInOverlay();
      }
    });
  }

  // Overlay entry for the check-in widget
  OverlayEntry? _checkInOverlayEntry;

  // Update the check-in overlay based on _showCheckIn state
  void _updateCheckInOverlay() {
    // Remove any existing overlay first
    _removeCheckInOverlay();
    
    // If check-in should be shown, create a new overlay entry
    if (_showCheckIn && mounted) {
      final overlay = Overlay.of(context);
      
      _checkInOverlayEntry = OverlayEntry(
        builder: (context) => DailyCheckInWidget(
          key: _checkInKey,
          usersCount: _usersStillGoing,
          onStillGoingStrong: _onStillGoingStrong,
          onRelapsed: _onRelapsed,
          onMoodSelected: _onMoodSelected,
          onReflect: _onReflect,
          onAnimationComplete: () async {
            // Save completion date
            final prefs = await SharedPreferences.getInstance();
            final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            await prefs.setString(_lastCheckInCompletionDateKey, today);
            debugPrint("Saved check-in completion date for today: $today");

            // Use post-frame callback to prevent setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _showCheckIn = false;
                });
                _removeCheckInOverlay();
                _checkPendingPledgeCheckIn();
              }
            });
          },
        ),
      );
      
      // Insert the overlay entry
      overlay.insert(_checkInOverlayEntry!);
    }
  }

  // Remove the check-in overlay
  void _removeCheckInOverlay() {
    if (_checkInOverlayEntry != null) {
      _checkInOverlayEntry!.remove();
      _checkInOverlayEntry = null;
      
      // After overlay is completely removed, check if we should show PMF survey
      // But only if no other UI elements are active
      if (!_showPledgeCheckIn) {
        _checkPMFSurvey();
      }
    }
  }
  
  // Public method to dismiss all overlays (called when tab changes)
  void dismissAllOverlays() {
    if (mounted) {
      // Use post-frame callback to prevent setState during build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showCheckIn = false;
            _showPledgeCheckIn = false;
          });
          _removeCheckInOverlay();
        }
      });
    }
  }

  // Navigation to pledge screen
  void _onPledgePressed() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Pledge', screenName: 'Home Screen');
    if (await _canPledge()) {
      Navigator.of(context).pushReplacement(
        BottomToTopPageRoute(
          child: const PledgeScreen(),
          settings: const RouteSettings(name: '/pledge'),
        ),
      );
    }
  }
  
  // Navigation to calorie tracker screen
  void _onCalorieTrackerPressed() {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Calorie Tracker', screenName: 'Home Screen');
    Navigator.of(context).push(
      BottomToTopPageRoute(
        child: const CalorieTrackerDashboard(),
        settings: const RouteSettings(name: '/calorie_tracker'),
      ),
    );
  }

  // Navigation methods
  void _onPanicButtonPressed() {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Panic Button', screenName: 'Home Screen');
    
    Navigator.of(context).push(
      BottomToTopPageRoute(
        child: const WhatHappeningScreen(),
        settings: const RouteSettings(name: '/panic_what_happening'),
      ),
    );
  }

  // Load the current achievement rosace
  Future<void> _loadAchievementRosace() async {
    try {
      // Initialize achievements service first
      await _achievementsService.initialize();
      
      // Get the highest unlocked achievement
      final highestAchievement = _achievementsService.getHighestUnlockedAchievement();
      
      if (highestAchievement != null && highestAchievement.imageAsset.isNotEmpty) {
        // Update rosace image with the highest unlocked achievement rosace
        if (mounted) {
          setState(() {
            _currentRosaceImage = highestAchievement.imageAsset;
          });
        }
        
        // Save the current rosace image for persistence
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_rosace', highestAchievement.imageAsset);
      } else {
        // Fallback to default rosace if no achievement is unlocked or imageAsset is empty
        if (mounted) {
          setState(() {
            _currentRosaceImage = 'assets/images/rosaces/achievements_seed.json';
          });
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_rosace', 'assets/images/rosaces/achievements_seed.json');
      }
    } catch (e) {
      debugPrint('Error loading achievement rosace: $e');
      // Fallback to default rosace on any error
      if (mounted) {
        setState(() {
          _currentRosaceImage = 'assets/images/rosaces/achievements_seed.json';
        });
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_rosace', 'assets/images/rosaces/achievements_seed.json');
      } catch (prefsError) {
        debugPrint('Error saving default rosace to preferences: $prefsError');
      }
    }
  }

  // Update rosace image when achievements change
  void _updateRosaceFromAchievements() {
    try {
      final highestAchievement = _achievementsService.getHighestUnlockedAchievement();
      
      if (highestAchievement != null && highestAchievement.imageAsset.isNotEmpty) {
        // Only update if we're mounted to prevent setState after dispose
        if (mounted) {
          setState(() {
            _currentRosaceImage = highestAchievement.imageAsset;
          });
          
          // Save the current rosace image for persistence - using a safer approach
          SharedPreferences.getInstance().then((prefs) {
            if (highestAchievement.imageAsset.isNotEmpty) {
              prefs.setString('current_rosace', highestAchievement.imageAsset);
            }
          }).catchError((error) {
            debugPrint('Error saving rosace image: $error');
          });
        }
      } else {
        debugPrint('No valid achievement found or achievement has empty imageAsset');
        // Fallback to default rosace
        if (mounted) {
          setState(() {
            _currentRosaceImage = 'assets/images/rosaces/achievements_seed.json';
          });
          
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('current_rosace', 'assets/images/rosaces/achievements_seed.json');
          }).catchError((error) {
            debugPrint('Error saving default rosace image: $error');
          });
        }
      }
    } catch (e) {
      debugPrint('Error in _updateRosaceFromAchievements: $e');
      // Fallback to default rosace on any error
      if (mounted) {
        setState(() {
          _currentRosaceImage = 'assets/images/rosaces/achievements_seed.json';
        });
      }
    }
  }

  Widget _buildMainOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    // Map of icon colors
    final Map<String, Color> iconColors = {
      AppLocalizations.of(context)!.translate('calorieTracker_title'): const Color(0xFFFFA726), // Orange for calorie tracker
      AppLocalizations.of(context)!.translate('homeScreen_talkToJarvis'): const Color(0xFF4FACFE),
      AppLocalizations.of(context)!.translate('homeScreen_scanYourCraving'): const Color(0xFFE040FB),
      AppLocalizations.of(context)!.translate('homeScreen_rateMyPlate'): const Color(0xFF2196F3),
      AppLocalizations.of(context)!.translate('homeScreen_selfReflection'): const Color(0xFF66BB6A),
      AppLocalizations.of(context)!.translate('homeScreen_chat'): const Color(0xFF4AFE4F),
      AppLocalizations.of(context)!.translate('homeScreen_achievements'): const Color(0xFFE57373),
      AppLocalizations.of(context)!.translate('homeScreen_breathingExercise'): const Color(0xFFFF9800),
      AppLocalizations.of(context)!.translate('homeScreen_addStreakToHome'): const Color(0xFF666666), // Gray for widget option
      AppLocalizations.of(context)!.translate('homeScreen_meditationSession'): const Color(0xFF8E24AA), // Calming purple
      AppLocalizations.of(context)!.translate('homeScreen_podcast'): const Color(0xFF1976D2), // Blue
      AppLocalizations.of(context)!.translate('homeScreen_audio'): const Color(0xFF667eea), // Purple/Blue matching audio player
      AppLocalizations.of(context)!.translate('homeScreen_articles'): const Color(0xFF00BCD4), // Cyan for articles
    };

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColors[label] ?? const Color(0xFF1A1A1A), // Dark fallback color for white background
              size: 26,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                                                  color: HomeScreenColors.primaryText, // Dark text for white background
                  fontSize: 17,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: HomeScreenColors.secondaryText, // Darker gray chevron for better visibility
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinGroupChatDialog() {
    if (!mounted) return; // Added mounted check
    final l10n = AppLocalizations.of(context)!; 
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white, // White background for dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.translate('homeScreen_joinGroupChatTitle'),
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A), // Dark text for white dialog
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'ElzaRound',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.translate('homeScreen_joinGroupChatContent'),
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A), // Dark text for white dialog
                    fontSize: 15,
                    height: 1.4,
                    fontFamily: 'ElzaRound',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  height: 44,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFFE0E0E0), // Light gray border
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            if (!mounted) return; // Added mounted check
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: Text(
                            l10n.translate('common_cancel'),
                            style: TextStyle(
                              color: const Color(0xFFed3272), // Brand pink for button
                              fontSize: 16,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 44,
                        child: VerticalDivider(
                          color: const Color(0xFFE0E0E0), // Light gray border
                          width: 0.5,
                          thickness: 0.5,
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            if (!mounted) return; // Added mounted check
                            Navigator.of(context).pop();
                            // Track button tap with Mixpanel
                            MixpanelService.trackButtonTap('Join Chat', screenName: 'Home Screen');
                            launchUrl(
                              Uri.parse('https://t.me/+SKqx1P0D3iljZGRh'), 
                              mode: LaunchMode.externalApplication
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          child: Text(
                            l10n.translate('homeScreen_joinChat'),
                            style: TextStyle(
                              color: const Color(0xFFfd5d32), // Brand orange for join button
                              fontSize: 16,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
                            ),
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
      },
    );
  }

  // Check for pending notifications that were tapped while app was in background
  Future<void> _checkPendingNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPendingNotification = prefs.getBool('notification_pending_processing') ?? false;
      
      if (hasPendingNotification) {
        final payload = prefs.getString('last_notification_payload');
        final timestamp = prefs.getInt('notification_tap_timestamp');
        
        // Clear the pending flag immediately to prevent multiple processing
        await prefs.setBool('notification_pending_processing', false);
        
        debugPrint('Processing pending notification: $payload from timestamp: $timestamp');
        
        // Process based on payload type
        if (payload != null) {
          if (payload.startsWith('achievement_unlocked_')) {
            // If it's an achievement notification, make sure services are initialized
            await _initializeServices();
            // No need to explicitly navigate since we're already on the home screen
            // Just ensure the achievement rosace is properly updated
            _updateRosaceFromAchievements();
          } else if (payload.startsWith('trigger_standard_paywall_')) {
            // Non-paying user who has seen pre-paywall should see the standard paywall
            debugPrint('Processing standard paywall trigger for non-paying user');
            await _triggerStandardPaywall();
          } else if (payload == 'marketing_offer_x_tap') {
            // Marketing offer notification tapped - trigger x_tap paywall
            debugPrint('Processing marketing offer notification - triggering x_tap paywall');
            await _triggerXTapPaywall();
          }
          // Add other payload type handling as needed
        }
      }
    } catch (e) {
      debugPrint('Error processing pending notification: $e');
    }
  }

  // Function to show instructions for adding the widget
  void _showAddWidgetInstructions() {
    // Track button tap
    MixpanelService.trackButtonTap('Add Streak to Home', screenName: 'Home Screen');
    if (!mounted) return; // Added mounted check
    final l10n = AppLocalizations.of(context)!; 

    showDialog(
      context: context,
      barrierDismissible: true, // Allow closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // White background for dialog // Consistent dark background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            l10n.translate('homeScreen_addWidgetTitle_multi'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for white dialog
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          content: SingleChildScrollView( // Removed const
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('homeScreen_addWidgetInstructions_intro_multi'),
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A), // Dark text for white dialog
                    fontFamily: 'ElzaRound',
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16), // Add spacing after the intro text
                Text(
                  l10n.translate('homeScreen_addWidgetInstructions_note'),
                  style: const TextStyle(color: Color(0xFF666666), fontFamily: 'ElzaRound', fontSize: 14, height: 1.3, fontStyle: FontStyle.italic), // Gray text for white dialog
                ),
                SizedBox(height: 16), // Add spacing before the numbered list
                
                // Show platform-specific instructions
                if (Platform.isIOS) ... [
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step1'),
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3), // Dark text for white dialog
                  ),
                  SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step2'),
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3), // Dark text for white dialog
                  ),
                  SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step3'),
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3), // Dark text for white dialog
                  ),
                  SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step4'),
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3), // Dark text for white dialog
                  ),
                  SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step5_multi'),
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3), // Dark text for white dialog
                  ),
                  SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step6'),
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3), // Dark text for white dialog
                  ),
                ] else if (Platform.isAndroid) ... [
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_android_step1'),
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3), // Dark text for white dialog
                  ),
                  SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_android_step2'),
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3), // Dark text for white dialog
                  ),
                  SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_android_step3'),
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3), // Dark text for white dialog
                  ),
                  SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_android_step4_multi'),
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3), // Dark text for white dialog
                  ),
                  SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_android_step5_resize'),
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3), // Dark text for white dialog
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5), // Light gray background
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFF666666),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.translate('homeScreen_addWidgetInstructions_android_tip_largeText'),
                            style: const TextStyle(
                              color: Color(0xFF666666), 
                              fontFamily: 'ElzaRound', 
                              fontSize: 13, 
                              fontStyle: FontStyle.italic
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Instructions for viewing a friend's shared streak
                SizedBox(height: 24),
                Text(
                  "Viewing a Friend's Shared Streak:", // TODO: Localize this title
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A), // Dark text for white dialog
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Once a friend shares their streak link with you and you've accepted it in the Stoppr app:", // TODO: Localize
                  style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3),
                ),
                SizedBox(height: 8),
                Text(
                  "1. Add the Stoppr widget to your home screen (if you haven't already using the steps above).", // TODO: Localize
                  style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3),
                ),
                SizedBox(height: 8),
                Text(
                  "2. Long-press the Stoppr widget on your home screen.", // TODO: Localize
                  style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3),
                ),
                SizedBox(height: 8),
                Text(
                  "3. Tap 'Edit Widget' (or similar, wording may vary by OS version).", // TODO: Localize
                  style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3),
                ),
                SizedBox(height: 8),
                Text(
                  "4. Select your friend's name from the list to display their streak.", // TODO: Localize
                  style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3),
                ),
                SizedBox(height: 8),
                 Text(
                  "Their streak will then update automatically on your widget!", // TODO: Localize
                  style: const TextStyle(color: Color(0xFF1A1A1A), fontFamily: 'ElzaRound', fontSize: 15, height: 1.3),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white, // White background
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Add padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0), // Rounded corners
                ),
              ),
              onPressed: () {
                if (!mounted) return; // Added mounted check
                Navigator.of(context).pop();
              },
              child: Text(
                l10n.translate('common_gotIt'),
                style: TextStyle(
                  color: Colors.black, // Black text
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Trigger standard paywall for non-paying users who have seen pre-paywall
  Future<void> _triggerStandardPaywall() async {
    try {
      // MIXPANEL_COST_CUT: Removed paywall trigger tracking - Superwall has its own analytics
      
      debugPrint('Attempting to trigger standard_paywall Superwall campaign from notification...');
      
      // Create a handler for paywall presentation
      PaywallPresentationHandler handler = PaywallPresentationHandler();
      
      handler.onPresent((paywallInfo) async {
        String? name = await paywallInfo.name;
        print("Handler (onPresent): ${name ?? 'Unknown'}");
        // MIXPANEL_COST_CUT: Removed paywall presentation - Superwall analytics
      });

      handler.onDismiss((paywallInfo, paywallResult) async {
        String? name = await paywallInfo.name;
        print("Handler (onDismiss): ${name ?? 'Unknown'}");
        
        // MIXPANEL_COST_CUT: Removed paywall dismiss - Superwall analytics
      });

      handler.onError((error) {
        debugPrint('🛑 Superwall error: $error');
        // MIXPANEL_COST_CUT: Removed Superwall error - use Crashlytics
      });

      handler.onSkip((skipReason) async {
        String reasonString = skipReason.toString();
        print("Handler (onSkip): $reasonString");
      });

      // Check if placement is already registered to avoid stacking handlers
      if (_isStandardPaywallRegistered) {
        debugPrint('Standard paywall placement already registered, skipping registration');
        return;
      }

      // Mark as registered immediately to prevent race conditions
      _isStandardPaywallRegistered = true;

      // Use the correct method to register a placement with feature callback and handler
      await Superwall.shared.registerPlacement(
        "INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE", 
        handler: handler,
        feature: () async {
          await PostPurchaseHandler.handlePostPurchase(context);
        }
      );
      
      debugPrint('Triggered Superwall campaign with INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE placement from notification');
    } catch (e) {
      debugPrint('Error triggering Superwall campaign from notification: $e');
    }
  }

  // Trigger x_tap paywall for marketing offer notifications
  Future<void> _triggerXTapPaywall() async {
    try {
      // MIXPANEL_COST_CUT: Removed X tap paywall trigger - Superwall analytics
      
      debugPrint('Attempting to trigger x_tap Superwall campaign from marketing notification...');
      
      // Create a handler for the x_tap paywall presentation
      PaywallPresentationHandler xTapHandler = PaywallPresentationHandler();
      
      xTapHandler.onPresent((xTapPaywallInfo) async {
        String? xTapName = await xTapPaywallInfo.name;
        print("Handler (onPresent - x_tap): ${xTapName ?? 'Unknown'}");
        // MIXPANEL_COST_CUT: Removed X tap paywall presentation - Superwall analytics
      });

      xTapHandler.onDismiss((xTapPaywallInfo, xTapPaywallResult) async {
        String? xTapName = await xTapPaywallInfo.name;
        String resultString = xTapPaywallResult?.toString() ?? 'null';
        
        print("Handler (onDismiss - x_tap): ${xTapName ?? 'Unknown'}");
        debugPrint('🔍 X Tap Paywall dismissed - detailed result: $resultString');
        
        // MIXPANEL_COST_CUT: Removed X tap paywall dismiss - Superwall analytics
        
        // Check if this is a successful purchase result
        if (resultString.contains('PurchasedPaywallResult')) {
          debugPrint('✅ Purchase detected in x_tap handler from marketing notification! Navigating to congratulations screen');
          
          // MIXPANEL_COST_CUT: Removed X tap purchase success - Superwall analytics
          
          // Update Firebase with subscription data using 80% off product ID
          await _updateFirebaseSubscriptionWithProductId(Platform.isIOS ? 'com.stoppr.app.annual80off' : 'com.stoppr.sugar.app.annual80off:annual80off');
          
          // Navigate to congratulations screen
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const CongratulationsScreen1(),
              ),
              (route) => false,
            );
          }
        }
      });

      xTapHandler.onError((error) {
        debugPrint('🛑 X Tap Paywall error: $error');
        // MIXPANEL_COST_CUT: Removed X tap Superwall error - use Crashlytics
      });

      xTapHandler.onSkip((skipReason) async {
        String reasonString = skipReason.toString();
        print("Handler (onSkip - x_tap): $reasonString");
        // MIXPANEL_COST_CUT: Removed X tap paywall skip - Superwall analytics
      });

      // Register and trigger the x_tap placement
      await Superwall.shared.registerPlacement(
        "INSERT_YOUR_X_TAP_PLACEMENT_ID_HERE", 
        handler: xTapHandler,
        feature: () async {
          final defaultProductId = Platform.isIOS 
              ? 'com.stoppr.app.annual80off' 
              : 'com.stoppr.sugar.app.annual80off:annual80off';
          
          await PostPurchaseHandler.handlePostPurchase(
            context,
            defaultProductId: defaultProductId,
          );
        }
      );
      
      debugPrint('Triggered Superwall campaign with x_tap placement from marketing notification');
    } catch (e) {
      debugPrint('Error triggering x_tap Superwall campaign from marketing notification: $e');
      // MIXPANEL_COST_CUT: Removed X tap trigger failed - use Crashlytics for errors
    }
  }

  // Trigger trial gift banner paywall placement
  Future<void> _triggerTrialGiftPaywall() async {
    try {
      PaywallPresentationHandler handler = PaywallPresentationHandler();

      handler.onPresent((paywallInfo) async {
        try {
          String? name = await paywallInfo.name;
          debugPrint('Handler (onPresent - banner_homescreen_trial_gift): ${name ?? 'Unknown'}');
        } catch (_) {}
      });

      handler.onDismiss((paywallInfo, paywallResult) async {
        final resultString = paywallResult?.toString() ?? 'null';
        debugPrint('Trial Gift Paywall dismissed - result: $resultString');
      });

      handler.onError((error) {
        debugPrint('Trial Gift Paywall error: $error');
      });

      handler.onSkip((skipReason) async {
        debugPrint('Trial Gift Paywall skipped: $skipReason');
      });

      await Superwall.shared.registerPlacement(
        "banner_homescreen_trial_gift",
        handler: handler,
        feature: () async {
          final defaultProductId = Platform.isIOS
              ? 'com.stoppr.app.annual80OFF'
              : 'com.stoppr.sugar.app.annual80off:annual80off';
          
          await PostPurchaseHandler.handlePostPurchase(
            context,
            defaultProductId: defaultProductId,
          );
        },
      );
      debugPrint('Triggered Superwall placement banner_homescreen_trial_gift');
    } catch (e) {
      debugPrint('Error triggering banner_homescreen_trial_gift: $e');
    }
  }

  // Helper method to update Firebase subscription data (simplified version for home screen)
  Future<void> _updateFirebaseSubscriptionWithProductId(String productId) async {
    try {
      debugPrint('🔄 Starting _updateFirebaseSubscriptionWithProductId() with productId: $productId');
      
      // Get the current user ID
      final uid = FirebaseAuth.instance.currentUser?.uid;
      
      if (uid == null) {
        debugPrint('❌ User ID is null in _updateFirebaseSubscriptionWithProductId');
        return;
      }
      
      debugPrint('🔍 Current user ID: $uid');
      
      final now = DateTime.now();
      final subscriptionStartDate = now;
      
      // Determine subscription type and expiration date based on product ID
      String subscriptionType;
      DateTime subscriptionExpirationDate;
      
      // Get base product ID if it's in the new format (platformID:baseID)
      String baseProductId = productId;
      if (productId.contains(':')) {
        baseProductId = productId.split(':').last;
        debugPrint('📱 Using base product ID for subscription detection: $baseProductId');
      }
      
      // Customize subscription details based on product ID
      if (baseProductId.toLowerCase().contains('lifetime')) {
        subscriptionType = 'SubscriptionType.paid_standard';
        subscriptionExpirationDate = DateTime(
          now.year + 100, 
          now.month, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting LIFETIME purchase - Expiring in 100 years');
      } else if (baseProductId.toLowerCase().contains('annual80off') || 
          baseProductId.toLowerCase() == 'sugar.app.annual80off') {
        subscriptionType = 'SubscriptionType.paid_gift';
        subscriptionExpirationDate = DateTime(
          now.year + 1, 
          now.month, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting GIFT annual subscription - Expiring in 1 year');
      } else if (baseProductId.toLowerCase().contains('annual') || 
                baseProductId.toLowerCase().contains('trial')) {
        subscriptionType = 'SubscriptionType.paid_standard';
        subscriptionExpirationDate = DateTime(
          now.year + 1, 
          now.month, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting STANDARD annual subscription - Expiring in 1 year');
      } else if (baseProductId.toLowerCase().contains('monthly')) {
        subscriptionType = 'SubscriptionType.paid_standard';
        subscriptionExpirationDate = DateTime(
          now.year, 
          now.month + 1, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting STANDARD monthly subscription - Expiring in 1 month');
      } else if (baseProductId.toLowerCase().contains('weekly')) {
        subscriptionType = 'SubscriptionType.paid_standard';
        subscriptionExpirationDate = now.add(const Duration(days: 7));
        debugPrint('📅 Setting STANDARD weekly subscription - Expiring in 7 days');
      } else {
        subscriptionType = 'SubscriptionType.paid_standard';
        subscriptionExpirationDate = DateTime(
          now.year + 1, 
          now.month, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting DEFAULT subscription for unknown product ID - Expiring in 1 year');
      }
      
      debugPrint('📅 Subscription details - Product: $productId, Type: $subscriptionType, Start: $subscriptionStartDate, Expiration: $subscriptionExpirationDate');
      
      // Update Firestore directly
      Map<String, dynamic> subscriptionData = {
        'subscriptionStatus': subscriptionType,
        'subscriptionProductId': productId,
        'subscriptionStartDate': subscriptionStartDate,
        'subscriptionExpirationDate': subscriptionExpirationDate,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(subscriptionData, SetOptions(merge: true));
      
      debugPrint('📱 Updated Firebase: User granted subscription ($productId, type: $subscriptionType)');
    } catch (e, stack) {
      debugPrint('⚠️ Error updating Firebase: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Widget _buildAchievementAnimation() {
    try {
      return Lottie.asset(
        _currentRosaceImage,
        width: 180,
        height: 180,
        fit: BoxFit.contain,
        animate: true,
        repeat: true,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading Lottie animation: $error');
          return _buildFallbackAnimation();
        },
      );
    } catch (e) {
      debugPrint('Error creating Lottie widget: $e');
      return _buildFallbackAnimation();
    }
  }

  Widget _buildFallbackAnimation() {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.3),
            Colors.purple.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 60,
      ),
    );
  }

  // Check if user is on a trial subscription
  Future<bool> _isUserOnTrial() async {
    try {
      debugPrint('start homescreen _isUserOnTrial');
      final customerInfo = await Purchases.getCustomerInfo();
      
      // Check if any active entitlement is from a trial product
      for (final entitlement in customerInfo.entitlements.active.values) {
        final productId = entitlement.productIdentifier;
        
        // Check if product ID contains "trial" (case insensitive)
        if (productId.toLowerCase().contains('trial')) {
          debugPrint('Trial user detected with product: $productId');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking trial status: $e');
      return false; // Default to non-trial if check fails
    }
  }

  // Trigger standard_paywall_no_trial for trial users
  Future<void> _triggerNoTrialPaywall() async {
    try {
      // MIXPANEL_COST_CUT: Removed no trial paywall trigger - Superwall analytics
      
      debugPrint('🔍 DEBUG: Attempting to trigger standard_paywall_no_trial Superwall campaign from expiration banner...');
      
      // Check subscription status before triggering (guarded by readiness)
      if (NotificationService.isSuperwallReady) {
        final status = await Superwall.shared.getSubscriptionStatus();
        debugPrint('🔍 DEBUG: Current Superwall subscription status: $status');
      } else {
        debugPrint('🔍 DEBUG: Superwall not ready; skipping status check before trigger');
      }
      
      // Create a handler for paywall presentation
      PaywallPresentationHandler handler = PaywallPresentationHandler();
      
      handler.onPresent((paywallInfo) async {
        String? name = await paywallInfo.name;
        print("🔍 DEBUG Handler (onPresent): ${name ?? 'Unknown'}");
        debugPrint("🔍 DEBUG: Paywall IS showing - this means placement is working correctly");
        // MIXPANEL_COST_CUT: Removed no trial paywall presentation - Superwall analytics
      });

      handler.onDismiss((paywallInfo, paywallResult) async {
        String? name = await paywallInfo.name;
        print("🔍 DEBUG Handler (onDismiss): ${name ?? 'Unknown'}");
        debugPrint("🔍 DEBUG: Paywall was dismissed with result: ${paywallResult?.toString()}");
        
        // MIXPANEL_COST_CUT: Removed no trial paywall dismiss - Superwall analytics
      });

      handler.onError((error) {
        debugPrint('🛑 DEBUG Superwall error: $error');
        // MIXPANEL_COST_CUT: Removed no trial Superwall error - use Crashlytics
      });

      handler.onSkip((skipReason) async {
        String reasonString = skipReason.toString();
        print("🔍 DEBUG Handler (onSkip): $reasonString");
        debugPrint("🔍 DEBUG: Paywall was SKIPPED - this is why you see congratulations directly!");
        debugPrint("🔍 DEBUG: Skip reason details: $reasonString");
      });

      // Use the correct method to register a placement with feature callback and handler
      debugPrint('🔍 DEBUG: About to register standard_paywall_no_trial placement...');
      await Superwall.shared.registerPlacement(
        "standard_paywall_no_trial", 
        handler: handler,
        feature: () async {
          await PostPurchaseHandler.handlePostPurchase(context);
        }
      );
      
      debugPrint('🔍 DEBUG: Successfully registered standard_paywall_no_trial placement');
      debugPrint('🔍 DEBUG: If you see congratulations screen immediately, check the onSkip handler logs above');
    } catch (e) {
      debugPrint('🛑 DEBUG: Error triggering Superwall campaign from expiration banner: $e');
    }
  }
}