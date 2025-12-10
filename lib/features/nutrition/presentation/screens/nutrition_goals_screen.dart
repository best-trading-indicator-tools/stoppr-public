import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../data/models/nutrition_goals.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../widgets/nutrient_progress_ring.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../onboarding/screens/workouts_per_week_screen.dart';
import 'package:stoppr/features/nutrition/presentation/screens/calorie_tracker_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NutritionGoalsScreen extends StatefulWidget {
  const NutritionGoalsScreen({
    Key? key, 
    this.showDoneButton = false,
    this.aiGeneratedGoals,
    this.heightCm,
    this.weightKg,
    this.targetWeightKg,
  }) : super(key: key);
  
  final bool showDoneButton;
  final NutritionGoals? aiGeneratedGoals;
  final double? heightCm;
  final double? weightKg;
  final double? targetWeightKg;

  @override
  State<NutritionGoalsScreen> createState() => _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends State<NutritionGoalsScreen> {
  final _nutritionRepository = NutritionRepository();
  
  // Text controllers
  final _calorieController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _waterController = TextEditingController();

  bool _showMicronutrients = false;
  bool _isLoading = false;
  NutritionGoals? _currentGoals;
  bool _goalsValidated = false;
  bool _waterGoalUseOz = false; // preference for water unit in goals screen
  bool _isTyping = false; // prevent stream overwrites and CTA flicker
  Timer? _typingDebounce;
  NutritionGoals? _lastSavedGoals; // stable baseline for unsaved-change check
  bool _forceShowSaveCta = false; // keep Save CTA visible once any edit occurs

  void _updateCaloriesFromMacros() {
    final protein = double.tryParse(_proteinController.text) ?? 0;
    final carbs = double.tryParse(_carbController.text) ?? 0;
    final fat = double.tryParse(_fatController.text) ?? 0;
    final calories = (protein * 4) + (carbs * 4) + (fat * 9);
    _calorieController.text = calories.round().toString();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    
    // Force status bar to dark
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    MixpanelService.trackPageView('Nutrition Goals Screen');
    _loadCurrentGoals();

    // Force reload localizations so newly-added keys show up without app restart
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        await l10n.forceReload();
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _loadCurrentGoals() async {
    final prefs = await SharedPreferences.getInstance();
    _waterGoalUseOz = prefs.getBool('water_goal_unit_oz') ?? false;
    // If we have AI-generated goals, use those instead of loading from database
    if (widget.aiGeneratedGoals != null) {
      final goals = widget.aiGeneratedGoals!;
      setState(() {
        _currentGoals = goals;
        _proteinController.text = goals.protein.round().toString();
        _carbController.text = goals.carbs.round().toString();
        _fatController.text = goals.fat.round().toString();
        _fiberController.text = goals.fiber.round().toString();
        _sugarController.text = goals.sugar.round().toString();
        _sodiumController.text = goals.sodium.round().toString();
        _waterController.text = _waterGoalUseOz
            ? (goals.water / 29.5735).round().toString()
            : (goals.water / 1000).toStringAsFixed(2);
      });
      _updateCaloriesFromMacros();
      return;
    }

    // Otherwise, load existing goals from database
    final goalsStream = _nutritionRepository.getNutritionGoals();
    goalsStream.listen((goals) {
      if (goals != null && mounted) {
        if (_isTyping) return; // avoid overriding user inputs mid-typing
        setState(() {
          _currentGoals = goals;
          _proteinController.text = goals.protein.round().toString();
          _carbController.text = goals.carbs.round().toString();
          _fatController.text = goals.fat.round().toString();
          _fiberController.text = goals.fiber.round().toString();
          _sugarController.text = goals.sugar.round().toString();
          _sodiumController.text = goals.sodium.round().toString();
          _waterController.text = _waterGoalUseOz
              ? (goals.water / 29.5735).round().toString()
              : (goals.water / 1000).toStringAsFixed(2);
          _lastSavedGoals = goals;
        });
        // Ensure calories reflect macros when loading existing goals
        _updateCaloriesFromMacros();
      }
    });
  }

  Future<void> _saveGoals() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      
      // Generate default goals if fields are empty
      final defaultGoals = NutritionGoals.defaultGoals(
        userId: userId,
        gender: 'male', // TODO: Get from user profile
        age: 30,
        weight: 70,
        height: 170,
        activityLevel: 'moderate',
      );
      
      final goals = NutritionGoals(
        userId: userId,
        calories: double.tryParse(_calorieController.text) ?? defaultGoals.calories,
        protein: double.tryParse(_proteinController.text) ?? defaultGoals.protein,
        carbs: double.tryParse(_carbController.text) ?? defaultGoals.carbs,
        fat: double.tryParse(_fatController.text) ?? defaultGoals.fat,
        fiber: double.tryParse(_fiberController.text) ?? defaultGoals.fiber,
        sugar: double.tryParse(_sugarController.text) ?? defaultGoals.sugar,
        sodium: double.tryParse(_sodiumController.text) ?? defaultGoals.sodium,
        water: (() {
          final v = double.tryParse(_waterController.text);
          if (v == null) return defaultGoals.water;
          return _waterGoalUseOz ? (v * 29.5735) : (v * 1000.0);
        })(),
        updatedAt: DateTime.now(),
      );

      await _nutritionRepository.saveNutritionGoals(goals);
      if (mounted) {
        setState(() {
          _lastSavedGoals = goals; // update baseline on successful save
          _forceShowSaveCta = false; // reset after successful save
        });
      }
      
      MixpanelService.trackEvent('Nutrition Goals Saved', properties: {
        'calories': goals.calories,
        'protein': goals.protein,
        'carbs': goals.carbs,
        'fat': goals.fat,
      });

    } catch (e) {
      // Handle error
      debugPrint('Error saving goals: $e');
    }
  }

  Future<void> _toggleWaterGoalUnit() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final current = double.tryParse(_waterController.text) ?? 0;
      if (_waterGoalUseOz) {
        // switch to liters
        final liters = current / 33.814; // 1 L = 33.814 fl oz
        _waterController.text = liters.toStringAsFixed(2);
        _waterGoalUseOz = false;
      } else {
        // switch to ounces
        final ounces = current * 33.814;
        _waterController.text = ounces.round().toString();
        _waterGoalUseOz = true;
      }
    });
    await prefs.setBool('water_goal_unit_oz', _waterGoalUseOz);
  }

  void _showWaterSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, modalSetState) {
            String _servingLabel(double servingMl) {
              if (_waterGoalUseOz) {
                final oz = servingMl / 29.5735;
                final String ozStr = (oz - oz.roundToDouble()).abs() < 0.05
                    ? oz.round().toString()
                    : oz.toStringAsFixed(1);
                return '$ozStr ${AppLocalizations.of(context)!.translate('unit_oz')}';
              } else {
                final liters = servingMl / 1000.0;
                return '${liters.toStringAsFixed(2)} ${AppLocalizations.of(context)!.translate('unit_l')}';
              }
            }

            return FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, snap) {
                final prefs = snap.data;
                final servingMl = prefs?.getDouble('water_serving_ml') ?? (_waterGoalUseOz ? 236.588 : 250.0);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(AppLocalizations.of(context)!.translate('water_settings_title'),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 20),
                      Text(AppLocalizations.of(context)!.translate('water_settings_serving_size'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _servingLabel(servingMl),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              await _toggleWaterGoalUnit();
                              modalSetState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _waterGoalUseOz
                                    ? AppLocalizations.of(context)!.translate('unit_oz')
                                    : AppLocalizations.of(context)!.translate('unit_l'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              await _showServingPicker(ctx, useOz: _waterGoalUseOz, onSaved: () { modalSetState(() {}); });
                            },
                            child: const Icon(Icons.edit, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(AppLocalizations.of(context)!.translate('water_settings_hydration_question'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        _waterGoalUseOz
                            ? AppLocalizations.of(context)!.translate('water_settings_recommendation_oz')
                            : AppLocalizations.of(context)!.translate('water_settings_recommendation_l'),
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      // Branded Done button
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)!.translate('done'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showServingPicker(BuildContext bottomSheetContext, {required bool useOz, VoidCallback? onSaved}) async {
    final prefs = await SharedPreferences.getInstance();
    double tempServingMl = prefs.getDouble('water_serving_ml') ?? (useOz ? 236.588 : 250.0);
    final controller = FixedExtentScrollController(
      initialItem: useOz
          ? (tempServingMl / 29.5735).round().clamp(1, 16) - 1
          : ((tempServingMl / 1000.0) / 0.05).round().clamp(1, 10) - 1,
    );

    await showModalBottomSheet(
      context: bottomSheetContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(AppLocalizations.of(context)!.translate('water_settings_serving_size'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 36,
                    onSelectedItemChanged: (i) {
                      if (useOz) {
                        final oz = (i + 1).toDouble();
                        tempServingMl = oz * 29.5735;
                      } else {
                        final liters = (i + 1) * 0.05; // 0.05L increments
                        tempServingMl = liters * 1000.0;
                      }
                    },
                    children: List.generate(useOz ? 16 : 10, (i) {
                      if (useOz) {
                        final oz = i + 1;
                        final cupsFrac = oz / 8.0;
                        return Center(child: Text('$oz ${AppLocalizations.of(context)!.translate('unit_oz')} (${cupsFrac.toStringAsFixed(cupsFrac == cupsFrac.roundToDouble() ? 0 : 3)} cups)'));
                      } else {
                        final liters = ((i + 1) * 0.05);
                        final cups = (liters * 1000.0) / 250.0;
                        return Center(child: Text('${liters.toStringAsFixed(2)} ${AppLocalizations.of(context)!.translate('unit_l')} (${cups.toStringAsFixed(cups == cups.roundToDouble() ? 0 : 1)} cups)'));
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(16)),
                        child: Center(
                          child: Text(AppLocalizations.of(context)!.translate('common_cancel'),
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await prefs.setDouble('water_serving_ml', tempServingMl);
                          if (onSaved != null) onSaved();
                          if (mounted) Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(AppLocalizations.of(context)!.translate('common_save'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _markTyping() {
    _isTyping = true;
    if (!_forceShowSaveCta) {
      // Once user starts editing, keep CTA visible until saved
      setState(() => _forceShowSaveCta = true);
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _isTyping = false);
    });
  }

  Future<void> _saveAIGeneratedGoals() async {
    try {
      if (widget.aiGeneratedGoals == null) return;

      debugPrint('🔄 Starting to save AI-generated goals to Firestore...');

      // Save the AI-generated nutrition goals
      try {
        await _nutritionRepository.saveNutritionGoals(widget.aiGeneratedGoals!);
        debugPrint('✅ AI-generated nutrition goals CONFIRMED saved to Firestore: ${widget.aiGeneratedGoals!.calories} calories');
      } catch (e) {
        debugPrint('❌ Failed to save nutrition goals: $e');
        rethrow;
      }
      
      // Save height, weight, and target weight if provided
      if (widget.heightCm != null) {
        try {
          await _nutritionRepository.saveHeight(widget.heightCm!);
          debugPrint('✅ Height CONFIRMED saved to Firestore: ${widget.heightCm}cm');
        } catch (e) {
          debugPrint('❌ Failed to save height: $e');
          rethrow;
        }
      }
      
      if (widget.weightKg != null) {
        try {
          await _nutritionRepository.addWeightEntry(widget.weightKg!);
          debugPrint('✅ Weight entry CONFIRMED saved to Firestore: ${widget.weightKg}kg');
        } catch (e) {
          debugPrint('❌ Failed to save weight entry: $e');
          rethrow;
        }
      }
      
      if (widget.targetWeightKg != null) {
        try {
          await _nutritionRepository.saveGoalWeight(widget.targetWeightKg!);
          debugPrint('✅ Target weight CONFIRMED saved to Firestore: ${widget.targetWeightKg}kg');
        } catch (e) {
          debugPrint('❌ Failed to save target weight: $e');
          rethrow;
        }
      }

      debugPrint('🎉 ALL AI-generated data successfully saved to Firestore!');

      // Track the AI goals being saved
      MixpanelService.trackEvent('AI Generated Goals Saved', properties: {
        'calories': widget.aiGeneratedGoals!.calories,
        'protein': widget.aiGeneratedGoals!.protein,
        'carbs': widget.aiGeneratedGoals!.carbs,
        'fat': widget.aiGeneratedGoals!.fat,
        'height_cm': widget.heightCm,
        'weight_kg': widget.weightKg,
        'target_weight_kg': widget.targetWeightKg,
      });

    } catch (e) {
      debugPrint('❌ CRITICAL ERROR saving AI-generated goals: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  @override
  void dispose() {
    _calorieController.dispose();
    _proteinController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _sodiumController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            MixpanelService.trackButtonTap('Nutrition Goals Screen: Back Button');
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        title: Text(
          AppLocalizations.of(context)!
              .translate('calorieTracker_editNutritionGoals'),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                MixpanelService.trackButtonTap('Nutrition Goals Screen: Re-run Generator Link');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WorkoutsPerWeekScreen(isOnboarding: false),
                  ),
                );
              },
              child: Text(
                l10n.translate('nutritionGoals_rerunGenerator'),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
              // Calorie goal
              _buildGoalItem(
                icon: '🔥',
                label: AppLocalizations.of(context)!
                    .translate('calorieTracker_calorieGoal'),
                controller: _calorieController,
                color: const Color(0xFFed3272),
                value: double.tryParse(_calorieController.text) ?? 0,
                maxValue: 3000,
                readOnly: true,
                enabled: false,
              ),
              
              // Protein goal
              _buildGoalItem(
                icon: '🥩',
                label: AppLocalizations.of(context)!
                    .translate('calorieTracker_proteinGoal'),
                controller: _proteinController,
                color: const Color(0xFFFF6B6B),
                value: double.tryParse(_proteinController.text) ?? 0,
                maxValue: 300,
                onChanged: (_) {
                  _markTyping();
                  _updateCaloriesFromMacros();
                },
              ),
              
              // Carb goal
              _buildGoalItem(
                icon: '🥖',
                label: AppLocalizations.of(context)!
                    .translate('calorieTracker_carbGoal'),
                controller: _carbController,
                color: const Color(0xFFFFA726),
                value: double.tryParse(_carbController.text) ?? 0,
                maxValue: 400,
                onChanged: (_) {
                  _markTyping();
                  _updateCaloriesFromMacros();
                },
              ),
              
              // Fat goal
              _buildGoalItem(
                icon: '🧈',
                label: AppLocalizations.of(context)!
                    .translate('calorieTracker_fatGoal'),
                controller: _fatController,
                color: const Color(0xFF42A5F5),
                value: double.tryParse(_fatController.text) ?? 0,
                maxValue: 150,
                onChanged: (_) {
                  _markTyping();
                  _updateCaloriesFromMacros();
                },
              ),

              // Sugar goal (refined sugar limit)
              _buildGoalItem(
                icon: '🍬',
                label: AppLocalizations.of(context)!
                    .translate('calorieTracker_sugarGoal'),
                controller: _sugarController,
                color: const Color(0xFFFF69B4),
                value: double.tryParse(_sugarController.text) ?? 0,
                maxValue: 50,
                onChanged: (_) => _markTyping(),
              ),

              // Water goal with unit toggle (L or fl oz)
              Row(
                children: [
                  Expanded(child: _buildWaterGoalItem()),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showWaterSettingsSheet(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.settings, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              
              // Micronutrients toggle
              GestureDetector(
                onTap: () {
                  MixpanelService.trackButtonTap('Nutrition Goals Screen: Micronutrients Toggle', 
                    additionalProps: {
                      'toggle_state': (!_showMicronutrients).toString(),
                    });
                  setState(() {
                    _showMicronutrients = !_showMicronutrients;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showMicronutrients
                            ? AppLocalizations.of(context)!
                                .translate('calorieTracker_hideMicronutrients')
                            : AppLocalizations.of(context)!
                                .translate('calorieTracker_viewMicronutrients'),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      Icon(
                        _showMicronutrients ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Micronutrients
              if (_showMicronutrients) ...[
                _buildGoalItem(
                  icon: '🍎',
                  label: AppLocalizations.of(context)!
                      .translate('calorieTracker_fiberGoal'),
                  controller: _fiberController,
                  color: const Color(0xFF9C27B0),
                  value: double.tryParse(_fiberController.text) ?? 0,
                  maxValue: 100,
                  onChanged: (_) { _markTyping(); },
                ),
                
                _buildGoalItem(
                  icon: '🍬',
                  label: AppLocalizations.of(context)!
                      .translate('calorieTracker_sugarGoal'),
                  controller: _sugarController,
                  color: const Color(0xFFE91E63),
                  value: double.tryParse(_sugarController.text) ?? 0,
                  maxValue: 50,
                  onChanged: (_) { _markTyping(); },
                ),
                
                _buildGoalItem(
                  icon: '🧂',
                  label: AppLocalizations.of(context)!
                      .translate('calorieTracker_sodiumGoal'),
                  controller: _sodiumController,
                  color: const Color(0xFFFF9800),
                  value: double.tryParse(_sodiumController.text) ?? 0,
                  maxValue: 5000,
                  onChanged: (_) { _markTyping(); },
                ),
              ],
              
              const SizedBox(height: 32),
              
              const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  bool _hasUnsavedChanges() {
    final baseline = _lastSavedGoals ?? _currentGoals;
    if (baseline == null) return false;
    final protein = double.tryParse(_proteinController.text) ?? 0;
    final carbs = double.tryParse(_carbController.text) ?? 0;
    final fat = double.tryParse(_fatController.text) ?? 0;
    final fiber = double.tryParse(_fiberController.text) ?? 0;
    final sugar = double.tryParse(_sugarController.text) ?? 0;
    final sodium = double.tryParse(_sodiumController.text) ?? 0;
    final waterInput = double.tryParse(_waterController.text) ?? 0;
    final waterMl = _waterGoalUseOz ? (waterInput * 29.5735) : (waterInput * 1000.0);

    bool diff(num a, num b) => (a - b).abs() > 0.5; // tolerance
    final g = baseline;
    return diff(protein, g.protein) ||
        diff(carbs, g.carbs) ||
        diff(fat, g.fat) ||
        diff(fiber, g.fiber) ||
        diff(sugar, g.sugar) ||
        diff(sodium, g.sodium) ||
        diff(waterMl, g.water);
  }

  Widget? _buildFab(BuildContext context) {
    // First run: no saved goals and no AI-generated goals → show Auto-generate CTA
    if (_currentGoals == null && widget.aiGeneratedGoals == null) {
      return SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: FloatingActionButton.extended(
            onPressed: () {
              MixpanelService.trackButtonTap('Nutrition Goals Screen: Auto Generate Button');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkoutsPerWeekScreen(isOnboarding: false),
                ),
              );
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            label: Text(
              AppLocalizations.of(context)!.translate('calorieOnboarding_autoGenerate'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    // First pass: show Done button
    if (widget.showDoneButton && !_goalsValidated) {
      return SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: FloatingActionButton.extended(
            onPressed: () async {
              MixpanelService.trackButtonTap('Nutrition Goals Screen: Done Button');
              await _saveAIGeneratedGoals();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const CalorieTrackerDashboard()),
              );
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            label: Text(AppLocalizations.of(context)!.translate('done'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    // Subsequent visits: show Save Changes only when edits exist
    if (!(_forceShowSaveCta || _hasUnsavedChanges())) return null;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            MixpanelService.trackButtonTap('Nutrition Goals Screen: Save Changes Button');
            await _saveGoals();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              AppLocalizations.of(context)!.translate('calorieTracker_saveChanges'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalItem({
    required String icon,
    required String label,
    required TextEditingController controller,
    required Color color,
    required double value,
    required double maxValue,
    bool readOnly = false,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          // Progress ring with icon
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                NutrientProgressRing(
                  value: value,
                  maxValue: maxValue,
                  color: color,
                  size: 72,
                  strokeWidth: 5,
                ),
                const SizedBox(height: 0),
                Text(
                  icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          
          // Label and input
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        readOnly: readOnly,
                        enabled: enabled,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: enabled
                              ? Colors.white
                              : Colors.grey.shade200,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 0.8,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 0.8,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black.withOpacity(0.7),
                              width: 1.0,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (onChanged != null) {
                            onChanged(value);
                          } else {
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label.contains('Water')
                          ? AppLocalizations.of(context)!
                              .translate('unit_ml')
                          : label.contains('Sodium')
                              ? AppLocalizations.of(context)!
                                  .translate('unit_mg')
                              : AppLocalizations.of(context)!
                                  .translate('unit_g'),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterGoalItem() {
    final value = double.tryParse(_waterController.text) ?? 0;
    final unitLabel = _waterGoalUseOz
        ? AppLocalizations.of(context)!.translate('unit_oz')
        : AppLocalizations.of(context)!.translate('unit_l');
    // Progress ring: full at 2L (or 67.6 fl oz)
    final double normalizedValue = _waterGoalUseOz ? (value / 67.6 * 2.0) : value; // convert oz scale to liters-equivalent
    final double ringValue = normalizedValue; // NutrientProgressRing expects 'value' relative to 'maxValue'
    final double ringMax = 2.0; // full at 2L
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                NutrientProgressRing(
                  value: ringValue,
                  maxValue: ringMax,
                  color: const Color(0xFF29B6F6),
                  size: 72,
                  strokeWidth: 5,
                ),
                const Text('💧', style: TextStyle(fontSize: 24)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.translate('calorieTracker_waterGoal'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _waterController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.black.withOpacity(0.7), width: 1.0),
                          ),
                        ),
                        onChanged: (_) {
                          _markTyping();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _toggleWaterGoalUnit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unitLabel,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Onboarding Flow Screens (inline) =====================

class _NutritionOnboardingHeightWeightScreen extends StatefulWidget {
  const _NutritionOnboardingHeightWeightScreen({required this.activity});
  final String activity;

  @override
  State<_NutritionOnboardingHeightWeightScreen> createState() => _NutritionOnboardingHeightWeightScreenState();
}

class _NutritionOnboardingHeightWeightScreenState extends State<_NutritionOnboardingHeightWeightScreen> {
  final _repo = NutritionRepository();
  bool _metric = true;
  int _heightCm = 170;
  int _weightKg = 70;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const _NutritionOnboardingActivityScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        centerTitle: true,
        title: const SizedBox(),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Column(
        children: [
          // Progress bar aligned with back button
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
            child: Row(
              children: [
                const SizedBox(width: 40), // Space for back button
                Expanded(child: _TopProgressBar(value: 0.5)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    l10n.translate('calorieOnboarding_heightWeight_title'),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('calorieOnboarding_heightWeight_subtitle'),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const Spacer(flex: 1),
                  // Toggle switch
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _metric = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: !_metric ? Colors.black : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                l10n.translate('calorieOnboarding_imperial'),
                                style: TextStyle(
                                  color: !_metric ? Colors.white : Colors.grey.shade600,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _metric = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: _metric ? Colors.black : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                l10n.translate('calorieOnboarding_metric'),
                                style: TextStyle(
                                  color: _metric ? Colors.white : Colors.grey.shade600,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Height and Weight inputs
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('calorieOnboarding_height_label'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            _NumberPicker(
                              value: _heightCm,
                              unit: l10n.translate('unit_cm'),
                              onChanged: (v) => setState(() => _heightCm = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('calorieOnboarding_weight_label'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            _NumberPicker(
                              value: _weightKg,
                              unit: _metric ? l10n.translate('unit_kg') : l10n.translate('unit_lbs'),
                              onChanged: (v) => setState(() => _weightKg = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final height = _heightCm.toDouble();
          final weightKg = _metric ? _weightKg.toDouble() : _weightKg / 2.20462;
          await _repo.saveBodyProfile(heightCm: height, goalWeightKg: weightKg);
          await _repo.addWeightEntry(weightKg);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => _NutritionOnboardingGoalScreen(
                heightCm: height,
                weightKg: weightKg,
                activity: widget.activity,
              ),
            ),
          );
        },
        backgroundColor: Colors.black,
        label: Text(AppLocalizations.of(context)!.translate('calorieOnboarding_next'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _NutritionOnboardingGoalScreen extends StatefulWidget {
  const _NutritionOnboardingGoalScreen({required this.heightCm, required this.weightKg, required this.activity});
  final double heightCm;
  final double weightKg;
  final String activity;

  @override
  State<_NutritionOnboardingGoalScreen> createState() => _NutritionOnboardingGoalScreenState();
}

class _NutritionOnboardingGoalScreenState extends State<_NutritionOnboardingGoalScreen> {
  String _selectedGoal = 'maintain';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget goalTile(String key, String value) => GestureDetector(
          onTap: () => setState(() => _selectedGoal = value),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _selectedGoal == value ? Colors.black : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              l10n.translate(key),
              style: TextStyle(color: _selectedGoal == value ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => _NutritionOnboardingHeightWeightScreen(activity: widget.activity)),
          ),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress bar aligned with back button
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
            child: Row(
              children: [
                const SizedBox(width: 40), // Space for back button
                Expanded(child: _TopProgressBar(value: 0.75)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
            Text(l10n.translate('calorieOnboarding_goal_title'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(l10n.translate('calorieOnboarding_goal_subtitle'), style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
            const SizedBox(height: 24),
            goalTile('calorieOnboarding_goal_lose', 'lose'),
            goalTile('calorieOnboarding_goal_maintain', 'maintain'),
            goalTile('calorieOnboarding_goal_gain', 'gain'),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50),
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
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => _NutritionOnboardingPlanScreen(
                    heightCm: widget.heightCm,
                    weightKg: widget.weightKg,
                    goal: _selectedGoal,
                    activity: widget.activity,
                  ),
                ),
              );
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            label: Text(AppLocalizations.of(context)!.translate('calorieOnboarding_autoGenerate'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _NutritionOnboardingActivityScreen extends StatefulWidget {
  const _NutritionOnboardingActivityScreen();

  @override
  State<_NutritionOnboardingActivityScreen> createState() => _NutritionOnboardingActivityScreenState();
}

class _NutritionOnboardingActivityScreenState extends State<_NutritionOnboardingActivityScreen> {
  String _activity = 'moderate';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget option(String labelKey, String value, {bool selected = false}) => GestureDetector(
          onTap: () => setState(() => _activity = value),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: selected ? Colors.black : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? Colors.white : Colors.black),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.translate(labelKey), style: TextStyle(color: selected ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NutritionGoalsScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress bar aligned with back button
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
            child: Row(
              children: [
                const SizedBox(width: 40), // Space for back button
                Expanded(child: _TopProgressBar(value: 0.25)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
            Text(l10n.translate('calorieOnboarding_activity_title'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(l10n.translate('calorieOnboarding_activity_subtitle'), style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
            const SizedBox(height: 24),
            option('calorieOnboarding_activity_0_2', 'light', selected: _activity == 'light'),
            option('calorieOnboarding_activity_3_5', 'moderate', selected: _activity == 'moderate'),
            option('calorieOnboarding_activity_6_plus', 'active', selected: _activity == 'active'),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => _NutritionOnboardingHeightWeightScreen(
                activity: _activity,
              ),
            ),
          );
        },
        backgroundColor: Colors.black,
        label: Text(AppLocalizations.of(context)!.translate('calorieOnboarding_next'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _NutritionOnboardingPlanScreen extends StatelessWidget {
  const _NutritionOnboardingPlanScreen({required this.heightCm, required this.weightKg, required this.goal, required this.activity});
  final double heightCm;
  final double weightKg;
  final String goal; // lose | maintain | gain
  final String activity; // light | moderate | active

  double _activityMultiplier() {
    switch (activity) {
      case 'light':
        return 1.375;
      case 'moderate':
        return 1.55;
      case 'active':
        return 1.725;
      default:
        return 1.2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    // Mifflin-St Jeor, assume female by default for conservative calories
    final bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * 28) - 161;
    double calories = bmr * _activityMultiplier();
    if (goal == 'lose') calories *= 0.8;
    if (goal == 'gain') calories *= 1.1;
    final protein = (calories * 0.30) / 4; // Slightly higher protein
    final carbs = (calories * 0.35) / 4;
    final fat = (calories * 0.35) / 9;

    final goals = NutritionGoals(
      userId: userId,
      calories: calories.roundToDouble(),
      protein: protein.roundToDouble(),
      carbs: carbs.roundToDouble(),
      fat: fat.roundToDouble(),
      sugar: 50,
      fiber: 25,
      sodium: 2300,
      water: (weightKg * 35).roundToDouble(),
      updatedAt: DateTime.now(),
    );

    // Don't save goals here - pass them to be saved when DONE is clicked
    return FutureBuilder<void>(
      future: Future.value(), // No saving, just immediate UI
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
                    leading: GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => _NutritionOnboardingGoalScreen(
                heightCm: heightCm,
                weightKg: weightKg,
                activity: activity,
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Progress bar aligned with back button
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
                child: Row(
                  children: [
                    const SizedBox(width: 40), // Space for back button
                    Expanded(child: _TopProgressBar(value: 1.0)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                const Icon(Icons.check_circle, color: Colors.black, size: 48),
                const SizedBox(height: 12),
                Text(l10n.translate('calorieOnboarding_plan_ready_title'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(l10n.translate('calorieOnboarding_plan_ready_subtitle'), style: TextStyle(color: Colors.grey.shade700, fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(22)),
                  child: Text('${weightKg.round()} ${AppLocalizations.of(context)!.translate('unit_kg')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.translate('calorieOnboarding_daily_reco'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(l10n.translate('calorieOnboarding_daily_edit_anytime'), style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 12),
                      _PlanRow(label: l10n.translate('calorieTracker_calories'), value: goals.calories.round(), unit: ''),
                      _PlanRow(label: l10n.translate('calorieTracker_carbs'), value: goals.carbs.round(), unit: l10n.translate('unit_g')),
                      _PlanRow(label: l10n.translate('calorieTracker_protein'), value: goals.protein.round(), unit: l10n.translate('unit_g')),
                      _PlanRow(label: l10n.translate('calorieTracker_fats'), value: goals.fat.round(), unit: l10n.translate('unit_g')),
                    ],
                  ),
                ),
              ],
            ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => NutritionGoalsScreen(
                    showDoneButton: true,
                    aiGeneratedGoals: goals,
                    heightCm: heightCm,
                    weightKg: weightKg,
                    targetWeightKg: weightKg, // Use current weight as target for maintain goal
                  ),
                ),
              );
            },
            backgroundColor: Colors.black,
            label: Text(l10n.translate('calorieOnboarding_continue'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.label, required this.value, required this.unit});
  final String label;
  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text('$value$unit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _NumberPicker extends StatelessWidget {
  const _NumberPicker({required this.value, required this.unit, required this.onChanged});
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = FixedExtentScrollController(initialItem: value);
    return Container(
      height: 200,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        onSelectedItemChanged: (i) => onChanged(i),
        physics: const FixedExtentScrollPhysics(),
        itemExtent: 36,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            final display = index;
            if (display < 0 || display > 250) return null;
            final selected = display == value;
            return Center(
              child: Text(
                '$display $unit',
                style: TextStyle(
                  fontSize: selected ? 20 : 18,
                  color: selected ? Colors.black : Colors.grey.shade400,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopProgressBar extends StatelessWidget {
  const _TopProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}