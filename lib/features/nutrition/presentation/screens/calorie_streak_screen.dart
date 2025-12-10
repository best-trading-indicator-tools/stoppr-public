import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:stoppr/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:stoppr/features/nutrition/data/models/food_log.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

class CalorieStreakScreen extends StatefulWidget {
  const CalorieStreakScreen({super.key});

  @override
  State<CalorieStreakScreen> createState() => _CalorieStreakScreenState();
}

class _CalorieStreakScreenState extends State<CalorieStreakScreen> {
  final _nutritionRepository = NutritionRepository();

  int _streakDays = 0;
  List<bool> _last7Days = List<bool>.filled(7, false);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    MixpanelService.trackPageView('Calorie Streak Screen');
    _loadData();
  }

  Future<void> _loadData() async {
    // Calculate current streak (max 365 days back)
    final now = DateTime.now();
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final logs = await _nutritionRepository.getFoodLogsForDate(date).first;
      if (logs.isNotEmpty) {
        streak++;
      } else {
        break;
      }
    }

    // Load current week (Monday -> Sunday) activity
    final List<bool> days = [];
    final todayAtMidnight = DateTime(now.year, now.month, now.day);
    final startOfWeek = todayAtMidnight
        .subtract(Duration(days: todayAtMidnight.weekday - DateTime.monday));
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final logs = await _nutritionRepository.getFoodLogsForDate(date).first;
      days.add(logs.isNotEmpty);
    }

    if (!mounted) return;
    setState(() {
      _streakDays = streak;
      _last7Days = days;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayAtMidnight = DateTime(now.year, now.month, now.day);
    final startOfWeek = todayAtMidnight
        .subtract(Duration(days: todayAtMidnight.weekday - DateTime.monday));
    final weekLabels = List.generate(7, (i) {
      final d = startOfWeek.add(Duration(days: i));
      return DateFormat.E().format(d).substring(0, 1);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            MixpanelService.trackButtonTap('Calorie Streak Screen: Back Button');
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('calorieTracker_calorieStreak'),
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Text('🔥', style: TextStyle(fontSize: 28))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.translate('calorieTracker_currentStreak'),
                          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                        ),
                        Text(
                          '$_streakDays ${_getCalorieDaysSuffix(_streakDays, AppLocalizations.of(context)!)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.translate('calorieTracker_thisWeek'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  // Monday-first order (already aligned with _last7Days)
                  final index = i;
                  final active = _last7Days[index];
                  return Column(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFFed3272) : const Color(0xFFE6E6EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        weekLabels[index],
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.translate('calorieTracker_tip'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.translate('calorieTracker_streakTip'),
              style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
            ),
          ],
        ),
      ),
    );
  }

  String _getCalorieDaysSuffix(int days, AppLocalizations l10n) {
    if (days == 1) {
      return l10n.translate('calorieTracker_day');
    } else if (days >= 2 && days <= 4 && l10n.locale.languageCode == 'cs') {
      return l10n.translate('calorieTracker_days_few');
    } else {
      return l10n.translate('calorieTracker_days');
    }
  }
}


