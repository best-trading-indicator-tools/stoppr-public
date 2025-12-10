import 'package:flutter/material.dart';
import '../../../../core/streak/app_open_streak_service.dart';
import '../../../../core/localization/app_localizations.dart';

class WeeklyTrackerWidget extends StatelessWidget {
  final AppOpenStreakData streakData;
  
  const WeeklyTrackerWidget({
    super.key,
    required this.streakData,
  });

  @override
  Widget build(BuildContext context) {
    final currentDay = DateTime.now().weekday;
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          // Standard week order starting with Monday
          final dayOrder = [1, 2, 3, 4, 5, 6, 7]; // M T W T F S S
          final weekday = dayOrder[index];
          final isToday = weekday == currentDay;
          final isCompleted = streakData.weeklyOpens[weekday] ?? false;
          
          return _DayCircle(
            day: _getDayLabel(context, weekday),
            isCompleted: isCompleted,
            isToday: isToday,
          );
        }),
      ),
    );
  }
  
  String _getDayLabel(BuildContext context, int weekday) {
    final l10n = AppLocalizations.of(context)!;
    switch (weekday) {
      case 1:
        return l10n.translate('common_day_monday_letter');
      case 2:
        return l10n.translate('common_day_tuesday_letter');
      case 3:
        return l10n.translate('common_day_wednesday_letter');
      case 4:
        return l10n.translate('common_day_thursday_letter');
      case 5:
        return l10n.translate('common_day_friday_letter');
      case 6:
        return l10n.translate('common_day_saturday_letter');
      case 7:
        return l10n.translate('common_day_sunday_letter');
      default:
        return '';
    }
  }
}

class _DayCircle extends StatelessWidget {
  final String day;
  final bool isCompleted;
  final bool isToday;
  
  const _DayCircle({
    required this.day,
    required this.isCompleted,
    required this.isToday,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isToday 
              ? const Color(0xFFed3272) // Brand pink for current day
              : Colors.transparent,
            border: Border.all(
              color: isCompleted && !isToday
                ? const Color(0xFFed3272) // Brand pink for completed days
                : isToday
                  ? const Color(0xFFed3272) // Brand pink for current day
                  : const Color(0xFFE0E0E0), // Light gray border for future days
              width: 1.5,
            ),
          ),
          child: Center(
            child: isCompleted && !isToday
              ? Icon(
                  Icons.check,
                  color: const Color(0xFFed3272), // Brand pink checkmark
                  size: 18,
                )
              : isToday
                ? Container(
                    width: 12,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  )
                : null, // Empty for future/incomplete days
          ),
        ),
        const SizedBox(height: 4),
        Text(
          day,
          style: const TextStyle(
            color: Color(0xFF666666), // Gray text for white background
            fontSize: 12,
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
