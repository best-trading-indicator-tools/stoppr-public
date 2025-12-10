import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nutrition_data.dart';

part 'food_log.freezed.dart';
part 'food_log.g.dart';

enum MealType {
  @JsonValue('breakfast')
  breakfast,
  @JsonValue('lunch')
  lunch,
  @JsonValue('dinner')
  dinner,
  @JsonValue('snack')
  snack,
}

@freezed
class FoodLog with _$FoodLog {
  const factory FoodLog({
    String? id,
    required String userId,
    required String foodName,
    required MealType mealType,
    String? imageUrl,
    required NutritionData nutritionData,
    @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
    required DateTime loggedAt,
    String? notes,
  }) = _FoodLog;

  factory FoodLog.fromJson(Map<String, dynamic> json) =>
      _$FoodLogFromJson(json);
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
