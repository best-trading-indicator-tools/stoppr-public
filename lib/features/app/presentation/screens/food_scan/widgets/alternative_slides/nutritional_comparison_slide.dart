import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../../../core/models/food_alternative.dart';
import 'base_slide.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Import SVG
import 'package:stoppr/core/localization/app_localizations.dart'; // Added for localization

class NutritionalComparisonSlide extends BaseSlide {
  const NutritionalComparisonSlide({
    Key? key,
    required super.alternative,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (alternative.nutritionalComparison == null || alternative.nutritionalComparison!.isEmpty) {
      return buildSlideCard(
        title: l10n.translate('foodAlternatives_title_nutritionalComparison'),
        icon: Icons.compare_arrows,
        content: Center(child: Text(l10n.translate('foodAlternatives_noComparisonData'))),
        titleColor: const Color(0xFFed3272), // Brand pink
      );
    }
    
    return buildSlideCard(
      title: l10n.translate('foodAlternatives_title_nutritionalComparison'),
      icon: Icons.compare_arrows,
      content: _buildNutritionalComparison(context, nutritionalData: alternative.nutritionalComparison!, l10n: l10n),
      titleColor: const Color(0xFFed3272), // Brand pink
    );
  }

  Widget _buildNutritionalComparison(BuildContext context, {required Map<String, Map<String, NutritionalData>> nutritionalData, required AppLocalizations l10n}) {
    // Define colors with STOPPR branding
    const Color originalColor = Color(0xFFed3272); // Brand pink
    const Color alternativeColor = Color(0xFFfd5d32); // Brand orange
    
    // Define nutrients to display with more specific, visually appealing icons
    final List<String> nutrients = ['calories', 'carbs', 'protein', 'fat', 'sugar', 'fiber'];
    final List<IconData> nutrientIcons = [
      Icons.local_fire_department_rounded, // Calories
      Icons.cookie_outlined,               // Carbs (cookie)
      Icons.fitness_center_rounded,        // Protein (dumbbell)
      Icons.opacity_rounded,               // Fat (drop)
      Icons.cake_outlined,                 // Sugar (cake)
      Icons.grass_rounded,                 // Fiber (grass/plant)
    ];
    
    // Create the header widgets with shimmer
    final legendHeader = Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem(originalColor, l10n.translate('foodAlternatives_originalLabel')).animate().fadeIn(delay: 200.ms),
        _buildLegendItem(alternativeColor, l10n.translate('foodAlternatives_alternativeLabel')).animate().fadeIn(delay: 300.ms),
      ],
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          legendHeader,
          const SizedBox(height: 24),
          // Build animated comparison items for each nutrient
          ...createAnimatedChildren(
            nutrients.asMap().entries.map((entry) {
              final int index = entry.key;
              final String nutrient = entry.value;
              
              if (!nutritionalData.containsKey(nutrient)) {
                return const SizedBox.shrink();
              }
              
              final data = nutritionalData[nutrient]!;
              final original = data['original']!;
              final alternativeVal = data['alternative']!;
              
              // Use a more appealing, animated nutrient card
              return _buildNutrientComparisonCard(
                context,
                nutrient, 
                nutrientIcons[index],
                original,
                alternativeVal,
                originalColor,
                alternativeColor,
                l10n,
              );
            }).toList(),
            seed: 2 // Use a different seed
          ),
          const SizedBox(height: 24),
          // Add an informational tip
          _buildInfoTip(l10n).animate().fadeIn(delay: 800.ms, duration: 600.ms),
        ],
      ),
    );
  }
  
  // Helper for legend items
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 4,
              ),
              BoxShadow(
                color: const Color(0xFFfd5d32).withOpacity(0.2), // Add subtle orange glow
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF1A1A1A), // Dark text for light background
            fontFamily: 'ElzaRound',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // More visually appealing nutrient comparison card
  Widget _buildNutrientComparisonCard(
    BuildContext context,
    String nutrient,
    IconData icon,
    NutritionalData original,
    NutritionalData alternative,
    Color originalColor,
    Color alternativeColor,
    AppLocalizations l10n,
  ) {
    final double originalValue = original.value;
    final double alternativeValue = alternative.value;
    final String unit = original.unit;
    
    // Calculate percentage difference
    double difference = 0;
    if (originalValue > 0) {
      difference = ((alternativeValue - originalValue) / originalValue) * 100;
    }
    
    // Determine color and icon for the difference - using STOPPR brand colors only
    final Color diffColor = difference <= 0 ? const Color(0xFFed3272) : const Color(0xFFfd5d32); // Brand pink for improvement, Brand orange for warning
    final IconData diffIcon = difference <= 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // Clean white card background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFed3272).withOpacity(0.2), width: 1), // Brand pink border
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFed3272).withOpacity(0.1), // Soft pink shadow
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFfd5d32).withOpacity(0.05), // Subtle orange glow
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with icon and info button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFed3272).withOpacity(0.2), // Brand pink accent
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFed3272), size: 20), // Brand pink icon
              ).animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              ).shimmer(
                duration: 2.5.seconds,
                color: const Color(0xFFfd5d32), // Brand orange shimmer
              ),
              const SizedBox(width: 12),
              Text(
                _formatNutrientName(nutrient, l10n),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for light background
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              // Pulsing info icon to trigger the dialog
              InkWell(
                onTap: () => _showNutrientInfoDialog(context, nutrient, originalValue, alternativeValue, unit, l10n),
                borderRadius: BorderRadius.circular(20),
                child: buildPulsingInfoIcon(),
              ),
            ],
          ),
          const SizedBox(height: 24), // Increased spacing for better visual layout
          
          // Center the pie chart with increased size
          Center(
            child: _buildSingleSplitPieChart(originalValue, alternativeValue, originalColor, alternativeColor),
          ),
          
          const SizedBox(height: 20), // Increased spacing
          // Textual values stacked vertically to avoid overflow on small widths
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildValueText(
                l10n
                    .translate('foodAlternatives_originalValueLabel')
                    .replaceAll(
                      '{value}',
                      originalValue.toStringAsFixed(1),
                    )
                    .replaceAll('{unit}', unit),
                originalColor,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              _buildValueText(
                l10n
                    .translate('foodAlternatives_alternativeValueLabel')
                    .replaceAll(
                      '{value}',
                      alternativeValue.toStringAsFixed(1),
                    )
                    .replaceAll('{unit}', unit),
                alternativeColor,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: 12), // Increased spacing
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), // Slightly larger container
              decoration: BoxDecoration(
                color: diffColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: diffColor.withOpacity(0.3), width: 1.0), // Added subtle border
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(diffIcon, color: diffColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${difference.abs().toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: diffColor,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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

  // Format nutrient name for display
  String _formatNutrientName(String nutrient, AppLocalizations l10n) {
    // Use l10n.translate for nutrient names
    return l10n.translate('nutrient_${nutrient}_name');
  }

  // Build value text with color
  Widget _buildValueText(
    String text,
    Color color, {
    TextAlign textAlign = TextAlign.left,
  }) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        color: color,
        fontFamily: 'ElzaRound',
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // Format numeric values without unnecessary trailing .0
  String _formatNumber(double value) {
    return (value % 1 == 0)
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  // NEW: Build single pie chart visually split
  Widget _buildSingleSplitPieChart(
    double originalValue,
    double alternativeValue,
    Color originalColor,
    Color alternativeColor,
  ) {
    // Ensure non-zero total for division
    final double totalValue = (originalValue + alternativeValue) > 0 ? (originalValue + alternativeValue) : 1.0;
    // Calculate percentages relative to the combined total
    final double originalPercent = (originalValue / totalValue) * 100;
    final double alternativePercent = (alternativeValue / totalValue) * 100;
    const double chartRadius = 70.0; // INCREASED radius for a bigger chart
    const double sectionThickness = 20.0; // INCREASED thickness for better visibility

    // Use TweenAnimationBuilder for the alternative percentage for animation
    return SizedBox(
      width: chartRadius * 2,
      height: chartRadius * 2,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: alternativePercent),
        duration: 1200.ms,
        curve: Curves.easeInOutCubic,
        builder: (context, animatedAlternativePercent, child) {
          // Calculate animated original percent based on the alternative's animation progress
          double animatedOriginalPercent = 100.0 - animatedAlternativePercent;
          // Handle edge case where total is zero initially
          if (originalPercent + alternativePercent == 0) {
             animatedOriginalPercent = 50.0;
             animatedAlternativePercent = 50.0;
             originalColor = Colors.grey[800]!;
             alternativeColor = Colors.grey[800]!;
          } else if (animatedAlternativePercent == 0) {
             // If alternative is 0, original takes 100%
             animatedOriginalPercent = 100.0;
          } else if (animatedOriginalPercent + animatedAlternativePercent < 100) {
            // Adjust if sum is slightly off due to animation tweening
             animatedOriginalPercent = 100.0 - animatedAlternativePercent;
          }

          return PieChart(
            PieChartData(
              startDegreeOffset: -90, // Start from the top
              sectionsSpace: 3, // Slightly larger space for better visual separation
              centerSpaceRadius: chartRadius - sectionThickness, // Keep ring thickness consistent
              sections: [
                // Original section (adjust value based on animation)
                PieChartSectionData(
                  color: originalColor,
                  value: animatedOriginalPercent,
                  radius: sectionThickness, // Thickness of the section
                  showTitle: false,
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.2), width: 0.5), // Subtle border
                ),
                // Alternative section (animated value)
                PieChartSectionData(
                  color: alternativeColor,
                  value: animatedAlternativePercent,
                  radius: sectionThickness,
                  showTitle: false,
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.2), width: 0.5), // Subtle border
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Build info tip section
  Widget _buildInfoTip(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFed3272).withOpacity(0.1), // Brand pink accent
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFed3272).withOpacity(0.2)), // Brand pink border
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: const Color(0xFFed3272), // Brand pink icon
            size: 20,
          ).animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          ).shimmer(
            duration: 2.seconds,
            color: const Color(0xFFfd5d32), // Brand orange shimmer
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.translate('foodAlternatives_nutrientInfoTip'),
              style: TextStyle(
                color: const Color(0xFF666666), // Gray text for secondary info
                fontFamily: 'ElzaRound',
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show detailed info dialog for a nutrient
  void _showNutrientInfoDialog(
    BuildContext context,
    String nutrient,
    double originalValue,
    double alternativeValue,
    String unit,
    AppLocalizations l10n,
  ) {
    final String formattedNutrientName = _formatNutrientName(nutrient, l10n);
    final String title = l10n.translate('foodAlternatives_aboutNutrientTitle').replaceAll('{nutrientName}', formattedNutrientName);
    final String explanation = _getNutrientExplanation(nutrient, l10n);
    final Color nutrientColor = _getNutrientColorForDialog(nutrient); // Use consistent color

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        // Animate the dialog entrance
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white, // Clean white dialog background
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFed3272).withOpacity(0.3), width: 1), // Brand pink border
              boxShadow: [
                BoxShadow(
                  color: nutrientColor.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 5,
                )
              ]
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Title with Icon
                  Row(
                    children: [
                      Icon(
                        _getNutrientIconForDialog(nutrient),
                        color: nutrientColor,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: nutrientColor,
                            fontFamily: 'ElzaRound',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF666666)),
                        onPressed: () => Navigator.pop(context),
                        splashRadius: 20,
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: const Color(0xFF1A1A1A).withOpacity(0.1)),
                  const SizedBox(height: 16),
                  // Explanation Text
                  Text(
                    explanation,
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for light background
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Comparison Card inside Dialog
                  _buildDialogComparisonCard(nutrient, originalValue, alternativeValue, unit, nutrientColor, l10n),
                ],
              ),
            ),
          ).animate()
            .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 400.ms, curve: Curves.easeOutBack),
        );
      },
    );
  }
  
  // Get explanation for each nutrient
  String _getNutrientExplanation(String nutrient, AppLocalizations l10n) {
    // Use l10n.translate for explanations
    return l10n.translate('nutrient_${nutrient}_explanation');
  }
  
  // Helper to get a specific icon for the dialog title
  IconData _getNutrientIconForDialog(String nutrient) {
    switch (nutrient.toLowerCase()) {
      case 'calories': return Icons.local_fire_department_rounded;
      case 'carbs': return Icons.cookie_outlined;
      case 'protein': return Icons.fitness_center_rounded;
      case 'fat': return Icons.opacity_rounded;
      case 'sugar': return Icons.cake_outlined;
      case 'fiber': return Icons.grass_rounded;
      default: return Icons.info_outline;
    }
  }
  
  // Helper to get a specific color for the dialog accent - STOPPR branding only
  Color _getNutrientColorForDialog(String nutrient) {
    switch (nutrient.toLowerCase()) {
      case 'calories': return const Color(0xFFfd5d32); // Brand orange
      case 'carbs': return const Color(0xFFed3272); // Brand pink
      case 'protein': return const Color(0xFFfd5d32); // Brand orange
      case 'fat': return const Color(0xFFed3272); // Brand pink
      case 'sugar': return const Color(0xFFed3272); // Brand pink
      case 'fiber': return const Color(0xFFfd5d32); // Brand orange
      default: return const Color(0xFFed3272); // Default brand pink (no more blue BS)
    }
  }

  // Create a more visually appealing comparison card for the dialog
  Widget _buildDialogComparisonCard(
    String nutrient, 
    double originalValue, 
    double alternativeValue, 
    String unit, 
    Color accentColor,
    AppLocalizations l10n,
  ) {
    double difference = 0;
    if (originalValue > 0) {
      difference = ((alternativeValue - originalValue) / originalValue) * 100;
    }
    bool isImprovement = (nutrient == 'protein' || nutrient == 'fiber') ? difference >= 0 : difference <= 0;
    final Color resultColor = isImprovement ? const Color(0xFFed3272) : const Color(0xFFfd5d32); // STOPPR brand colors only
    final IconData resultIcon = isImprovement ? Icons.thumb_up_alt_rounded : Icons.thumb_down_alt_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8FA), // Light pink-tinted background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFed3272).withOpacity(0.2), width: 1), // Brand pink border
      ),
      child: Column(
        children: [
          // Headers row
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.translate('foodAlternatives_originalLabel'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFed3272), // Brand pink for original
                    fontFamily: 'ElzaRound',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  l10n.translate('foodAlternatives_alternativeLabel'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFfd5d32), // Brand orange for alternative
                    fontFamily: 'ElzaRound',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Values row with icons
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Original value
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_formatNumber(originalValue)} $unit',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontFamily: 'ElzaRound',
                        fontSize: 20, // Reduce to avoid trimming (kcal visible)
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Icon in the middle with animation
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: resultColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(resultIcon, color: resultColor, size: 24),
              ).animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              ).scale(
                duration: 1.5.seconds,
                begin: const Offset(1, 1),
                end: const Offset(1.15, 1.15),
              ),
              
              // Alternative value
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_formatNumber(alternativeValue)} $unit',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontFamily: 'ElzaRound',
                        fontSize: 20, // Reduce to avoid trimming (kcal visible)
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          // Show the comparison text
          Text(
            _getComparisonText(nutrient, difference, l10n),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: resultColor, // Use result color for emphasis
              fontFamily: 'ElzaRound',
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Get comparison text based on nutrient and difference
  String _getComparisonText(String nutrient, double difference, AppLocalizations l10n) {
    final formattedNutrientName = _formatNutrientName(nutrient, l10n);
    String changeKey = difference > 0 ? 'foodAlternatives_increase' : 'foodAlternatives_decrease';
    String changeText = l10n.translate(changeKey);
    String absDiff = '${difference.abs().toStringAsFixed(0)}%';
    
    bool isPositiveNutrient = nutrient == 'protein' || nutrient == 'fiber';
    bool isImprovement = isPositiveNutrient ? difference >= 0 : difference <= 0;
    
    if (difference == 0) {
      return l10n.translate('foodAlternatives_nutrientNoChange').replaceAll('{nutrientName}', formattedNutrientName);
    }
    
    String resultKey = isImprovement 
      ? 'foodAlternatives_nutrientImprovement' 
      : 'foodAlternatives_nutrientWarning';
      
    return l10n.translate(resultKey)
      .replaceAll('{percentage}', absDiff)
      .replaceAll('{change}', changeText)
      .replaceAll('{nutrientName}', formattedNutrientName);
  }
} 