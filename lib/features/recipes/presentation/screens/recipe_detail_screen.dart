import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';
import 'package:stoppr/features/recipes/data/models/recipe_model.dart';
import 'package:stoppr/features/recipes/presentation/widgets/nutrition_info_card.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:stoppr/core/config/env_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:stoppr/features/nutrition/data/models/food_log.dart';
import 'package:stoppr/features/nutrition/data/models/nutrition_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/features/recipes/data/repositories/recipe_favorites_repository.dart';

/// Recipe detail screen showing full recipe information
/// Styled per style_brand.md with white background, brand gradients
/// Reference: User's screenshot showing recipe detail layout
class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({
    required this.recipe,
    super.key,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isGeneratingRecipe = false;
  String? _generatedRecipe;
  String? _recipeError;
  final _nutritionRepository = NutritionRepository();
  final _favoritesRepository = RecipeFavoritesRepository();
  bool _isLoggingToTracker = false;
  bool _isFavorite = false;
  bool _isCheckingFavorite = true;

  @override
  void initState() {
    super.initState();
    // Track page view
    MixpanelService.trackPageView('Recipe Detail Screen: ${widget.recipe.label}');
    // Check if recipe is favorited
    _checkFavoriteStatus();
  }

  /// Check if recipe is currently favorited
  Future<void> _checkFavoriteStatus() async {
    try {
      final isFav = await _favoritesRepository.isFavorite(widget.recipe.uri);
      if (mounted) {
        setState(() {
          _isFavorite = isFav;
          _isCheckingFavorite = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
      if (mounted) {
        setState(() {
          _isCheckingFavorite = false;
        });
      }
    }
  }

  /// Toggle favorite status
  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorite) {
        await _favoritesRepository.removeFavorite(widget.recipe.uri);
        if (mounted) {
          setState(() {
            _isFavorite = false;
          });
        }
        MixpanelService.trackEvent('Recipe Unfavorited', properties: {
          'recipe_name': widget.recipe.label,
        });
      } else {
        await _favoritesRepository.saveFavorite(widget.recipe);
        if (mounted) {
          setState(() {
            _isFavorite = true;
          });
        }
        MixpanelService.trackEvent('Recipe Favorited', properties: {
          'recipe_name': widget.recipe.label,
        });
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.translate('recipes_favoriteError'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFFFF3B30),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Helper to build recipe prompt (non-async to avoid 'yield' keyword conflict)
  String _buildRecipePrompt(String langCode) {
    final ingredientsList = widget.recipe.ingredientLines.join('\n');
    final recipeServings = widget.recipe.yield;
    final recipeName = widget.recipe.label;
    
    return '''Create cooking instructions for: $recipeName

Ingredients:
$ingredientsList

Serves: $recipeServings servings''';
  }

  /// Fetch instructions from Spoonacular API
  Future<String?> _fetchSpoonacularInstructions() async {
    // Extract recipe ID from URI (format: spoonacular:12345)
    final uri = widget.recipe.uri;
    if (!uri.startsWith('spoonacular:')) return null;
    
    final recipeId = uri.replaceFirst('spoonacular:', '');
    final apiKey = EnvConfig.spoonacularApiKey;
    
    if (apiKey == null || apiKey.isEmpty) return null;
    
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.spoonacular.com/recipes/$recipeId/information?apiKey=$apiKey&includeNutrition=false',
        ),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        
        // Check for analyzedInstructions
        final instructions = data['analyzedInstructions'] as List<dynamic>?;
        if (instructions != null && instructions.isNotEmpty) {
          final steps = instructions[0]['steps'] as List<dynamic>?;
          if (steps != null && steps.isNotEmpty) {
            // Format steps as numbered list
            final formattedSteps = steps.map((step) {
              final number = step['number'];
              final text = step['step'];
              return '$number. $text';
            }).join('\n\n');
            
            return formattedSteps;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching Spoonacular instructions: $e');
    }
    
    return null;
  }

  /// Generate cooking instructions using OpenAI GPT
  Future<void> _generateRecipeInstructions() async {
    if (_isGeneratingRecipe || _generatedRecipe != null) return;

    setState(() {
      _isGeneratingRecipe = true;
      _recipeError = null;
    });

    try {
      // First, try to fetch from Spoonacular if it's a Spoonacular recipe
      if (widget.recipe.uri.startsWith('spoonacular:')) {
        debugPrint('🥄 Attempting to fetch Spoonacular instructions...');
        final spoonacularInstructions = await _fetchSpoonacularInstructions();
        
        if (spoonacularInstructions != null && spoonacularInstructions.isNotEmpty) {
          if (mounted) {
            setState(() {
              _generatedRecipe = spoonacularInstructions;
              _isGeneratingRecipe = false;
            });
          }
          
          MixpanelService.trackEvent('Recipe Instructions from Spoonacular',
            properties: {'recipe': widget.recipe.label}
          );
          return; // Successfully got Spoonacular instructions
        }
        
        debugPrint('🥄 No Spoonacular instructions found, falling back to AI generation');
      }
      
      // Fall back to AI generation (for Edamam recipes or Spoonacular without instructions)
      final apiKey = EnvConfig.openaiApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('OpenAI API key not configured');
      }

      // Get user's saved language from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString('languageCode') ?? 'en';
      
      // Build prompt using non-async helper to avoid 'yield' keyword conflict
      final userPrompt = _buildRecipePrompt(langCode);

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a professional chef. Generate clear, step-by-step cooking instructions for a recipe.
              
CRITICAL RULES:
- Respond in $langCode language
- Use PLAIN TEXT only - NO markdown formatting
- NO asterisks (*), NO hashtags (#), NO bold, NO italic
- Format as simple numbered steps: 1. 2. 3. etc.
- Be concise and clear
- Include cooking times and temperatures where appropriate
- Make instructions easy to follow for home cooks'''
            },
            {
              'role': 'user',
              'content': userPrompt
            }
          ],
          'max_tokens': 800,
          'temperature': 0.7,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final instructions = data['choices'][0]['message']['content'];
        
        if (mounted) {
          setState(() {
            _generatedRecipe = instructions.trim();
            _isGeneratingRecipe = false;
          });
        }

        // Track successful AI generation
        MixpanelService.trackEvent('Recipe Instructions Generated',
          properties: {
            'recipe': widget.recipe.label,
            'source': widget.recipe.uri.startsWith('spoonacular:') ? 'AI (Spoonacular fallback)' : 'AI (Edamam)',
          }
        );
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        debugPrint('OpenAI API error: ${response.statusCode} - $errorBody');
        throw Exception('Failed to generate recipe');
      }
    } catch (e) {
      debugPrint('Error generating recipe: $e');
      if (mounted) {
        setState(() {
          _recipeError = e.toString();
          _isGeneratingRecipe = false;
        });
      }
    }
  }

  /// Helper to get recipe servings (non-async to avoid yield keyword conflict)
  int _getRecipeServings() => widget.recipe.yield;

  /// Log recipe to calorie tracker (1 serving, today)
  Future<void> _logToTracker() async {
    if (_isLoggingToTracker) return;

    setState(() {
      _isLoggingToTracker = true;
    });

    try {
      final localizations = AppLocalizations.of(context)!;
      
      // Get current user ID
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }
      
      // Get recipe data
      final servings = _getRecipeServings();
      final recipeName = widget.recipe.label;
      final recipeImage = widget.recipe.image;
      final recipeCalories = widget.recipe.calories;
      final recipeTotalNutrients = widget.recipe.totalNutrients;
      
      // Calculate nutrition per serving
      final calories = (recipeCalories / servings).round().toDouble();
      final protein = (recipeTotalNutrients['PROCNT']?.quantity ?? 0) / servings;
      final carbs = (recipeTotalNutrients['CHOCDF']?.quantity ?? 0) / servings;
      final fat = (recipeTotalNutrients['FAT']?.quantity ?? 0) / servings;
      final fiber = (recipeTotalNutrients['FIBTG']?.quantity ?? 0) / servings;
      
      // Try multiple sugar fields with fallback strategy
      // 1. SUGAR (total sugars) - most comprehensive
      // 2. SUGAR.added (added sugars only) - fallback if total not available
      final sugarTotal = recipeTotalNutrients['SUGAR']?.quantity;
      final sugarAdded = recipeTotalNutrients['SUGAR.added']?.quantity;
      final sugar = ((sugarTotal ?? sugarAdded) ?? 0) / servings;
      
      final sodium = (recipeTotalNutrients['NA']?.quantity ?? 0) / servings;

      // Calculate serving size in grams
      final totalWeight = widget.recipe.totalWeight;
      final servingSizeGrams = totalWeight != null && totalWeight > 0
          ? (totalWeight / servings)
          : 0.0;
      
      // Extract micronutrients for nutrition detail page
      final micronutrients = <String, Micronutrient>{};
      
      // Helper function to add micronutrient if available
      void addMicro(String key, String edamamCode, String unit) {
        final nutrient = recipeTotalNutrients[edamamCode];
        if (nutrient != null && nutrient.quantity != null) {
          micronutrients[key] = Micronutrient(
            value: nutrient.quantity! / servings,
            unit: unit,
          );
        }
      }
      
      // Add micronutrients (codes from Edamam API doc)
      addMicro('saturated_fat', 'FASAT', 'g');
      addMicro('polyunsaturated_fat', 'FAPU', 'g');
      addMicro('monounsaturated_fat', 'FAMS', 'g');
      addMicro('cholesterol', 'CHOLE', 'mg');
      addMicro('potassium', 'K', 'mg');
      addMicro('vitaminA', 'VITA_RAE', 'µg');
      addMicro('vitaminC', 'VITC', 'mg');
      addMicro('calcium', 'CA', 'mg');
      addMicro('iron', 'FE', 'mg');

      // Determine meal type based on current time
      final now = DateTime.now();
      final hour = now.hour;
      MealType mealType;
      if (hour >= 5 && hour < 11) {
        mealType = MealType.breakfast;
      } else if (hour >= 11 && hour < 16) {
        mealType = MealType.lunch;
      } else if (hour >= 16 && hour < 22) {
        mealType = MealType.dinner;
      } else {
        mealType = MealType.snack;
      }

      // Create FoodLog entry
      final foodLog = FoodLog(
        userId: userId,
        foodName: recipeName,
        mealType: mealType,
        loggedAt: DateTime.now(),
        nutritionData: NutritionData(
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          fiber: fiber,
          sugar: sugar,
          sodium: sodium,
          micronutrients: micronutrients,
          servingInfo: servingSizeGrams > 0
              ? ServingInfo(
                  amount: 1.0,
                  unit: 'serving',
                  weight: servingSizeGrams,
                  weightUnit: 'g',
                )
              : null,
        ),
        imageUrl: recipeImage,
      );

      // Save to Firestore
      await _nutritionRepository.addFoodLog(foodLog);

      if (mounted) {
        setState(() {
          _isLoggingToTracker = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.translate('recipes_loggedToTracker'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFFed3272), // Brand pink
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Track event
        MixpanelService.trackEvent('Recipe Logged to Tracker', properties: {
          'recipe_name': widget.recipe.label,
          'calories': calories,
        });
      }
    } catch (e) {
      debugPrint('Error logging to tracker: $e');
      if (mounted) {
        setState(() {
          _isLoggingToTracker = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.translate('recipes_logError'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFFFF3B30), // Red error (keep red for errors)
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final servings = widget.recipe.yield;
    final caloriesPerServing = (widget.recipe.calories / servings).round();
    
    // Calculate serving size in grams (if available from API)
    final totalWeight = widget.recipe.totalWeight;
    final servingSizeGrams = totalWeight != null && totalWeight > 0
        ? (totalWeight / servings).round()
        : 0;

    // Extract key nutrients and calculate per serving
    final protein = widget.recipe.totalNutrients['PROCNT'];
    final carbs = widget.recipe.totalNutrients['CHOCDF'];
    final fat = widget.recipe.totalNutrients['FAT'];
    
    final proteinPerServing = protein != null ? protein.quantity / servings : 0.0;
    final carbsPerServing = carbs != null ? carbs.quantity / servings : 0.0;
    final fatPerServing = fat != null ? fat.quantity / servings : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB), // White background per style guide
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark, // Dark/black icons
              statusBarBrightness: Brightness.light, // For iOS
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Color(0xFF1A1A1A), // Dark for visibility
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              // Favorite button
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: _isCheckingFavorite
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFed3272),
                            ),
                          ),
                        )
                      : Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite
                              ? const Color(0xFFed3272)
                              : const Color(0xFF1A1A1A),
                          size: 24,
                        ),
                  onPressed: _isCheckingFavorite ? null : _toggleFavorite,
                ),
              ),
              // Add to tracker button
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272), // Brand pink
                      Color(0xFFfd5d32), // Brand orange
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFed3272).withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: _isLoggingToTracker
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                  onPressed: _isLoggingToTracker ? null : _logToTracker,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'recipe_${widget.recipe.uri}',
                child: Image.network(
                  widget.recipe.image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFFBFBFB),
                      child: const Center(
                        child: Icon(
                          Icons.restaurant,
                          size: 80,
                          color: Color(0xFFed3272),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFFBFBFB),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe title and source
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TextSanitizer.sanitizeForDisplay(
                            widget.recipe.label.replaceAll(RegExp(r'[{}]'), ''), // Remove braces
                          ),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A), // Dark text per style guide
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        
                        // Diet/health labels chips with gradient background
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...widget.recipe.healthLabels.take(5).map(
                              (label) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Color(0xFFed3272), // Brand pink
                                      Color(0xFFfd5d32), // Brand orange
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white, // White text on gradient
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Nutrition info cards (2x2 grid) with subtle background
                  Container(
                    margin: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 0),
                    padding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA), // Very subtle gray background
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.translate('recipes_nutrition'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          servingSizeGrams > 0
                              ? '${localizations.translate('recipes_perServing')} (~${servingSizeGrams}g) • Recipe makes $servings ${servings == 1 ? localizations.translate('recipes_serving') : localizations.translate('recipes_servings')}'
                              : '${localizations.translate('recipes_perServing')} • Recipe makes $servings ${servings == 1 ? localizations.translate('recipes_serving') : localizations.translate('recipes_servings')}',
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          localizations.translate('recipes_nutritionForOneServing'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF666666), // Gray text
                          ),
                        ),
                        const SizedBox(height: 4),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          childAspectRatio: 1.6,
                          children: [
                            NutritionInfoCard(
                              icon: Icons.local_fire_department,
                              label: localizations.translate('recipes_calories'),
                              value: caloriesPerServing.toString(),
                              unit: 'kcal',
                            ),
                            if (protein != null)
                              NutritionInfoCard(
                                icon: Icons.fitness_center,
                                label: localizations.translate('recipes_protein'),
                                value: proteinPerServing.toStringAsFixed(1),
                                unit: protein.unit,
                              ),
                            if (carbs != null)
                              NutritionInfoCard(
                                icon: Icons.grass,
                                label: localizations.translate('recipes_carbs'),
                                value: carbsPerServing.toStringAsFixed(1),
                                unit: carbs.unit,
                              ),
                            if (fat != null)
                              NutritionInfoCard(
                                icon: Icons.water_drop,
                                label: localizations.translate('recipes_fat'),
                                value: fatPerServing.toStringAsFixed(1),
                                unit: fat.unit,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                 // const SizedBox(height: 2),

                  // Ingredients section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.translate('recipes_ingredients'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...widget.recipe.ingredientLines.map(
                          (ingredient) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: Color(0xFFed3272), // Brand pink
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    TextSanitizer.sanitizeForDisplay(ingredient),
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Cooking Instructions section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.translate('recipes_cookingInstructions'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Show button if recipe not generated
                        if (_generatedRecipe == null && !_isGeneratingRecipe && _recipeError == null)
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color(0xFFed3272), // Brand pink
                                    Color(0xFFfd5d32), // Brand orange
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFed3272).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: _generateRecipeInstructions,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.auto_awesome,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          localizations.translate('recipes_generateInstructions'),
                                          style: const TextStyle(
                                            fontFamily: 'ElzaRound',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        
                        // Loading state
                        if (_isGeneratingRecipe)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFed3272),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    localizations.translate('recipes_generatingInstructions'),
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        // Error state
                        if (_recipeError != null && _generatedRecipe == null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFfd5d32).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Color(0xFFfd5d32),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        localizations.translate('recipes_generationError'),
                                        style: const TextStyle(
                                          fontFamily: 'ElzaRound',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _recipeError = null;
                                    });
                                    _generateRecipeInstructions();
                                  },
                                  child: Text(
                                    localizations.translate('recipes_tryAgain'),
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFed3272),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Display generated recipe
                        if (_generatedRecipe != null)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFed3272).withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(0xFFed3272),
                                        Color(0xFFfd5d32),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  TextSanitizer.sanitizeForDisplay(_generatedRecipe!),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF1A1A1A),
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

