import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../../data/models/food_log.dart';
import '../../data/models/daily_summary.dart';
import '../../data/models/nutrition_goals.dart';
import '../../data/models/workout_log.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../../../../core/services/local_food_image_service.dart';
import '../../../../core/utils/text_sanitizer.dart';
import 'package:stoppr/core/services/in_app_review_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'food_scanner_screen.dart';
import 'daily_breakdown_screen.dart';
import 'calorie_streak_screen.dart';
import 'calorie_progress_screen.dart';
import 'food_nutrition_edit_screen.dart';
import '../widgets/activity_popup.dart';
import 'package:stoppr/features/nutrition/presentation/screens/nutrition_goals_screen.dart';
import '../../../app/presentation/screens/main_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'log_exercice/run_exercise_setup_screen.dart';
import 'log_exercice/weight_lifting_setup_screen.dart';
import 'log_exercice/manual_exercise_setup_screen.dart';
import 'package:stoppr/features/recipes/presentation/screens/recipes_list_screen.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/core/accountability/accountability_widget_service.dart';

class CalorieTrackerDashboard extends StatefulWidget {
  const CalorieTrackerDashboard({super.key, this.initialDate});
  
  final DateTime? initialDate;

  @override
  State<CalorieTrackerDashboard> createState() => _CalorieTrackerDashboardState();
}

class _CalorieTrackerDashboardState extends State<CalorieTrackerDashboard> {
  final _nutritionRepository = NutritionRepository();
  final _imageService = LocalFoodImageService();
  final InAppReviewService _inAppReviewService = InAppReviewService();
  late DateTime _selectedDate;
  bool _promptedForGoals = false;
  final PageController _macroPageController = PageController();
  int _macroPageIndex = 0;
  bool _hasPromptedGoalsEver = false; // persisted once-only redirect flag
  bool _prefsLoaded = false; // ensure we don't redirect until prefs are loaded
  
  // Day selector with PageView - initialize immediately
  bool _isInitialized = false;
  PageController? _weekPageController;
  
  Stream<DailySummary?>? _dailySummaryStream;
  Stream<NutritionGoals?>? _nutritionGoalsStream;
  StreamSubscription<List<FoodLog>>? _foodLogsSubscription;
  Timer? _progressTimer;
  final Map<String, int> _progressByLogId = {}; // 5..95 while analyzing
  // Live totals from logs for authoritative UI
  double _logsTotalCalories = 0;
  double _logsTotalProtein = 0;
  double _logsTotalCarbs = 0;
  double _logsTotalFat = 0;
  bool _hasCompletedLogs = false; // whether the selected day has any finished logs
  int _previousLogCount = 0; // Track log count to detect new additions
  bool _waterUseOz = false; // user preference for ounces vs metric
  double? _waterServingMl; // persisted serving size per glass
  double? _localWaterOverrideMl; // optimistic UI override for water intake
  
  // Refined sugar tracking
  final StreakService _streakService = StreakService();
  final Set<String> _processedFoodLogIds = {}; // Track which logs we've already shown popup for
  FoodLog? _lastTriggeringFoodLog; // Track which log triggered the popup
  double _sugarGoalThreshold = 50.0; // User's refined sugar limit (defaults to 50g)
  bool _sugarPopupShownForToday = false; // Guard to show popup once per day (persisted in SharedPreferences)
  double _previousTotalSugar = 0.0; // Track previous total sugar to detect edits
  bool _isShowingPopup = false; // Prevent multiple popups in same cycle
  bool _isPopupDecisionInFlight = false; // Debounce popup decision to avoid double show


  @override
  void initState() {
    super.initState();
    
    // Always default to today when loading the dashboard, unless explicitly specified
    _selectedDate = widget.initialDate ?? DateTime.now();
    
    debugPrint('🏠 Dashboard initState - selectedDate: ${_selectedDate.toIso8601String().substring(0, 10)}');
    debugPrint('   Initial date param: ${widget.initialDate?.toIso8601String().substring(0, 10) ?? 'null (using today)'}');
    
    // Set up days list immediately and synchronously
    _initializeDaysSelector();
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    MixpanelService.trackPageView('Calorie Tracker Dashboard');
    _loadGoalsPromptFlag();
    _initializeStreams();
  }

  Future<void> _loadGoalsPromptFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('nutrition_goals_prompted_ever') ?? false;
      final useOz = prefs.getBool('water_unit_oz') ?? false;
      final savedServing = prefs.getDouble('water_serving_ml');
      
      // Load sugar popup flag - check if already shown today
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final lastShownDate = prefs.getString('sugar_popup_last_shown_date') ?? '';
      final popupAlreadyShownToday = (lastShownDate == today);
      
      // Don't persist selected date - always default to today for fresh focus
      
      if (mounted) {
        setState(() {
          _hasPromptedGoalsEver = seen;
          _prefsLoaded = true;
          _waterUseOz = useOz;
          _waterServingMl = savedServing ?? (useOz ? 236.588 : 250.0);
          _sugarPopupShownForToday = popupAlreadyShownToday;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _prefsLoaded = true);
    }
  }

  void _initializeStreams() {
    // Always use Firestore for both debug and production
    _dailySummaryStream = _nutritionRepository.getDailySummary(_selectedDate);
    _nutritionGoalsStream = _nutritionRepository.getNutritionGoals();
    
    // Reset log count when switching dates to allow fresh detection of new logs
    _previousLogCount = 0;
    
    _foodLogsSubscription?.cancel();
    
    _foodLogsSubscription = _nutritionRepository.getFoodLogsForDate(_selectedDate).listen((logs) async {
        if (mounted) {
          final bool prevHasCompletedLogs = _hasCompletedLogs;
          final now = DateTime.now();
          // Detect analyzing logs: calories==0 AND created by scanner (has image or analyzing label)
          final analyzing = logs.where(_isAnalyzingLog).toList();
          final hasAnalyzingLogs = analyzing.isNotEmpty;
          
          if (hasAnalyzingLogs) {
            debugPrint('🔍 DASHBOARD: Found ${analyzing.length} logs being analyzed');
            for (final log in analyzing) {
              final ageSeconds = now.difference(log.loggedAt).inSeconds;
              debugPrint('   - ${log.foodName} (ID: ${log.id}, age: ${ageSeconds}s, calories: ${log.nutritionData.calories})');
            }
          }
          
          // Track local progress per analyzing log - start immediately at 10%
          for (final log in analyzing) {
            final id = log.id ?? '${log.loggedAt.millisecondsSinceEpoch}';
            _progressByLogId.putIfAbsent(id, () => 10); // Start at 10% instead of 5%
          }
          // Remove finished logs from local tracking
          final currentIds = analyzing.map((l) => l.id ?? '${l.loggedAt.millisecondsSinceEpoch}').toSet();
          _progressByLogId.removeWhere((id, _) => !currentIds.contains(id));
          
          if (hasAnalyzingLogs && _progressTimer == null) {
            // Start progress timer immediately when we have analyzing logs
            debugPrint('⏱️ DASHBOARD: Starting progress timer for ${analyzing.length} analyzing logs');
            _progressTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) { // Faster updates
              if (!mounted) return;
              // Bump each analyzing progress deterministically up to 95%
              bool changed = false;
              _progressByLogId.updateAll((key, value) {
                if (value < 95) {
                  changed = true;
                  return (value + 3).clamp(10, 95); // Smaller increments for smoother progress
                }
                return value;
              });
              if (changed) setState(() {});
            });
          } else if (!hasAnalyzingLogs && _progressTimer != null) {
            // Stop timer when no more analyzing logs
            debugPrint('⏹️ DASHBOARD: Stopping progress timer - no more analyzing logs');
            _progressTimer?.cancel();
            _progressTimer = null;
            _progressByLogId.clear();
          }
          
          // Compute authoritative totals from logs
          double cals = 0, p = 0, c = 0, f = 0;
          for (final l in logs) {
            if (l.nutritionData.calories > 0) {
              cals += l.nutritionData.calories;
              p += l.nutritionData.protein;
              c += l.nutritionData.carbs;
              f += l.nutritionData.fat;
            }
          }
          final bool hasCompletedNow = logs.any((l) => l.nutritionData.calories > 0);
          
          // Check for newly ADDED logs (not just state initialization)
          // Only trigger popup when log count actually INCREASES from a previous count > 0
          final completedLogs = logs.where((l) => l.nutritionData.calories > 0).toList();
          final currentLogCount = completedLogs.length;
          
          // If we're already over the threshold on initial load for today, show once
          // This check also accounts for workout calories burned
          if (!_sugarPopupShownForToday && _isSameDay(_selectedDate, DateTime.now())) {
            final totalRefined = await _calculateDailyRefinedSugar();
            final totalSugar = await _calculateDailyTotalSugar();
            final exceeds = math.max(totalRefined, totalSugar);
            
            // Get workout adjustment
            final summary = await _nutritionRepository.getDailySummary(_selectedDate).first;
            final caloriesBurned = summary?.totalCaloriesBurned ?? 0.0;
            final thresholdAdjustment = (caloriesBurned / 100.0) * 10.0;
            final adjustedThreshold = _sugarGoalThreshold + thresholdAdjustment;
            
            if (exceeds > adjustedThreshold) {
              // Use the most recent completed log as context if available
              final completed = logs.where((l) => l.nutritionData.calories > 0).toList();
              if (completed.isNotEmpty) {
                final newest = completed.reduce((a, b) => a.loggedAt.isAfter(b.loggedAt) ? a : b);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  debugPrint('🚀 Initial exceed detected - delegating to popup checker');
                  _checkAndShowRefinedSugarPopup(newest);
                });
              }
            }
          }

