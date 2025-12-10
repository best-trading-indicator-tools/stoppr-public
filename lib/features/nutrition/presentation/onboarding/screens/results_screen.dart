import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/nutrition/presentation/screens/nutrition_goals_screen.dart';
import 'package:stoppr/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:stoppr/features/nutrition/data/models/nutrition_goals.dart';
import 'package:stoppr/features/nutrition/presentation/screens/calorie_tracker_dashboard.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.activity,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.isMetric,
  });
  
  final String activity;
  final int heightCm;
  final int weightKg;
  final String goal;
  final bool isMetric;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final Map<String, dynamic> _calculations;
  
  @override
  void initState() {
    super.initState();
    _calculations = _calculateNutritionPlan();
  }

  Map<String, dynamic> _calculateNutritionPlan() {
    // Calculate BMR using Mifflin-St Jeor Equation (assuming age 25, male for simplicity)
    // For more accuracy, you'd collect gender and age in onboarding
    final bmr = (10 * widget.weightKg) + (6.25 * widget.heightCm) - (5 * 25) + 5;
    
    // Activity multipliers
    final activityMultipliers = {
      'light': 1.375,
      'moderate': 1.55,
      'active': 1.725,
    };
    
    final tdee = bmr * (activityMultipliers[widget.activity] ?? 1.55);
    
    // Goal adjustments
    double targetCalories = tdee;
    double targetWeightKg = widget.weightKg.toDouble();
    
    switch (widget.goal) {
      case 'lose':
        targetCalories = tdee - 500; // 500 calorie deficit for 1lb/week loss
        targetWeightKg -= 5; // Target to lose 5 kg (approximately 10 lbs)
        break;
      case 'gain':
        targetCalories = tdee + 300; // 300 calorie surplus for gradual gain
        targetWeightKg += 4; // Target to gain 4 kg (approximately 8 lbs)
        break;
      case 'maintain':
      default:
        targetCalories = tdee;
        // For maintain goal, preserve exact original weight to avoid rounding issues
        // No change to targetWeightKg - it stays the same as current weight
        break;
    }
    
    // Macronutrient distribution (low-carb focused approach)
    final proteinGrams = (widget.weightKg * 2.0).round(); // 2.0g per kg body weight (optimal for muscle preservation/building)
    final proteinCalories = proteinGrams * 4;
    
    final fatCalories = targetCalories * 0.35; // 35% of calories from fat (higher for satiety)
    final fatGrams = (fatCalories / 9).round();
    
    // Calculate carbs based on goal (very specific targets)
    int carbGrams;
    switch (widget.goal) {
      case 'lose':
        carbGrams = 25; // Fixed 20-30g max for weight loss
        break;
      case 'maintain':
        carbGrams = 50; // Fixed 50g for maintenance
        break;
      case 'gain':
        carbGrams = 100; // Fixed 100g for muscle gain
        break;
      default:
        carbGrams = 50; // Default to maintenance
        break;
    }
    
    final carbCalories = carbGrams * 4;
    
    // Recalculate target calories based on actual macros (protein + fat + carbs)
    // Use the same calculation method as the nutrition goals screen
    final actualCalories = (proteinGrams * 4) + (carbGrams * 4) + (fatGrams * 9).toDouble();
    
    // Calculate micronutrient goals based on plan
    final fiberGrams = _calculateFiberGoal(targetCalories);
    final sugarGrams = _calculateSugarGoal(carbGrams.toDouble());
    final sodiumMg = _calculateSodiumGoal(widget.goal);
    final waterMl = _calculateWaterGoal(widget.weightKg.toDouble(), widget.activity);

    // Smart health score calculation (similar to daily breakdown logic)
    double healthScore = _calculateSmartHealthScore(
      carbGrams.toDouble(),
      sugarGrams, // Use calculated sugar goal
      fiberGrams, // Use calculated fiber goal
      proteinGrams.toDouble(),
      widget.weightKg.toDouble(),
      actualCalories, // Use actual calculated calories
      bmr,
      tdee,
    );

    return {
      'calories': actualCalories.round(),
      'carbs': carbGrams,
      'protein': proteinGrams,
      'fat': fatGrams,
      'fiber': fiberGrams,
      'sugar': sugarGrams,
      'sodium': sodiumMg,
      'water': waterMl,
      'targetWeightKg': targetWeightKg,
      'healthScore': healthScore.round(),
    };
  }

  /// Smart health score calculation based on nutrition quality
  /// Similar to the logic used in daily breakdown screen
  double _calculateSmartHealthScore(
    double carbs,
    double sugar,
    double fiber,
    double protein,
    double bodyWeightKg,
    double calories,
    double bmr,
    double tdee,
  ) {
    // Start with perfect score
    double score = 10.0;

    // 1. Carb penalty (major factor for health)
    // Movement/workout mitigation factor - assume moderate activity reduces penalty by 20%
    double movementFactor = widget.activity == 'active' ? 0.6 : 
                           widget.activity == 'moderate' ? 0.8 : 1.0;

    if (carbs > 100) {
      score -= 4.0 * movementFactor; // Terrible carb intake
    } else if (carbs > 50) {
      score -= 2.0 * movementFactor; // Bad carb intake
    }

    // 2. Sugar penalty (estimated from carbs)
    if (sugar > 50) {
      score -= (sugar - 50) / 10; // Progressive penalty for excess sugar
    }

    // 3. Fiber bonus (gut health & satiety)
    if (fiber >= 25) {
      score += 1.0; // Reward adequate fiber
    }

    // 4. Protein adequacy (muscle preservation/building)
    final proteinPerKg = protein / bodyWeightKg;
    if (proteinPerKg >= 2.0) {
      score += 0.5; // Bonus for optimal protein (2g/kg)
    } else if (proteinPerKg >= 1.6) {
      score += 0.2; // Small bonus for adequate protein
    } else if (proteinPerKg < 1.2) {
      score -= 1.0; // Penalty for insufficient protein
    }

    // 5. Calorie appropriateness (metabolic health)
    if (calories < bmr * 1.2) {
      score -= 2.0; // Too aggressive deficit - metabolic damage risk
    } else if (calories > tdee * 1.2) {
      score -= 1.0; // Excessive surplus - unnecessary fat gain
    } else if (calories >= bmr * 1.2 && calories <= tdee * 1.1) {
      score += 0.5; // Bonus for reasonable calorie target
    }

    // 6. Goal-specific adjustments
    switch (widget.goal) {
      case 'lose':
        // Reward moderate deficit for weight loss
        if (calories >= tdee - 600 && calories <= tdee - 300) {
          score += 0.5;
        }
        break;
      case 'gain':
        // Reward conservative surplus for muscle gain
        if (calories >= tdee + 200 && calories <= tdee + 400) {
          score += 0.5;
        }
        break;
      case 'maintain':
        // Reward maintenance calories
        if (calories >= tdee * 0.95 && calories <= tdee * 1.05) {
          score += 0.5;
        }
        break;
    }

    return score.clamp(0.0, 10.0);
  }

  /// Calculate fiber goal based on calories (14g per 1000 calories - FDA recommendation)
  double _calculateFiberGoal(double calories) {
    return (calories / 1000 * 14).clamp(20.0, 40.0); // Min 20g, max 40g
  }

  /// Calculate sugar goal based on carbs (max 10% of total calories - WHO recommendation)
  double _calculateSugarGoal(double carbs) {
    // Default to 50g for first-time AI analysis after calories tracker onboarding
    return 50.0;
  }

  /// Calculate sodium goal based on goal type
  double _calculateSodiumGoal(String goal) {
    switch (goal) {
      case 'lose':
        return 1800.0; // Lower sodium for weight loss (reduces water retention)
      case 'gain':
        return 2500.0; // Higher sodium for muscle gain (supports training)
      case 'maintain':
      default:
        return 2300.0; // Standard FDA recommendation
    }
  }

  /// Calculate water goal based on body weight and activity
  double _calculateWaterGoal(double weightKg, String activity) {
    // Base: 35ml per kg body weight
    double baseWater = weightKg * 35;
    
    // Activity adjustments
    switch (activity) {
      case 'active':
        baseWater *= 1.3; // +30% for active individuals
        break;
      case 'moderate':
        baseWater *= 1.15; // +15% for moderate activity
        break;
      case 'light':
      default:
        baseWater *= 1.0; // No adjustment for light activity
        break;
    }
    
    return baseWater.clamp(1500.0, 4000.0); // Min 1.5L, max 4L
  }

  /// For maintain goal with imperial units, calculate the closest original weight
  /// that would have resulted in the current kg value after rounding
  int _getOriginalImperialWeight() {
    final currentKg = widget.weightKg;
    // Find the lb value that, when converted to kg and rounded, gives currentKg
    // Try values around the exact conversion, preferring the lower value
    final exactLbs = currentKg * 2.20462;
    final baseLbs = exactLbs.round();
    
    // Test values around the conversion, starting from lower values
    for (int testLbs = baseLbs - 2; testLbs <= baseLbs + 2; testLbs++) {
      if ((testLbs / 2.20462).round() == currentKg) {
        return testLbs; // Return the first (lowest) value that works
      }
    }
    
    // Fallback to the simple conversion
    return baseLbs;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      
                      // Checkmark icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFed3272), // Brand pink
                              Color(0xFFfd5d32), // Brand orange
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Title (localized + overflow-safe)
                      Text(
                        l10n.translate('calorieOnboarding_results_title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      
                      // Target weight section
                      Text(
                        l10n.translate('calorieOnboarding_results_shouldMaintain'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFed3272), // Brand pink
                              Color(0xFFfd5d32), // Brand orange
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.isMetric
                              ? '${_calculations['targetWeightKg'].round()} ${l10n.translate('unit_kg')}'
                              : widget.goal == 'maintain'
                                  ? '${_getOriginalImperialWeight()} ${l10n.translate('unit_lbs')}'
                                  : '${(_calculations['targetWeightKg'] * 2.20462).round()} ${l10n.translate('unit_lbs')}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Daily recommendation section with gray background
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('calorieOnboarding_results_dailyRecommendation'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.translate('calorieOnboarding_results_canEdit'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Macros grid (2x2)
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              // Slightly taller cards to comfortably fit larger content
                              childAspectRatio: 1.2,
                              children: [
                                _MacroCard(
                                  icon: '🔥',
                                  title: l10n.translate('calorieOnboarding_results_calories'),
                                  value: _calculations['calories'].toString(),
                                  color: Colors.black,
                                  currentValue: _calculations['calories'].toDouble(),
                                  maxValue: _calculations['calories'].toDouble(),
                                ),
                                _MacroCard(
                                  icon: '🌾',
                                  title: l10n.translate('calorieOnboarding_results_carbs'),
                                  value: '${_calculations['carbs']}${l10n.translate('unit_g')}',
                                  color: const Color(0xFFE67E22),
                                  currentValue: _calculations['carbs'].toDouble(),
                                  maxValue: _calculations['carbs'].toDouble(),
                                ),
                                _MacroCard(
                                  icon: '🥩',
                                  title: l10n.translate('calorieOnboarding_results_protein'),
                                  value: '${_calculations['protein']}${l10n.translate('unit_g')}',
                                  color: const Color(0xFFE74C3C),
                                  currentValue: _calculations['protein'].toDouble(),
                                  maxValue: _calculations['protein'].toDouble(),
                                ),
                                _MacroCard(
                                  icon: '🥑',
                                  title: l10n.translate('calorieOnboarding_results_fats'),
                                  value: '${_calculations['fat']}${l10n.translate('unit_g')}',
                                  color: const Color(0xFF3498DB),
                                  currentValue: _calculations['fat'].toDouble(),
                                  maxValue: _calculations['fat'].toDouble(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Processed Sugar card (full width below grid)
                            _MacroCard(
                              icon: '🍬',
                              title: l10n.translate('calorieOnboarding_results_sugar'),
                              value: '${_calculations['sugar'].round()}${l10n.translate('unit_g')}',
                              color: const Color(0xFF9B59B6),
                              currentValue: _calculations['sugar'].toDouble(),
                              maxValue: 50.0,
                            ),
                            const SizedBox(height: 8),
                            
                            // Health score as a white subsection
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE91E63),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.favorite,
                                          color: Colors.white,
                                          size: 10,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.translate('calorieOnboarding_results_healthScore'),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${_calculations['healthScore']}/10',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _calculations['healthScore'] / 10,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              
              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
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
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ElevatedButton(
                  onPressed: () async {
                    try {
                      // Create and save the calculated nutrition goals
                      final goals = NutritionGoals(
                        userId: '', // Repository handles userId internally
                        calories: _calculations['calories'].toDouble(),
                        protein: _calculations['protein'].toDouble(),
                        carbs: _calculations['carbs'].toDouble(),
                        fat: _calculations['fat'].toDouble(),
                        fiber: _calculations['fiber'].toDouble(),
                        sugar: _calculations['sugar'].toDouble(),
                        sodium: _calculations['sodium'].toDouble(),
                        water: _calculations['water'].toDouble(),
                        updatedAt: DateTime.now(),
                      );
                      
                      // Save goals to Firestore
                      final repository = NutritionRepository();
                      await repository.saveNutritionGoals(goals);
                      
                      debugPrint('✅ AI nutrition goals saved: ${goals.calories} calories');
                      
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CalorieTrackerDashboard(),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('❌ Error saving nutrition goals: $e');
                      // Continue to navigation even if save fails
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CalorieTrackerDashboard(),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.translate('calorieOnboarding_continue'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.currentValue,
    required this.maxValue,
  });

  final String icon;
  final String title;
  final String value;
  final Color color;
  final double currentValue;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon and title row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Progress circle - centered
          Center(
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: (currentValue / maxValue).clamp(0.0, 1.0),
                      strokeWidth: 3.0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


