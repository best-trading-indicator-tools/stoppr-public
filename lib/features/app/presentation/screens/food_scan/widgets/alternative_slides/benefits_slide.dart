import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../../../core/models/food_alternative.dart';
import 'base_slide.dart';
import 'dart:math';
import 'package:stoppr/core/localization/app_localizations.dart';

class BenefitsSlide extends BaseSlide {
  const BenefitsSlide({
    Key? key,
    required super.alternative,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return buildSlideCard(
      title: l10n.translate('foodAlternatives_title_healthBenefits'),
      icon: Icons.favorite,
              titleColor: const Color(0xFFed3272), // Brand pink
      content: _buildBenefitsContent(context),
    );
  }

  Widget _buildBenefitsContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool hasDetailedBenefits = alternative.detailedBenefits != null && 
        alternative.detailedBenefits!.isNotEmpty;
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main benefits section
          Text(
            l10n.translate('foodAlternatives_benefits_whyBetterTitle'),
            style: const TextStyle(
              color: Color(0xFFed3272), // Brand pink
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
          ).animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          ).shimmer(
            duration: 3.seconds,
            color: const Color(0xFFfd5d32), // Brand orange shimmer
          ),
          
          const SizedBox(height: 16),
          
          // Animated benefits container
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white, // Clean white card background
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFed3272).withOpacity(0.1), // Brand pink shadow
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFed3272).withOpacity(0.2), // Brand pink border
                width: 1.5,
              ),
            ),
            child: Text(
              _stripCitations(
                alternative.benefits ??
                    l10n.translate('foodAlternatives_benefits_noInfo'),
              ),
              style: const TextStyle(
                color: Color(0xFF1A1A1A), // Dark text for light background
                fontFamily: 'ElzaRound',
                fontSize: 17,
                height: 1.6,
              ),
            ),
          ).animate()
            .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic)
            .moveY(begin: 20, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
          
          // Detailed benefits section (if available)
          if (hasDetailedBenefits) ...[
            const SizedBox(height: 24),
            
            // Animated title with sparkle icon
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: const Color(0xFFed3272), // Brand pink
                  size: 20,
                ).animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                ).rotate(
                  duration: 2.seconds,
                  begin: 0,
                  end: 0.08,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.translate('foodAlternatives_benefits_detailedTitle'),
                  style: const TextStyle(
                    color: Color(0xFFed3272), // Brand pink
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                    fontSize: 22,
                  ),
                ).animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                ).shimmer(
                  duration: 2.5.seconds,
                  color: const Color(0xFFfd5d32), // Brand orange shimmer
                ),
              ],
            ).animate()
              .fadeIn(delay: 300.ms, duration: 600.ms)
              .slideX(begin: -0.2, end: 0, delay: 300.ms, duration: 600.ms),
                
            const SizedBox(height: 16),
                
            // Generate animated benefit bullet points
            ..._generateBenefitPoints(alternative.detailedBenefits!),
          ],
          
          // Add decorative elements for teenage appeal
          const SizedBox(height: 30),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Icon(
                  Icons.favorite,
                  color: _getRandomHeartColor(index),
                  size: 16 + (index % 3) * 4,
                ).animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                ).scale(
                  duration: (1 + index * 0.3).seconds,
                  begin: const Offset(1, 1),
                  end: const Offset(1.2, 1.2),
                  curve: Curves.easeInOut,
                ).rotate(
                  duration: (2 + index * 0.5).seconds,
                  begin: -0.05,
                  end: 0.05,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
  
  // Generate animated bullet points from the detailed benefits text
  List<Widget> _generateBenefitPoints(String detailedText) {
    // Sanitize citations and parse the detailed benefits into bullet points
    final String sanitized = _stripCitations(detailedText);
    final List<String> bulletPoints = sanitized
        .split('\n')
        .expand((paragraph) => paragraph.split('. '))
        .where((sentence) =>
            sentence.trim().isNotEmpty &&
            RegExp(r'[A-Za-z0-9]').hasMatch(sentence))
        .map((sentence) => sentence.endsWith('.') ? sentence : '$sentence.')
        .toList();
    
    // Generate an animated widget for each bullet point
    return bulletPoints.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _getRandomBulletColor(),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getRandomBulletColor().withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).scale(
              duration: 2.seconds,
              begin: const Offset(1, 1),
              end: const Offset(1.2, 1.2),
              curve: Curves.easeInOut,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                point,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for light background
                  fontFamily: 'ElzaRound',
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ).animate()
        .fadeIn(delay: (300 + index * 200).ms, duration: 600.ms)
        .moveY(begin: 20, end: 0, delay: (300 + index * 200).ms, duration: 600.ms, curve: Curves.easeOutCubic);
    }).toList();
  }

  // Remove bracketed numeric citations (e.g., "[1]", "[2]") and collapse
  // multiple spaces into one. Keeps the rest of the text unchanged.
  String _stripCitations(String text) {
    final withoutCitations = text.replaceAll(RegExp(r"\s*\[\d+\]"), '');
    final collapsedSpaces =
        withoutCitations.replaceAll(RegExp(r"\s{2,}"), ' ');
    return collapsedSpaces.trim();
  }
  
  // Get STOPPR brand colors for bullet points
  Color _getRandomBulletColor() {
    final List<Color> colors = [
      const Color(0xFFed3272), // Brand pink
      const Color(0xFFfd5d32), // Brand orange
    ];
    
    // Use a seeded random for consistency across rebuilds
    return colors[Random(colors.length).nextInt(colors.length)];
  }
  
  // Get STOPPR brand colors for heart icons
  Color _getRandomHeartColor(int index) {
    final List<Color> colors = [
      const Color(0xFFed3272), // Brand pink
      const Color(0xFFfd5d32), // Brand orange
      const Color(0xFFed3272), // Brand pink
      const Color(0xFFfd5d32), // Brand orange
      const Color(0xFFed3272), // Brand pink
    ];
    
    return colors[index % colors.length];
  }
} 