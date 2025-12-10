import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../features/app/presentation/screens/challenge_28_days_screen.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../../../../core/localization/app_localizations.dart';
// Summary: Compute challenge progress from completed days count rather than
// current day, so completing day 14 shows exactly 50% (14/28).

class ChallengeProgressWidget extends StatefulWidget {
  const ChallengeProgressWidget({super.key});

  @override
  State<ChallengeProgressWidget> createState() => _ChallengeProgressWidgetState();
}

class _ChallengeProgressWidgetState extends State<ChallengeProgressWidget> {
  late double _challengePercentage = 0.0;
  bool _challengeStarted = false;
  int _challengeCurrentDay = 0;
  
  @override
  void initState() {
    super.initState();
    _loadChallengeProgress();
  }
  
  Future<void> _loadChallengeProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final started = prefs.getBool('challenge_started') ?? false;
    final List<String> dayStatusListJson =
        prefs.getStringList('challenge_day_status') ?? [];
    final int completedDays = dayStatusListJson
        .where((e) => e == 'true')
        .length;
    
    setState(() {
      _challengeStarted = started;
      _challengeCurrentDay = prefs.getInt('challenge_current_day') ?? 0;
      
      // Calculate challenge percentage (0% if not started)
      if (started && completedDays > 0) {
        _challengePercentage = completedDays / 28;
      } else {
        _challengePercentage = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE0E0E0), // Light gray border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 56,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          debugPrint('28 Day Challenge block tapped');
          // Track block tap with Mixpanel
          MixpanelService.trackEvent('28 Day Challenge Block Tap');
          Navigator.of(context).pushReplacement(
            BottomToTopPageRoute(
              child: const Challenge28DaysScreen(),
              settings: const RouteSettings(name: '/challenge_28_days'),
            ),
          );
        },
        child: Row(
          children: [
            SizedBox(
              width: 150, // More room for long localized titles
              child: Text(
                l10n.translate('home_28DayChallenge_title'),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for white background
                  fontSize: 16,
                  fontFamily: 'ElzaRound',
                ),
                maxLines: 2,
                softWrap: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0), // Light gray background for progress bar
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: [
                    Container(
                      // Always show at least 2% progress for visual feedback
                      width: MediaQuery.of(context).size.width * 0.4 * max(_challengePercentage, 0.02),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFed3272), Color(0xFFfd5d32)], // Brand gradient
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(_challengePercentage * 100).round()}%', // Keep showing actual percentage
              style: const TextStyle(
                color: Color(0xFF666666), // Gray text for white background
                fontSize: 16,
                fontFamily: 'ElzaRound',
              ),
            ),
          ],
        ),
      ),
    );
  }
} 