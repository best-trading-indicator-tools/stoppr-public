import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';

class WaterTrackerWidget extends StatelessWidget {
  final double currentIntake;
  final double goal;
  final Function(double) onUpdate;

  const WaterTrackerWidget({
    Key? key,
    required this.currentIntake,
    required this.goal,
    required this.onUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final percentage = (currentIntake / goal).clamp(0.0, 1.0);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.water_drop,
                    color: Color(0xFF42A5F5),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.translate('calorieTracker_water'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '${currentIntake.toInt()}/${goal.toInt()} ml',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontFamily: 'ElzaRound',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick add buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAddButton('+250ml', 250),
              _buildQuickAddButton('+500ml', 500),
              _buildQuickAddButton('+750ml', 750),
              _buildQuickAddButton('+1L', 1000),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButton(String label, double amount) {
    return GestureDetector(
      onTap: () => onUpdate(currentIntake + amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF42A5F5).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF42A5F5).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF42A5F5),
            fontSize: 12,
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