          // Only check if we have MORE logs than before (new food added)
          // _previousLogCount > 0 ensures we skip the initial stream load after navigation
          if (currentLogCount > _previousLogCount && _previousLogCount > 0) {
            // A new log was added - check the newest one
            final newestCompleted = completedLogs.reduce(
              (a, b) => a.loggedAt.isAfter(b.loggedAt) ? a : b
            );
            
            // Only check if we haven't already processed this log
            final logId = newestCompleted.id;
            if (logId != null && !_processedFoodLogIds.contains(logId)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkAndShowRefinedSugarPopup(newestCompleted);
              });
            }
          }
          
          // IMPORTANT: Check if sugar dropped below threshold FIRST before checking for increases
          // This ensures the flag is reset before we check for significant increases
          if (_isSameDay(_selectedDate, DateTime.now()) && _sugarPopupShownForToday) {
            final currentTotalRefined = await _calculateDailyRefinedSugar();
            final summary = await _nutritionRepository
              .getDailySummary(_selectedDate).first;
            final caloriesBurned = summary?.totalCaloriesBurned ?? 0.0;
            final thresholdAdjustment = (caloriesBurned / 100.0) * 10.0;
            final adjustedThreshold = _sugarGoalThreshold + thresholdAdjustment;
            
            debugPrint('🔍 Checking if sugar dropped below threshold: ${currentTotalRefined.toStringAsFixed(1)}g vs ${adjustedThreshold.toStringAsFixed(0)}g (flag currently: $_sugarPopupShownForToday)');
            
            if (currentTotalRefined <= adjustedThreshold) {
              debugPrint('✅ Sugar dropped below threshold - RESETTING POPUP FLAG');
              _sugarPopupShownForToday = false;
              _processedFoodLogIds.clear();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('sugar_popup_last_shown_date');
              debugPrint('✅ Popup flag reset complete: $_sugarPopupShownForToday');
            }
          }
          
          // Check for significant sugar increases from EDITS
          // (when log count stays same but sugar increases)
          if (_isSameDay(_selectedDate, DateTime.now()) && 
              _previousLogCount > 0) {
            final currentTotalSugar = completedLogs.fold<double>(
              0.0, 
              (sum, log) => sum + log.nutritionData.sugar,
            );
            
            // Significant = >40% of sugar goal or >50% relative increase
            final sugarIncrease = currentTotalSugar - _previousTotalSugar;
            final significantThreshold = _sugarGoalThreshold * 0.4;
            final percentIncrease = _previousTotalSugar > 0 
              ? (sugarIncrease / _previousTotalSugar) * 100 
              : 0.0;
            
            if (sugarIncrease > significantThreshold || 
                percentIncrease > 50.0) {
              // Check if we're now over threshold
              final totalRefined = 
                await _calculateDailyRefinedSugar();
              final exceeds = 
                math.max(totalRefined, currentTotalSugar);
              
              // Get workout adjustment
              final summary = await _nutritionRepository
                .getDailySummary(_selectedDate).first;
              final caloriesBurned = summary?.totalCaloriesBurned ?? 0.0;
              final thresholdAdjustment = 
                (caloriesBurned / 100.0) * 10.0;
              final adjustedThreshold = 
                _sugarGoalThreshold + thresholdAdjustment;
              
              if (exceeds > adjustedThreshold && !_isShowingPopup) {
                debugPrint('🍬 Significant sugar increase detected: '
                  '+${sugarIncrease.toStringAsFixed(1)}g '
                  '(threshold: ${significantThreshold.toStringAsFixed(1)}g '
                  'or ${percentIncrease.toStringAsFixed(0)}%)');
                debugPrint('🔍 Current popup flag state: $_sugarPopupShownForToday');
                
                // Only reset popup guard if user hasn't already acknowledged it today
                if (!_sugarPopupShownForToday) {
                  debugPrint('✅ Popup flag is FALSE - Will show popup for significant increase');
                  _processedFoodLogIds.clear();
                  
                  // Find most recent log to use as trigger
                  if (completedLogs.isNotEmpty) {
                    final mostRecent = completedLogs.reduce(
                      (a, b) => a.loggedAt.isAfter(b.loggedAt) ? a : b,
                    );
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _checkAndShowRefinedSugarPopup(mostRecent);
                    });
                  }
                } else {
                  debugPrint('⏭️ Popup flag is TRUE - Sugar popup already acknowledged today, not resetting guard');
                }
              }
            }
            
            _previousTotalSugar = currentTotalSugar;
          }
          
          setState(() {
            _logsTotalCalories = cals;
            _logsTotalProtein = p;
            _logsTotalCarbs = c;
            _logsTotalFat = f;
            _hasCompletedLogs = hasCompletedNow;
            _previousLogCount = currentLogCount; // Update count for next comparison
          });

          // Trigger a one-time daily in-app review prompt after the first successful scan
          if (!prevHasCompletedLogs && hasCompletedNow && _isSameDay(_selectedDate, DateTime.now())) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _inAppReviewService.requestReviewIfAppropriateDaily(
                screenName: 'Calorie Tracker Dashboard',
              );
            });
          }
        }
      });
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('🏠 Dashboard didChangeDependencies - selectedDate: ${_selectedDate.toIso8601String().substring(0, 10)}');
  }


  @override
  void dispose() {
    _foodLogsSubscription?.cancel();
    _progressTimer?.cancel();
    _macroPageController.dispose();
    _weekPageController?.dispose();
    super.dispose();
  }

  void _showActivityPopup() {
    MixpanelService.trackButtonTap(
      'Calorie Tracker Dashboard: Add Activity Popup',
      additionalProps: {'source': 'fab'},
    );
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return ActivityPopup(
          targetDate: _selectedDate,
          onDismiss: () => Navigator.of(context).pop(),
        );
      },
    ).then((_) {
      // Ensure we stay on the selected date after activity popup/scanning
      // This prevents any potential reset to today
      // Ensure we stay on the selected date after activity popup/scanning
      // This prevents any potential reset to today
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: StreamBuilder<NutritionGoals?>(
          stream: _nutritionGoalsStream,
          builder: (context, goalsSnapshot) {
            return StreamBuilder<DailySummary?>(
              stream: _dailySummaryStream,
              builder: (context, summarySnapshot) {
                final goals = goalsSnapshot.data;
                final summary = summarySnapshot.data;
                
                // Update sugar threshold from user's goals
                if (goals != null && goals.sugar != _sugarGoalThreshold) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _sugarGoalThreshold = goals.sugar;
                      });
                    }
                  });
                }
                
                // If goals exist (from onboarding), mark as prompted to prevent re-prompting
                if (goals != null && !_hasPromptedGoalsEver) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _hasPromptedGoalsEver = true;
                      });
                      // Persist the flag
                      SharedPreferences.getInstance().then((p) {
                        p.setBool('nutrition_goals_prompted_ever', true);
                      });
                    }
                  });
                }
                
                // Only prompt if no goals exist and we haven't prompted before
                if (_prefsLoaded && goals == null && !_promptedForGoals && !_hasPromptedGoalsEver) {
                  // First time ever for this user: open goals setup once
                  _promptedForGoals = true;
                  _hasPromptedGoalsEver = true;
                  // Persist the once-only flag
                  SharedPreferences.getInstance().then((p) {
                    p.setBool('nutrition_goals_prompted_ever', true);
                  });
                  // Defer navigation to end of frame to avoid build-time nav
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NutritionGoalsScreen(),
                        settings: const RouteSettings(name: '/nutrition_goals_auto'),
                      ),
                    );
                  });
                }
                
                // Debug logging for summary data
                // debugPrint('📊 DASHBOARD SUMMARY UPDATE:');
                // debugPrint('   Goals: ${goals?.calories} cal, ${goals?.protein}p, ${goals?.carbs}c, ${goals?.fat}f');
                // debugPrint('   Summary: ${summary?.totalCalories} cal, ${summary?.totalProtein}p, ${summary?.totalCarbs}c, ${summary?.totalFat}f');

                return Column(
                  children: [
                    _buildHeader(),
                    _buildWeekSelector(goals),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildMainCalorieCircle(goals, summary),
                            const SizedBox(height: 30),
                            _buildMacroPager(goals, summary),
                            const SizedBox(height: 12),
                            _buildDotsIndicator(count: 3, activeIndex: _macroPageIndex),
                            SizedBox(height: _macroPageIndex == 2 ? 24 : 16),
                            _buildRecentlyUploaded(),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              MixpanelService.trackButtonTap('Calorie Tracker Back Button');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => MainScaffold(initialIndex: 0),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'STOPPR',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -0.8,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              MixpanelService.trackButtonTap('Calorie Tracker Dashboard: Streak Button');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CalorieStreakScreen(),
                  settings: const RouteSettings(name: '/calorie_streak'),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  StreamBuilder<int>(
                    stream: _getStreakCount(),
                    builder: (context, snapshot) {
                      return Text(
                        '${snapshot.data ?? 0}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              MixpanelService.trackButtonTap('Calorie Tracker Dashboard: Edit Goals Button');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NutritionGoalsScreen(),
                  settings: const RouteSettings(name: '/nutrition_goals'),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings_outlined,
                size: 20,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isFutureDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    return d.isAfter(today);
  }

  bool _isPastDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    return d.isBefore(today);
  }

  bool _canEditDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    // Allow editing for today and past 30 days
    final thirtyDaysAgo = today.subtract(const Duration(days: 30));
    return !d.isAfter(today) && !d.isBefore(thirtyDaysAgo);
  }

  // Calculate refined sugar from a single food log
  // Sugar from fruits don't count due to their high fiber content
  // Uses proportional calculation: refined_sugar = sugar - (fiber × 2)
  double _calculateRefinedSugar(FoodLog log) {
    final double totalSugar = log.nutritionData.sugar;
    final double fiber = log.nutritionData.fiber;
    
    // Each gram of fiber offsets 2g of sugar
    // Examples:
    // - Cinnamon bun (60g sugar, 5g fiber): 60 - 10 = 50g refined ✅
    // - Apple (20g sugar, 4g fiber): 20 - 8 = 12g refined (mostly offset)
    // - Banana (27g sugar, 3g fiber): 27 - 6 = 21g refined (some counted)
    // - Candy (30g sugar, 0g fiber): 30 - 0 = 30g refined ✅
    return math.max(0.0, totalSugar - (fiber * 2.0));
  }

  // Calculate total refined sugar consumed for the selected date
  Future<double> _calculateDailyRefinedSugar() async {
    try {
      final logs = await _nutritionRepository.getFoodLogsForDate(_selectedDate).first;
      double totalRefinedSugar = 0.0;
      
      debugPrint('🍬 Calculating refined sugar for ${logs.length} food logs:');
      for (final log in logs) {
        // Only count completed logs (calories > 0)
        if (log.nutritionData.calories > 0) {
          final refinedSugar = _calculateRefinedSugar(log);
          totalRefinedSugar += refinedSugar;
          debugPrint('   ${log.foodName}: ${log.nutritionData.sugar.toStringAsFixed(1)}g sugar, ${log.nutritionData.fiber.toStringAsFixed(1)}g fiber → ${refinedSugar.toStringAsFixed(1)}g refined');
        }
      }
      
      debugPrint('📊 Daily refined sugar total: ${totalRefinedSugar.toStringAsFixed(1)}g (threshold: ${_sugarGoalThreshold.toStringAsFixed(0)}g)');
      return totalRefinedSugar;
    } catch (e) {
      debugPrint('❌ Error calculating daily refined sugar: $e');
      return 0.0;
    }
  }

  // Calculate total sugar (not refined) consumed for the selected date
  Future<double> _calculateDailyTotalSugar() async {
    try {
      final logs = await _nutritionRepository.getFoodLogsForDate(_selectedDate).first;
      double totalSugar = 0.0;
      for (final log in logs) {
        if (log.nutritionData.calories > 0) {
          totalSugar += log.nutritionData.sugar;
        }
      }
      debugPrint('📊 Daily total sugar: ${totalSugar.toStringAsFixed(1)}g (threshold: ${_sugarGoalThreshold.toStringAsFixed(0)}g)');
      return totalSugar;
    } catch (e) {
      debugPrint('❌ Error calculating daily total sugar: $e');
      return 0.0;
    }
  }

  // Check if we should show the refined sugar popup
  // Shows when daily total exceeds threshold after adding/editing a food log
  // Accounts for workout calories: exercise improves metabolic flexibility and insulin sensitivity
  Future<void> _checkAndShowRefinedSugarPopup(FoodLog triggeringLog) async {
    debugPrint('🔍 _checkAndShowRefinedSugarPopup called for: ${triggeringLog.foodName}');
    
    // Only check for today's date
    if (!_isSameDay(_selectedDate, DateTime.now())) {
      debugPrint('⏭️ Not today\'s date, skipping popup check');
      return;
    }
    
    // Debounce: avoid running multiple concurrent decisions
    if (_isPopupDecisionInFlight || _isShowingPopup) {
      debugPrint('⏭️ Popup decision in flight or already showing, skipping');
      return;
    }
    _isPopupDecisionInFlight = true;
    try {
    
    // Check if popup already shown today (prevents showing on screen reload)
    debugPrint('🔍 Popup flag state: $_sugarPopupShownForToday');
    if (_sugarPopupShownForToday) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      debugPrint('⏭️ Sugar popup already shown today ($today), skipping');
      return;
    }
    
    // Skip if we've already processed this exact food log
    final logId = triggeringLog.id ?? '${triggeringLog.loggedAt.millisecondsSinceEpoch}';
    if (_processedFoodLogIds.contains(logId)) {
      debugPrint('⏭️ Already showed popup for this food log, skipping');
      return;
    }
    
    final totalRefinedSugar = await _calculateDailyRefinedSugar();
    final totalSugar = await _calculateDailyTotalSugar();
    final exceeds = math.max(totalRefinedSugar, totalSugar);
    
    // Get workout calories burned to adjust threshold
    // Exercise increases insulin sensitivity and glucose disposal capacity
    final summary = await _nutritionRepository.getDailySummary(_selectedDate).first;
    final caloriesBurned = summary?.totalCaloriesBurned ?? 0.0;
    
    // For every 100 calories burned, increase sugar threshold by 10g
    // This reflects improved metabolic flexibility from exercise
    final thresholdAdjustment = (caloriesBurned / 100.0) * 10.0;
    final adjustedThreshold = _sugarGoalThreshold + thresholdAdjustment;
    
    debugPrint('💪 Workout adjustment: ${caloriesBurned.toInt()} cal burned → +${thresholdAdjustment.toStringAsFixed(1)}g sugar threshold');
    
    // Show popup if either refined OR total sugar exceeds adjusted threshold
    if (exceeds > adjustedThreshold) {
      debugPrint('⚠️ Refined sugar threshold exceeded: ${totalRefinedSugar.toStringAsFixed(1)}g (adjusted limit: ${adjustedThreshold.toStringAsFixed(0)}g, base: ${_sugarGoalThreshold.toStringAsFixed(0)}g)');
      debugPrint('🚀 SHOWING SUGAR POPUP NOW');

      // Mark as shown today in both memory and SharedPreferences
      _sugarPopupShownForToday = true;
      _lastTriggeringFoodLog = triggeringLog;
      _processedFoodLogIds.add(logId); // Mark as processed
      _isShowingPopup = true; // Prevent duplicate popups

      // Persist flag to prevent showing again today after screen reload
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await prefs.setString('sugar_popup_last_shown_date', today);
      debugPrint('✅ Popup flag set to TRUE and persisted to SharedPreferences');

      if (mounted) {
        _showRefinedSugarPopup(totalRefinedSugar);
      }
    } else {
      debugPrint('✅ Sugar within adjusted threshold: ${exceeds.toStringAsFixed(1)}g / ${adjustedThreshold.toStringAsFixed(0)}g (workout bonus: +${thresholdAdjustment.toStringAsFixed(1)}g)');
    }
    } finally {
      _isPopupDecisionInFlight = false;
    }
  }

  void _initializeDaysSelector() {
    debugPrint('🚀 Initializing days selector');
    _isInitialized = true;
  }
  

  Widget _buildWeekSelector(NutritionGoals? goals) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thirtyDaysAgo = today.subtract(const Duration(days: 30));
    
    // Calculate the week index for the selected date
    final selectedWeekStart = _selectedDate.subtract(Duration(days: (_selectedDate.weekday - 1) % 7));
    final currentWeekStart = now.subtract(Duration(days: (now.weekday - 1) % 7));
    final oldestWeekStart = thirtyDaysAgo.subtract(Duration(days: (thirtyDaysAgo.weekday - 1) % 7));
    
    // Calculate total weeks available (from 30 days ago to current week)
    final totalWeeks = ((currentWeekStart.difference(oldestWeekStart).inDays) / 7).ceil() + 1;
    
    // Calculate initial page index (0 = oldest week, totalWeeks-1 = current week)
    final weeksSinceOldest = ((selectedWeekStart.difference(oldestWeekStart).inDays) / 7).round();
    final initialPage = weeksSinceOldest.clamp(0, totalWeeks - 1);
    
    // Initialize PageController if needed
    if (_weekPageController == null) {
      _weekPageController = PageController(initialPage: initialPage);
      debugPrint('🔧 Initialized week PageController with page: $initialPage');
    } else {
      // Jump to correct page if selected date changed externally
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_weekPageController!.hasClients && _weekPageController!.page?.round() != initialPage) {
          _weekPageController!.jumpToPage(initialPage);
        }
      });
    }
    
    debugPrint('🔧 Building week selector with PageView');
    debugPrint('   Total weeks: $totalWeeks, Current page: $initialPage');
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      height: 114,
      child: PageView.builder(
        controller: _weekPageController,
        itemCount: totalWeeks,
        onPageChanged: (pageIndex) {
          // Calculate the Monday of the selected week
          final weekStart = oldestWeekStart.add(Duration(days: pageIndex * 7));
          
          // Find the corresponding day in the new week
          final newWeekday = _selectedDate.weekday;
          var newDate = weekStart.add(Duration(days: newWeekday - 1));
          
          // Ensure we don't go beyond today
          if (newDate.isAfter(today)) {
            newDate = today;
          }
          
          // Ensure we don't go before 30 days ago
          if (newDate.isBefore(thirtyDaysAgo)) {
            newDate = thirtyDaysAgo;
          }
          
          setState(() {
            _selectedDate = newDate;
            _localWaterOverrideMl = null; // reset optimistic water when date changes
          });
          _initializeStreams();
          
          MixpanelService.trackButtonTap('Calorie Tracker Dashboard: Week Swipe', 
            additionalProps: {
              'direction': pageIndex > initialPage ? 'forward' : 'backward',
              'selected_week': weekStart.toIso8601String().substring(0, 10),
            });
        },
        itemBuilder: (context, pageIndex) {
          final weekStart = oldestWeekStart.add(Duration(days: pageIndex * 7));
          return _buildWeekView(weekStart, goals, now);
        },
      ),
    );
  }
  
  Widget _buildWeekView(DateTime weekStart, NutritionGoals? goals, DateTime now) {
    final dayLetters = [
      AppLocalizations.of(context)!.translate('common_day_monday_letter'),
      AppLocalizations.of(context)!.translate('common_day_tuesday_letter'),
      AppLocalizations.of(context)!.translate('common_day_wednesday_letter'),
      AppLocalizations.of(context)!.translate('common_day_thursday_letter'),
      AppLocalizations.of(context)!.translate('common_day_friday_letter'),
      AppLocalizations.of(context)!.translate('common_day_saturday_letter'),
      AppLocalizations.of(context)!.translate('common_day_sunday_letter'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final date = weekStart.add(Duration(days: index));
        final isSelected = _isSameDay(date, _selectedDate);
        final isToday = _isSameDay(date, now);
        final canTap = !_isFutureDay(date) && _canEditDate(date);

        return Flexible(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: canTap
                ? () {
                    debugPrint('🎯 Day tapped: ${date.toIso8601String().substring(0, 10)}');
                    setState(() {
                      _selectedDate = date;
                      _localWaterOverrideMl = null; // reset on day change
                    });
                    _initializeStreams();

                    MixpanelService.trackButtonTap(
                      'Calorie Tracker Dashboard: Day Selector',
                      additionalProps: {
                        'selected_day': date.day.toString(),
                        'weekday': date.weekday.toString(),
                      },
                    );
                  }
                : null,
            child: Opacity(
              opacity: canTap ? 1.0 : 0.4,
              child: SizedBox(
                height: 70,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: _WeekDayRing(
                        date: date,
                        isSelected: isSelected,
                        isToday: isToday,
                        dayLetter: dayLetters[date.weekday - 1],
                        goals: goals,
                        getSummary: (d) => _nutritionRepository.getDailySummary(d),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date.day.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.black
                            : const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }



  Widget _buildMainCalorieCircle(NutritionGoals? goals, DailySummary? summary) {
    // Always compute using defaults if goals are not yet set so the dashboard updates
    final double goalCalories = (goals?.calories ?? 1662).toDouble();
    // If no completed logs, treat consumed as 0 and ignore any stale summary values
    // Always prefer log totals over summary when available for real-time accuracy
    final double consumedCalories = (!_hasCompletedLogs)
        ? 0.0
        : _logsTotalCalories; // Always use log totals, never fall back to summary
    
    // Add burned calories from workouts to available calories
    final double burnedCalories = summary?.totalCaloriesBurned ?? 0.0;
    final double adjustedGoal = goalCalories + burnedCalories;
    
    final bool isOverTarget = consumedCalories > adjustedGoal;
    final double displayAmount = isOverTarget 
        ? (consumedCalories - adjustedGoal) 
        : (adjustedGoal - consumedCalories).clamp(0.0, double.infinity);
    final double progress = adjustedGoal > 0
        ? (consumedCalories / adjustedGoal).clamp(0.0, 1.0)
        : 0.0;
    
    // Debug logging to verify ring should update
    // debugPrint('🔴 RING PROGRESS: ${(progress * 100).toStringAsFixed(1)}% (${consumedCalories.toInt()}/${adjustedGoal.toInt()} cal)');
    final String calorieLabel = isOverTarget 
        ? AppLocalizations.of(context)!.translate('calorieTracker_caloriesOver')
        : AppLocalizations.of(context)!.translate('calorieTracker_caloriesLeft');
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayAmount.toInt().toString(),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  height: 0.9,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w400,
                  ),
                  children: _buildLabelSpans(calorieLabel),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Small circular progress indicator on the right
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Add key to force rebuild when progress changes
                _BrandProgressRing(
                  key: ValueKey('ring_${progress.toStringAsFixed(3)}'),
                  progress: progress, 
                  strokeWidth: 8,
                ),
                // Debug overlay showing numeric progress (small, nearly invisible)
                Positioned(
                  bottom: 0,
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.transparent, // keep UI clean
                    ),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.local_fire_department, color: Color(0xFFed3272), size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCards(NutritionGoals? goals, DailySummary? summary) {
    // Use defaults while goals load so totals reflect consumed values
    final double proteinGoal = (goals?.protein ?? 150).toDouble();
    final double carbsGoal = (goals?.carbs ?? 161).toDouble();
    final double fatGoal = (goals?.fat ?? 46).toDouble();
    
    // Always use log totals for real-time accuracy, never fall back to summary
    final proteinConsumed = !_hasCompletedLogs ? 0.0 : _logsTotalProtein;
    final carbsConsumed = !_hasCompletedLogs ? 0.0 : _logsTotalCarbs;
    final fatConsumed = !_hasCompletedLogs ? 0.0 : _logsTotalFat;
    
    // Calculate whether we're over or under goals
    final proteinOver = proteinConsumed > proteinGoal;
    final carbsOver = carbsConsumed > carbsGoal;
    final fatOver = fatConsumed > fatGoal;
    
    final proteinAmount = proteinOver ? (proteinConsumed - proteinGoal).toInt() : (proteinGoal - proteinConsumed).clamp(0, double.infinity).toInt();
    final carbsAmount = carbsOver ? (carbsConsumed - carbsGoal).toInt() : (carbsGoal - carbsConsumed).clamp(0, double.infinity).toInt();
    final fatAmount = fatOver ? (fatConsumed - fatGoal).toInt() : (fatGoal - fatConsumed).clamp(0, double.infinity).toInt();
    
    final proteinLabel = proteinOver ? AppLocalizations.of(context)!.translate('calorieTracker_proteinOver') : AppLocalizations.of(context)!.translate('calorieTracker_proteinLeft');
    final carbsLabel = carbsOver ? AppLocalizations.of(context)!.translate('calorieTracker_carbsOver') : AppLocalizations.of(context)!.translate('calorieTracker_carbsLeft');
    final fatLabel = fatOver ? AppLocalizations.of(context)!.translate('calorieTracker_fatOver') : AppLocalizations.of(context)!.translate('calorieTracker_fatLeft');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildClickableMacroCard('$proteinAmount${AppLocalizations.of(context)!.translate('unit_g')}', proteinLabel, '🥩', const Color(0xFFE57373), proteinConsumed, proteinGoal, 'protein')),
          const SizedBox(width: 12),
          Expanded(child: _buildClickableMacroCard('$carbsAmount${AppLocalizations.of(context)!.translate('unit_g')}', carbsLabel, '🥖', const Color(0xFFFFB74D), carbsConsumed, carbsGoal, 'carbs')),
          const SizedBox(width: 12),
          Expanded(child: _buildClickableMacroCard('$fatAmount${AppLocalizations.of(context)!.translate('unit_g')}', fatLabel, '🧈', const Color(0xFF64B5F6), fatConsumed, fatGoal, 'fat')),
        ],
      ),
    );
  }

  Widget _buildMicrosCards(NutritionGoals? goals, DailySummary? summary) {
    final double fiberGoal = (goals?.fiber ?? 38).toDouble();
    final double sugarGoal = (goals?.sugar ?? 62).toDouble();
    final double sodiumGoal = (goals?.sodium ?? 2300).toDouble(); // mg

    final fiberConsumed = summary?.totalFiber ?? 0;
    final sugarConsumed = summary?.totalSugar ?? 0;
    final sodiumConsumed = summary?.totalSodium ?? 0; // mg

    // Calculate whether we're over or under goals
    final fiberOver = fiberConsumed > fiberGoal;
    final sugarOver = sugarConsumed > sugarGoal;
    final sodiumOver = sodiumConsumed > sodiumGoal;

    final fiberAmount = fiberOver ? (fiberConsumed - fiberGoal).toInt() : (fiberGoal - fiberConsumed).clamp(0, double.infinity).toInt();
    final sugarAmount = sugarOver ? (sugarConsumed - sugarGoal).toInt() : (sugarGoal - sugarConsumed).clamp(0, double.infinity).toInt();
    final sodiumAmount = sodiumOver ? (sodiumConsumed - sodiumGoal).toInt() : (sodiumGoal - sodiumConsumed).clamp(0, double.infinity).toInt();

    final fiberLabel = fiberOver ? AppLocalizations.of(context)!.translate('calorieTracker_fiberOver') : AppLocalizations.of(context)!.translate('calorieTracker_fiberLeft');
    final sugarLabel = sugarOver ? AppLocalizations.of(context)!.translate('calorieTracker_sugarOver') : AppLocalizations.of(context)!.translate('calorieTracker_sugarLeft');
    final sodiumLabel = sodiumOver ? AppLocalizations.of(context)!.translate('calorieTracker_sodiumOver') : AppLocalizations.of(context)!.translate('calorieTracker_sodiumLeft');

    final fiberUnit = AppLocalizations.of(context)!.translate('unit_g');
    final sugarUnit = AppLocalizations.of(context)!.translate('unit_g');
    final sodiumUnit = AppLocalizations.of(context)!.translate('unit_mg');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildClickableMacroCard('$fiberAmount$fiberUnit', fiberLabel, '🫐', const Color(0xFF9C27B0), fiberConsumed, fiberGoal, 'fiber')),
          const SizedBox(width: 12),
          Expanded(child: _buildClickableMacroCard('$sugarAmount$sugarUnit', sugarLabel, '🍬', const Color(0xFFE91E63), sugarConsumed, sugarGoal, 'sugar')),
          const SizedBox(width: 12),
          Expanded(child: _buildClickableMacroCard('$sodiumAmount$sodiumUnit', sodiumLabel, '🍚', const Color(0xFFFFB74D), sodiumConsumed, sodiumGoal, 'sodium')),
        ],
      ),
    );
  }

  double _waterSlideHeightForGoals(NutritionGoals? goals) {
    final double goalMl = (goals?.water ?? 2000).toDouble();
    final double perCupMl = _waterServingMl ?? (_waterUseOz ? 236.588 : 250.0);
    final int cupsTotal = (goalMl / perCupMl).ceil().clamp(1, 100);
    final int rows = ((cupsTotal - 1) ~/ 8) + 1; // max 8 per row
    const double baseHeader = 150; // title + goal + value + paddings
    const double perRow = 78; // each row height incl. spacing
    return baseHeader + (rows * perRow) + 8; // small buffer to avoid rounding overflow
  }

  Widget _buildMacroPager(NutritionGoals? goals, DailySummary? summary) {
    final double waterHeight = _waterSlideHeightForGoals(goals).clamp(240, 520);
    final double height = _macroPageIndex == 2 ? waterHeight : 150;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: height,
      child: PageView(
        controller: _macroPageController,
        onPageChanged: (i) => setState(() => _macroPageIndex = i),
        children: [
          _buildMacroCards(goals, summary),
          _buildMicrosCards(goals, summary),
          _buildWaterSlide(goals, summary),
        ],
      ),
    );
  }

  Widget _buildClickableMacroCard(String value, String label, String emoji, Color color, double current, double goal, String macroType) {
    return GestureDetector(
      onTap: () {
        MixpanelService.trackButtonTap('Macro Card Tap: $macroType');
        // Show macro details
        _showMacroDetails(macroType, current, goal, value, label);
      },
      child: _buildMacroCard(value, label, emoji, color, current, goal),
    );
  }

  Widget _buildMacroCard(String value, String label, String emoji, Color color, double current, double goal) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    // Slightly reduce font size for longer localized labels to keep them readable
    final double labelFontSize = label.length > 28
        ? 9
        : (label.length > 18 ? 10 : 11);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: labelFontSize,
                  color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                children: _buildLabelSpans(label),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: const Color(0xFFF0F0F0),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMacroDetails(String macroType, double current, double goal, String value, String label) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyBreakdownScreen(date: _selectedDate),
        settings: const RouteSettings(name: '/daily_breakdown'),
      ),
    );
  }

  Widget _buildDotsIndicator({int count = 3, int activeIndex = 0}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == activeIndex ? Colors.black : const Color(0xFFD1D1D6),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildRecentlyUploaded() {
    return StreamBuilder<List<FoodLog>>(
      stream: _nutritionRepository.getFoodLogsForDate(_selectedDate),
      builder: (context, foodSnapshot) {
        return StreamBuilder<List<WorkoutLog>>(
          stream: _nutritionRepository.getWorkoutLogsForDate(_selectedDate),
          builder: (context, workoutSnapshot) {
            final foodLogs = foodSnapshot.data ?? [];
            final workoutLogs = workoutSnapshot.data ?? [];

            if (foodLogs.isEmpty && workoutLogs.isEmpty) {
              return _buildRecentlyEmptyState();
            }
            // Process food logs
            final analyzingFoodLogs = foodLogs.where((log) => log.nutritionData.calories == 0).toList();
            final completedFoodLogs = foodLogs.where((log) => log.nutritionData.calories > 0).toList();
            final errorFoodLogs = foodLogs.where((log) => log.nutritionData.calories == -1).toList();

            // Combine all logs and sort by timestamp (most recent first)
            final List<dynamic> allLogs = [
              ...analyzingFoodLogs,
              ...errorFoodLogs, 
              ...completedFoodLogs,
              ...workoutLogs,
            ];
            
            allLogs.sort((a, b) {
              final DateTime aTime = a is FoodLog ? a.loggedAt : (a as WorkoutLog).loggedAt;
              final DateTime bTime = b is FoodLog ? b.loggedAt : (b as WorkoutLog).loggedAt;
              return bTime.compareTo(aTime); // Most recent first
            });

            if (allLogs.isEmpty) {
              return _buildRecentlyEmptyState();
            }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!
                          .translate('calorieTracker_recentlyUploaded'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...allLogs.map((log) {
                final bool isFoodLog = log is FoodLog;
                final String logId = isFoodLog 
                  ? (log as FoodLog).id ?? log.loggedAt.millisecondsSinceEpoch.toString()
                  : (log as WorkoutLog).id ?? log.loggedAt.millisecondsSinceEpoch.toString();
                final dismissKey = isFoodLog ? 'food-$logId' : 'workout-$logId';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Dismissible(
                    key: ValueKey(dismissKey),
                    direction: DismissDirection.endToStart,
                    dismissThresholds: const {
                      DismissDirection.endToStart: 0.7, // Require 70% swipe (less sensitive)
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFed3272), // Brand pink
                            Color(0xFFfd5d32), // Brand orange
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Icon(Icons.delete, color: Colors.white),
                          const SizedBox(height: 4),
                          Text(AppLocalizations.of(context)!.translate('common_delete'), style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    confirmDismiss: (_) async {
                      try {
                        if (isFoodLog) {
                          final foodLog = log as FoodLog;
                          if (foodLog.id != null && foodLog.id!.isNotEmpty) {
                            await _nutritionRepository.deleteFoodLog(foodLog.id!);
                            
                            if (foodLog.imageUrl != null && foodLog.imageUrl!.isNotEmpty) {
                              try {
                                await _imageService.deleteImageFromStorage(foodLog.id!);
                                debugPrint('✅ Successfully deleted image from Firebase Storage: ${foodLog.id!}');
                              } catch (e) {
                                debugPrint('❌ Failed to delete image from Firebase Storage: $e');
                                if (kDebugMode && e.toString().contains('channel-error')) {
                                  debugPrint('🔧 Debug mode: Firebase Storage connection unavailable, but local image should be deleted');
                                }
                              }
                            }
                          }
                        } else {
                          final workoutLog = log as WorkoutLog;
                          if (workoutLog.id != null && workoutLog.id!.isNotEmpty) {
                            await _nutritionRepository.deleteWorkoutLog(workoutLog.id!);
                          }
                        }
                        return true;
                      } catch (e) {
                        debugPrint('Delete failed: $e');
                        return false;
                      }
                    },
                    onDismissed: (direction) {
                      // This callback is required by Flutter to properly remove the widget from the tree
                      debugPrint('🐛 Dismissible onDismissed called for $dismissKey');
                    },
                    child: GestureDetector(
                      onLongPress: () async {
                        if (isFoodLog) {
                          final foodLog = log as FoodLog;
                          if (foodLog.id != null && foodLog.id!.isNotEmpty) {
                            await _nutritionRepository.deleteFoodLog(foodLog.id!);
                            
                            if (foodLog.imageUrl != null && foodLog.imageUrl!.isNotEmpty) {
                              try {
                                await _imageService.deleteImageFromStorage(foodLog.id!);
                                debugPrint('✅ Successfully deleted image from Firebase Storage: ${foodLog.id!}');
                              } catch (e) {
                                debugPrint('❌ Failed to delete image from Firebase Storage: $e');
                                if (kDebugMode && e.toString().contains('channel-error')) {
                                  debugPrint('🔧 Debug mode: Firebase Storage connection unavailable, but local image should be deleted');
                                }
                              }
                            }
                          }
                        } else {
                          final workoutLog = log as WorkoutLog;
                          if (workoutLog.id != null && workoutLog.id!.isNotEmpty) {
                            await _nutritionRepository.deleteWorkoutLog(workoutLog.id!);
                          }
                        }
                      },
                    child: isFoodLog 
                      ? _buildFoodLogWidget(log as FoodLog)
                      : GestureDetector(
                          onTap: () => _editWorkout(log as WorkoutLog),
                          child: _buildWorkoutLogCard(log as WorkoutLog),
                        ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildWaterSlide(NutritionGoals? goals, DailySummary? summary) {
    final double goalMl = (goals?.water ?? 2000).toDouble();
    final double currentMl = (_localWaterOverrideMl ?? (summary?.waterIntake ?? 0)).toDouble();
    final double perCupMl = _waterServingMl ?? (_waterUseOz ? 236.588 : 250.0); // user-set serving size
    // Render as many glasses as needed by the goal
    final int cupsTotal = (goalMl / perCupMl).round().clamp(1, 100);
    final double cupsExact = (currentMl / perCupMl);
    final int cupsFilled = cupsExact.floor().clamp(0, cupsTotal);
    final bool hasPartialCup = (cupsExact - cupsFilled) > 0.0001;

    Future<void> _toggleWaterUnit() async {
      _waterUseOz = !_waterUseOz;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('water_unit_oz', _waterUseOz);
      if (mounted) setState(() {});
    }

    Future<void> _addQuarterL() async {
      final double next = (currentMl + 250).clamp(0, goalMl);
      try {
        await _nutritionRepository.updateWaterIntake(_selectedDate, next);
        MixpanelService.trackButtonTap('Calorie Tracker Dashboard: Water +0.25L');
      } catch (_) {}
    }
    Future<void> _setWaterToCups(int cups) async {
      final double next = (cups * perCupMl).toDouble().clamp(0, goalMl);
      // Optimistic UI update
      if (mounted) {
        setState(() {
          _localWaterOverrideMl = next;
        });
      }
      try {
        debugPrint('💧 Setting water to cups=$cups (ml=${next.toStringAsFixed(0)})');
        await _nutritionRepository.updateWaterIntake(_selectedDate, next);
      } catch (e) {
        debugPrint('❌ Failed to set water intake: $e');
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF29B6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.translate('calorieTracker_water'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Row(children: [
                GestureDetector(
                  onTap: () => _showWaterSettingsSheet(context),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings, color: Colors.white, size: 16),
                  ),
                ),
                GestureDetector(
                  onTap: _toggleWaterUnit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _waterUseOz
                          ? AppLocalizations.of(context)!.translate('unit_oz')
                          : AppLocalizations.of(context)!.translate('unit_l'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _waterUseOz
                ? '${AppLocalizations.of(context)!.translate('calorieTracker_goal')}: ${(goalMl / 29.5735).toStringAsFixed(0)} ${AppLocalizations.of(context)!.translate('unit_oz')}'
                : '${AppLocalizations.of(context)!.translate('calorieTracker_goal')}: ${(goalMl / 1000).toStringAsFixed(2)} ${AppLocalizations.of(context)!.translate('unit_l')}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _waterUseOz
                ? '${(currentMl / 29.5735).toStringAsFixed(0)} ${AppLocalizations.of(context)!.translate('unit_oz')}'
                : '${(currentMl / 1000).toStringAsFixed(2)} ${AppLocalizations.of(context)!.translate('unit_l')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: (((cupsTotal - 1) ~/ 8) + 1) * 66,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double spacing = 6.0; // space between items
                final double itemWidth = (constraints.maxWidth - (7 * spacing)) / 8;
                return Wrap(
                  runSpacing: 8,
                  spacing: spacing,
                  children: List.generate(cupsTotal, (index) {
                double fractional = (cupsExact - index).clamp(0.0, 1.0);
                final bool isNext = index == cupsFilled && cupsFilled < cupsTotal;
                final bool reachedGoal = currentMl >= goalMl && cupsTotal > 0;
                if (reachedGoal && index == cupsTotal - 1) {
                  fractional = 1.0; // show the last glass fully filled at goal
                }
                return SizedBox(
                      width: itemWidth,
                      child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      debugPrint('🧃 Water glass tapped: index=$index cupsFilled=$cupsFilled hasPartial=$hasPartialCup');
                      // Decrement when tapping the currently active last glass (partial or full)
                      final int decrementIndex = hasPartialCup ? cupsFilled : (cupsFilled - 1);
                      if (decrementIndex >= 0 && index == decrementIndex) {
                        await _setWaterToCups(index);
                      } else {
                        await _setWaterToCups(index + 1);
                      }
                    },
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: fractional),
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => _CupGlass(
                            fill: value,
                            showPlus: isNext,
                            showCheck: reachedGoal && index == cupsTotal - 1,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Future<void> _toggleWaterUnit() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterUseOz = !_waterUseOz;
    });
    await prefs.setBool('water_unit_oz', _waterUseOz);
    // If serving not set, switch to sensible default for new unit
    if (_waterServingMl == null) {
      _waterServingMl = _waterUseOz ? 236.588 : 250.0;
      await prefs.setDouble('water_serving_ml', _waterServingMl!);
    }
  }

  void _showWaterSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, modalSetState) {
            String _servingLabel() {
              final double ml = _waterServingMl ?? (_waterUseOz ? 236.588 : 250.0);
              if (_waterUseOz) {
                final oz = ml / 29.5735;
                final String ozStr = (oz - oz.roundToDouble()).abs() < 0.05
                    ? oz.round().toString()
                    : oz.toStringAsFixed(1);
                return '$ozStr ${AppLocalizations.of(context)!.translate('unit_oz')}';
              } else {
                final liters = ml / 1000.0;
                return '${liters.toStringAsFixed(2)} ${AppLocalizations.of(context)!.translate('unit_l')}';
              }
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(AppLocalizations.of(context)!.translate('water_settings_title'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 20),
                  Text(AppLocalizations.of(context)!.translate('water_settings_serving_size'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _servingLabel(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Unit toggle inside settings
                      GestureDetector(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          setState(() { _waterUseOz = !_waterUseOz; });
                          await prefs.setBool('water_unit_oz', _waterUseOz);
                          modalSetState(() {});
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _waterUseOz
                                ? AppLocalizations.of(context)!.translate('unit_oz')
                                : AppLocalizations.of(context)!.translate('unit_l'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await _showServingPicker(ctx, onSaved: () { modalSetState(() {}); });
                        },
                        child: const Icon(Icons.edit, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(AppLocalizations.of(context)!.translate('water_settings_hydration_question'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    _waterUseOz
                        ? AppLocalizations.of(context)!.translate('water_settings_recommendation_oz')
                        : AppLocalizations.of(context)!.translate('water_settings_recommendation_l'),
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.translate('done'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showServingPicker(BuildContext bottomSheetContext, {VoidCallback? onSaved}) async {
    final prefs = await SharedPreferences.getInstance();
    double tempServingMl = _waterServingMl ?? (_waterUseOz ? 236.588 : 250.0);
    final controller = FixedExtentScrollController(
      initialItem: _waterUseOz
          ? (tempServingMl / 29.5735).round().clamp(1, 16) - 1
          : ((tempServingMl / 1000.0) / 0.05).round().clamp(1, 10) - 1,
    );

    await showModalBottomSheet(
      context: bottomSheetContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(AppLocalizations.of(context)!.translate('water_settings_serving_size'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 36,
                    onSelectedItemChanged: (i) {
                      if (_waterUseOz) {
                        final oz = (i + 1).toDouble();
                        tempServingMl = oz * 29.5735;
                      } else {
                        final liters = (i + 1) * 0.05; // 0.05L increments
                        tempServingMl = liters * 1000.0;
                      }
                    },
                    children: List.generate(_waterUseOz ? 16 : 10, (i) {
                      if (_waterUseOz) {
                        final oz = i + 1;
                        final cupsFrac = oz / 8.0;
                        return Center(child: Text('$oz ${AppLocalizations.of(context)!.translate('unit_oz')} (${cupsFrac.toStringAsFixed(cupsFrac == cupsFrac.roundToDouble() ? 0 : 3)} cups)'));
                      } else {
                        final liters = ((i + 1) * 0.05);
                        final cups = (liters * 1000.0) / 250.0;
                        return Center(child: Text('${liters.toStringAsFixed(2)} ${AppLocalizations.of(context)!.translate('unit_l')} (${cups.toStringAsFixed(cups == cups.roundToDouble() ? 0 : 1)} cups)'));
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(16)),
                        child: Center(
                          child: Text(AppLocalizations.of(context)!.translate('common_cancel'),
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          setState(() {
                            _waterServingMl = tempServingMl;
                          });
                          await prefs.setDouble('water_serving_ml', _waterServingMl!);
                          if (onSaved != null) onSaved();
                          if (mounted) Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(AppLocalizations.of(context)!.translate('common_save'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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

  Widget _buildFoodLogWidget(FoodLog log) {
    if (_isAnalyzingLog(log)) {
      return _buildAnalyzingFoodCard(log);
    } else if (log.nutritionData.calories == -1) {
      return GestureDetector(
        onTap: () => _retryFoodAnalysis(log),
        child: _buildErrorFoodCard(log),
      );
    } else {
      return GestureDetector(
        onTap: () async {
          if (!_canEditDate(_selectedDate)) {
            return; // Only allow editing today
          }
          final updated = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FoodNutritionEditScreen(foodLog: log),
              settings: const RouteSettings(name: '/food_nutrition_edit'),
            ),
          );
          if (updated != null) {
            setState(() {});
            // Check refined sugar after editing nutrition values
            // Add delay to ensure Firestore data is fully updated before calculation
            if (updated is FoodLog) {
              await Future.delayed(const Duration(milliseconds: 1000)); // Increased to 1s
              _checkAndShowRefinedSugarPopup(updated);
            }
          }
        },
        child: _buildCompletedFoodCard(log),
      );
    }
  }

  bool _isAnalyzingLog(FoodLog log) {
    final name = (log.foodName ?? '').toLowerCase();
    final hasAnalyzingName = name.startsWith('analyzing');
    // Only treat as analyzing when explicitly labeled so.
    // This avoids "0 calories" items like water being stuck as analyzing.
    return log.nutritionData.calories == 0 && hasAnalyzingName;
  }

  Widget _buildWorkoutLogCard(WorkoutLog workoutLog) {
    final timeStr = '${workoutLog.loggedAt.hour.toString().padLeft(2, '0')}:${workoutLog.loggedAt.minute.toString().padLeft(2, '0')}';
    final sanitizedExerciseType = TextSanitizer.sanitizeForDisplay(workoutLog.exerciseType);
    
    // Choose appropriate emoji based on exercise type
    String exerciseEmoji;
    if (sanitizedExerciseType.toLowerCase().contains('run')) {
      exerciseEmoji = '👟'; // Running shoe for running
    } else if (sanitizedExerciseType.toLowerCase().contains('weight')) {
      exerciseEmoji = '🏋️'; // Weight lifting for weight lifting
    } else {
      exerciseEmoji = '💪'; // Muscle for manual/other exercises
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          // Exercise icon - no background
          Container(
            width: 88,
            height: 88,
            child: Center(
              child: Text(exerciseEmoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exercise name and time row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        sanitizedExerciseType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          height: 1.1,
                        ),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Calories burned display
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 20)),
                    Text(
                      '${workoutLog.caloriesBurned} ${AppLocalizations.of(context)!.translate('exercise_cals').toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Exercise details row
                Row(
                  children: [
                    // Intensity
                    Flexible(
                      flex: 1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 2),
                          Text(
                            AppLocalizations.of(context)!.translate('exercise_intensity_${workoutLog.intensity}'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Duration
                    Flexible(
                      flex: 1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('⏱️', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 2),
                          Text(
                            '${workoutLog.duration} ${AppLocalizations.of(context)!.translate('unit_mins')}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!
                      .translate('calorieTracker_recentlyUploaded'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
            // Small stacked card illusion
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('🥗', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6E6EB),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          width: 140,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6E6EB),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!
                  .translate('calorieTracker_addFirstMeal'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            // Browse Recipes button
            GestureDetector(
              onTap: () {
                MixpanelService.trackButtonTap('Calorie Tracker Empty State: Browse Recipes');
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RecipesListScreen(),
                    settings: const RouteSettings(name: '/recipes_list_from_empty'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272), // Brand pink
                      Color(0xFFfd5d32), // Brand orange
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.restaurant_menu,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.translate('activitySelector_browseRecipes'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildAnalyzingFoodCard(FoodLog foodLog) {
    // Prefer local deterministic progress; fallback to time-based with better initial progress
    final id = foodLog.id ?? '${foodLog.loggedAt.millisecondsSinceEpoch}';
    int progressPercent = _progressByLogId[id] ?? 10; // Start at 10% instead of 5%
    if (progressPercent < 95) {
      final now = DateTime.now();
      final elapsed = now.difference(foodLog.loggedAt);
      // Faster initial progress to show immediate feedback
      final timePct = ((elapsed.inSeconds / 20.0) * 100).clamp(10, 95).toInt(); // 20 seconds instead of 30
      if (timePct > progressPercent) progressPercent = timePct;
    }
    final double progress = progressPercent / 100.0;

    final rawName = (foodLog.foodName ?? 'food').trim();
    final sanitizedName = TextSanitizer.sanitizeForDisplay(rawName);
    final alreadyPrefixed = rawName.toLowerCase().startsWith('analyzing');
    final titleText = alreadyPrefixed ? sanitizedName : 'Analyzing $sanitizedName...';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Show image thumbnail with progress overlay
          Stack(
            alignment: Alignment.center,
            children: [
              _imageService.buildThumbnail(foodLog.imageUrl, size: 80),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                child: _buildProgressIndicator(progress, progressPercent),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double leading = (
                      constraints.maxWidth * (progressPercent / 100)
                    ).clamp(8.0, constraints.maxWidth - 4.0).toDouble(); // Better minimum width
                    return Stack(
                      children: [
                        Container(
                          height: 4, // Slightly thicker for better visibility
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300), // Faster animation
                          curve: Curves.easeInOut, // Smoother curve
                          height: 4,
                          width: leading,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient( // Add gradient for better visual feedback
                              colors: [Color(0xFF34C759), Color(0xFF30D158)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF34C759).withOpacity(0.3),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!
                      .translate('calorieTracker_notifyWhenDone'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorFoodCard(FoodLog foodLog) {
    // Extract the specific error reason from the foodName and sanitize
    final errorMessage = TextSanitizer.sanitizeForDisplay(foodLog.foodName);
    final isNonFoodError = errorMessage.toLowerCase().contains('not food') || 
                          errorMessage.toLowerCase().contains('not drink') ||
                          errorMessage.toLowerCase().contains('not a food') ||
                          errorMessage.toLowerCase().contains('not a drink') ||
                          errorMessage.toLowerCase().contains('can consume');
    
    // Always show the concise non-food message in the red pill
    final displayMessage = AppLocalizations.of(context)!.translate('calorieTracker_nonConsumableDetected');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Show image thumbnail with error overlay
          Stack(
            alignment: Alignment.center,
            children: [
              _imageService.buildThumbnail(foodLog.imageUrl, size: 80),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withOpacity(0.5),
                ),
                child: Center(
                  child: Icon(
                    isNonFoodError ? Icons.no_food : Icons.error_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show "Analysis failed" as title
                Text(
                  AppLocalizations.of(context)!.translate('calorieTracker_analysisFailed'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                // Show the specific error reason prominently
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    displayMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFFF3B30),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, size: 16, color: Color(0xFFFF3B30)),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)!.translate('videoPlayer_retry'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF3B30),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayFoodName(String? raw) {
    final name = (raw ?? '').trim();
    if (name.isEmpty) {
      return AppLocalizations.of(context)!.translate('calorieTracker_unnamedFood');
    }
    // Sanitize to prevent UTF-16 crashes from AI-generated or user-entered names
    return TextSanitizer.sanitizeForDisplay(name);
  }

  Widget _buildCompletedFoodCard(FoodLog foodLog) {
    final timeStr = '${foodLog.loggedAt.hour.toString().padLeft(2, '0')}:${foodLog.loggedAt.minute.toString().padLeft(2, '0')}';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          // Large food image thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _imageService.buildThumbnail(foodLog.imageUrl, size: 88),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food name and time row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _displayFoodName(foodLog.foodName),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          height: 1.1,
                        ),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Large calorie display
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 20)),
                    Text(
                      '${foodLog.nutritionData.calories.toInt()} ${AppLocalizations.of(context)!.translate('calorieTracker_calories').toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                                          // Macro breakdown row - using Flexible to prevent overflow
                          Row(
                            children: [
                              // Protein
                              Flexible(
                                flex: 1,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🥩', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${foodLog.nutritionData.protein.toInt()}${AppLocalizations.of(context)!.translate('unit_g')}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Carbs
                              Flexible(
                                flex: 1,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🌾', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        '${foodLog.nutritionData.carbs.toInt()}${AppLocalizations.of(context)!.translate('unit_g')}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Fat
                              Flexible(
                                flex: 1,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🧈', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${foodLog.nutritionData.fat.toInt()}${AppLocalizations.of(context)!.translate('unit_g')}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(double progress, int progressPercent) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor: const Color(0xFFF0F0F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
              ),
            ),
            Text(
              '$progressPercent%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                'Home',
                Icons.home_rounded,
                false,
                onTap: () {
                  MixpanelService.trackButtonTap('Calorie Tracker Dashboard: Home Navigation');
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => MainScaffold(initialIndex: 0),
                    ),
                  );
                },
              ),
              const SizedBox(width: 60), // Space for FAB
              _buildNavItem(
                'Progress',
                Icons.bar_chart_rounded,
                false,
                onTap: () {
                  MixpanelService.trackButtonTap('Calorie Tracker Dashboard: Progress Navigation');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CalorieProgressScreen(),
                      settings: const RouteSettings(name: '/calorie_progress'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String label, IconData icon, bool isSelected, {VoidCallback? onTap}) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Icon(
              icon,
              color: isSelected ? Colors.black : const Color(0xFF8E8E93),
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.black : const Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFed3272), // Brand pink
            Color(0xFFfd5d32), // Brand orange
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: FloatingActionButton(
        onPressed: () {
          _showActivityPopup();
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  Stream<int> _getStreakCount() {
    return Stream.fromFuture(_calculateStreak());
  }

  Future<void> _retryFoodAnalysis(FoodLog failedLog) async {
    if (failedLog.id == null) return;
    
    try {
      MixpanelService.trackButtonTap('Retry Food Analysis', additionalProps: {
        'original_food_name': failedLog.foodName,
        'failure_reason': 'analysis_failed',
      });
      
      // For now, simple approach: delete the failed log and let user scan again
      // This is more reliable than trying to duplicate all food scanner analysis logic
      await _nutritionRepository.deleteFoodLog(failedLog.id!);
      debugPrint('🔄 Deleted failed food log: ${failedLog.id}');
      
              // Show activity popup so user can scan again
        _showActivityPopup();
      
    } catch (e) {
      debugPrint('Failed to retry food analysis: $e');
    }
  }

  Future<int> _calculateStreak() async {
    try {
      final now = DateTime.now();
      int streak = 0;
      
      for (int i = 0; i < 365; i++) {
        final date = now.subtract(Duration(days: i));
        final logs = await _nutritionRepository.getFoodLogsForDate(date).first;
        
        if (logs.isNotEmpty) {
          streak++;
        } else if (i == 0) {
          return 0;
        } else {
          break;
        }
      }
      
      return streak;
    } catch (e) {
      return 0;
    }
  }

  // Show branded refined sugar warning popup
  void _showRefinedSugarPopup(double totalRefinedSugar) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        AppLocalizations.of(context)!.translate('refinedSugar_popup_title'),
                        textAlign: TextAlign.left,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                  
                  // Body text with dynamic user limit
                  Text(
                    AppLocalizations.of(context)!.translate('refinedSugar_popup_body_with_limit')
                      .replaceAll('{userLimit}', _sugarGoalThreshold.toStringAsFixed(0)),
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 20),
                
                // Total refined sugar display (informational, not clickable)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3B30), size: 28),
                    const SizedBox(width: 12),
                    Text(
                      '${totalRefinedSugar.toStringAsFixed(1)}g',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF3B30),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.translate('calorieTracker_sugar').toLowerCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                  
                // Confirm button (Reset streak)
                GestureDetector(
                onTap: () async {
                  Navigator.of(dialogContext).pop();
                  _isShowingPopup = false;
                  
                  MixpanelService.trackButtonTap(
                    'Refined Sugar Popup: Confirm Reset',
                    additionalProps: {
                      'total_refined_sugar': totalRefinedSugar.toStringAsFixed(1),
                    },
                  );
                    
                    // Reset streak to zero
                    await _streakService.resetStreakCounter();
                    debugPrint('🔄 Streak reset due to refined sugar consumption');
                    
                    // Update accountability widget with new streak value (0 days)
                    await AccountabilityWidgetService.instance.updateWidget();
                    debugPrint('📱 Accountability widget updated with reset streak');
                    
                    // Mark popup as shown for today to prevent re-showing
                    debugPrint('🔒 Setting popup flag to TRUE after streak reset');
                    _sugarPopupShownForToday = true;
                    final prefs = await SharedPreferences.getInstance();
                    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    await prefs.setString('sugar_popup_last_shown_date', today);
                    debugPrint('✅ Sugar popup marked as shown for today after streak reset (flag: $_sugarPopupShownForToday)');
                    
                    // Show feedback
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.translate('common_streakReset'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: const Color(0xFFed3272), // Brand pink
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFed3272), // Brand pink
                          Color(0xFFfd5d32), // Brand orange
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.translate('refinedSugar_popup_confirm'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Decline button (Delete log)
                GestureDetector(
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    _isShowingPopup = false;
                    debugPrint('❌ Popup declined - food will be deleted (flag remains: $_sugarPopupShownForToday)');
                    
                    MixpanelService.trackButtonTap(
                      'Refined Sugar Popup: Decline Delete',
                      additionalProps: {
                        'total_refined_sugar': totalRefinedSugar.toStringAsFixed(1),
                      },
                    );
                    
                    // Delete the triggering food log
                    if (_lastTriggeringFoodLog != null && _lastTriggeringFoodLog!.id != null) {
                      try {
                        final logId = _lastTriggeringFoodLog!.id!;
                        
                        // Keep the ID in the processed set to prevent re-triggering during deletion propagation
                        // If user adds the food again later, it will have a new ID anyway
                        
                        await _nutritionRepository.deleteFoodLog(logId);
                        
                        // Delete associated image if exists
                        if (_lastTriggeringFoodLog!.imageUrl != null && _lastTriggeringFoodLog!.imageUrl!.isNotEmpty) {
                          try {
                            await _imageService.deleteImageFromStorage(logId);
                            debugPrint('✅ Deleted image for declined food log');
                          } catch (e) {
                            debugPrint('⚠️ Could not delete image: $e');
                          }
                        }
                        
                        debugPrint('✅ Deleted triggering food log: ${_lastTriggeringFoodLog!.foodName}');
                        
                        // Show feedback
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)!.translate('common_deleted'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: const Color(0xFFed3272), // Brand pink
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('❌ Error deleting food log: $e');
                      }
                    }
                    
                    _lastTriggeringFoodLog = null;
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.translate('refinedSugar_popup_decline'),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                ],
              ),
            ),
            // Close button (X icon) at top right
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _isShowingPopup = false;
                  debugPrint('❌ Popup dismissed via X button (flag remains: $_sugarPopupShownForToday)');
                  MixpanelService.trackButtonTap(
                    'Refined Sugar Popup: Dismiss',
                    additionalProps: {
                      'total_refined_sugar': totalRefinedSugar.toStringAsFixed(1),
                    },
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.close,
                    color: Color(0xFF666666),
                    size: 20,
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

  List<TextSpan> _buildLabelSpans(String label) {
    // Split the label to find "over", "left", "restante", "excedida", etc.
    final keywords = [
      'over', 'left', 'restante', 'restantes', 'excedida', 'excedido', 'excedidos',
      'en excès', 'überschritten', 'превышение', 'осталось', '超标', '剩余',
      'prekročené', 'prekročená', 'prekročený', 'zostávajúce', 'zostávajúci', 'zostávajúca',
      'překročené', 'překročená', 'překročený', 'zbývající'
    ];
    
    // Choose the LONGEST matching keyword to avoid partial bolding
    String keyword = '';
    for (final k in keywords) {
      final contains = label.toLowerCase().contains(k.toLowerCase());
      if (contains && k.length > keyword.length) {
        keyword = k;
      }
    }
    
    if (keyword.isEmpty) {
      return [TextSpan(text: label)];
    }
    
    // Find the position of the keyword (case-insensitive)
    final lowerLabel = label.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final index = lowerLabel.indexOf(lowerKeyword);
    
    if (index == -1) {
      return [TextSpan(text: label)];
    }
    
    final beforeKeyword = label.substring(0, index);
    final actualKeyword = label.substring(index, index + keyword.length);
    final afterKeyword = label.substring(index + keyword.length);
    
    return [
      if (beforeKeyword.isNotEmpty) TextSpan(text: beforeKeyword),
      TextSpan(
        text: actualKeyword,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
      if (afterKeyword.isNotEmpty) TextSpan(text: afterKeyword),
    ];
  }

  void _editWorkout(WorkoutLog workoutLog) {
    if (!_canEditDate(_selectedDate)) {
      debugPrint('❌ Cannot edit workout - date not editable: ${_selectedDate.toIso8601String().substring(0, 10)}');
      return; // Only allow editing within last 30 days
    }
    
    MixpanelService.trackButtonTap('Edit Workout', additionalProps: {
      'exercise_type': workoutLog.exerciseType,
      'from': 'calorie_tracker_dashboard',
    });
    
    // Navigate to appropriate setup screen based on exercise type
    if (workoutLog.exerciseType.toLowerCase().contains('run')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RunExerciseSetupScreen(
            targetDate: _selectedDate,
            editingWorkout: workoutLog,
          ),
        ),
      );
    } else if (workoutLog.exerciseType.toLowerCase().contains('weight')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WeightLiftingSetupScreen(
            targetDate: _selectedDate,
            editingWorkout: workoutLog,
          ),
        ),
      );
    } else {
      // Manual exercise
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ManualExerciseSetupScreen(
            targetDate: _selectedDate,
            editingWorkout: workoutLog,
          ),
        ),
      );
    }
  }
}

class _WeekDayRing extends StatelessWidget {
  const _WeekDayRing({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.dayLetter,
    required this.goals,
    required this.getSummary,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final String dayLetter;
  final NutritionGoals? goals;
  final Stream<DailySummary?> Function(DateTime) getSummary;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isFutureDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);
    return dd.isAfter(today);
  }

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFed3272), // Brand pink
              Color(0xFFfd5d32), // Brand orange
            ],
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            dayLetter,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Future days: solid light gray circle
    if (_isFutureDay(date)) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E5EA), width: 1.5),
        ),
        child: Center(
          child: Text(
            dayLetter,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
            ),
          ),
        ),
      );
    }

    // Today: gradient dashed circle using brand colors
    if (isToday) {
      return CustomPaint(
        painter: _DashedCirclePainter(color: const Color(0xFFed3272), strokeWidth: 2),
        child: Center(
          child: Text(
            dayLetter,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
            ),
          ),
        ),
      );
    }

    // Past days: check for any data (food logs or workout logs)
    return StreamBuilder<DailySummary?>(
      stream: getSummary(date),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        // Check if there's any data - either food calories or calories burned from workouts
        final hasFoodData = (summary?.totalCalories ?? 0) > 0;
        final hasWorkoutData = (summary?.totalCaloriesBurned ?? 0) > 0;
        final hasAnyData = hasFoodData || hasWorkoutData;

        if (!hasAnyData) {
          return CustomPaint(
            painter: _DashedCirclePainter(color: const Color(0xFFE5E5EA), strokeWidth: 1.5),
            child: Center(
              child: Text(
                dayLetter,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ),
          );
        }

        // If there's any data, show green border
        const Color borderColor = Color(0xFF34C759); // light green

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Center(
            child: Text(
              dayLetter,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color, this.strokeWidth = 2});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Rect rect = Offset.zero & size;
    final double inset = strokeWidth / 2;
    final Rect arcRect = Rect.fromLTWH(
      rect.left + inset,
      rect.top + inset,
      rect.width - strokeWidth,
      rect.height - strokeWidth,
    );

    // Draw dashed circle as many short arcs
    const double total = 6.28318530718; // 2*pi
    const double dash = 0.22; // radians length for dash
    const double gap = 0.12;  // radians gap
    double start = -1.57079632679; // start at top
    while (start < total - 1.57079632679 + 0.0001) {
      canvas.drawArc(arcRect, start, dash, false, paint);
      start += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _BrandProgressRing extends StatelessWidget {
  const _BrandProgressRing({super.key, required this.progress, this.strokeWidth = 8});
  final double progress;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    // Bind directly to progress so frequent rebuilds (from analyzing timers)
    // do not reset the tween and visually freeze the ring.
    // debugPrint('🟢 _BrandProgressRing build with progress: '
    //     '${(progress * 100).toStringAsFixed(1)}%');
    return CustomPaint(
      painter: _RingPainter(
        progress: progress,
        strokeWidth: strokeWidth,
        trackColor: const Color(0xFFEFF1F5),
        progressColor: const Color(0xFFed3272), // Brand pink CTA color
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double inset = strokeWidth / 2;
    final Rect arcRect = Rect.fromLTWH(
      rect.left + inset,
      rect.top + inset,
      rect.width - strokeWidth,
      rect.height - strokeWidth,
    );

    final Paint track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Track
    canvas.drawArc(arcRect, -1.57079632679, 6.28318530718, false, track);
    // Progress
    final double sweep = 6.28318530718 * progress.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(arcRect, -1.57079632679, sweep, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

class _CupGlass extends StatelessWidget {
  const _CupGlass({required this.fill, this.showPlus = false, this.showCheck = false});
  final double fill; // 0.0 - 1.0
  final bool showPlus;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final double clamped = fill.clamp(0.0, 1.0);
    return CustomPaint(
      painter: _GlassPainter(
        borderColor: Colors.white.withValues(alpha: 0.9),
        waterColor: const Color(0xFFB3E5FC), // light blue water
        fill: clamped,
      ),
      child: SizedBox(
        height: 74,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showPlus)
              const Icon(Icons.add, size: 18, color: Colors.white),
            if (showCheck)
              const Icon(Icons.check_circle, size: 24, color: Color(0xFF34C759)),
          ],
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  _GlassPainter({required this.borderColor, required this.waterColor, required this.fill});
  final Color borderColor;
  final Color waterColor;
  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final double topWidth = size.width * 0.7; // wider top, narrow bottom (normal glass)
    final double bottomWidth = size.width * 0.48;
    final double height = size.height * 0.82;
    final double topY = size.height * 0.06;
    final double leftX = (size.width - bottomWidth) / 2;
    final double topLeftX = (size.width - topWidth) / 2;

    final Path outline = Path()
      ..moveTo(topLeftX, topY)
      ..lineTo(topLeftX + topWidth, topY)
      ..lineTo(leftX + bottomWidth, topY + height)
      ..lineTo(leftX, topY + height)
      ..close();

    // Water level path
    final double waterH = height * fill;
    if (waterH > 0) {
      final double currentWidth = topWidth + (bottomWidth - topWidth) * (waterH / height);
      final double currentLeft = (size.width - currentWidth) / 2;
      final Path water = Path()
        ..moveTo(currentLeft, topY + height - waterH)
        ..lineTo(currentLeft + currentWidth, topY + height - waterH)
        ..lineTo(leftX + bottomWidth, topY + height)
        ..lineTo(leftX, topY + height)
        ..close();
      final Paint waterPaint = Paint()..color = waterColor;
      canvas.drawPath(water, waterPaint);
    }

    final Paint border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(outline, border);
  }

  @override
  bool shouldRepaint(covariant _GlassPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.waterColor != waterColor;
  }
}