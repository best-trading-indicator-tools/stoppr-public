import 'package:flutter/material.dart';
import 'dart:math';
import '../../../../core/streak/streak_service.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:stoppr/app/theme/colors.dart';
import '../screens/home_screen.dart';

class ActionButton {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  
  const ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class StreakCounterWidget extends StatefulWidget {
  final bool showResetButton;
  final Function()? onReset;
  final double daysTextSize;
  final bool showStars;
  final List<ActionButton>? actionButtons;
  
  const StreakCounterWidget({
    super.key,
    this.showResetButton = true,
    this.onReset,
    this.daysTextSize = 60,
    this.showStars = true,
    this.actionButtons,
  });

  @override
  State<StreakCounterWidget> createState() => _StreakCounterWidgetState();
}

class _StreakCounterWidgetState extends State<StreakCounterWidget> {
  final StreakService _streakService = StreakService();
  
  @override
  void initState() {
    super.initState();
  }
  
  String _getTimeDisplay(StreakData streakData) {
    final l10n = AppLocalizations.of(context)!;
    
    if (streakData.days > 0) {
      // If more than a day, use format: 23hr 58m 17s
      final hoursUnit = streakData.hours == 1 ? l10n.translate('common_hour_singular') : l10n.translate('common_hours_plural');
      final minutesUnit = streakData.minutes == 1 ? l10n.translate('common_minute_singular') : l10n.translate('common_minutes_plural');
      final secondsUnit = streakData.seconds == 1 ? l10n.translate('common_second_singular') : l10n.translate('common_seconds_plural');
      return '${streakData.hours}$hoursUnit ${streakData.minutes}$minutesUnit ${streakData.seconds}$secondsUnit';
    } else if (streakData.hours > 0) {
      // If more than an hour but less than a day
      final hoursUnit = streakData.hours == 1 ? l10n.translate('common_hour_singular') : l10n.translate('common_hours_plural');
      final minutesUnit = streakData.minutes == 1 ? l10n.translate('common_minute_singular') : l10n.translate('common_minutes_plural');
      final secondsUnit = streakData.seconds == 1 ? l10n.translate('common_second_singular') : l10n.translate('common_seconds_plural');
      return '${streakData.hours}$hoursUnit ${streakData.minutes}$minutesUnit ${streakData.seconds}$secondsUnit';
    } else if (streakData.minutes > 0) {
      // If more than a minute but less than an hour
      final minutesUnit = streakData.minutes == 1 ? l10n.translate('common_minute_singular') : l10n.translate('common_minutes_plural');
      final secondsUnit = streakData.seconds == 1 ? l10n.translate('common_second_singular') : l10n.translate('common_seconds_plural');
      return '${streakData.minutes}$minutesUnit ${streakData.seconds}$secondsUnit';
    } else {
      // If less than a minute, show only seconds
      final secondsUnit = streakData.seconds == 1 ? l10n.translate('common_second_singular') : l10n.translate('common_seconds_plural');
      return '${streakData.seconds}$secondsUnit';
    }
  }

  Widget _buildTimeDisplay(StreakData streakData) {
    final l10n = AppLocalizations.of(context)!;
    if (streakData.days > 0) {
      // If more than a day, show days as main counter
      return Column(
        children: [
          Text(
            '${streakData.days}${_getDaysSuffix(streakData.days, l10n)}',
            style: TextStyle(
              color: HomeScreenColors.primaryText, // Dark text for white background
              fontSize: widget.daysTextSize,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: HomeScreenColors.buttonBackground, // Darker gray background for visibility
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _getTimeDisplay(streakData),
              style: const TextStyle(
                color: HomeScreenColors.primaryText, // Dark text for light background
                fontSize: 18,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    } else if (streakData.hours > 0) {
      // If more than an hour but less than a day
      return Column(
        children: [
          // Hours and minutes display
          Text(
            '${streakData.hours}${streakData.hours == 1 ? l10n.translate('common_hour_singular') : l10n.translate('common_hours_plural')} ${streakData.minutes}${streakData.minutes == 1 ? l10n.translate('common_minute_singular') : l10n.translate('common_minutes_plural')}',
            style: const TextStyle(
              color: HomeScreenColors.primaryText, // Dark text for white background
              fontSize: 40,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          // Seconds with purple background
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: HomeScreenColors.buttonBackground, // Darker gray background for visibility
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${streakData.seconds}${streakData.seconds == 1 ? l10n.translate('common_second_singular') : l10n.translate('common_seconds_plural')}',
              style: const TextStyle(
                color: HomeScreenColors.primaryText, // Dark text for light background
                fontSize: 24,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    } else {
      // If less than an hour, show minutes prominently with seconds in purple background
      return Column(
        children: [
          // Minutes display
          Text(
            '${streakData.minutes}${streakData.minutes == 1 ? l10n.translate('common_minute_singular') : l10n.translate('common_minutes_plural')}',
            style: const TextStyle(
              color: HomeScreenColors.primaryText, // Dark text for white background
              fontSize: 50,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          // Seconds with purple background
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: HomeScreenColors.buttonBackground, // Darker gray background for visibility
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${streakData.seconds}${streakData.seconds == 1 ? l10n.translate('common_second_singular') : l10n.translate('common_seconds_plural')}',
              style: const TextStyle(
                color: HomeScreenColors.primaryText, // Dark text for light background
                fontSize: 24,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StreakData>(
      stream: _streakService.streakStream,
      initialData: _streakService.currentStreak,
      builder: (context, snapshot) {
        final streakData = snapshot.data ?? 
            const StreakData(days: 0, hours: 0, minutes: 0, seconds: 0, startTime: null);
        
        return SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              
              // Time display
              _buildTimeDisplay(streakData),
              
              // Add fixed spacing instead of Spacer
              const SizedBox(height: 30),
              
              // Action buttons
              if (widget.actionButtons != null && widget.actionButtons!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: widget.actionButtons!.map((button) => 
                      Expanded(
                        child: _buildActionButton(
                          icon: button.icon,
                          label: button.label,
                          onTap: button.onTap,
                        ),
                      )
                    ).toList(),
                  ),
                ),
              
              const SizedBox(height: 36),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: HomeScreenColors.buttonBackground, // Darker gray for better visibility
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: HomeScreenColors.primaryText, // Dark icon for light background
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: HomeScreenColors.secondaryText, // Gray text for white background
              fontSize: 14,
              fontFamily: 'ElzaRound',
            ),
          ),
        ),
      ],
    );
  }

  String _getDaysSuffix(int days, AppLocalizations l10n) {
    if (days == 1) {
      return l10n.translate('common_day_singular');
    } else if (days >= 2 && days <= 4 && l10n.locale.languageCode == 'cs') {
      return l10n.translate('common_days_few');
    } else {
      return l10n.translate('common_days_plural');
    }
  }
} 