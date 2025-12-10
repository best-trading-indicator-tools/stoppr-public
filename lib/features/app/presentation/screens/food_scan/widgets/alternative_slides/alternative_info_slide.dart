import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../../../core/models/food_alternative.dart';
import 'base_slide.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math';
import 'package:stoppr/core/localization/app_localizations.dart';

class AlternativeInfoSlide extends BaseSlide {
  const AlternativeInfoSlide({
    Key? key,
    required super.alternative,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return buildSlideCard(
      title: AppLocalizations.of(context)!.translate('foodAlternatives_title_healthierAlternative'),
      icon: Icons.local_florist_rounded,
      titleColor: const Color(0xFFed3272), // Brand pink
      content: _buildAlternativeInfoContent(context),
    );
  }

  Widget _buildAlternativeInfoContent(BuildContext context) {
    // Create base widgets without animations
    final nameText = Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        alternative.name,
        textAlign: TextAlign.start,
        style: const TextStyle(
          color: Color(0xFFed3272), // Brand pink for alternative name
          fontFamily: 'ElzaRound',
          fontWeight: FontWeight.bold,
          fontSize: 30,
          letterSpacing: -0.5,
        ),
      ),
    );
    
    final descriptionText = Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Text(
        alternative.description,
        style: const TextStyle(
          color: Color(0xFF1A1A1A), // Dark text for light background
          fontFamily: 'ElzaRound',
          fontSize: 17,
          height: 1.55,
          letterSpacing: 0.1,
        ),
      ),
    );
    
    final healthScoreWidget = _buildHealthScoreIndicator(context, alternative.healthScore ?? 75);
    final difficultyWidget = _buildPreparationDifficultyIndicator(context, alternative.preparationDifficulty ?? 3);
    
    // Cost comparison widget if available
    Widget? costComparisonWidget;
    if (alternative.costComparison != null) {
      costComparisonWidget = _buildCostComparisonCard(context, alternative.costComparison!);
    }

    // Use the createAnimatedChildren helper to apply staggered animations
    final animatedWidgets = createAnimatedChildren([
      nameText,
      descriptionText,
      healthScoreWidget,
      difficultyWidget,
      if (costComparisonWidget != null) costComparisonWidget,
    ], seed: 1);

    return Container(
      width: MediaQuery.of(context).size.width,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...animatedWidgets,
            const SizedBox(height: 30),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.eco_rounded,
                    color: _getRandomLeafColor(index),
                    size: 18 + (index % 3) * 5,
                  ).animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  ).scale(
                    duration: (1.5 + index * 0.4).seconds,
                    begin: const Offset(1, 1),
                    end: const Offset(1.15, 1.15),
                    curve: Curves.easeInOut,
                  ).rotate(
                    duration: (2.5 + index * 0.6).seconds,
                    begin: -0.08,
                    end: 0.08,
                  );
                }),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHealthScoreIndicator(BuildContext context, int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFed3272).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFed3272).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.spa_outlined,
                  color: Color(0xFFed3272),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context)!.translate('foodAlternatives_healthScoreTitle'),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for light background
                  fontFamily: 'ElzaRound',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder(
            duration: 1200.ms,
            curve: Curves.easeOutCubic, 
            tween: Tween<double>(begin: 0.0, end: (score / 100).clamp(0.0, 1.0)),
            builder: (context, double value, _) {
              return Container(
                height: 12,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.1), // Dark background for progress
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TweenAnimationBuilder<int>(
              duration: 1200.ms,
              curve: Curves.easeOutCubic,
              tween: IntTween(begin: 0, end: score),
              builder: (context, value, child) {
                return Text(
                  '$value/100',
                  style: TextStyle(
                    color: const Color(0xFF666666), // Gray text for secondary info
                    fontFamily: 'ElzaRound',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreparationDifficultyIndicator(BuildContext context, int difficulty) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFed3272).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFfd5d32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_cafe_outlined,
                  color: Color(0xFFfd5d32), // Brand orange
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.translate('foodAlternatives_prepDifficultyTitle'),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for light background
                  fontFamily: 'ElzaRound',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              bool isActive = index < difficulty;
              double iconSize = 18;
              IconData diffIcon = isActive 
                  ? (difficulty <= 2 ? Icons.sentiment_very_satisfied : difficulty <= 4 ? Icons.sentiment_satisfied : Icons.sentiment_very_dissatisfied) 
                  : Icons.sentiment_neutral_outlined; 
              Color activeColor = isActive 
                  ? (difficulty <= 2 ? const Color(0xFF0D4F0C) : difficulty <= 4 ? const Color(0xFFBF360C) : const Color(0xFFB71C1C))
                  : const Color(0xFF1A1A1A); // Dark gray for better contrast on light background
              
              return Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: isActive ? Colors.transparent : const Color(0xFF1A1A1A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? activeColor.withOpacity(0.5) : const Color(0xFF1A1A1A),
                    width: 1.5
                  ),
                ),
                child: Icon(
                  diffIcon,
                  size: iconSize,
                  color: activeColor,
                ),
              ).animate(
                delay: 800.ms + (index * 150).ms,
              ).fadeIn(
                duration: 500.ms,
              ).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 400.ms, curve: Curves.easeOutBack);
            }),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              difficulty <= 2 
                ? l10n.translate('foodAlternatives_prepDifficultyEasy') 
                : difficulty <= 4 
                  ? l10n.translate('foodAlternatives_prepDifficultyMedium') 
                  : l10n.translate('foodAlternatives_prepDifficultyHard'),
              style: const TextStyle(
                color: Color(0xFFfd5d32), // Brand orange
                fontFamily: 'ElzaRound',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostComparisonCard(BuildContext context, CostComparison costComparison) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFed3272).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFfd5d32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.savings_outlined,
                  color: Color(0xFFfd5d32),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.translate('foodAlternatives_costComparisonTitle'),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for light background
                  fontFamily: 'ElzaRound',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCostItem(l10n.translate('foodAlternatives_originalLabel'), costComparison.original, const Color(0xFFed3272), isOriginal: true, context: context),
              const SizedBox(width: 16),
              _buildCostItem(l10n.translate('foodAlternatives_alternativeLabel'), costComparison.alternative, const Color(0xFFfd5d32), isOriginal: false, context: context),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            costComparison.description,
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

  Widget _buildCostItem(String label, String cost, Color accentColor, {required bool isOriginal, required BuildContext context}) {
    Widget costVisual;
    final costTextStyle = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.bold,
      color: accentColor,
      letterSpacing: 1.0,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 4,
          offset: const Offset(0, 1),
        )
      ]
    );

    IconData costIconData = Icons.attach_money;
    switch (cost) {
      case '\$':
        costVisual = Text(cost, style: costTextStyle);
        break;
      case '\$\$':
        costVisual = Row(mainAxisSize: MainAxisSize.min, children: List.generate(2, (i) => Icon(costIconData, color: accentColor, size: 28)));
        break;
      case '\$\$\$':
        costVisual = Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => Icon(costIconData, color: accentColor, size: 28)));
        break;
      default:
        costVisual = Text(cost, style: costTextStyle.copyWith(fontSize: 18));
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withOpacity(0.05), // Dark background
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1A1A1A), // Dark text for light background
                fontFamily: 'ElzaRound',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            costVisual,
          ],
        ),
      ),
    );
  }
  
  Color _getRandomLeafColor(int index) {
    final List<Color> colors = [
      const Color(0xFF81C784),
      const Color(0xFF66BB6A),
      const Color(0xFF4CAF50),
      const Color(0xFFAED581),
      const Color(0xFFDCEDC8),
    ];
    return colors[index % colors.length];
  }
} 