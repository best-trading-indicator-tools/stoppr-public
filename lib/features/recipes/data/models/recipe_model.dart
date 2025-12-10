import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipe_model.freezed.dart';

/// Recipe model representing a single recipe from Edamam API
@freezed
class Recipe with _$Recipe {
  const factory Recipe({
    /// Unique recipe URI/ID
    required String uri,
    
    /// Recipe title/label
    required String label,
    
    /// Recipe image URL
    required String image,
    
    /// Source website name
    required String source,
    
    /// Full recipe URL on source website
    required String url,
    
    /// Total calories
    required double calories,
    
    /// Total weight in grams (nullable if not provided by API)
    double? totalWeight,
    
    /// Total cooking/prep time in minutes (0 if not specified)
    @Default(0) int totalTime,
    
    /// Number of servings
    @Default(1) int yield,
    
    /// Diet labels (e.g., balanced, high-protein)
    @Default([]) List<String> dietLabels,
    
    /// Health labels (e.g., vegan, gluten-free)
    @Default([]) List<String> healthLabels,
    
    /// Ingredient lines (text list)
    @Default([]) List<String> ingredientLines,
    
    /// Cuisine type (e.g., mediterranean, asian)
    @Default([]) List<String> cuisineType,
    
    /// Meal type (e.g., lunch/dinner, breakfast)
    @Default([]) List<String> mealType,
    
    /// Dish type (e.g., main course, salad)
    @Default([]) List<String> dishType,
    
    /// Total nutrients map (protein, fat, carbs, etc.)
    @Default({}) Map<String, NutrientInfo> totalNutrients,
  }) = _Recipe;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Edamam API returns nested structure: {recipe: {...}}
    final recipeData = json['recipe'] as Map<String, dynamic>? ?? json;
    
    return Recipe(
      uri: recipeData['uri'] as String? ?? '',
      label: recipeData['label'] as String? ?? 'Untitled Recipe',
      image: recipeData['image'] as String? ?? '',
      source: recipeData['source'] as String? ?? '',
      url: recipeData['url'] as String? ?? '',
      calories: (recipeData['calories'] as num?)?.toDouble() ?? 0.0,
      totalWeight: (recipeData['totalWeight'] as num?)?.toDouble() ?? 0.0,
      totalTime: (recipeData['totalTime'] as num?)?.toInt() ?? 0,
      yield: (recipeData['yield'] as num?)?.toInt() ?? 1,
      dietLabels: (recipeData['dietLabels'] as List<dynamic>?)?.cast<String>() ?? [],
      healthLabels: (recipeData['healthLabels'] as List<dynamic>?)?.cast<String>() ?? [],
      ingredientLines: (recipeData['ingredientLines'] as List<dynamic>?)?.cast<String>() ?? [],
      cuisineType: (recipeData['cuisineType'] as List<dynamic>?)?.cast<String>() ?? [],
      mealType: (recipeData['mealType'] as List<dynamic>?)?.cast<String>() ?? [],
      dishType: (recipeData['dishType'] as List<dynamic>?)?.cast<String>() ?? [],
      totalNutrients: _parseNutrients(recipeData['totalNutrients']),
    );
  }

  /// Parse nutrients from API response
  static Map<String, NutrientInfo> _parseNutrients(dynamic nutrients) {
    if (nutrients == null || nutrients is! Map) return {};
    
    final result = <String, NutrientInfo>{};
    nutrients.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = NutrientInfo.fromJson(value);
      }
    });
    return result;
  }
}

/// Nutrient information (protein, carbs, fat, etc.)
@freezed
class NutrientInfo with _$NutrientInfo {
  const factory NutrientInfo({
    required String label,
    required double quantity,
    required String unit,
  }) = _NutrientInfo;

  factory NutrientInfo.fromJson(Map<String, dynamic> json) {
    return NutrientInfo(
      label: json['label'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
    );
  }
}

