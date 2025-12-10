// This file contains the models used for the Food Alternative feature

class FoodAlternative {
  final String name;
  final String description;
  final String benefits;
  final String? detailedBenefits;
  final String? imageUrl;
  // Nutritional comparison data - structure matches what we parse and use
  final Map<String, Map<String, NutritionalData>>? nutritionalComparison;
  // Preparation difficulty (1-5 scale)
  final int? preparationDifficulty;
  // Health score (0-100 scale)
  final int? healthScore;
  // Recipe and preparation steps
  final String? recipe;
  final List<String>? preparationSteps;
  // Structured ingredients with quantities and emojis
  final List<Ingredient>? ingredients;
  // Blood sugar impact data
  final BloodSugarImpact? bloodSugarImpact;
  // Glycemic index data
  final GlycemicIndex? glycemicIndex;
  // Meal timing impact
  final MealTiming? mealTiming;
  // Bloat information
  final BloatInfo? bloatInfo;
  // Cost comparison
  final CostComparison? costComparison;
  // Scientific sources/citations
  final List<Source>? sources;
  
  FoodAlternative({
    required this.name,
    required this.description,
    required this.benefits,
    this.detailedBenefits,
    this.imageUrl,
    this.nutritionalComparison,
    this.preparationDifficulty,
    this.healthScore,
    this.recipe,
    this.preparationSteps,
    this.ingredients,
    this.bloodSugarImpact,
    this.glycemicIndex,
    this.mealTiming,
    this.bloatInfo,
    this.costComparison,
    this.sources,
  });
}

// Class for scientific sources/citations
class Source {
  final String title;
  final String? authors;
  final String? publication;
  final String? year;
  final String? url;
  final String? description;
  
  Source({
    required this.title,
    this.authors,
    this.publication,
    this.year,
    this.url,
    this.description,
  });
}

class NutritionalData {
  final double value;
  final String unit;
  
  NutritionalData({required this.value, required this.unit});
}

class BloodSugarImpact {
  final String originalImpact;
  final String alternativeImpact;
  final int originalScore; // 0-100 score, higher is worse impact (more blood sugar elevation)
  final int alternativeScore; // 0-100 score, higher is worse impact (more blood sugar elevation)
  
  BloodSugarImpact({
    required this.originalImpact,
    required this.alternativeImpact,
    required this.originalScore,
    required this.alternativeScore,
  });
}

class GlycemicIndex {
  final int originalValue;
  final String originalCategory; // "Low" (0-55), "Medium" (56-69), "High" (70+)
  final int alternativeValue;
  final String alternativeCategory;
  
  GlycemicIndex({
    required this.originalValue,
    required this.originalCategory,
    required this.alternativeValue,
    required this.alternativeCategory,
  });
}

class MealTiming {
  final String breakfast;
  final String lunch;
  final String dinner;
  final String snack;
  
  MealTiming({
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.snack,
  });
}

class CostComparison {
  final String original; // "$", "$$", "$$$"
  final String alternative; // "$", "$$", "$$$"
  final String description;
  
  CostComparison({
    required this.original,
    required this.alternative,
    required this.description,
  });
}

class BloatInfo {
  final int score; // 0-100 scale (higher = worse bloating)
  final String description;
  final Map<String, String>? skinEffects; // Map of skin effects and descriptions

  BloatInfo({
    required this.score, 
    required this.description,
    this.skinEffects,
  });
} 

// Ingredient with quantity, unit, and optional emoji/icon character
class Ingredient {
  final String name;
  final String? quantity; // e.g., "1", "1/2"
  final String? unit; // e.g., "cup", "tbsp", "tsp", "oz", "g"
  final String? note; // chopped, minced, etc.
  final String? emoji; // "🥚", "🧀", etc.

  Ingredient({
    required this.name,
    this.quantity,
    this.unit,
    this.note,
    this.emoji,
  });
}