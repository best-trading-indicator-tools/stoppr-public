import 'package:freezed_annotation/freezed_annotation.dart';

part 'nutrition_data.freezed.dart';
part 'nutrition_data.g.dart';

@freezed
class NutritionData with _$NutritionData {
  const factory NutritionData({
    String? foodName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double sugar,
    required double fiber,
    required double sodium,
    @Default({}) Map<String, Micronutrient> micronutrients,
    ServingInfo? servingInfo,
  }) = _NutritionData;

  factory NutritionData.fromJson(Map<String, dynamic> json) =>
      _$NutritionDataFromJson(json);
}

@freezed
class Micronutrient with _$Micronutrient {
  const factory Micronutrient({
    required double value,
    required String unit,
  }) = _Micronutrient;

  factory Micronutrient.fromJson(Map<String, dynamic> json) =>
      _$MicronutrientFromJson(json);
}

@freezed
class ServingInfo with _$ServingInfo {
  const factory ServingInfo({
    required double amount,
    required String unit,
    double? weight,
    String? weightUnit,
  }) = _ServingInfo;

  factory ServingInfo.fromJson(Map<String, dynamic> json) =>
      _$ServingInfoFromJson(json);
}
