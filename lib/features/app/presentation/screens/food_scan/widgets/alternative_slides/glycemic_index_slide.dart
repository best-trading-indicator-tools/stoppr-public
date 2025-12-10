import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../../../core/models/food_alternative.dart';
import 'base_slide.dart';
import 'package:fl_chart/fl_chart.dart'; // Added for gauge
import 'dart:math';
import 'package:stoppr/core/localization/app_localizations.dart'; // Added for localization

class GlycemicIndexSlide extends BaseSlide {
  const GlycemicIndexSlide({
    Key? key,
    required super.alternative,
  }) : super(key: key);

  // STOPPR Brand colors - light theme only
  Color get cardBackgroundColor => Colors.white; // Clean white cards
  Color get cardBorderColor => const Color(0xFFed3272).withOpacity(0.2); // Brand pink border
  Color get primaryTextColor => const Color(0xFF1A1A1A); // Dark text for light background
  Color get secondaryTextColor => const Color(0xFF666666); // Gray text for secondary info
  double get cardBorderRadius => 20.0; // Modern rounded corners
  
  // Dialog colors - STOPPR branding
  Color get dialogBgColor => Colors.white; // Clean white background
  Color get dialogTextColor => const Color(0xFF1A1A1A); // Dark text
  Color get dialogSecondaryTextColor => const Color(0xFF666666); // Gray text

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (alternative.glycemicIndex == null) {
      return buildSlideCard(
        title: l10n.translate('foodAlternatives_title_glycemicIndex'),
        icon: Icons.speed_rounded,
        content: Center(child: Text(l10n.translate('foodAlternatives_noGIData'))),
        titleColor: const Color(0xFFed3272), // Brand pink
      );
    }
    
