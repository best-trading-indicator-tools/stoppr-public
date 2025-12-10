import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:stoppr/features/nutrition/data/models/daily_summary.dart';
import 'package:stoppr/features/nutrition/data/models/weight_entry.dart';
import 'package:stoppr/features/nutrition/data/models/body_profile.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/features/nutrition/presentation/screens/edit_weight_screen.dart';
import 'package:stoppr/features/nutrition/presentation/screens/calorie_tracker_dashboard.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/nutrition/presentation/screens/bmi_info_screen.dart';
import 'package:stoppr/features/nutrition/presentation/screens/edit_height_screen.dart';
import 'package:stoppr/features/nutrition/presentation/screens/edit_workout_habits_screen.dart';
import 'package:stoppr/features/nutrition/presentation/screens/workout_energy_info_screen.dart';
import 'package:stoppr/features/nutrition/presentation/screens/net_calories_info_screen.dart';
import 'package:stoppr/features/nutrition/presentation/screens/goal_weight_info_screen.dart';

class CalorieProgressScreen extends StatefulWidget {
  const CalorieProgressScreen({super.key});

  @override
  State<CalorieProgressScreen> createState() => _CalorieProgressScreenState();
}

class _CalorieProgressScreenState extends State<CalorieProgressScreen> {
  final _repo = NutritionRepository();

  // Period selection for goal progress
  int _periodIndex = 0; // 0:90d 1:6m 2:1y 3:all
  // Week selection for stacked bars
  int _weekIndex = 0; // 0:this,1:last,2:2w,3:3w

  BodyProfile? _profile;
  WeightEntry? _latestWeight;
  List<DailySummary> _rangeSummaries = [];

  // Workout habits (raw fields from body profile)
  double? _workoutsPerWeek;
  int? _avgWorkoutMinutes;
  String? _workoutStyle;

  // Unit preferences
  bool _isWeightMetric = true; // kg vs lbs
  bool _isHeightMetric = true; // cm vs inches

