import 'package:flutter/material.dart';

/// Calorie range card widget with emoji icon and calorie range label
/// Per style_brand.md: gradient when selected, white when unselected
class CalorieRangeCard extends StatelessWidget {
  final String emoji;
  final String calorieRange;
  final bool isSelected;
  final VoidCallback onTap;

  const CalorieRangeCard({
    required this.emoji,
    required this.calorieRange,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          // Per style_brand.md: gradient when selected, white when unselected
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFed3272), // Brand pink
                    Color(0xFFfd5d32), // Brand orange
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? null
              : Border.all(
                  color: const Color(0xFFE0E0E0), // Light gray border
                  width: 1,
                ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              calorieRange,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ElzaRound',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white // White text on gradient
                    : const Color(0xFF1A1A1A), // Dark text on white
              ),
            ),
          ],
        ),
      ),
    );
  }
}

