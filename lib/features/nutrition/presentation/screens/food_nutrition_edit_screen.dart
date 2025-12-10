import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:stoppr/features/nutrition/data/models/food_log.dart';
import 'package:stoppr/features/nutrition/data/models/nutrition_data.dart';
import 'package:stoppr/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import '../../../../core/services/local_food_image_service.dart';

// Summary: Fix incorrect calorie scaling on the edit screen.
// - Remove per-gram normalization that divided values by serving weight.
//   The dashboard stores values per item, so dividing by grams yielded ~3 cals.
// - Keep stable measurement tokens ('Small'|'Medium'|'Large'|'G') and only
//   localize labels. Tapping chips now sets the token, not the localized text.
// - In 'G' mode, treat the text field value as grams and scale relative to the
//   item's serving weight (grams / weightPerItem), keeping parity with dashboard.

class FoodNutritionEditScreen extends StatefulWidget {
  final FoodLog foodLog;
  const FoodNutritionEditScreen({super.key, required this.foodLog});

  @override
  State<FoodNutritionEditScreen> createState() => _FoodNutritionEditScreenState();
}

class _FoodNutritionEditScreenState extends State<FoodNutritionEditScreen> {
  final _repo = NutritionRepository();
  final _imageService = LocalFoodImageService();

  late TextEditingController _servingsCtrl;
  late TextEditingController _caloriesCtrl;
  late TextEditingController _proteinCtrl;
  late TextEditingController _carbsCtrl;
  late TextEditingController _fatCtrl;
  late TextEditingController _fiberCtrl;
  late TextEditingController _sugarCtrl;
  late TextEditingController _sodiumCtrl;
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  String _measurement = 'Medium';
  Map<String, Micronutrient> _micros = {};
  late NutritionData _baseData; // baseline to scale from

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('Food Nutrition Edit Screen');
    // debugPrint('🖼️ FoodNutritionEditScreen - Image URL: ${widget.foodLog.imageUrl}');
    // debugPrint('🖼️ FoodNutritionEditScreen - Food name: ${widget.foodLog.foodName}');
    final n = widget.foodLog.nutritionData;
    
    // Check if servingInfo contains a serving count > 1
    // If so, we need to calculate the per-serving base by dividing total by servings
    final savedServings = n.servingInfo?.amount ?? 1.0;
    final isMultiServing = savedServings > 1.0;
    
    if (isMultiServing) {
      // The stored values are TOTAL values (e.g., 4 servings × 256 = 1024)
      // Calculate per-serving base by dividing by saved servings
      _baseData = n.copyWith(
        calories: n.calories / savedServings,
        protein: n.protein / savedServings,
        carbs: n.carbs / savedServings,
        fat: n.fat / savedServings,
        sugar: n.sugar / savedServings,
        fiber: n.fiber / savedServings,
        sodium: n.sodium / savedServings,
        micronutrients: n.micronutrients.map((k, v) => 
          MapEntry(k, v.copyWith(value: v.value / savedServings))),
      );
      _servingsCtrl = TextEditingController(text: savedServings.toStringAsFixed(0));
    } else {
      // Single serving or unset - use values as stored
      _baseData = n;
      _servingsCtrl = TextEditingController(text: '1');
    }
    
