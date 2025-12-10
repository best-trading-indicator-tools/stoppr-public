import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:ui' as ui;
import '../../../../core/streak/streak_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/navigation/page_transitions.dart';
import 'home_screen.dart';
import 'challenge_28_days_screen.dart';
import 'package:stoppr/features/app/presentation/screens/home_achievements.dart';
import 'profile/user_profile_screen.dart';
import 'main_scaffold.dart';
import 'dart:async';
import '../../../../core/pledges/pledge_service.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/streak/app_open_streak_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeRewireBrainScreen extends StatefulWidget {
  const HomeRewireBrainScreen({super.key});

  @override
  State<HomeRewireBrainScreen> createState() => _HomeRewireBrainScreenState();
}

class _HomeRewireBrainScreenState extends State<HomeRewireBrainScreen>
    with TickerProviderStateMixin {
  final StreakService _streakService = StreakService();
  final PledgeService _pledgeService = PledgeService();
  // Controllers: animate only on toggle
  late AnimationController _ringController;
  late AnimationController _radarController;
  bool _isRingAnimating = false;
  bool _isRadarAnimating = false;
  double _progressPercentage = 0.0;
  int _daysCompleted = 0;
  DateTime? _targetDateTime;
  String _firstName = "";
  double _hoursUntilCheckIn = 0.0;
  List<bool> _weeklyCheckIns = List.generate(7, (_) => false);
  int _selectedIndex = 1;
  Timer? _refreshTimer;
  
  // Ring / Radar toggle
  _ViewMode _viewMode = _ViewMode.ring;
  
  // Listen for streak updates to refresh radar/ring progress dynamically
  StreamSubscription<StreakData>? _streakSubscription;
  
  // Days of the week - NOW USING KEYS
  final List<String> _daysOfWeek = [
    'common_day_monday_short',
    'common_day_tuesday_short',
    'common_day_wednesday_short',
    'common_day_thursday_short',
    'common_day_friday_short',
    'common_day_saturday_short',
    'common_day_sunday_short'
  ];

  @override
  void initState() {
    super.initState();
    

    // Force status bar icons to dark mode for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    
    // Initialize animation controllers (triggered on toggle only)
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    
    // Calculate progress and completion date
    _calculateProgress();
    
    // Live updates from streak service so radar progresses with time
    _streakSubscription = _streakService.streakStream.listen((streak) {
      if (streak.startTime != null) {
        final daysElapsed = DateTime.now().difference(streak.startTime!).inDays;
        if (daysElapsed != _daysCompleted && mounted) {
          setState(() {
            _daysCompleted = daysElapsed;
            _progressPercentage = min(1.0, daysElapsed / 90);
          });
        }
      }
    });
    
    // Load user's first name
    _loadUserData();
    
    // Check for an active pledge first
    _checkForActivePledgeOnStartup();
    
    // Calculate hours directly
    _calculateHoursUntilCheckIn();
    
    // Load weekly check-ins
    _loadWeeklyCheckIns();
    
    // Set up a timer to refresh the hours calculation every minute
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _calculateHoursUntilCheckIn();
      } else {
        timer.cancel();
      }
    });
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
          });
        }
        return; // Exit if we found a name
      }
      
      // Fallback to Firebase Auth if name not in SharedPreferences
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.displayName != null) {
        final displayNameParts = currentUser.displayName!.split(' ');
        if (displayNameParts.isNotEmpty) {
          if (mounted) {
            setState(() {
              _firstName = displayNameParts[0]; // Get first name from display name
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _calculateProgress() async {
    // Get the streak data
    final streakData = _streakService.currentStreak;
    
    if (streakData.startTime != null) {
      final daysElapsed = DateTime.now().difference(streakData.startTime!).inDays;
      final progress = min(1.0, daysElapsed / 90);
      
      // Calculate target date (90 days from start)
      final targetDate = streakData.startTime!.add(const Duration(days: 90));
      
      setState(() {
        _progressPercentage = progress;
        _daysCompleted = daysElapsed;
        _targetDateTime = targetDate;
      });
    } else {
      // If no start time, use current time as fallback
      final now = DateTime.now();
      final targetDate = now.add(const Duration(days: 90));
      
      setState(() {
        _progressPercentage = 0.0;
        _daysCompleted = 0;
        _targetDateTime = targetDate;
      });
    }
  }

  Future<void> _calculateHoursUntilCheckIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // First check for an active pledge (has both timestamps)
      final pledgeTimestamp = prefs.getInt('pledge_timestamp');
      final completionTimestamp = prefs.getInt('pledge_completion_timestamp');
      final now = DateTime.now().millisecondsSinceEpoch;
      
      //debugPrint('Checking pledge timing - now: ${DateTime.now().toString()}');
      //debugPrint('Pledge timestamp: $pledgeTimestamp');
      //debugPrint('Completion timestamp: $completionTimestamp');
      
      // If there's an active pledge, show time until completion
      if (pledgeTimestamp != null && completionTimestamp != null) {
        final remainingMillis = completionTimestamp - now;
        
        if (remainingMillis > 0) {
          // Convert to hours and minutes for display
          final remainingHours = (remainingMillis ~/ (1000 * 60 * 60)).toDouble();
          final remainingMinutes = ((remainingMillis % (1000 * 60 * 60)) ~/ (1000 * 60)).toDouble();
          
          if (mounted) {
            setState(() {
              _hoursUntilCheckIn = remainingHours + (remainingMinutes / 60.0);
            });
          }
          return;
        } else {
          // Pledge period has ended, show ready for check-in
          if (mounted) {
            setState(() {
              _hoursUntilCheckIn = 0.0;
            });
          }
          await prefs.setBool('pending_pledge_check_in', true);
          return;
        }
      }
      
      // If no active pledge, check if we're in cooldown after a recent check-in
      final lastCheckInTimestamp = prefs.getInt('last_pledge_check_in_timestamp');
      if (lastCheckInTimestamp != null) {
        final nextPledgeTime = lastCheckInTimestamp + (12 * 60 * 60 * 1000); // 12 hours cooldown
        final cooldownRemaining = nextPledgeTime - now;
        
        if (cooldownRemaining > 0) {
          // Still in cooldown period
          final remainingHours = (cooldownRemaining ~/ (1000 * 60 * 60)).toDouble();
          final remainingMinutes = ((cooldownRemaining % (1000 * 60 * 60)) ~/ (1000 * 60)).toDouble();
          
          if (mounted) {
            setState(() {
              _hoursUntilCheckIn = remainingHours + (remainingMinutes / 60.0);
            });
          }
          return;
        }
      }
      
      // If no active pledge and not in cooldown, show ready for check-in
      if (mounted) {
        setState(() {
          _hoursUntilCheckIn = 0.0;
        });
      }
    } catch (e) {
      debugPrint('Error calculating hours until check-in: $e');
      if (mounted) {
        setState(() {
          _hoursUntilCheckIn = 0.0;
        });
      }
    }
  }
  
  Future<bool> _checkForActivePledge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // First check for direct pledge timestamps
      final pledgeTimestamp = prefs.getInt('pledge_timestamp');
      final completionTimestamp = prefs.getInt('pledge_completion_timestamp');
      
      if (pledgeTimestamp != null && completionTimestamp != null) {
        // If we have both timestamps, there's an active pledge
        debugPrint('Found active pledge with timestamps');
        return true;
      }
      
      // If no direct timestamps, check all pledge-related keys
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('pledge_') && !key.contains('completed')) {
          debugPrint('Found potential active pledge key: $key');
        }
      }
      
      // Check for pending check-in flag
      final pendingCheckIn = prefs.getBool('pending_pledge_check_in') ?? false;
      if (pendingCheckIn) {
        debugPrint('Found pending pledge check-in flag');
        return true;
      }
      
      // Check today's date for a pledge
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final todayPledgeKey = 'pledge_started_$todayString';
      final todayPledge = prefs.getBool(todayPledgeKey) ?? false;
      
      debugPrint('Checking for today\'s pledge: $todayString, key: $todayPledgeKey, exists: $todayPledge');
      
      return todayPledge;
    } catch (e) {
      debugPrint('Error checking for active pledge: $e');
      return false;
    }
  }
  
  // Update the check for active pledges on startup
  Future<void> _checkForActivePledgeOnStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Print all keys for debugging
      final allKeys = prefs.getKeys();
      debugPrint('All SharedPreferences keys: $allKeys');
      
      // Directly check for the pledge_completion_timestamp
      final completionTimestamp = prefs.getInt('pledge_completion_timestamp');
      if (completionTimestamp != null) {
        final completionDate = DateTime.fromMillisecondsSinceEpoch(completionTimestamp);
        debugPrint('Found pledge completion timestamp: $completionTimestamp, date: $completionDate');
        
        // Check if we need to show the pending check-in
        final now = DateTime.now().millisecondsSinceEpoch;
        if (completionTimestamp <= now) {
          // Set the pending check-in flag to ensure the user is prompted
          await prefs.setBool('pending_pledge_check_in', true);
        }
      }
      
      // Directly check for pledge_timestamp
      final pledgeTimestamp = prefs.getInt('pledge_timestamp');
      if (pledgeTimestamp != null) {
        final pledgeDate = DateTime.fromMillisecondsSinceEpoch(pledgeTimestamp);
        debugPrint('Found pledge timestamp: $pledgeTimestamp, date: $pledgeDate');
      }
      
      // Calculate hours until check-in
      _calculateHoursUntilCheckIn();
      
      // Reload weekly check-ins to show all completed days
      _loadWeeklyCheckIns();
    } catch (e) {
      debugPrint('Error checking for active pledge on startup: $e');
    }
  }
  
  Future<void> _loadWeeklyCheckIns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Initialize weeklyCheckIns with all false values for 7 days
      List<bool> weeklyCheckIns = List.generate(7, (_) => false);
      
      // Get the current date and determine the start of the current week (Monday)
      final now = DateTime.now();
      
      // Calculate days since Monday (0 = Monday, 1 = Tuesday, etc.)
      final int daysSinceMonday = now.weekday - 1;
      
      // Get the date of this week's Monday
      final monday = now.subtract(Duration(days: daysSinceMonday));
      
      // Check each day of the current week
      for (int i = 0; i < 7; i++) {
        // Get the date for this day of the week
        final currentDate = monday.add(Duration(days: i));
        final dateString = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
        
        // Check if there was a successful pledge completion for this day
        final pledgeCompletedKey = 'pledge_completed_$dateString';
        final pledgeSuccessfulKey = 'pledge_successful_$dateString';
        
        // A day is marked as completed if:
        // 1. The pledge was completed (checked in) AND
        // 2. The pledge was marked as successful during check-in
        final pledgeCompleted = prefs.getBool(pledgeCompletedKey) ?? false;
        final pledgeSuccessful = prefs.getBool(pledgeSuccessfulKey) ?? false;
        
        debugPrint('Checking $dateString: Completed=$pledgeCompleted, Successful=$pledgeSuccessful');
        
        if (pledgeCompleted && pledgeSuccessful) {
          weeklyCheckIns[i] = true;
        }
      }
      
      if (mounted) {
        setState(() {
          _weeklyCheckIns = weeklyCheckIns;
        });
      }
      
      debugPrint('Final weekly check-ins: $_weeklyCheckIns');
    } catch (e) {
      debugPrint('Error loading weekly check-ins: $e');
      if (mounted) {
        setState(() {
          _weeklyCheckIns = List.generate(7, (_) => false);
        });
      }
    }
  }

  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Rewire Brain Screen');
    
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
  void dispose() {
    _ringController.dispose();
    _radarController.dispose();
    _refreshTimer?.cancel();
    _streakSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayPercentage = (_progressPercentage * 100).round();
    final l10n = AppLocalizations.of(context)!;
    String formattedDisplayTargetDate = _targetDateTime != null
        ? DateFormat('MMMM d, yyyy', l10n.locale.languageCode).format(_targetDateTime!)
        : "...";

    if (formattedDisplayTargetDate != "..." && formattedDisplayTargetDate.isNotEmpty) {
      formattedDisplayTargetDate = formattedDisplayTargetDate[0].toUpperCase() + formattedDisplayTargetDate.substring(1);
    }
    
    // Force dark status bar icons for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.of(context).pushReplacement(
              TopToBottomPageRoute(
                child: const MainScaffold(initialIndex: 0),
                settings: const RouteSettings(name: '/home'),
              ),
            ),
          ),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            statusBarColor: Colors.transparent,
          ),
          title: Text(
            l10n.translate('homeRewire_appBarTitle'),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
              fontSize: 22,
              color: Color(0xFF1A1A1A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // Ring / Radar segmented toggle
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFCCCCCC)),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ToggleChip(
                          label: l10n.translate('homeRewire_toggle_ring'),
                          selected: _viewMode == _ViewMode.ring,
                          onTap: () {
                            if (_viewMode != _ViewMode.ring && mounted) {
                              setState(() => _viewMode = _ViewMode.ring);
                              // Start ring animation on toggle
                              _radarController.stop();
                              _radarController.reset();
                              _ringController
                                ..stop()
                                ..reset();
                              setState(() => _isRingAnimating = true);
                              _ringController.forward().whenComplete(() {
                                if (mounted) {
                                  setState(() => _isRingAnimating = false);
                                }
                              });
                            }
                          },
                        ),
                        _ToggleChip(
                          label: l10n.translate('homeRewire_toggle_radar'),
                          selected: _viewMode == _ViewMode.radar,
                          onTap: () {
                            if (_viewMode != _ViewMode.radar && mounted) {
                              setState(() => _viewMode = _ViewMode.radar);
                              // Start radar animation on toggle
                              _ringController.stop();
                              _ringController.reset();
                              _radarController
                                ..stop()
                                ..reset();
                              setState(() => _isRadarAnimating = true);
                              _radarController.forward().whenComplete(() {
                                if (mounted) {
                                  setState(() => _isRadarAnimating = false);
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Help & Info icon
            IconButton(
              icon: const Icon(
                Icons.help_outline,
                color: Color(0xFF1A1A1A),
                size: 28,
              ),
              onPressed: _openMedicalInfo,
              tooltip: l10n.translate('pledgeScreen_tooltip_help'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  // User display name
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _firstName.isEmpty ? "" : _firstName,
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w400,
                        fontSize: 24,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Progress area: Ring or Radar
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: _viewMode == _ViewMode.ring
                          ? SizedBox(
                              key: const ValueKey('ring'),
                              height: 280,
                              width: 280,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _ringController,
                                    builder: (context, child) {
                                      final animationFactor =
                                          _isRingAnimating ? _ringController.value : 1.0;
                                      return CustomPaint(
                                        size: const Size(280, 280),
                                        painter: CircleProgressPainter(
                                          progress: animationFactor * _progressPercentage,
                                        ),
                                      );
                                    },
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        l10n.translate('homeRewire_progressCircle_label'),
                                        style: const TextStyle(
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Color(0xFF1A1A1A),
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      AnimatedBuilder(
                                        animation: _ringController,
                                        builder: (context, child) {
                                          final animationFactor =
                                              _isRingAnimating ? _ringController.value : 1.0;
                                          final animatedPercentage =
                                              (animationFactor * _progressPercentage * 100).round();
                                          return Text(
                                            '${animatedPercentage}%',
                                            style: const TextStyle(
                                              fontFamily: 'ElzaRound',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 54,
                                              color: Color(0xFF1A1A1A),
                                            ),
                                          );
                                        },
                                      ),
                                      Text(
                                        '$_daysCompleted${l10n.translate('homeRewire_progressCircle_streakSuffix')}',
                                        style: const TextStyle(
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                          color: Color(0xFF666666),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                // Slightly reduce to add visual margins left/right
                                final side = (MediaQuery.of(context).size.width - 40) * 0.9;
                                return SizedBox(
                                  key: const ValueKey('radar'),
                                  height: side,
                                  width: side,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _radarController,
                                        builder: (context, child) {
                                          final fillFactor =
                                              _isRadarAnimating ? _radarController.value : 1.0;
                                          return CustomPaint(
                                            size: Size(side, side),
                                            painter: _RadarChartPainter(
                                              values: List<double>.filled(6, _progressPercentage),
                                              color: _getRadarColorForDays(_daysCompleted),
                                              labels: _radarDomainKeys
                                                  .map((k) => l10n.translate(k))
                                                  .toList(),
                                              fillFactor: fillFactor,
                                            ),
                                          );
                                        },
                                      ),
                                      Text(
                                        '${(_progressPercentage * 100).round()}%',
                                        style: const TextStyle(
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 28,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Motivational text
                  Text(
                    l10n.translate('homeRewire_motivationalText'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      color: Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // STOPPR logo - Using brand gradient
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          colors: [
                            Color(0xFFed3272), // Brand pink
                            Color(0xFFfd5d32), // Brand orange
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds);
                      },
                      child: const Text(
                        "STOPPR",
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 42,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // You're on track to:
                  Text(
                    l10n.translate('homeRewire_onTrackToLabel'),
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w400,
                      fontSize: 18,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Quit Sugar date CTA (brand gradient)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      l10n
                          .translate('homeRewire_quitSugarByDate')
                          .replaceAll('{date}', formattedDisplayTargetDate),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Helper text under CTA
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      l10n
                          .translate('homeRewire_firstDaysHard')
                          .replaceAll('—', ' ')
                          .replaceAll('–', ' '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Color(0xFF666666),
                        height: 1.35,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress chart using app-open streak
                  _StreakProgressSection(),
                  
                  const SizedBox(height: 30),
                  
                  // Benefits section in a single container with dividers
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFCCCCCC),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Improved Confidence
                        _buildBenefitItemWithProgressBar(
                          emoji: "💪",
                          title: l10n.translate('homeRewire_benefit_confidence_title'),
                          description: l10n.translate('homeRewire_benefit_confidence_description'),
                          progressPercentage: _calculateBenefitProgress(45, 75), // Medium timeline benefit
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Increased Self-Esteem
                        _buildBenefitItemWithProgressBar(
                          emoji: "⬆️",
                          title: l10n.translate('homeRewire_benefit_esteem_title'),
                          description: l10n.translate('homeRewire_benefit_esteem_description'),
                          progressPercentage: _calculateBenefitProgress(60, 90), // Longer timeline benefit
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Mental Clarity
                        _buildBenefitItemWithProgressBar(
                          emoji: "🧠",
                          title: l10n.translate('homeRewire_benefit_clarity_title'),
                          description: l10n.translate('homeRewire_benefit_clarity_description'),
                          progressPercentage: _calculateBenefitProgress(30, 60), // Faster timeline benefit
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Increased Energy
                        _buildBenefitItemWithProgressBar(
                          emoji: "⚡",
                          title: l10n.translate('homeRewire_benefit_energy_title'),
                          description: l10n.translate('homeRewire_benefit_energy_description'),
                          progressPercentage: _calculateBenefitProgress(30, 45), // Fast timeline benefit
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Healthier Thoughts
                        _buildBenefitItemWithProgressBar(
                          emoji: "💭",
                          title: l10n.translate('homeRewire_benefit_thoughts_title'),
                          description: l10n.translate('homeRewire_benefit_thoughts_description'),
                          progressPercentage: _calculateBenefitProgress(50, 85), // Medium-long timeline benefit
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // NEW SECTION: Hours until check-in
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFCCCCCC),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Hours till check-in
                        Text(
                          _hoursUntilCheckIn > 0.0 
                              ? l10n.translate('homeScreen_canPledgeAgainIn').replaceAll('{time}', (_hoursUntilCheckIn >= 1.0 
                                  ? "${_hoursUntilCheckIn.floor()}h${((_hoursUntilCheckIn % 1) * 60).round()}m" 
                                  : "${(_hoursUntilCheckIn * 60).round()}m"))
                              : l10n.translate('homeRewire_pledge_readyForCheckIn'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w600,
                            fontSize: 19,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Weekly tracker
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(7, (index) {
                            return Column(
                              children: [
                                // Day of week
                                Text(
                                  l10n.translate(_daysOfWeek[index]),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                
                                const SizedBox(height: 10),
                                
                                // Circle indicator
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _weeklyCheckIns[index] 
                                        ? const Color(0xFFed3272) 
                                        : Colors.white,
                                    border: Border.all(
                                      color: const Color(0xFFE0E0E0),
                                      width: 1,
                                    ),
                                  ),
                                  child: _weeklyCheckIns[index]
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 24,
                                        )
                                      : null,
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // NEW SECTION: Achievements
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        BottomToTopPageRoute(
                          child: const HomeAchievementsScreen(),
                          settings: const RouteSettings(name: '/achievements'),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFCCCCCC),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Trophy icon
                          const Icon(
                            Icons.emoji_events,
                            color: Color(0xFF1A1A1A),
                            size: 28,
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Title
                          Text(
                            l10n.translate('achievementsScreen_title'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Chevron icon
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF1A1A1A),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
        extendBody: true,
      ),
    );
  }
  
  Widget _buildBenefitItemWithDivider({
    required String emoji,
    required String title,
    required String description,
    required bool showDivider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emoji,
              style: const TextStyle(
                fontSize: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      color: Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Show divider if not the last item
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Container(
              height: 5, // Increased from 2 to 4
              color: const Color(0xFFE0E0E0).withOpacity(0.3), // Light gray with opacity
              width: double.infinity,
            ),
          ),
      ],
    );
  }
  
  // New method to build benefit item with progress bar
  Widget _buildBenefitItemWithProgressBar({
    required String emoji,
    required String title,
    required String description,
    required double progressPercentage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emoji,
              style: const TextStyle(
                fontSize: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      color: Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 6,
                      width: double.infinity,
                      color: const Color(0xFFE0E0E0), // Light background
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progressPercentage,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFed3272), // Brand pink
                                Color(0xFFfd5d32), // Brand orange
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Calculate the benefit progress based on expected timeline and current streak
  double _calculateBenefitProgress(int minDays, int maxDays) {
    // If no streak, show minimal progress
    if (_daysCompleted <= 0) return 0.05;
    
    // If days completed is less than minimum days, show progress proportional to minimum
    if (_daysCompleted < minDays) {
      return 0.05 + (0.3 * _daysCompleted / minDays);
    }
    
    // If days completed is between min and max, show progress from 35% to 100%
    if (_daysCompleted >= minDays && _daysCompleted <= maxDays) {
      return 0.35 + (0.65 * (_daysCompleted - minDays) / (maxDays - minDays));
    }
    
    // If days completed is greater than maximum, show full progress
    return 1.0;
  }

}

// Section widget that reads streak data and shows chart with labels
class _StreakProgressSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = AppOpenStreakService().currentStreak;
    final streakStart = data.streakStartDate ??
        DateTime.now().subtract(const Duration(days: 1));
    final today = DateTime.now();
    final days = data.consecutiveDays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          FutureBuilder<DateTime?>(
            future: _fetchFirstPaidDate(),
            builder: (context, snapshot) {
              final first = snapshot.data ?? streakStart;
              return Container(
            height: 170,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCCCCCC), width: 2),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ProgressChartPainter(
                      firstDate: first,
                      today: today,
                      consecutiveDays: days,
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 8,
                  child: Text(
                    _formatDate(first, l10n),
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      color: Color(0xFF666666),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 8,
                  child: Text(
                    l10n.translate('progressChart_today'),
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      color: Color(0xFF666666),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressChartPainter extends CustomPainter {
  final DateTime firstDate;
  final DateTime today;
  final int consecutiveDays;

  _ProgressChartPainter({
    required this.firstDate,
    required this.today,
    required this.consecutiveDays,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1A1A1A).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const gridCount = 5;
    for (int i = 0; i <= gridCount; i++) {
      final x = size.width * (i / gridCount);
      canvas.drawLine(Offset(x, 12), Offset(x, size.height - 28), gridPaint);
    }

    // Line path (brand gradient)
    final path = Path();
    final startY = size.height * 0.75;
    final ratio = (consecutiveDays / 30).clamp(0.0, 1.0);
    final endY = size.height * (0.75 - 0.55 * ratio);
    path.moveTo(12, startY);
    path.cubicTo(
      size.width * 0.3,
      startY - 12,
      size.width * 0.6,
      (startY + endY) / 2,
      size.width - 12,
      endY,
    );

    final shader = const LinearGradient(
      colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatDate(DateTime date, AppLocalizations l10n) {
  try {
    return DateFormat('MMM d, yyyy', l10n.locale.languageCode).format(date);
  } catch (_) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}

Future<DateTime?> _fetchFirstPaidDate() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return null;
    final Timestamp? conversionTs = data['trialToSubscriptionConversionDate'] as Timestamp?;
    if (conversionTs != null) return conversionTs.toDate();
    final Timestamp? startTs = data['subscriptionStartDate'] as Timestamp?;
    if (startTs != null) return startTs.toDate();
    // Fallback to locally persisted first-use date
    return await _getOrInitFirstUseDate();
  } catch (_) {
    // On any error, still try local fallback
    return await _getOrInitFirstUseDate();
  }
}

// Reads first app use date from SharedPreferences; initializes it if missing.
Future<DateTime> _getOrInitFirstUseDate() async {
  const key = 'first_app_use_date_iso';
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(key);
  if (existing != null && existing.isNotEmpty) {
    final parsed = DateTime.tryParse(existing);
    if (parsed != null) return parsed;
  }
  final now = DateTime.now();
  await prefs.setString(key, now.toIso8601String());
  return now;
}

// View switching enum
enum _ViewMode { ring, radar }

// Small segmented chip for the toggle
class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFed3272) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: selected ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}

// Radar domain keys (localized via l10n)
const List<String> _radarDomainKeys = [
  'weeksProgression_domain_overall',
  'weeksProgression_domain_focus',
  'weeksProgression_domain_confidence',
  'weeksProgression_domain_energy',
  'weeksProgression_domain_selfControl',
  'weeksProgression_domain_mood',
];

// Painter adapted from onboarding weeks progression to avoid overflow
class _RadarChartPainter extends CustomPainter {
  final List<double> values; // 0..1 for six axes
  final Color color;
  final List<String> labels;
  final double fillFactor; // 0..1 expansion factor for animated toggle

  _RadarChartPainter({
    required this.values,
    required this.color,
    required this.labels,
    this.fillFactor = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 32;

    _drawGrid(canvas, center, radius);
    _drawValues(canvas, center, radius);
    _drawLabels(canvas, center, radius + 24, size);
  }

  void _drawGrid(Canvas canvas, Offset center, double radius) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1A1A1A).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final r = radius * (i / 3);
      _drawPolygon(canvas, center, r, gridPaint);
    }

    for (int i = 0; i < 6; i++) {
      final angle = (i * 2 * pi / 6) - pi / 2;
      final end = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
      canvas.drawLine(center, end, gridPaint);
    }
  }

  void _drawValues(Canvas canvas, Offset center, double radius) {
    final fill = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 2 * pi / 6) - pi / 2;
      final r = radius * (values[i].clamp(0.0, 1.0) * fillFactor).clamp(0.0, 1.0);
      final p = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawLabels(Canvas canvas, Offset center, double radius, Size size) {
    for (int i = 0; i < 6; i++) {
      final angle = (i * 2 * pi / 6) - pi / 2;
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      
      // Use smaller font size for longer labels to prevent overflow
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'ElzaRound',
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
      );
      textPainter.layout(maxWidth: size.width * 0.25);
      
      // Adjust text position based on angle to prevent overlap and clipping
      Offset textOffset = point;
      if (angle > pi / 4 && angle < 3 * pi / 4) {
        // Bottom labels
        textOffset = Offset(
          point.dx - textPainter.width / 2,
          point.dy + 8,
        );
        // Ensure doesn't go beyond bottom edge
        if (textOffset.dy + textPainter.height > size.height - 5) {
          textOffset = Offset(
            textOffset.dx,
            size.height - textPainter.height - 5,
          );
        }
      } else if (angle > -3 * pi / 4 && angle < -pi / 4) {
        // Top labels
        textOffset = Offset(
          point.dx - textPainter.width / 2,
          point.dy - textPainter.height - 8,
        );
        // Ensure doesn't go beyond top edge
        if (textOffset.dy < 5) {
          textOffset = Offset(textOffset.dx, 5);
        }
      } else if (angle >= -pi / 4 && angle <= pi / 4) {
        // Right labels - ensure they don't get clipped
        double rightOffset = point.dx + 15;
        // Prevent clipping by ensuring text doesn't go beyond right edge
        rightOffset = min(rightOffset, size.width - textPainter.width - 5);
        textOffset = Offset(rightOffset, point.dy - textPainter.height / 2);
        // Ensure doesn't go beyond vertical edges
        if (textOffset.dy < 5) {
          textOffset = Offset(textOffset.dx, 5);
        } else if (textOffset.dy + textPainter.height > size.height - 5) {
          textOffset = Offset(
            textOffset.dx,
            size.height - textPainter.height - 5,
          );
        }
      } else {
        // Left labels - ensure they don't get clipped
        double leftOffset = point.dx - textPainter.width - 15;
        // Prevent clipping by ensuring minimum distance from left edge
        leftOffset = max(leftOffset, 5);
        textOffset = Offset(leftOffset, point.dy - textPainter.height / 2);
        // Ensure doesn't go beyond vertical edges
        if (textOffset.dy < 5) {
          textOffset = Offset(textOffset.dx, 5);
        } else if (textOffset.dy + textPainter.height > size.height - 5) {
          textOffset = Offset(
            textOffset.dx,
            size.height - textPainter.height - 5,
          );
        }
      }
      
      textPainter.paint(canvas, textOffset);
    }
  }

  void _drawPolygon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 2 * pi / 6) - pi / 2;
      final p = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Map streak days to onboarding radar progression values
List<double> _getRadarValuesForStep(int stepIndex) {
  // Same order as _radarDomainKeys
  switch (stepIndex) {
    case 0: // Week 1
      return const [0.35, 0.45, 0.40, 0.42, 0.36, 0.54];
    case 1: // Week 5
      return const [0.6, 0.65, 0.58, 0.62, 0.55, 0.68];
    case 2: // Week 10
      return const [0.82, 0.78, 0.85, 0.75, 0.80, 0.83];
    default: // Week 13
      return const [0.97, 0.98, 0.96, 0.96, 0.97, 0.97];
  }
}

extension _RadarValues on _HomeRewireBrainScreenState {
  // Color mapping matches onboarding weeks progression colors
  Color _getRadarColorForDays(int days) {
    if (days < 28) return const Color(0xFFE53E3E); // Red (week 1)
    if (days < 63) return const Color(0xFFED8936); // Orange (week 5)
    if (days < 84) return const Color(0xFF6B46C1); // Purple (week 10)
    return const Color(0xFF38A169); // Green (week 13)
  }

  // Linear interpolation across steps for smooth, day-based progression
  List<double> _getInterpolatedRadarValues(int days) {
    // Step thresholds corresponding roughly to weeks 1, 5, 10, 13
    const t0 = 0; // start
    const t1 = 28; // ~week 4/5
    const t2 = 63; // ~week 9/10
    const t3 = 84; // ~week 12/13

    if (days <= t0) return _getRadarValuesForStep(0);
    if (days >= t3) return _getRadarValuesForStep(3);

    List<double> a;
    List<double> b;
    double t; // 0..1 between a and b
    if (days < t1) {
      a = _getRadarValuesForStep(0);
      b = _getRadarValuesForStep(1);
      t = (days - t0) / (t1 - t0);
    } else if (days < t2) {
      a = _getRadarValuesForStep(1);
      b = _getRadarValuesForStep(2);
      t = (days - t1) / (t2 - t1);
    } else {
      a = _getRadarValuesForStep(2);
      b = _getRadarValuesForStep(3);
      t = (days - t2) / (t3 - t2);
    }

    return List<double>.generate(6, (i) => a[i] + (b[i] - a[i]) * t);
  }
}

class CircleProgressPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  
  CircleProgressPainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    
    // Draw background track circle
    final trackPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0;
      
    canvas.drawCircle(center, radius - 6, trackPaint);
    
    // Always show at least 2% progress to give visual feedback even at 0%
    final minProgress = 0.02; // 2% minimum
    final displayProgress = max(progress, minProgress);
    
    // Draw progress arc
    final progressPaint = Paint()
      ..color = const Color(0xFFed3272) // Brand pink progress
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round;
    
    final progressAngle = 2 * pi * displayProgress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -pi / 2, // Start from top
      progressAngle,
      false,
      progressPaint,
    );
    
    // Draw green dot at the end of the progress arc only if progress is > 2%
    if (progress > 0.02) {
      final dotPosition = Offset(
        center.dx + (radius - 6) * cos(-pi/2 + progressAngle),
        center.dy + (radius - 6) * sin(-pi/2 + progressAngle),
      );
      
      final dotPaint = Paint()
        ..color = const Color(0xFFed3272)
        ..style = PaintingStyle.fill;
        
      canvas.drawCircle(dotPosition, 8, dotPaint);
    }
  }
  
  @override
  bool shouldRepaint(CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
} 