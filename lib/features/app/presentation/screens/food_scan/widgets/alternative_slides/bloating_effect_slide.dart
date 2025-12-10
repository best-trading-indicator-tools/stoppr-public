import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../../../core/models/food_alternative.dart';
import 'base_slide.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';

class BloatingEffectSlide extends BaseSlide {
  final String originalHealthConcerns;

  const BloatingEffectSlide({
    Key? key,
    required super.alternative,
    required this.originalHealthConcerns,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Very basic comparison using existing strings. If none available, show fallback.
    final bool hasData = originalHealthConcerns.isNotEmpty || (alternative.description.isNotEmpty);

    if (!hasData) {
      return buildSlideCard(
        title: l10n.translate('foodAlternatives_title_bloatingEffect'),
        icon: Icons.air_outlined,
        content: Center(child: Text(l10n.translate('foodAlternatives_noBloatingData'))),
        titleColor: const Color(0xFFed3272), // Brand pink
      );
    }

    return buildSlideCard(
      title: l10n.translate('foodAlternatives_title_bloatingEffect'),
      icon: Icons.air_outlined,
      titleColor: const Color(0xFFed3272), // Brand pink
      content: _buildContent(context, l10n),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    // Build two section cards: Original Food & Alternative
    final List<Widget> infoCards = [
      _buildSectionCard(
        title: l10n.translate('foodAlternatives_originalFoodLabel'),
        text: (
          (originalHealthConcerns.isNotEmpty ? originalHealthConcerns : l10n.translate('foodAlternatives_noBloatingData')) +
          "\n\n" + l10n.translate('foodAlternatives_bloating_originalEffects')
        ),
        color: const Color(0xFFfd5d32), // Brand orange for original (warning)
      ),

      // Fancy arrow indicator between cards
      _buildArrowIndicator(),

      _buildSectionCard(
        title: l10n.translate('foodAlternatives_alternativeLabel'),
        text: (
          (alternative.benefits.isNotEmpty ? alternative.benefits : alternative.description) +
          "\n\n" + l10n.translate('foodAlternatives_bloating_alternativeEffects')
        ),
        color: const Color(0xFFed3272), // Brand pink for alternative (good)
      ),
    ];

    final List<Widget> animatedCards = createAnimatedChildren(infoCards, seed: 7);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Determine score & description for original food bloating
          _buildBloatGauge(
            context,
            l10n,
            _computeOriginalBloatScore(),
            originalHealthConcerns.isNotEmpty ? originalHealthConcerns : l10n.translate('foodAlternatives_noBloatingData'),
            alternative.bloatInfo?.skinEffects,
          ),
          const SizedBox(height:20),
          _buildSeverityChart(l10n),
          const SizedBox(height: 24),
          ...animatedCards,
          const SizedBox(height: 24),
          _buildDecorativeEmojis(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required String text, required Color color}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
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
              Icon(Icons.waves_rounded, color: const Color(0xFFed3272), size: 22).animate( // Brand pink icon
                onPlay: (c) => c.repeat(reverse: true),
              ).shimmer(duration: 2.seconds, color: const Color(0xFFfd5d32)), // Brand orange shimmer
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFed3272), // Brand pink for titles
                    fontFamily: 'ElzaRound',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().shimmer(duration: 2.seconds, color: const Color(0xFFfd5d32)), // Brand orange shimmer
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
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

  // Build animated arrow indicator between original & alternative cards
  Widget _buildArrowIndicator() {
    return Center(
      child: Icon(Icons.arrow_downward_rounded, color: const Color(0xFFed3272), size: 28) // Brand pink arrow
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: -5, end: 5, duration: 1.seconds)
          .fadeIn(duration: 600.ms),
    );
  }

  Widget _buildSeverityChart(AppLocalizations l10n) {
    // Determine bloating severity scores (0 worst-100 best? We'll treat higher = worse)
    int original = 80;
    int alt = 30;
    if (alternative.bloodSugarImpact != null) {
      original = alternative.bloodSugarImpact!.originalScore.clamp(0, 100);
      alt = alternative.bloodSugarImpact!.alternativeScore.clamp(0, 100);
    }

    double originalFactor = original / 100;
    double altFactor = alt / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('foodAlternatives_bloating_severityTitle'),
          style: const TextStyle(
            color: Color(0xFF1A1A1A), // Dark text for light background
            fontFamily: 'ElzaRound',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ).animate().fadeIn(duration: 600.ms).moveY(begin: 10, end: 0),
        const SizedBox(height: 12),
        _buildBar(l10n.translate('foodAlternatives_originalLabel'), originalFactor, const Color(0xFFfd5d32)), // Brand orange
        const SizedBox(height: 10),
        _buildBar(l10n.translate('foodAlternatives_alternativeLabel'), altFactor, const Color(0xFFed3272)), // Brand pink
      ],
    );
  }

  Widget _buildBar(String label, double factor, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: factor),
      duration: 1.seconds,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontFamily: 'ElzaRound', fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFed3272).withOpacity(0.15), // Brand pink background
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.6), color],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ).animate().fadeIn(duration: 700.ms).moveY(begin: 10, end: 0);
  }

  // Cute emojis row to lighten up slide
  Widget _buildDecorativeEmojis() {
    const List<String> emojis = ['😮‍💨', '🍔', '➡️', '🫄', '🌿', '😊'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: emojis.asMap().entries.map((e) {
        final idx = e.key;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            e.value,
            style: const TextStyle(fontSize: 24),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 600.ms, delay: (idx * 100).ms)
          .moveY(begin: idx.isEven ? -3 : 3, end: 0, duration: 1.seconds)
        );
      }).toList(),
    );
  }

  Widget _buildBloatGauge(BuildContext context, AppLocalizations l10n, int score, String description, Map<String, String>? skinEffects) {
    // Determine color based on score ranges - STOPPR brand colors only
    final Color gaugeColor = score <= 30 
      ? const Color(0xFFed3272) // Brand pink for good scores
      : score <= 70 
        ? const Color(0xFFfd5d32) // Brand orange for medium scores
        : const Color(0xFFfd5d32); // Brand orange for high scores (warning)
        
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.translate('foodAlternatives_bloating_scoreTitle'),
          style: const TextStyle(
            color: Color(0xFF1A1A1A), // Dark text for light background
            fontFamily: 'ElzaRound',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 15,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFed3272)), // Exact brand pink
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  // Progress circle
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 15,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                    ),
                  ),
                  // Center text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        score.toString(),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A), // Dark text for light background
                          fontFamily: 'ElzaRound',
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '/100',
                        style: const TextStyle(
                          color: Color(0xFF666666), // Gray text for secondary info
                          fontFamily: 'ElzaRound',
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A), // Dark text for light background
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                    ),
                  ),
                  if (score > 50)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        l10n.translate('foodAlternatives_bloating_highScoreMessage'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFfd5d32), // Brand orange for warning
                          fontFamily: 'ElzaRound',
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (skinEffects != null && skinEffects.isNotEmpty)
          _buildSkinEffectsSection(context, l10n, skinEffects),
      ],
    );
  }
  
  String _getLocalizedSkinEffectKey(AppLocalizations l10n, String englishKey) {
    switch (englishKey.toLowerCase()) {
      case 'puffiness':
        return l10n.translate('skinEffect_puffiness');
      case 'redness':
        return l10n.translate('skinEffect_redness');
      case 'texture':
        return l10n.translate('skinEffect_texture');
      default:
        return englishKey; // fallback to original if not found
    }
  }

  Widget _buildSkinEffectsSection(BuildContext context, AppLocalizations l10n, Map<String, String> skinEffects) {
    return Container(
      width: double.infinity, // ensures left alignment within parent Column
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            l10n.translate('foodAlternatives_bloating_skinEffectsTitle'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for light background
              fontFamily: 'ElzaRound',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: skinEffects.entries.map((entry) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.75,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white, // Clean white card background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFed3272).withOpacity(0.2), width: 1), // Brand pink border
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFed3272).withOpacity(0.1), // Brand pink shadow
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          entry.key.toLowerCase().contains('puffy') || entry.key.toLowerCase().contains('swell') 
                              ? Icons.face
                              : entry.key.toLowerCase().contains('red') 
                                ? Icons.favorite
                                : Icons.texture,
                          color: const Color(0xFFed3272), // Brand pink icon
                          size: 20,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _getLocalizedSkinEffectKey(l10n, entry.key),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A), // Dark text for light background
                              fontFamily: 'ElzaRound',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.value,
                      style: const TextStyle(
                        color: Color(0xFF666666), // Gray text for secondary info
                        fontFamily: 'ElzaRound',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true, period: 5.seconds))
              .shimmer(delay: 1.seconds, duration: 1.5.seconds);
            }).toList(),
          ),
        ],
      ),
    );
  }

  int _computeOriginalBloatScore() {
    // Fallback: approximate using blood sugar original score (proxy)
    if (alternative.bloodSugarImpact != null) {
      // For high-sugar foods, we want a higher bloating score (worse bloating)
      // Blood sugar impact and bloating are often correlated
      // Clamp to a high range, assuming high blood sugar impact correlates with high bloating
      return alternative.bloodSugarImpact!.originalScore.clamp(70, 100);
    }
    // Default placeholder value - assume high bloating for original unhealthy food if no other data
    return 85;
  }
} 