import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/core/config/env_config.dart';
import 'package:stoppr/features/recipes/data/models/recipe_model.dart';

/// Repository for fetching recipes from Edamam API with Spoonacular fallback
class RecipeRepository {
  static const String _edamamBaseUrl = 'https://api.edamam.com/api/recipes/v2';
  static const String _spoonacularBaseUrl =
      'https://api.spoonacular.com/recipes/complexSearch';
  
  /// Search for recipes with optional filters
  /// 
  /// [query] - Search term (e.g., "chicken", "salad")
  /// [dietLabels] - Diet filters (e.g., ["balanced", "high-protein"])
  /// [healthLabels] - Health filters (e.g., ["vegan", "gluten-free"])
  /// [cuisineType] - Cuisine type (e.g., "mediterranean")
  /// [mealType] - Meal type (e.g., "breakfast", "lunch/dinner")
  /// [calories] - Calorie range in format "MIN-MAX" (e.g., "100-300")
  /// [imageSize] - Image size preference (THUMBNAIL, SMALL, REGULAR, LARGE)
  /// [language] - Language code for localization (e.g., "en-US", "fr-FR", "es-ES")
  Future<List<Recipe>> searchRecipes({
    String? query,
    List<String>? dietLabels,
    List<String>? healthLabels,
    String? cuisineType,
    String? mealType,
    String? calories,
    String imageSize = 'REGULAR',
    String language = 'en-US',
    int maxResults = 60,
  }) async {
    try {
      final apiKey = EnvConfig.edamamApiKey;
      final appId = EnvConfig.edamamAppId;

      if (apiKey == null || appId == null) {
        throw Exception('Edamam API credentials not found in .env file');
      }

      // Debug: Check if credentials are present (don't log actual values for security)
      debugPrint(
        '🔑 Edamam credentials check: '
        'API Key present: ${apiKey.isNotEmpty}, '
        'App ID present: ${appId.isNotEmpty}',
      );

      // Build query parameters
      final queryParams = {
        'type': 'public',
        'app_id': appId,
        'app_key': apiKey,
        'imageSize': imageSize,
        'random': 'true', // Get different results each time
      };

      // Add search query (default to healthy options)
      if (query != null && query.isNotEmpty) {
        queryParams['q'] = query;
      } else {
        queryParams['q'] = 'healthy'; // Default search
      }

      // Add diet labels
      if (dietLabels != null && dietLabels.isNotEmpty) {
        for (final diet in dietLabels) {
          queryParams['diet'] = diet;
        }
      }

      // Add health labels
      if (healthLabels != null && healthLabels.isNotEmpty) {
        for (final health in healthLabels) {
          queryParams['health'] = health;
        }
      }

      // Add cuisine type
      if (cuisineType != null && cuisineType.isNotEmpty) {
        queryParams['cuisineType'] = cuisineType;
      }

      // Add meal type
      if (mealType != null && mealType.isNotEmpty) {
        queryParams['mealType'] = mealType;
      }

      // Add calories range
      if (calories != null && calories.isNotEmpty) {
        queryParams['calories'] = calories;
      }

      // Build base headers (mutable map)
      final headers = <String, String>{
        'Accept': 'application/json',
        'Accept-Charset': 'utf-8',
        'Accept-Language': '$language,${language.split('-')[0]};q=0.9',
      };

      // Get user ID for Edamam-Account-User header if needed
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 
          'anonymous-user';

      // Make multiple API calls to get recipes (20 per call limit, max 60 total)
      final allRecipes = <Recipe>[];
      final calculatedCalls = (maxResults / 20).ceil();
      final callsNeeded = calculatedCalls.clamp(1, 3); // Max 3 calls = 60 recipes

      for (int callIndex = 0; callIndex < callsNeeded && allRecipes.length < maxResults; callIndex++) {
        // Create a copy of queryParams for this call
        final callParams = Map<String, String>.from(queryParams);
        
        // Calculate pagination: each call gets 20 results
        final from = callIndex * 20;
        final to = from + 20;
        callParams['from'] = from.toString();
        callParams['to'] = to.toString();

        // Build URI for this call
        final uri = Uri.parse(_edamamBaseUrl).replace(queryParameters: callParams);

        debugPrint('🍽️ Fetching recipes from Edamam (call ${callIndex + 1}/$callsNeeded): from=$from, to=$to');

        // Make API request without user header first (some app IDs don't require it)
        var response = await http.get(
          uri,
          headers: headers,
        ).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            throw Exception('Request timeout - please check your internet connection');
          },
        );

        // If 401 and error says we need userID, retry with header
        if (response.statusCode == 401) {
          final errorBody = utf8.decode(response.bodyBytes);
          if (errorBody.contains('userID') || 
              errorBody.contains('user') ||
              errorBody.contains('Edamam-Account-User')) {
            debugPrint(
              '⚠️ Edamam requires user header, retrying with header...',
            );
            final retryHeaders = Map<String, String>.from(headers);
            retryHeaders['Edamam-Account-User'] = userId;
            
            response = await http.get(
              uri,
              headers: retryHeaders,
            ).timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                throw Exception(
                  'Request timeout - please check your internet connection',
                );
              },
            );
          }
        }

        if (response.statusCode == 200) {
          // Properly decode UTF-8 to handle special characters (fractions, accents, etc.)
          final jsonData = json.decode(
            utf8.decode(response.bodyBytes),
          ) as Map<String, dynamic>;
          final hits = jsonData['hits'] as List<dynamic>? ?? [];
          final count = jsonData['count'] as int?;
          final toActual = jsonData['to'] as int?;
          final fromActual = jsonData['from'] as int?;

          debugPrint(
            '✅ Call ${callIndex + 1}: Retrieved ${hits.length} recipes\n'
            '   Requested: from=$fromActual, to=$toActual\n'
            '   Total available: $count',
          );

          // Parse recipes and add to collection
          final recipes = hits
              .map((hit) => Recipe.fromJson(hit as Map<String, dynamic>))
              .where((recipe) => recipe.image.isNotEmpty) // Filter out recipes without images
              .toList();

          allRecipes.addAll(recipes);

          // If we got fewer than 20, we've reached the end
          if (hits.length < 20) {
            debugPrint('   Reached end of results (got ${hits.length} < 20)');
            break;
          }
        } else if (response.statusCode == 401) {
          final errorBody = utf8.decode(response.bodyBytes);
          debugPrint('❌ Edamam 401 Unauthorized - Response: $errorBody');
          debugPrint(
            '💡 Possible causes:\n'
            '   1. Invalid or expired API credentials in .env file\n'
            '   2. API quota/limit reached\n'
            '   3. Incorrect App ID or API Key format\n'
            '   4. Account requires additional authentication\n'
            '   → Falling back to Spoonacular API',
          );
          throw Exception(
            'Invalid API credentials - please check your .env file',
          );
        } else if (response.statusCode == 402) {
          throw Exception('API limit reached - please try again later');
        } else if (response.statusCode == 503) {
          // Service unavailable - fall back to Spoonacular immediately
          debugPrint(
            '⚠️ Edamam service unavailable (503), '
            'falling back to Spoonacular API immediately',
          );
          // If we have some recipes, return them; otherwise fall back
          if (allRecipes.isEmpty) {
            throw Exception('Edamam service unavailable');
          }
          break;
        } else {
          // If this call fails, break and return what we have
          debugPrint('⚠️ Call ${callIndex + 1} failed with status ${response.statusCode}');
          // If we have some recipes, return them; otherwise throw
          if (allRecipes.isEmpty) {
            throw Exception('Failed to load recipes: ${response.statusCode}');
          }
          break;
        }
      }

      debugPrint(
        '✅ Total retrieved: ${allRecipes.length} recipes from $callsNeeded call(s)',
      );

      // Return up to maxResults
      if (allRecipes.isEmpty) {
        // If we got no recipes at all, check if it was an auth error
        throw Exception('Failed to load recipes from Edamam');
      }

      return allRecipes.take(maxResults).toList();
    } catch (e) {
      // If Edamam fails with any error, try Spoonacular as fallback
      debugPrint('⚠️ Edamam error, falling back to Spoonacular API: $e');
      try {
        return await _searchSpoonacular(
          query: query,
          dietLabels: dietLabels,
          healthLabels: healthLabels,
          cuisineType: cuisineType,
          mealType: mealType,
          calories: calories,
          maxResults: maxResults,
        );
      } catch (spoonacularError) {
        debugPrint('❌ Spoonacular fallback also failed: $spoonacularError');
        rethrow;
      }
    }
  }

  /// Fallback search using Spoonacular API
  Future<List<Recipe>> _searchSpoonacular({
    String? query,
    List<String>? dietLabels,
    List<String>? healthLabels,
    String? cuisineType,
    String? mealType,
    String? calories,
    int maxResults = 60,
  }) async {
    final apiKey = EnvConfig.spoonacularApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Spoonacular API key not found in .env file');
    }

    // Map Edamam filters to Spoonacular equivalents
    final queryParams = {
      'apiKey': apiKey,
      'number': maxResults.toString(),
      'addRecipeInformation': 'true',
      'addRecipeNutrition': 'true',
      'fillIngredients': 'true',
      'instructionsRequired': 'false',
    };

    // Add search query
    if (query != null && query.isNotEmpty) {
      queryParams['query'] = query;
    }

    // Map diet labels (Edamam → Spoonacular)
    if (dietLabels != null && dietLabels.isNotEmpty) {
      final dietParams = _mapDietToSpoonacular(dietLabels.first);
      // Add all parameters from diet mapping (diet, maxCarbs, minProtein, etc.)
      dietParams.forEach((key, value) {
        if (value != null && value.isNotEmpty) {
          queryParams[key] = value;
        }
      });
    }

    // Map health labels to intolerances/diet
    if (healthLabels != null && healthLabels.isNotEmpty) {
      final mappedLabels = _mapHealthLabelsToSpoonacular(healthLabels);
      if (mappedLabels['diet'] != null) {
        queryParams['diet'] = mappedLabels['diet']!;
      }
      if (mappedLabels['intolerances'] != null) {
        queryParams['intolerances'] = mappedLabels['intolerances']!;
      }
      if (mappedLabels['maxSugar'] != null) {
        queryParams['maxSugar'] = mappedLabels['maxSugar']!;
      }
      if (mappedLabels['excludeIngredients'] != null) {
        queryParams['excludeIngredients'] = mappedLabels['excludeIngredients']!;
      }
      if (mappedLabels['cuisine'] != null) {
        queryParams['cuisine'] = mappedLabels['cuisine']!;
      }
    }

    // Add cuisine type
    if (cuisineType != null && cuisineType.isNotEmpty) {
      queryParams['cuisine'] = cuisineType;
    }

    // Add meal type
    if (mealType != null && mealType.isNotEmpty) {
      queryParams['type'] = _mapMealTypeToSpoonacular(mealType);
    }

    // Add calories range (parse "MIN-MAX" format)
    if (calories != null && calories.isNotEmpty) {
      final parts = calories.split('-');
      if (parts.length == 2) {
        final minCal = parts[0].trim();
        final maxCal = parts[1].trim();
        queryParams['minCalories'] = minCal;
        queryParams['maxCalories'] = maxCal;
      }
    }

    final uri = Uri.parse(_spoonacularBaseUrl).replace(
      queryParameters: queryParams,
    );

    debugPrint('🥄 Fetching recipes from Spoonacular: $uri');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Accept-Charset': 'utf-8',
      },
    ).timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        throw Exception('Spoonacular request timeout');
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;
      final results = jsonData['results'] as List<dynamic>? ?? [];

      debugPrint('✅ Retrieved ${results.length} recipes from Spoonacular');

      // Convert Spoonacular recipes to Recipe model
      final recipes = results
          .map((item) => _convertSpoonacularToRecipe(item))
          .where((recipe) => recipe.image.isNotEmpty)
          .toList();

      return recipes;
    } else if (response.statusCode == 402) {
      throw Exception('Spoonacular API limit reached');
    } else {
      throw Exception('Spoonacular API error: ${response.statusCode}');
    }
  }

  /// Map Edamam diet labels to Spoonacular diet parameter
  /// 
  /// UI Filter → Edamam → Spoonacular:
  /// - "Low-Carb" → low-carb → ketogenic
  /// - "Carnivore"/"High-Protein" → high-protein → nutrient filters (maxCarbs, minProtein)
  /// 
  /// Returns Map with diet and/or nutrient filters
  Map<String, String?> _mapDietToSpoonacular(String edamamDiet) {
    switch (edamamDiet) {
      case 'high-protein':
        // Carnivore: No native support, use nutrient filters
        // Very low carbs + high protein = meat-focused recipes
        return {
          'maxCarbs': '5',      // Max 5g carbs per serving
          'minProtein': '25',   // Min 25g protein per serving
        };
      case 'low-carb':
        return {'diet': 'ketogenic'};
      case 'balanced':
      case 'low-fat':
        return {}; // No direct equivalent
      default:
        return {};
    }
  }

  /// Map Edamam health labels to Spoonacular diet/intolerances
  /// 
  /// Complete UI Filter Coverage (15 filters):
  /// 1. All - no filter
  /// 2. Low-Carb - diet: ketogenic (handled by _mapDietToSpoonacular)
  /// 3. Low Sugar - maxSugar: 10
  /// 4. Sugar-Conscious - maxSugar: 10
  /// 5. Carnivore - maxCarbs: 5, minProtein: 25 (handled by _mapDietToSpoonacular)
  /// 6. Kosher - excludeIngredients: pork,shellfish
  /// 7. Keto - diet: ketogenic
  /// 8. Gluten-Free - intolerances: gluten
  /// 9. Peanut-Free - intolerances: peanut
  /// 10. Wheat-Free - intolerances: wheat
  /// 11. Dairy-Free - intolerances: dairy
  /// 12. Vegan - diet: vegan
  /// 13. Vegetarian - diet: vegetarian
  /// 14. Mediterranean - cuisine: Mediterranean
  /// 15. High-Protein - maxCarbs: 5, minProtein: 25 (handled by _mapDietToSpoonacular)
  Map<String, String?> _mapHealthLabelsToSpoonacular(
    List<String> healthLabels,
  ) {
    final result = <String, String?>{};
    final intolerances = <String>[];

    for (final label in healthLabels) {
      switch (label) {
        // Diet-based filters
        case 'vegan': // UI: Vegan
          result['diet'] = 'vegan';
          break;
        case 'vegetarian': // UI: Vegetarian
          result['diet'] = 'vegetarian';
          break;
        case 'paleo': // UI: Not in current filters, but supported
          result['diet'] = 'paleo';
          break;
        case 'pescetarian': // UI: Not in current filters, but supported
          result['diet'] = 'pescatarian';
          break;
        case 'keto-friendly': // UI: Keto
          result['diet'] = 'ketogenic';
          break;
        case 'Mediterranean': // UI: Mediterranean
          // Spoonacular doesn't have Mediterranean diet
          // Use cuisine filter instead
          result['cuisine'] = 'Mediterranean';
          break;
        
        // Intolerance-based filters
        case 'gluten-free': // UI: Gluten-Free
          intolerances.add('gluten');
          break;
        case 'dairy-free': // UI: Dairy-Free
          intolerances.add('dairy');
          break;
        case 'peanut-free': // UI: Peanut-Free
          intolerances.add('peanut');
          break;
        case 'wheat-free': // UI: Wheat-Free
          intolerances.add('wheat');
          break;
        
        // Sugar-based filters
        case 'low-sugar': // UI: Low Sugar
        case 'sugar-conscious': // UI: Sugar-Conscious
          result['maxSugar'] = '10'; // Max 10g sugar per serving
          break;
        
        // Special dietary restrictions
        case 'kosher': // UI: Kosher
          // Spoonacular doesn't have kosher diet type
          // Best approximation: exclude non-kosher ingredients
          result['excludeIngredients'] = 'pork,shellfish';
          break;
      }
    }

    if (intolerances.isNotEmpty) {
      result['intolerances'] = intolerances.join(',');
    }

    return result;
  }

  /// Map Edamam meal type to Spoonacular type
  /// 
  /// Edamam → Spoonacular:
  /// - breakfast → breakfast
  /// - lunch/dinner → main course
  /// - lunch → main course
  /// - dinner → main course
  /// - snack → snack
  String _mapMealTypeToSpoonacular(String edamamMealType) {
    const mealTypeMap = {
      'breakfast': 'breakfast',
      'lunch/dinner': 'main course',
      'lunch': 'main course',
      'dinner': 'main course',
      'snack': 'snack',
    };
    return mealTypeMap[edamamMealType] ?? edamamMealType;
  }

  /// Convert Spoonacular recipe format to Recipe model
  Recipe _convertSpoonacularToRecipe(dynamic spoonacularRecipe) {
    final recipe = spoonacularRecipe as Map<String, dynamic>;

    // Extract nutrition data
    final nutrition = recipe['nutrition'] as Map<String, dynamic>?;
    final nutrients = nutrition?['nutrients'] as List<dynamic>? ?? [];

    // Build nutrients map
    final totalNutrients = <String, NutrientInfo>{};
    for (final nutrient in nutrients) {
      final n = nutrient as Map<String, dynamic>;
      final name = n['name'] as String?;
      final amount = (n['amount'] as num?)?.toDouble() ?? 0.0;
      final unit = n['unit'] as String? ?? '';

      if (name != null) {
        // Map Spoonacular nutrient names to Edamam-style keys
        String key = name.toUpperCase().replaceAll(' ', '_');
        if (name == 'Calories') key = 'ENERC_KCAL';
        if (name == 'Protein') key = 'PROCNT';
        if (name == 'Carbohydrates') key = 'CHOCDF';
        if (name == 'Fat') key = 'FAT';
        if (name == 'Fiber') key = 'FIBTG';
        if (name == 'Sugar') key = 'SUGAR';
        if (name == 'Sodium') key = 'NA';

        totalNutrients[key] = NutrientInfo(
          label: name,
          quantity: amount,
          unit: unit,
        );
      }
    }

    // Extract calories
    final caloriesNutrient = nutrients.firstWhere(
      (n) => (n as Map)['name'] == 'Calories',
      orElse: () => {'amount': 0.0},
    ) as Map<String, dynamic>;
    final calories = (caloriesNutrient['amount'] as num?)?.toDouble() ?? 0.0;

    // Extract diet and health labels
    final diets = (recipe['diets'] as List<dynamic>?)?.cast<String>() ?? [];
    final dishTypes = (recipe['dishTypes'] as List<dynamic>?)?.cast<String>() ?? [];

    return Recipe(
      uri: 'spoonacular:${recipe['id']}',
      label: recipe['title'] as String? ?? 'Untitled Recipe',
      image: recipe['image'] as String? ?? '',
      source: recipe['sourceName'] as String? ?? 'Spoonacular',
      url: recipe['sourceUrl'] as String? ?? '',
      calories: calories,
      totalWeight: null,
      totalTime: (recipe['readyInMinutes'] as num?)?.toInt() ?? 0,
      yield: (recipe['servings'] as num?)?.toInt() ?? 1,
      dietLabels: diets,
      healthLabels: diets, // Spoonacular combines both in 'diets'
      ingredientLines: _extractIngredients(recipe),
      cuisineType: (recipe['cuisines'] as List<dynamic>?)?.cast<String>() ?? [],
      mealType: dishTypes.isNotEmpty ? [dishTypes.first] : [],
      dishType: dishTypes,
      totalNutrients: totalNutrients,
    );
  }

  /// Extract ingredient lines from Spoonacular recipe
  List<String> _extractIngredients(Map<String, dynamic> recipe) {
    final extendedIngredients =
        recipe['extendedIngredients'] as List<dynamic>?;
    if (extendedIngredients != null) {
      return extendedIngredients
          .map((ing) => (ing as Map<String, dynamic>)['original'] as String?)
          .whereType<String>()
          .toList();
    }
    return [];
  }

  /// Get recipes by specific diet type
  Future<List<Recipe>> getRecipesByDiet(String diet) async {
    return searchRecipes(
      dietLabels: [diet],
    );
  }

  /// Get recipes by specific health label (e.g., vegan, vegetarian)
  Future<List<Recipe>> getRecipesByHealthLabel(String healthLabel) async {
    return searchRecipes(
      healthLabels: [healthLabel],
    );
  }

  /// Get popular healthy recipes (balanced diet, varied options)
  Future<List<Recipe>> getHealthyRecipes() async {
    return searchRecipes(
      query: 'healthy',
      dietLabels: ['balanced'],
      maxResults: 60,
    );
  }

  /// Get breakfast recipes
  Future<List<Recipe>> getBreakfastRecipes() async {
    return searchRecipes(
      mealType: 'breakfast',
      maxResults: 60,
    );
  }

  /// Get lunch/dinner recipes
  Future<List<Recipe>> getLunchDinnerRecipes() async {
    return searchRecipes(
      mealType: 'lunch/dinner',
      maxResults: 60,
    );
  }

  /// Get snack recipes
  Future<List<Recipe>> getSnackRecipes() async {
    return searchRecipes(
      mealType: 'snack',
      maxResults: 60,
    );
  }
}

