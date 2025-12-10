import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../../../core/models/food_alternative.dart';
import 'base_slide.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:stoppr/core/localization/app_localizations.dart';

class BloodSugarImpactSlide extends BaseSlide {
  const BloodSugarImpactSlide({
    Key? key,
    required super.alternative,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (alternative.bloodSugarImpact == null) {
      return buildSlideCard(
        title: AppLocalizations.of(context)!.translate('foodScan_bloodSugarTitle'),
        icon: Icons.show_chart_rounded,
        content: Center(child: Text(AppLocalizations.of(context)!.translate('foodScan_noBloodSugarData'))),
        titleColor: const Color(0xFFed3272), // Brand pink
      );
    }
    
    return buildSlideCard(
      title: AppLocalizations.of(context)!.translate('foodScan_bloodSugarTitle'),
      icon: Icons.show_chart_rounded,
      content: _buildBloodSugarImpactContent(context),
      titleColor: const Color(0xFFed3272), // Brand pink
    );
  }

  Widget _buildBloodSugarImpactContent(BuildContext context) {
    final bloodSugarImpact = alternative.bloodSugarImpact!;
    
    // Colors for blood sugar impact visualization - STOPPR brand only
    final Color highImpactColor = const Color(0xFFfd5d32);  // Brand orange for high impact (warning)
    final Color lowImpactColor = const Color(0xFFed3272);   // Brand pink for low impact (good)
    
    // NOTE: Higher score means WORSE impact on blood sugar (more elevation)
    
    // Ensure scores are within reasonable bounds
    final int safeOriginalScore = bloodSugarImpact.originalScore.clamp(0, 100);
    final int safeAlternativeScore = bloodSugarImpact.alternativeScore.clamp(0, 100);
    final int improvement = safeOriginalScore - safeAlternativeScore;

    // Build the comparison gauge section
    final gaugeSection = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildImpactGauge(context, safeOriginalScore, 'Original', highImpactColor, Icons.trending_up_rounded),
        _buildImpactGauge(context, safeAlternativeScore, 'Alternative', lowImpactColor, Icons.trending_down_rounded),
      ],
    );
    
    // Build improvement section
    final improvementSection = improvement > 0
        ? _buildImprovementSection(context, improvement, lowImpactColor)
        : const SizedBox.shrink();

    // Original food impact explanation card
    final originalImpactCard = _buildImpactExplanationCard(
      AppLocalizations.of(context)!.translate('foodScan_originalFoodImpact'),
      bloodSugarImpact.originalImpact,
      highImpactColor,
      Icons.warning_amber_rounded,
    );

    // Alternative food impact explanation card
    final alternativeImpactCard = _buildImpactExplanationCard(
      AppLocalizations.of(context)!.translate('foodScan_alternativeFoodImpact'),
      bloodSugarImpact.alternativeImpact,
      lowImpactColor,
      Icons.check_circle_outline_rounded,
    );

    // Informational section about blood sugar importance
    final whyItMattersSection = _buildWhyItMattersCard(context);

    // Apply staggered animation
    final animatedWidgets = createAnimatedChildren([
      gaugeSection,
      improvementSection,
      originalImpactCard,
      alternativeImpactCard,
      whyItMattersSection,
    ], seed: 4);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...animatedWidgets,
           const SizedBox(height: 30),
           _buildDecorativeElements(),
        ],
      ),
    );
  }

  // Build a single impact gauge
  Widget _buildImpactGauge(BuildContext context, int score, String label, Color color, IconData icon) {
     return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1A1A1A), // Dark text for light background
                fontFamily: 'ElzaRound',
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 100,
          height: 100,
          child: _buildAnimatedRadialGauge(score.toDouble(), color),
        ),
        const SizedBox(height: 12),
        // Animated score text
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: score),
          duration: 1200.ms,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Text(
              '${value}/100',
              style: TextStyle(
                color: color,
                fontFamily: 'ElzaRound',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                  )
                ]
              ),
            );
          }
        ),
        const SizedBox(height: 4),
        Text(
          score <= 40 ? AppLocalizations.of(context)!.translate('foodScan_lowImpact') : score <= 70 ? AppLocalizations.of(context)!.translate('foodScan_mediumImpact') : AppLocalizations.of(context)!.translate('foodScan_highImpact'),
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontFamily: 'ElzaRound',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Build the animated radial gauge using PieChart (similar to Glycemic Index slide)
  Widget _buildAnimatedRadialGauge(double score, Color color) {
    // Score is already 0-100
    final double percentage = score.clamp(0.0, 100.0);
    const double gaugeThickness = 14.0;
    final Color backgroundColor = const Color(0xFF1A1A1A).withOpacity(0.2); // Light gray for light background

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percentage),
      duration: 1200.ms,
      curve: Curves.easeInOutCubic,
      builder: (context, animatedValue, child) {
        return PieChart(
          PieChartData(
            startDegreeOffset: -210,
            sectionsSpace: 0,
            centerSpaceRadius: 36,
            sections: [
              PieChartSectionData(
                color: backgroundColor.withOpacity(0.5),
                value: 100 - animatedValue,
                radius: gaugeThickness,
                showTitle: false,
              ),
              PieChartSectionData(
                color: color,
                value: animatedValue,
                radius: gaugeThickness,
                showTitle: false,
                borderSide: BorderSide(color: Colors.black.withOpacity(0.2), width: 0.5),
              ),
              PieChartSectionData(
                color: Colors.transparent,
                value: (100 / (240 / 360)) - 100,
                radius: gaugeThickness,
                showTitle: false,
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Build the improvement percentage section
  Widget _buildImprovementSection(BuildContext context, int improvement, Color color) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(Icons.shield_outlined, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                AppLocalizations.of(context)!.translate('foodScan_impactReduced').replaceFirst('{improvement}', improvement.toString()),
                textAlign: TextAlign.center,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: color,
                  fontFamily: 'ElzaRound',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(delay: 500.ms, duration: 500.ms, curve: Curves.elasticOut);
  }

  // Build a styled explanation card
  Widget _buildImpactExplanationCard(String title, String explanation, Color accentColor, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // Clean white card background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFed3272).withOpacity(0.2), width: 1), // Brand pink border
         boxShadow: [
          BoxShadow(
            color: const Color(0xFFed3272).withOpacity(0.1), // Brand pink shadow
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFed3272), size: 20), // Brand pink icon
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Color(0xFF1A1A1A), // Dark text for light background
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explanation,
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for light background
              fontFamily: 'ElzaRound',
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  // Build the 'Why It Matters' card
  Widget _buildWhyItMattersCard(BuildContext context) {
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
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: const Color(0xFFed3272), // Brand pink icon
                size: 20,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  AppLocalizations.of(context)!.translate('foodScan_whyBloodSugarMatters'),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
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
            AppLocalizations.of(context)!.translate('foodScan_bloodSugarExplanation'),
            style: TextStyle(
              color: const Color(0xFF666666), // Gray text for secondary info
              fontFamily: 'ElzaRound',
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
   // Add decorative elements
  Widget _buildDecorativeElements() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Icon(
            index % 2 == 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: const Color(0xFFed3272).withOpacity(0.2 + index * 0.2), // Brand pink with varying opacity
            size: 20 + index * 4,
          ).animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          ).shimmer(
            duration: (2 + index * 0.5).seconds,
            delay: (index * 200).ms,
            color: const Color(0xFFfd5d32), // Brand orange shimmer
          ).moveY(
            duration: (1.5 + index * 0.3).seconds,
            begin: -5,
            end: 5,
            curve: Curves.easeInOut
          )
        );
      }),
    );
  }
} 