import 'package:flutter/material.dart';
import '../../data/models/food_log.dart';
import '../../../../core/localization/app_localizations.dart';

class MealCard extends StatelessWidget {
  final FoodLog foodLog;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const MealCard({
    Key? key,
    required this.foodLog,
    this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Food image
              if (foodLog.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    foodLog.imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          color: Colors.white54,
                          size: 30,
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Colors.white54,
                    size: 30,
                  ),
                ),
              const SizedBox(width: 16),

              // Food details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foodLog.foodName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMealTypeLabel(foodLog.mealType, l10n),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontFamily: 'ElzaRound',
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Nutritional highlights
                    Row(
                      children: [
                        _buildNutrientChip(
                          '${foodLog.nutritionData.calories.toInt()} cal',
                          Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _buildNutrientChip(
                          '${foodLog.nutritionData.protein.toInt()}g P',
                          const Color(0xFFFF6B6B),
                        ),
                        const SizedBox(width: 8),
                        // Sugar warning if high
                        if (foodLog.nutritionData.sugar > 10)
                          _buildNutrientChip(
                            '${foodLog.nutritionData.sugar.toInt()}g S',
                            Colors.red,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white54),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontFamily: 'ElzaRound',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getMealTypeLabel(MealType type, AppLocalizations l10n) {
    switch (type) {
      case MealType.breakfast:
        return l10n.translate('calorieTracker_mealType_breakfast');
      case MealType.lunch:
        return l10n.translate('calorieTracker_mealType_lunch');
      case MealType.dinner:
        return l10n.translate('calorieTracker_mealType_dinner');
      case MealType.snack:
        return l10n.translate('calorieTracker_mealType_snack');
    }
  }
}