    return buildSlideCard(
      title: l10n.translate('foodAlternatives_title_glycemicIndex'), // Potentially add " (GI)" if always needed or handle in translation
      icon: Icons.speed_rounded,
      content: _buildGlycemicIndexContent(context, l10n),
      titleColor: const Color(0xFFed3272), // Brand pink
    );
  }

  Widget _buildGlycemicIndexContent(BuildContext context, AppLocalizations l10n) {
    final giData = alternative.glycemicIndex!;

    // Use same brand colors as NutritionalComparisonSlide
    // Original: Brand pink, Alternative: Brand orange
    const Color originalColor = Color(0xFFed3272);
    const Color alternativeColor = Color(0xFFfd5d32);

    // Build the comparison gauge section
    final gaugeSection = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildGIGauge(
            context,
            giData.originalValue,
            giData.originalCategory,
            l10n.translate('foodAlternatives_originalFoodLabel'),
            originalColor,
            l10n,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGIGauge(
            context,
            giData.alternativeValue,
            giData.alternativeCategory,
            l10n.translate('foodAlternatives_alternativeFoodLabel'),
            alternativeColor,
            l10n,
          ),
        ),
      ],
    );

    // Build explanation card
    final explanationCard = _buildExplanationCard(l10n);
    
    // Build category legend card
    final legendCard = _buildLegendCard(l10n);

    // Apply staggered animation
    final animatedWidgets = createAnimatedChildren([
      gaugeSection,
      explanationCard,
      legendCard,
    ], seed: 3); // Use another seed

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          ...animatedWidgets,
          const SizedBox(height: 30), // Extra padding at bottom
        ],
      ),
    );
  }

  // Build a single GI Gauge with title and value
  Widget _buildGIGauge(BuildContext context, int value, String category, String label, Color color, AppLocalizations l10n) {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontFamily: 'ElzaRound',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 100,
          height: 100,
          child: _buildAnimatedRadialGauge(value.toDouble(), color),
        ),
        const SizedBox(height: 12),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontFamily: 'ElzaRound',
            fontSize: 26, // Larger font for value
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: const Color(0xFFed3272).withOpacity(0.3), // Brand pink shadow
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ]
          ),
        ),
        const SizedBox(height: 4),
        Text(
          category,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontFamily: 'ElzaRound',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Build the animated radial gauge using PieChart
  Widget _buildAnimatedRadialGauge(double value, Color color) {
    // Max GI is typically around 100-110, let's use 110 for scale
    final double percentage = (value / 110 * 100).clamp(0.0, 100.0);
    const double gaugeThickness = 14.0;
    // Create a light brand-tinted background (avoids dull gray on white)
    final Color backgroundColor = Color.lerp(color, Colors.white, 0.75)!;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percentage),
      duration: 1200.ms,
      curve: Curves.easeInOutCubic,
      builder: (context, animatedValue, child) {
        return PieChart(
          PieChartData(
            startDegreeOffset: -210, // Start gauge from bottom-left
            sectionsSpace: 0,
            centerSpaceRadius: 36, // Larger center space
            sections: [
              // Background arc
              PieChartSectionData(
                color: backgroundColor,
                value: 100 - animatedValue, // Remaining part up to 100
                radius: gaugeThickness,
                showTitle: false,
              ),
              // Value arc (animated)
              PieChartSectionData(
                color: color,
                value: animatedValue,
                radius: gaugeThickness,
                showTitle: false,
                borderSide: BorderSide(color: const Color(0xFFed3272).withOpacity(0.3), width: 1), // Brand pink border with subtle glow
              ),
              // Empty space to make it a semi-circle/arc gauge (approx 240 degrees)
              PieChartSectionData(
                color: Colors.transparent,
                value: (100 / (240 / 360)) - 100, // Calculate transparent section size
                radius: gaugeThickness,
                showTitle: false,
              ),
            ],
          ),
        );
      },
    );
  }

  // Build the explanation card
  Widget _buildExplanationCard(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // Clean white background like other cards
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFed3272).withOpacity(0.2), width: 1), // Subtle brand pink border
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFed3272).withOpacity(0.1), // Soft brand pink shadow
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
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFed3272), // Brand pink
                size: 20,
              ),
              const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.translate('foodAlternatives_whatIsGITitle'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for light background
                  fontFamily: 'ElzaRound',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.translate('foodAlternatives_giExplanation'),
            style: const TextStyle(
              color: Color(0xFF666666), // Gray text for secondary info
              fontFamily: 'ElzaRound',
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  // Build the category legend card
  Widget _buildLegendCard(AppLocalizations l10n) {
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
          Text(
            l10n.translate('foodAlternatives_giCategoriesTitle'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for light background
              fontFamily: 'ElzaRound',
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildLegendItem( _getGIColor('Low'), l10n.translate('foodAlternatives_giLowRange'), l10n.translate('foodAlternatives_giLowDescription'), l10n),
          const SizedBox(height: 10),
          _buildLegendItem( _getGIColor('Medium'), l10n.translate('foodAlternatives_giMediumRange'), l10n.translate('foodAlternatives_giMediumDescription'), l10n),
          const SizedBox(height: 10),
          _buildLegendItem( _getGIColor('High'), l10n.translate('foodAlternatives_giHighRange'), l10n.translate('foodAlternatives_giHighDescription'), l10n),
        ],
      ),
    );
  }
  
  // Helper to build a single legend item
  Widget _buildLegendItem(Color color, String range, String description, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ]
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                range,
                style: TextStyle(
                  color: color,
                  fontFamily: 'ElzaRound',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF666666), // Gray text for secondary info
                  fontFamily: 'ElzaRound',
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Get color based on GI category - using brand colors
  Color _getGIColor(String category) {
    switch (category.toLowerCase()) {
      case 'low':
        return const Color(0xFFed3272).withOpacity(0.7); // Light brand pink for low GI
      case 'medium':
        return const Color(0xFFfd5d32); // Brand orange for medium GI  
      case 'high':
        return const Color(0xFFed3272); // Full brand pink for high GI
      default:
        return const Color(0xFF666666); // Gray for unknown
    }
  }
} 