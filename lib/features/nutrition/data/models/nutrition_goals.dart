import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'nutrition_goals.freezed.dart';
part 'nutrition_goals.g.dart';

@freezed
class NutritionGoals with _$NutritionGoals {
  const factory NutritionGoals({
    required String userId,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double sugar,
    required double fiber,
    required double sodium,
    required double water, // in ml
    @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
    required DateTime updatedAt,
  }) = _NutritionGoals;

  factory NutritionGoals.fromJson(Map<String, dynamic> json) =>
      _$NutritionGoalsFromJson(json);

  // Factory constructor for default goals based on user profile
  factory NutritionGoals.defaultGoals({
    required String userId,
    String? gender,
    int? age,
    double? weight,
    double? height,
    String? activityLevel,
  }) {
    // Basic calorie calculation (Mifflin-St Jeor Equation)
    double bmr = 1500; // Default
    
    if (weight != null && height != null && age != null && gender != null) {
      if (gender.toLowerCase() == 'male') {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
      } else {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
      }
    }

    // Activity multiplier
    double activityMultiplier = 1.2; // Sedentary default
    if (activityLevel == 'light') activityMultiplier = 1.375;
    if (activityLevel == 'moderate') activityMultiplier = 1.55;
    if (activityLevel == 'active') activityMultiplier = 1.725;
    if (activityLevel == 'very_active') activityMultiplier = 1.9;

    double dailyCalories = bmr * activityMultiplier;

    // Macronutrient distribution (balanced diet)
    // Protein: 25% of calories (4 cal/g)
    // Carbs: 45% of calories (4 cal/g)
    // Fat: 30% of calories (9 cal/g)
    double proteinGrams = (dailyCalories * 0.25) / 4;
    double carbGrams = (dailyCalories * 0.45) / 4;
    double fatGrams = (dailyCalories * 0.30) / 9;

    // Water recommendation: base 35 ml/kg, adjusted by activity.
    // light: 1.0x, moderate: 1.2x, active/very_active: 1.35x. Minimum 2000 ml.
    double _activityWaterMultiplier(String? level) {
      switch (level) {
        case 'moderate':
          return 1.2;
        case 'active':
        case 'very_active':
          return 1.35;
        default:
          return 1.0;
      }
    }

    final double waterMl = (() {
      if (weight == null) return 2000.0;
      final base = weight * 35.0;
      final mult = _activityWaterMultiplier(activityLevel);
      final calc = base * mult;
      return calc < 2000.0 ? 2000.0 : calc.roundToDouble();
    })();

    return NutritionGoals(
      userId: userId,
      calories: dailyCalories.roundToDouble(),
      protein: proteinGrams.roundToDouble(),
      carbs: carbGrams.roundToDouble(),
      fat: fatGrams.roundToDouble(),
      sugar: 25, // WHO recommendation: 25g for women, 36g for men
      fiber: gender?.toLowerCase() == 'male' ? 38 : 25,
      sodium: 2300, // FDA recommendation
      water: waterMl,
      updatedAt: DateTime.now(),
    );
  }
}

// Helper functions for Timestamp conversion
DateTime _timestampFromJson(dynamic timestamp) {
  if (timestamp is Timestamp) {
    return timestamp.toDate();
  } else if (timestamp is Map && timestamp['seconds'] != null) {
    return DateTime.fromMillisecondsSinceEpoch(
      timestamp['seconds'] * 1000 + (timestamp['nanoseconds'] ?? 0) ~/ 1000000,
    );
  }
  return DateTime.now();
}

dynamic _timestampToJson(DateTime dateTime) {
  return Timestamp.fromDate(dateTime);
}
