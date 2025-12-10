import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../../../core/streak/streak_service.dart';
import '../../../../features/app/presentation/screens/home_rewire_brain.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../../../../features/app/presentation/screens/main_scaffold.dart';
import '../../../../core/localization/app_localizations.dart';

class BrainRewiringWidget extends StatefulWidget {
  const BrainRewiringWidget({super.key});

  @override
  State<BrainRewiringWidget> createState() => _BrainRewiringWidgetState();
}

class _BrainRewiringWidgetState extends State<BrainRewiringWidget> {
  final StreakService _streakService = StreakService();
  late double _brainRewiringPercentage = 0.0;
  StreamSubscription<StreakData>? _streakSub;
  
  @override
  void initState() {
    super.initState();
    _calculateBrainRewiringProgress();
    // Listen for streak updates so initial async load updates the UI
    _streakSub = _streakService.streakStream.listen((streakData) {
      if (!mounted) return;
      final startTime = streakData.startTime;
      if (startTime != null) {
        final daysElapsed = DateTime.now().difference(startTime).inDays;
        setState(() {
          _brainRewiringPercentage = max(0.0, min(1.0, daysElapsed / 90));
        });
      }
    });
  }
  
  @override
  void dispose() {
    _streakSub?.cancel();
    super.dispose();
  }

  void _calculateBrainRewiringProgress() {
    final streakData = _streakService.currentStreak;
    
    if (streakData.startTime != null) {
      final daysElapsed = DateTime.now().difference(streakData.startTime!).inDays;
      final progress = min(1.0, daysElapsed / 90);
      setState(() {
        _brainRewiringPercentage = progress;
      });
    }
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
      child: InkWell(
        onTap: () {
          // Track block tap with Mixpanel
          MixpanelService.trackEvent('Brain Rewiring Block Tap');
          Navigator.of(context).pushReplacement(
            BottomToTopPageRoute(
              child: const MainScaffold(initialIndex: 2),
              settings: const RouteSettings(name: '/home_rewire_brain'),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            SizedBox(
              width: 150, // Give more room for longer localized titles
              child: Text(
                l10n.translate('home_brainRewiring_title'),
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
              child: Container
              (
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: max(min(_brainRewiringPercentage, 1.0), 0.02),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(_brainRewiringPercentage * 100).round()}%',
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