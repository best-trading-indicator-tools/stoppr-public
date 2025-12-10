import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/localization/app_localizations.dart';

class HealthScoreWidget extends StatelessWidget {
  final double score;

  const HealthScoreWidget({
    Key? key,
    required this.score,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayScore = score > 0 ? score : 0.0;
    final scoreColor = _getScoreColor(displayScore);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('calorieTracker_healthScore'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayScore > 0
                    ? _getScoreDescription(displayScore, l10n)
                    : l10n.translate('calorieTracker_notEvaluated'),
                style: TextStyle(
                  color: displayScore > 0 ? scoreColor : Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontFamily: 'ElzaRound',
                ),
              ),
            ],
          ),
          // Score display
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: displayScore > 0 ? scoreColor : Colors.white.withOpacity(0.2),
                width: 3,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayScore > 0 ? displayScore.toStringAsFixed(1) : '-',
                    style: TextStyle(
                      color: displayScore > 0 ? scoreColor : Colors.white.withOpacity(0.6),
                      fontSize: 24,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '/10',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      fontFamily: 'ElzaRound',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return const Color(0xFF66BB6A);
    if (score >= 4) return Colors.orange;
    return Colors.red;
  }

  String _getScoreDescription(double score, AppLocalizations l10n) {
    if (score >= 8) return l10n.translate('calorieTracker_healthScore_excellent');
    if (score >= 6) return l10n.translate('calorieTracker_healthScore_good');
    if (score >= 4) return l10n.translate('calorieTracker_healthScore_fair');
    return l10n.translate('calorieTracker_healthScore_needsImprovement');
  }
}