    _caloriesCtrl = TextEditingController(text: n.calories.toStringAsFixed(0));
    _proteinCtrl = TextEditingController(text: n.protein.toStringAsFixed(0));
    _carbsCtrl = TextEditingController(text: n.carbs.toStringAsFixed(0));
    _fatCtrl = TextEditingController(text: n.fat.toStringAsFixed(0));
    _fiberCtrl = TextEditingController(text: n.fiber.toStringAsFixed(0));
    _sugarCtrl = TextEditingController(text: n.sugar.toStringAsFixed(0));
    _sodiumCtrl = TextEditingController(text: n.sodium.toStringAsFixed(0));
    _micros = Map<String, Micronutrient>.from(n.micronutrients);
    // Ensure micronutrients reflect current baseline at start
    _applyMeasurement();
  }

  @override
  void dispose() {
    _servingsCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _fiberCtrl.dispose();
    _sugarCtrl.dispose();
    _sodiumCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = widget.foodLog.nutritionData;
    final servings = double.tryParse(_servingsCtrl.text) ?? 1.0;
    
    final updated = widget.foodLog.copyWith(
      nutritionData: n.copyWith(
        calories: double.tryParse(_caloriesCtrl.text) ?? n.calories,
        protein: double.tryParse(_proteinCtrl.text) ?? n.protein,
        carbs: double.tryParse(_carbsCtrl.text) ?? n.carbs,
        fat: double.tryParse(_fatCtrl.text) ?? n.fat,
        fiber: double.tryParse(_fiberCtrl.text) ?? n.fiber,
        sugar: double.tryParse(_sugarCtrl.text) ?? n.sugar,
        sodium: double.tryParse(_sodiumCtrl.text) ?? n.sodium,
        micronutrients: _micros,
        servingInfo: n.servingInfo?.copyWith(amount: servings) ?? 
          ServingInfo(amount: servings, unit: 'serving', weight: null, weightUnit: null),
      ),
    );
    // Optimistic UI: close immediately
    if (mounted) Navigator.pop(context, updated);
    // Background update; log errors if any
    unawaited(_repo.updateFoodLog(updated).catchError((e) {
      debugPrint('FoodNutritionEditScreen: update failed: $e');
    }));
  }

  void _applyMeasurement() {
    // Scale relative to the medium baseline in _baseData.
    // Apply both measurement ratio and number of servings.
    final double servings = double.tryParse(_servingsCtrl.text) ?? 1.0;
    // debugPrint('📊 APPLY MEASUREMENT: Measurement=$_measurement, Servings=$servings');
    // debugPrint('📊 APPLY MEASUREMENT: Base calories=${_baseData.calories}, Base protein=${_baseData.protein}');

    final double defaultWeight = _baseData.servingInfo?.weight ??
        _baseData.servingInfo?.amount ?? 0.0;
    final double weightPerItem = defaultWeight > 0 ? defaultWeight : 1.0;

    double measurementRatio = 1.0; // Medium baseline multiplier (not grams)
    switch (_measurement) {
      case 'Small':
        measurementRatio = 0.8; // 20% less than medium
        break;
      case 'Large':
        measurementRatio = 1.5; // 50% more than medium
        break;
      case 'Medium':
        measurementRatio = 1.0;
        break;
      case 'G':
        // In G mode, servings = grams, so ratio is 1:1 per gram baseline
        measurementRatio = 1.0;
        break;
      default:
        measurementRatio = 1.0;
    }

    final double multiplier = _measurement == 'G'
        ? (servings / weightPerItem) // grams relative to one item's weight
        : (measurementRatio * servings);

    // debugPrint('📊 APPLY MEASUREMENT: MeasurementRatio=$measurementRatio, Multiplier=$multiplier');
    
    double scale(double v) => (v * multiplier);

    _caloriesCtrl.text = scale(_baseData.calories).toStringAsFixed(0);
    // debugPrint('📊 APPLY MEASUREMENT: Final calories=${scale(_baseData.calories)}');
    _proteinCtrl.text = scale(_baseData.protein).toStringAsFixed(0);
    _carbsCtrl.text = scale(_baseData.carbs).toStringAsFixed(0);
    _fatCtrl.text = scale(_baseData.fat).toStringAsFixed(0);
    _fiberCtrl.text = scale(_baseData.fiber).toStringAsFixed(0);
    _sugarCtrl.text = scale(_baseData.sugar).toStringAsFixed(0);
    _sodiumCtrl.text = scale(_baseData.sodium).toStringAsFixed(0);

    // Scale typed micronutrients too
    // debugPrint('📊 SCALING MICRONUTRIENTS:');
    _micros = _baseData.micronutrients.map((k, v) {
      final scaledValue = scale(v.value);
      // debugPrint('  $k: ${v.value} ${v.unit} × $multiplier = $scaledValue ${v.unit}');
      return MapEntry(k, v.copyWith(value: scaledValue));
    });
  }

  // Scale macros and micronutrients when calories is edited directly by user.
  void _applyCaloriesScale() {
    final double servings = double.tryParse(_servingsCtrl.text) ?? 1.0;

    double measurementRatio = 1.0; // Medium baseline multiplier (not grams)
    switch (_measurement) {
      case 'Small':
        measurementRatio = 0.8;
        break;
      case 'Large':
        measurementRatio = 1.5;
        break;
      case 'Medium':
        measurementRatio = 1.0;
        break;
      case 'G':
        measurementRatio = 1.0;
        break;
      default:
        measurementRatio = 1.0;
    }

    final double defaultWeight = _baseData.servingInfo?.weight ??
        _baseData.servingInfo?.amount ?? 0.0;
    final double weightPerItem = defaultWeight > 0 ? defaultWeight : 1.0;
    final double multiplier = _measurement == 'G'
        ? (servings / weightPerItem)
        : (measurementRatio * servings);

    final double baselineCalories = (_baseData.calories * multiplier);
    final double targetCalories = double.tryParse(_caloriesCtrl.text) ?? baselineCalories;

    if (baselineCalories <= 0) {
      return;
    }

    final double ratio = targetCalories / baselineCalories;

    double scale(double v) => (v * multiplier * ratio);

    _proteinCtrl.text = scale(_baseData.protein).toStringAsFixed(0);
    _carbsCtrl.text = scale(_baseData.carbs).toStringAsFixed(0);
    _fatCtrl.text = scale(_baseData.fat).toStringAsFixed(0);
    _fiberCtrl.text = scale(_baseData.fiber).toStringAsFixed(0);
    _sugarCtrl.text = scale(_baseData.sugar).toStringAsFixed(0);
    _sodiumCtrl.text = scale(_baseData.sodium).toStringAsFixed(0);

    _micros = _baseData.micronutrients.map((k, v) {
      final scaledValue = scale(v.value);
      return MapEntry(k, v.copyWith(value: scaledValue));
    });
  }

  Widget _numField(String label, TextEditingController c, {String suffix = 'g', String? emoji}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: c,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    suffixText: suffix,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editNumber(String title, TextEditingController c, {String suffix = ''}) async {
    final temp = TextEditingController(text: c.text);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: temp,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
            decoration: InputDecoration(suffixText: suffix),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.translate('cancel'))),
            TextButton(
              onPressed: () {
                c.text = temp.text.trim().isEmpty ? c.text : temp.text.trim();
                Navigator.pop(context);
                if (title == 'Number of Servings') {
                  _applyMeasurement();
                }
                setState(() {});
              },
              child: Text(AppLocalizations.of(context)!.translate('save')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            MixpanelService.trackButtonTap('Food Nutrition Edit Screen: Back Button');
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        title: Text(AppLocalizations.of(context)!.translate('calorieTracker_nutrition')),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food image preview at 16:9 aspect ratio
            if (widget.foodLog.imageUrl != null && widget.foodLog.imageUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _imageService.buildPreviewImage(
                    widget.foodLog.imageUrl!,
                    width: double.infinity,
                  ),
                ),
              )
            else
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '🍽️',
                        style: const TextStyle(fontSize: 60),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.translate('calorieTracker_noImageAvailable'),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontFamily: 'ElzaRound',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Measurement chips
            Text(AppLocalizations.of(context)!.translate('calorieTracker_measurement'), style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                {
                  'token': 'Large',
                  'label': AppLocalizations.of(context)!
                      .translate('calorieTracker_large'),
                },
                {
                  'token': 'Medium',
                  'label': AppLocalizations.of(context)!
                      .translate('calorieTracker_medium'),
                },
                {
                  'token': 'Small',
                  'label': AppLocalizations.of(context)!
                      .translate('calorieTracker_small'),
                },
                {
                  'token': 'G',
                  'label': 'G',
                },
              ].map((opt) {
                final String token = opt['token'] as String;
                final String label = opt['label'] as String;
                final bool selected = _measurement == token;
                return GestureDetector(
                  onTap: () {
                    MixpanelService.trackButtonTap(
                      'Food Nutrition Edit Screen: Measurement Chip',
                      additionalProps: {
                        'measurement': token,
                        'food_name': widget.foodLog.foodName,
                      },
                    );
                    setState(() {
                      _measurement = token;
                      _applyMeasurement();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFed3272),
                                Color(0xFFfd5d32),
                              ],
                            )
                          : null,
                      color: selected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? null
                          : Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(Icons.check, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Servings (direct input)
            _servingsField(),
            const SizedBox(height: 16),
            // Calories big card (inline editable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
              ]),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _caloriesCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                            onChanged: (_) {
                              setState(() {
                                _applyCaloriesScale();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.translate('calorieTracker_calories'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _pageIndex = i),
                children: [
                  Row(children: [
                    Expanded(child: _numField(AppLocalizations.of(context)!.translate('calorieTracker_protein'), _proteinCtrl, emoji: '🥩')),
                    const SizedBox(width: 12),
                    Expanded(child: _numField(AppLocalizations.of(context)!.translate('calorieTracker_carbs'), _carbsCtrl, emoji: '🥖')),
                    const SizedBox(width: 12),
                    Expanded(child: _numField(AppLocalizations.of(context)!.translate('calorieTracker_fat'), _fatCtrl, emoji: '🧈')),
                  ]),
                  Row(children: [
                    Expanded(child: _numField(AppLocalizations.of(context)!.translate('calorieTracker_fiber'), _fiberCtrl, emoji: '🫐')),
                    const SizedBox(width: 12),
                    Expanded(child: _numField(AppLocalizations.of(context)!.translate('calorieTracker_sugar'), _sugarCtrl, emoji: '🍬')),
                    const SizedBox(width: 12),
                    Expanded(child: _numField(AppLocalizations.of(context)!.translate('calorieTracker_sodium'), _sodiumCtrl, suffix: 'mg', emoji: '🧂')),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: i == _pageIndex ? Colors.black : const Color(0xFFD1D1D6), shape: BoxShape.circle),
              )),
            ),
            const SizedBox(height: 16),
            // Other nutrition facts list (dynamic from prompt)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: true,
              title: Text(AppLocalizations.of(context)!.translate('calorieTracker_otherNutritionFacts'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              children: _buildMicronutrientsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFed3272),
              Color(0xFFfd5d32),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            MixpanelService.trackButtonTap(
              'Food Nutrition Edit Screen: Save Button',
              additionalProps: {
                'food_name': widget.foodLog.foodName,
                'calories': _caloriesCtrl.text,
              },
            );
            _save();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          label: Text(
            AppLocalizations.of(context)!
                .translate('done')
                .toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 19,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

Widget _factItem({required String label, required String value}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE6E6EB)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

extension on _FoodNutritionEditScreenState {
  Widget _servingsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_measurement == 'G' 
            ? AppLocalizations.of(context)!.translate('calorieTracker_grams') 
            : AppLocalizations.of(context)!.translate('calorieTracker_numberOfServings'), 
          style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _servingsCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            onChanged: (_) {
              // Recalculate in real time when servings change
              setState(() {
                _applyMeasurement();
              });
            },
          ),
        ),
      ],
    );
  }

  // Spec for display order and default units
  List<Map<String, String>> get _microSpec => [
    {'key': 'saturated_fat', 'label': AppLocalizations.of(context)!.translate('calorieTracker_saturatedFat'), 'unit': AppLocalizations.of(context)!.translate('unit_g')},
    {'key': 'polyunsaturated_fat', 'label': AppLocalizations.of(context)!.translate('calorieTracker_polyunsaturatedFat'), 'unit': AppLocalizations.of(context)!.translate('unit_g')},
    {'key': 'monounsaturated_fat', 'label': AppLocalizations.of(context)!.translate('calorieTracker_monounsaturatedFat'), 'unit': AppLocalizations.of(context)!.translate('unit_g')},
    {'key': 'cholesterol', 'label': AppLocalizations.of(context)!.translate('calorieTracker_cholesterol'), 'unit': AppLocalizations.of(context)!.translate('unit_mg')},
    {'key': 'sodium', 'label': AppLocalizations.of(context)!.translate('calorieTracker_sodium'), 'unit': AppLocalizations.of(context)!.translate('unit_mg')},
    {'key': 'fiber', 'label': AppLocalizations.of(context)!.translate('calorieTracker_fiber'), 'unit': AppLocalizations.of(context)!.translate('unit_g')},
    {'key': 'sugar', 'label': AppLocalizations.of(context)!.translate('calorieTracker_sugar'), 'unit': AppLocalizations.of(context)!.translate('unit_g')},
    {'key': 'potassium', 'label': AppLocalizations.of(context)!.translate('calorieTracker_potassium'), 'unit': AppLocalizations.of(context)!.translate('unit_mg')},
    {'key': 'vitaminA', 'label': AppLocalizations.of(context)!.translate('calorieTracker_vitaminA'), 'unit': AppLocalizations.of(context)!.translate('unit_mcg')},
    {'key': 'vitaminC', 'label': AppLocalizations.of(context)!.translate('calorieTracker_vitaminC'), 'unit': AppLocalizations.of(context)!.translate('unit_mg')},
    {'key': 'calcium', 'label': AppLocalizations.of(context)!.translate('calorieTracker_calcium'), 'unit': AppLocalizations.of(context)!.translate('unit_mg')},
    {'key': 'iron', 'label': AppLocalizations.of(context)!.translate('calorieTracker_iron'), 'unit': AppLocalizations.of(context)!.translate('unit_mg')},
  ];

  List<Widget> _buildMicronutrientsList() {
    return _microSpec.map((def) {
      final key = def['key']!;
      final label = def['label']!;
      final unit = _unitForKey(key, def['unit']!);
      return _otherFactRow(key, label, unit);
    }).toList();
  }

  String _unitForKey(String key, String fallback) {
    final fromPrompt = _micros[key]?.unit;
    if (fromPrompt != null && fromPrompt.isNotEmpty) return fromPrompt;
    return fallback;
  }

  double _getMicronutrientValue(String key) {
    switch (key) {
      case 'fiber':
        return double.tryParse(_fiberCtrl.text) ?? 0;
      case 'sugar':
        return double.tryParse(_sugarCtrl.text) ?? 0;
      case 'sodium':
        return double.tryParse(_sodiumCtrl.text) ?? 0;
      default:
        return _micros[key]?.value ?? 0;
    }
  }

  Widget _otherFactRow(String key, String label, String unit) {
    double value = _getMicronutrientValue(key);
    // Clamp to sensible display range
    if (value.isNaN || value.isInfinite) value = 0;
    
    // Apply reasonable max values based on unit type
    if (unit.toLowerCase().contains('g')) {
      value = value.clamp(0, 999); // Max 999g
    } else if (unit.toLowerCase().contains('mg')) {
      value = value.clamp(0, 9999); // Max 9999mg
    } else if (unit.toLowerCase().contains('mcg') || unit.toLowerCase().contains('μg')) {
      value = value.clamp(0, 99999); // Max 99999mcg
    } else {
      value = value.clamp(0, 9999); // Default max
    }

    // Format with appropriate decimals
    String formatted;
    if (value >= 1000) {
      formatted = value.toStringAsFixed(0);
    } else if (value >= 10) {
      formatted = value.toStringAsFixed(1);
    } else if (value >= 1) {
      formatted = value.toStringAsFixed(2);
    } else if (value > 0) {
      // Very small values - show up to 3 decimals
      formatted = value.toStringAsFixed(3);
      // Remove trailing zeros
      formatted = formatted.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    } else {
      formatted = '0';
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _factItem(
        label: label,
        value: '$formatted$unit',
      ),
    );
  }

}