  // Stream subscriptions for proper disposal
  StreamSubscription<BodyProfile?>? _bodyProfileSubscription;
  StreamSubscription<WeightEntry?>? _latestWeightSubscription;
  StreamSubscription<Map<String, dynamic>?>? _bodyProfileRawSubscription;

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('Calorie Progress Screen');
    _loadUnitPreferences();
    _bodyProfileSubscription = _repo.getBodyProfile().listen((p) {
      if (mounted) setState(() => _profile = p);
    });
    _latestWeightSubscription = _repo.streamLatestWeight().listen((w) {
      if (mounted) setState(() => _latestWeight = w);
    });
    _bodyProfileRawSubscription = _repo.streamBodyProfileRaw().listen((data) {
      if (!mounted || data == null) return;
      setState(() {
        final wpw = data['workoutsPerWeek'];
        if (wpw != null) {
          _workoutsPerWeek = (wpw is num) ? wpw.toDouble() : double.tryParse('$wpw');
        }
        final avg = data['avgWorkoutMinutes'];
        if (avg != null) {
          _avgWorkoutMinutes = (avg is num) ? avg.toInt() : int.tryParse('$avg');
        }
        final sty = data['workoutStyle'];
        if (sty != null) _workoutStyle = '$sty';
      });
    });
    _loadRange();
  }

  void _loadUnitPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isWeightMetric = prefs.getBool('weight_unit_metric') ?? true;
        _isHeightMetric = prefs.getBool('height_unit_metric') ?? true;
      });
    }
  }

  // Weight conversion helpers
  String _formatWeight(double? weightKg) {
    if (weightKg == null) return AppLocalizations.of(context)!.translate('calorieTracker_noDataYet');
    
    if (_isWeightMetric) {
      return '${weightKg.toStringAsFixed(1)} kg';
    } else {
      final weightLbs = weightKg * 2.20462;
      return '${weightLbs.toStringAsFixed(1)} lbs';
    }
  }

  // Height conversion helpers
  String _formatHeight(double? heightCm) {
    if (heightCm == null) return AppLocalizations.of(context)!.translate('calorieTracker_noDataYet');
    
    if (_isHeightMetric) {
      return '${heightCm.toStringAsFixed(0)} ${AppLocalizations.of(context)!.translate('unit_cm')}';
    } else {
      final totalIn = (heightCm / 2.54).round();
      final ft = totalIn ~/ 12;
      final inches = totalIn % 12;
      return '$ft\' $inches"';
    }
  }

  void _loadRange() async {
    final now = DateTime.now();
    DateTime start;
    switch (_periodIndex) {
      case 1:
        start = DateTime(now.year, now.month - 6, now.day);
        break;
      case 2:
        start = DateTime(now.year - 1, now.month, now.day);
        break;
      case 3:
        start = now.subtract(const Duration(days: 3650));
        break;
      default:
        start = now.subtract(const Duration(days: 90));
    }
    final list = await _repo.getDailySummariesInRange(start, now);
    if (mounted) setState(() => _rangeSummaries = list);
  }

  @override
  void dispose() {
    _bodyProfileSubscription?.cancel();
    _latestWeightSubscription?.cancel();
    _bodyProfileRawSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      MixpanelService.trackButtonTap('Calorie Progress Screen: Back Button');
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const CalorieTrackerDashboard(),
                          settings: const RouteSettings(name: '/calorie_tracker_dashboard'),
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
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(AppLocalizations.of(context)!.translate('calorieTracker_progress'), style: text.displaySmall?.copyWith(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: -0.8)),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 16),
              _topCards(),
              const SizedBox(height: 16),
              // _periodSelector(),
              // const SizedBox(height: 8),
              // _goalProgressChart(),
              // const SizedBox(height: 16),
              _weekSelector(),
              const SizedBox(height: 8),
              _stackedCaloriesWeekChart(),
              const SizedBox(height: 16),
              _bmiCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topCards() {
    final latest = _latestWeight?.weightKg;
    final goal = _profile?.goalWeightKg;
    final heightCm = _profile?.heightCm;
    return Column(
      children: [
        // Weight card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4), spreadRadius: -2)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.translate('calorieTracker_myWeight'), 
                    style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                  ),
                ),
                IconButton(
                  onPressed: _showGoalWeightInfo,
                  icon: const Icon(Icons.info_outline, color: Colors.black),
                  tooltip: AppLocalizations.of(context)!.translate('common_info'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _formatWeight(latest),
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.w700, 
                      color: latest != null ? Colors.black : const Color(0xFF8E8E93),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (goal != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFed3272), // Strong pink/magenta
                            Color(0xFFfd5d32), // Vivid orange
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${AppLocalizations.of(context)!.translate('calorieTracker_goal')} ${_formatWeight(goal)}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272), // Strong pink/magenta
                      Color(0xFFfd5d32), // Vivid orange
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    MixpanelService.trackButtonTap('Calorie Progress Screen: Log Weight Button');
                    _openEditWeight();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(AppLocalizations.of(context)!.translate('calorieTracker_logWeight'), style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // Height card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4), spreadRadius: -2)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppLocalizations.of(context)!.translate('calorieTracker_myHeight'), style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text(
                  _formatHeight(heightCm),
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.w700, 
                    color: heightCm != null ? Colors.black : const Color(0xFF8E8E93),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272), // Strong pink/magenta
                      Color(0xFFfd5d32), // Vivid orange
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    MixpanelService.trackButtonTap('Calorie Progress Screen: Log Height Button');
                    _openEditHeight();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(AppLocalizations.of(context)!.translate('calorieTracker_logHeight'), style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // Workout habits card
        Container(
          width: double.infinity,
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.translate('workout_card_title'),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                  ),
                ),
                IconButton(
                  onPressed: _showWorkoutInfo,
                  icon: const Icon(Icons.info_outline, color: Colors.black),
                  tooltip: AppLocalizations.of(context)!.translate('common_info'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _workoutsPerWeek != null
                          ? '${AppLocalizations.of(context)!.translate('workout_workoutsPerWeek')}: ${_workoutsPerWeek!.toStringAsFixed(1)}'
                          : AppLocalizations.of(context)!.translate('calorieTracker_noDataYet'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _workoutsPerWeek != null ? Colors.black : const Color(0xFF8E8E93),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (_avgWorkoutMinutes != null)
                      Text(
                        '${AppLocalizations.of(context)!.translate('workout_avgDuration')}: ${_avgWorkoutMinutes} ${AppLocalizations.of(context)!.translate('workout_unit_min')}',
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (_workoutStyle != null)
                      Text(
                        '${AppLocalizations.of(context)!.translate('workout_style')}: ${_localizedStyle(_workoutStyle!)}',
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (_workoutsPerWeek != null)
                      Text(
                        '${AppLocalizations.of(context)!.translate('workout_activityLevel')}: ${_activityLevelLabel(_workoutsPerWeek!)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (_estimatedWeeklyKcal() != null)
                      Text(
                        '${AppLocalizations.of(context)!.translate('workout_estimatedExpenditure')}: ~${_estimatedWeeklyKcal()!.round()} kcal/week (≈ ${(_estimatedWeeklyKcal()! / 7).round()} kcal/day)',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272), // Strong pink/magenta
                      Color(0xFFfd5d32), // Vivid orange
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    MixpanelService.trackButtonTap('Calorie Progress Screen: Log Workouts Button');
                    _openEditWorkouts();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(
                        AppLocalizations.of(context)!.translate('workout_log'),
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  String _localizedStyle(String raw) {
    switch (raw) {
      case 'cardio':
        return AppLocalizations.of(context)!.translate('workout_style_cardio');
      case 'strength':
        return AppLocalizations.of(context)!.translate('workout_style_strength');
      case 'hiit':
        return AppLocalizations.of(context)!.translate('workout_style_hiit');
      case 'yoga':
        return AppLocalizations.of(context)!.translate('workout_style_yoga');
      case 'mixed':
      default:
        return AppLocalizations.of(context)!.translate('workout_style_mixed');
    }
  }

  void _openEditWorkouts() async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EditWorkoutHabitsScreen(),
        settings: const RouteSettings(name: '/edit_workout_habits'),
      ),
    );
    if (updated == true && mounted) {
      setState(() {});
    }
  }

  String _activityLevelLabel(double wpw) {
    if (wpw <= 1) return AppLocalizations.of(context)!.translate('activity_sedentary');
    if (wpw <= 3) return AppLocalizations.of(context)!.translate('activity_light');
    if (wpw <= 5) return AppLocalizations.of(context)!.translate('activity_moderate');
    if (wpw <= 7) return AppLocalizations.of(context)!.translate('activity_very');
    return AppLocalizations.of(context)!.translate('activity_extra');
  }

  double? _estimatedWeeklyKcal() {
    if (_workoutsPerWeek == null || _avgWorkoutMinutes == null || _latestWeight?.weightKg == null || _workoutStyle == null) return null;
    
    // Apply reasonable bounds to prevent unrealistic calculations
    final double weightKg = _latestWeight!.weightKg.clamp(30.0, 300.0); // 30-300kg
    final int minutes = _avgWorkoutMinutes!.clamp(1, 300); // 1-300 minutes per session
    final double workoutsPerWeek = _workoutsPerWeek!.clamp(0.1, 21.0); // 0.1-21 workouts per week
    
    final double met = () {
      switch (_workoutStyle) {
        case 'cardio':
          return 8.0;
        case 'strength':
          return 6.0;
        case 'hiit':
          return 9.0;
        case 'yoga':
          return 3.0;
        default:
          return 6.5;
      }
    }();
    final perSession = met * 3.5 * weightKg * minutes / 200.0;
    final weeklyTotal = perSession * workoutsPerWeek;
    
    // Cap weekly burn at 10,000 calories to prevent unrealistic values
    return weeklyTotal.clamp(0.0, 10000.0);
  }

  void _showWorkoutInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WorkoutEnergyInfoScreen(),
        settings: const RouteSettings(name: '/workout_energy_info'),
      ),
    );
  }

  Widget _periodSelector() {
    final labels = [AppLocalizations.of(context)!.translate('calorieTracker_90Days'), AppLocalizations.of(context)!.translate('calorieTracker_6Months'), AppLocalizations.of(context)!.translate('calorieTracker_1Year'), AppLocalizations.of(context)!.translate('calorieTracker_allTime')];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: List.generate(4, (i) {
        final sel = i == _periodIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              MixpanelService.trackButtonTap('Calorie Progress Screen: Period Selector', 
                additionalProps: {
                  'period_index': i.toString(),
                  'period_label': labels[i],
                });
              setState(() => _periodIndex = i);
              _loadRange();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: sel ? const Color(0xFFF5F5F7) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(labels[i], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sel ? Colors.black : const Color(0xFF8E8E93))),
            ),
          ),
        );
      })),
    );
  }

  Widget _goalProgressChart() {
    final List<FlSpot> spots = _weightSpots();
    final double? goal = _profile?.goalWeightKg;
    final bool hasData = spots.isNotEmpty && goal != null;

    return Container(
      height: 240,
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
      child: hasData
          ? Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  child: _GoalBadge(spots.last.y, goal!),
                ),
                LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 2,
                    ),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: (goal! - 6).clamp(0, double.infinity),
                    maxY: goal + 6,
                    lineBarsData: [
                      // Goal reference line
                      LineChartBarData(
                        isCurved: false,
                        color: const Color(0xFFDDDDDD),
                        barWidth: 2,
                        spots: [
                          FlSpot(0, goal),
                          FlSpot((spots.last.x).clamp(1, 100), goal),
                        ],
                        dotData: const FlDotData(show: false),
                      ),
                      // Weight trend
                      LineChartBarData(
                        isCurved: true,
                        color: Colors.black,
                        barWidth: 2,
                        spots: spots,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                AppLocalizations.of(context)!.translate('calorieTracker_gettingStartedMotivation'),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
    );
  }

  List<FlSpot> _weightSpots() {
    if (_latestWeight == null) return [];
    // Placeholder: single-point series using latest weight, x scaled to 1
    return [FlSpot(1, _latestWeight!.weightKg.toDouble())];
  }

  Widget _weekSelector() {
    final labels = [AppLocalizations.of(context)!.translate('calorieTracker_thisWeek'), AppLocalizations.of(context)!.translate('calorieTracker_lastWeek'), AppLocalizations.of(context)!.translate('calorieTracker_2WeeksAgo'), AppLocalizations.of(context)!.translate('calorieTracker_3WeeksAgo')];
    return Row(children: List.generate(4, (i) {
      final sel = i == _weekIndex;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            MixpanelService.trackButtonTap('Calorie Progress Screen: Week Selector', 
              additionalProps: {
                'week_index': i.toString(),
                'week_label': labels[i],
              });
            setState(() => _weekIndex = i);
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: sel ? Colors.white : const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(labels[i], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sel ? Colors.black : const Color(0xFF8E8E93))),
          ),
        ),
      );
    }));
  }

  Widget _stackedCaloriesWeekChart() {
    // Aggregate from _rangeSummaries; filter by selected week relative to current
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: (now.weekday - 1) + _weekIndex * 7));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    bool _inRange(String yyyymmdd, DateTime start, DateTime end) {
      final y = int.parse(yyyymmdd.substring(0, 4));
      final m = int.parse(yyyymmdd.substring(4, 6));
      final d = int.parse(yyyymmdd.substring(6, 8));
      final dt = DateTime(y, m, d);
      return !dt.isBefore(start) && dt.isBefore(end);
    }

    final week = _rangeSummaries.where((s) => _inRange(s.date, startOfWeek, endOfWeek)).toList();
    final prevStart = startOfWeek.subtract(const Duration(days: 7));
    final prevEnd = startOfWeek;
    final prevWeek = _rangeSummaries.where((s) => _inRange(s.date, prevStart, prevEnd)).toList();

    // Build bar groups and totals
    double weeklyTotal = 0;
    List<BarChartGroupData> groups = List.generate(7, (i) {
      final day = startOfWeek.add(Duration(days: i));
      final id = '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
      final s = week.firstWhere(
        (w) => w.date == id,
        orElse: () => DailySummary(date: id, userId: '', totalCalories: 0, totalProtein: 0, totalCarbs: 0, totalFat: 0, totalSugar: 0, totalFiber: 0, totalSodium: 0, updatedAt: DateTime.now()),
      );
      final proteinCals = s.totalProtein * 4;
      final carbCals = s.totalCarbs * 4;
      final fatCals = s.totalFat * 9;
      final total = proteinCals + carbCals + fatCals;
      weeklyTotal += total;
      return BarChartGroupData(
        x: i,
        barsSpace: 2,
        barRods: [
          BarChartRodData(
            toY: total,
            rodStackItems: [
              BarChartRodStackItem(0, proteinCals, const Color(0xFFE57373)),
              BarChartRodStackItem(proteinCals, proteinCals + carbCals, const Color(0xFFFFB74D)),
              BarChartRodStackItem(proteinCals + carbCals, total, const Color(0xFF64B5F6)),
            ],
            width: 14,
            borderRadius: BorderRadius.circular(4),
            color: Colors.transparent,
          ),
        ],
      );
    });

    // Previous-period total for delta (current tab - 1 period)
    final prevTotal = prevWeek.fold<double>(0, (sum, s) => sum + s.totalProtein * 4 + s.totalCarbs * 4 + s.totalFat * 9);
    final deltaPct = prevTotal > 0 ? ((weeklyTotal - prevTotal) / prevTotal * 100) : 0;
    final bool deltaUp = deltaPct >= 0;
    final deltaStr = NumberFormat.decimalPercentPattern(decimalDigits: 0).format(deltaPct / 100);

    // Workout energy reference (for pills, not line)
    final double weeklyBurn = _estimatedWeeklyKcal() ?? 0;

    final bottomLabels = [
      AppLocalizations.of(context)!.translate('common_day_monday_short'),
      AppLocalizations.of(context)!.translate('common_day_tuesday_short'),
      AppLocalizations.of(context)!.translate('common_day_wednesday_short'),
      AppLocalizations.of(context)!.translate('common_day_thursday_short'),
      AppLocalizations.of(context)!.translate('common_day_friday_short'),
      AppLocalizations.of(context)!.translate('common_day_saturday_short'),
      AppLocalizations.of(context)!.translate('common_day_sunday_short'),
    ];

    // Adaptive Y axis scaling: choose a "nice" ceiling close to data to
    // keep small values visually meaningful (zoom in when totals are small).
    final maxBar = groups.fold<double>(0, (m, g) =>
        g.barRods.isEmpty ? m : (g.barRods.first.toY > m ? g.barRods.first.toY : m));
    double niceCeil(double v) {
      final double target = v <= 0 ? 100 : v;
      const List<int> candidates = <int>[
        50, 75, 100, 125, 150, 200, 250, 300, 400, 500,
        750, 1000, 1500, 2000, 3000, 4000, 6000, 8000,
      ];
      for (final c in candidates) {
        if (target <= c) return c.toDouble();
      }
      // Fallback for very large values
      return ((target / 1000).ceil() * 1000).toDouble();
    }
    // Do not include burn in scaling to keep bars readable
    final double baseMax = maxBar;
    final maxY = niceCeil(baseMax == 0 ? 100 : baseMax * 1.2);
    final step = maxY / 3;

    return Container(
      height: 360,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (wrapped to avoid horizontal overflow)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!
                          .translate('calorieTracker_totalCalories'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(height: 4),
                    // Delta directly under title, tight spacing
                    Row(
                      children: [
                        Icon(
                          deltaUp
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 16,
                          color: deltaUp
                              ? const Color(0xFF34C759)
                              : const Color(0xFFFF3B30),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          deltaStr,
                          style: TextStyle(
                            color: deltaUp
                                ? const Color(0xFF34C759)
                                : const Color(0xFFFF3B30),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Total row immediately under delta
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.decimalPattern().format(weeklyTotal),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context)!
                              .translate('calorieTracker_cals'),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.black),
                    tooltip: AppLocalizations.of(context)!.translate('common_info'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NetCaloriesInfoScreen(),
                          settings:
                              const RouteSettings(name: '/net_calories_info'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  () {
                    final net = weeklyTotal - weeklyBurn;
                    return _StatPill(
                      label: AppLocalizations.of(context)!
                          .translate('calorieTracker_net'),
                      value:
                          '${net.round()} ${AppLocalizations.of(context)!.translate('calorieTracker_cals')}',
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFed3272), // Strong pink/magenta
                          Color(0xFFfd5d32), // Vivid orange
                        ],
                      ),
                      foreground: Colors.white,
                      large: false,
                    );
                  }(),
                  const SizedBox(height: 10),
                  _StatPill(
                    label: AppLocalizations.of(context)!
                        .translate('calorieTracker_burned'),
                    value:
                        '${weeklyBurn.round()} ${AppLocalizations.of(context)!.translate('calorieTracker_cals')}',
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272), // Strong pink/magenta
                        Color(0xFFfd5d32), // Vivid orange
                      ],
                    ),
                    foreground: Colors.white,
                    large: false,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 10),
          // Numbers moved to the right column; keep small spacing before chart
          const SizedBox(height: 10),
          // Chart
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: step),
                extraLinesData: const ExtraLinesData(horizontalLines: []),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: step,
                      getTitlesWidget: (value, meta) {
                        if (value < 0) return const SizedBox.shrink();
                        return Text(value.round().toString(),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(bottomLabels[i], style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: groups,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: const Color(0xFFE57373), label: AppLocalizations.of(context)!.translate('calorieTracker_protein')),
              SizedBox(width: 16),
              _LegendDot(color: const Color(0xFFFFB74D), label: AppLocalizations.of(context)!.translate('calorieTracker_carbs')),
              SizedBox(width: 16),
              _LegendDot(color: const Color(0xFF64B5F6), label: AppLocalizations.of(context)!.translate('calorieTracker_fat')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bmiCard() {
    final h = _profile?.heightCm;
    final w = _latestWeight?.weightKg;
    double? bmi;
    String status = '';
    Color statusColor = const Color(0xFF34C759);
    Color statusBgColor = const Color(0xFFE7F8EA);
    
    if (h != null && w != null && h > 0) {
      final m = h / 100.0;
      bmi = w / (m * m);
      if (bmi < 18.5) {
        status = AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_underweight');
        statusColor = const Color(0xFFFF9500); // Orange
        statusBgColor = const Color(0xFFFFF3E0); // Light orange
      } else if (bmi < 25) {
        status = AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_healthy');
        statusColor = const Color(0xFF34C759); // Green
        statusBgColor = const Color(0xFFE7F8EA); // Light green
      } else if (bmi < 30) {
        status = AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_overweight');
        statusColor = const Color(0xFFFF9500); // Orange
        statusBgColor = const Color(0xFFFFF3E0); // Light orange
      } else {
        status = AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_obese');
        statusColor = const Color(0xFFFF3B30); // Red
        statusBgColor = const Color(0xFFFFEBEA); // Light red
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4), spreadRadius: -2)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(AppLocalizations.of(context)!.translate('calorieTracker_yourBMI'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            onPressed: () {
              MixpanelService.trackButtonTap('Calorie Progress Screen: BMI Info Button');
              _showBmiInfo();
            }, 
            icon: const Icon(Icons.info_outline)
          )
        ]),
        const SizedBox(height: 6),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
          Text(bmi != null ? bmi.toStringAsFixed(1) : '--', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black)),
          if (bmi != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(12)), child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        Container(height: 10, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E90FF), Color(0xFF00C853), Color(0xFFFFC107), Color(0xFFFF5252)]), borderRadius: BorderRadius.circular(6))),
      ]),
    );
  }

  void _openEditWeight() async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditWeightScreen(initialKg: _latestWeight?.weightKg),
        settings: const RouteSettings(name: '/edit_weight'),
      ),
    );
    if (updated == true && mounted) {
      final latest = await _repo.streamLatestWeight().first;
      if (mounted) setState(() => _latestWeight = latest);
      _loadUnitPreferences(); // Reload unit preferences
    }
  }

  void _openEditHeight() async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditHeightScreen(
          initialCm: _profile?.heightCm,
          currentGoalWeightKg: _profile?.goalWeightKg,
        ),
        settings: const RouteSettings(name: '/edit_height'),
      ),
    );
    if (updated == true && mounted) {
      // Profile stream will update automatically; no-op
      setState(() {});
      _loadUnitPreferences(); // Reload unit preferences
    }
  }

  void _showBmiInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BmiInfoScreen(),
        settings: const RouteSettings(name: '/bmi_info'),
      ),
    );
  }

  void _showGoalWeightInfo() {
    MixpanelService.trackButtonTap('Calorie Progress Screen: Goal Weight Info Button');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GoalWeightInfoScreen(),
        settings: const RouteSettings(name: '/goal_weight_info'),
      ),
    );
  }
}


class _GoalBadge extends StatelessWidget {
  const _GoalBadge(this.current, this.goal);
  final double current;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final pct = ((current / goal) * 100).clamp(0, 999).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('$pct% ${AppLocalizations.of(context)!.translate('calorieTracker_ofGoal')}', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    this.background,
    this.gradient,
    required this.foreground,
    this.large = false,
    this.maxWidth,
  });
  final String label;
  final String value;
  final Color? background;
  final LinearGradient? gradient;
  final Color foreground;
  final bool large;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10, vertical: large ? 10 : 6),
      decoration: BoxDecoration(
        color: gradient == null ? background : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: large
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: large ? 14 : 12, fontWeight: FontWeight.w700, color: foreground)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: large ? 14 : 12, color: foreground)),
        ],
      ),
    );
    if (maxWidth != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: content,
      );
    }
    return content;
  }
}

