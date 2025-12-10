import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../../../core/models/food_alternative.dart';
import 'base_slide.dart';
import 'dart:math';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class RecipeSlide extends BaseSlide {
  const RecipeSlide({
    Key? key,
    required super.alternative,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return buildSlideCard(
      title: AppLocalizations.of(context)!.translate('recipe_title'),
      icon: Icons.restaurant_menu,
      titleColor: const Color(0xFFed3272), // Brand pink
      content: _buildRecipeContent(context),
    );
  }

  Widget _buildRecipeContent(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe Title with cooking icon
          Row(
            children: [
              const Icon(
                Icons.local_dining,
                color: Color(0xFFed3272), // Brand pink
                size: 22,
              ).animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              ).rotate(
                duration: 3.seconds,
                begin: -0.05,
                end: 0.05,
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context)!.translate('recipe_makeItYourself'),
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
            ],
          ).animate().fadeIn(duration: 600.ms).moveY(begin: 20, end: 0, duration: 700.ms),
          
          const SizedBox(height: 20),
          
          // Recipe ingredients container with glowing border
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.translate('recipe_ingredientsNotes'),
                  style: const TextStyle(
                    color: Color(0xFFed3272), // Brand pink
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ).animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                ).shimmer(
                  duration: 2.seconds,
                  color: const Color(0xFFfd5d32), // Brand orange shimmer
                ),
                const SizedBox(height: 16),
                _buildIngredientsList(context),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 800.ms).moveY(begin: 20, end: 0, delay: 300.ms, duration: 800.ms),
          
          const SizedBox(height: 24),
          
          // Preparation steps section
          if (alternative.preparationSteps != null && alternative.preparationSteps!.isNotEmpty) ...[
            Row(
              children: [
                _buildAnimatedStepIcon(),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)!.translate('recipe_preparationSteps'),
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
            ).animate().fadeIn(delay: 600.ms, duration: 600.ms).moveY(begin: 20, end: 0, delay: 600.ms, duration: 700.ms),
            
            const SizedBox(height: 16),
            
            ..._buildPreparationSteps(alternative.preparationSteps!),
          ],
          
          // Fun decorative elements for teenage appeal
          const SizedBox(height: 30),
          Center(
            child: Wrap(
              spacing: 15,
              runSpacing: 15,
              alignment: WrapAlignment.center,
              children: [
                _buildFunEmojiContainer('🍳', const Color(0xFFed3272)),
                _buildFunEmojiContainer('🥗', const Color(0xFFfd5d32)),
                _buildFunEmojiContainer('🍓', const Color(0xFFed3272)),
                _buildFunEmojiContainer('🥑', const Color(0xFFfd5d32)),
                _buildFunEmojiContainer('🥤', const Color(0xFFed3272)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build structured ingredients list with emoji bullets
  Widget _buildIngredientsList(BuildContext context) {
    final ingredients = alternative.ingredients;
    if (ingredients == null || ingredients.isEmpty) {
      // Fallback: show recipe notes if present
      return Text(
        alternative.recipe ?? '-',
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontFamily: 'ElzaRound',
          fontSize: 16,
          height: 1.5,
        ),
      );
    }
    return Column(
      children: ingredients.map((ing) {
        final bullet = TextSanitizer.sanitizeForDisplay(ing.emoji ?? '•');
        final qty = [ing.quantity, ing.unit]
            .where((s) => s != null && s!.isNotEmpty)
            .join(' ');
        final hasQty = qty.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFed3272).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    bullet,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      if (hasQty)
                        TextSpan(
                          text: '${TextSanitizer.sanitizeForDisplay(qty)} ',
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      TextSpan(
                        text: TextSanitizer.sanitizeForDisplay(ing.name),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontFamily: 'ElzaRound',
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      if (ing.note != null && ing.note!.isNotEmpty)
                        TextSpan(
                          text: ' (${TextSanitizer.sanitizeForDisplay(ing.note!)})',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontFamily: 'ElzaRound',
                            fontSize: 15,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Build animated steps from a list of preparation instructions
  List<Widget> _buildPreparationSteps(List<String> steps) {
    return steps.asMap().entries.map((entry) {
      final index = entry.key;
      final step = entry.value;
      
      final randomDelay = 800 + (index * 200);
      
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, // Clean white card background
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFed3272).withOpacity(0.2), // Brand pink border
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFed3272).withOpacity(0.1), // Brand pink shadow
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ]
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFed3272), // Brand pink
                    const Color(0xFFfd5d32), // Brand orange
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).shimmer(
              duration: 2.seconds,
              color: Colors.white.withOpacity(0.8), // Keep white shimmer for gradient numbers
            ),
            Expanded(
              child: Text(
                step,
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
        .fadeIn(delay: randomDelay.ms, duration: 600.ms)
        .moveY(begin: 20, end: 0, delay: randomDelay.ms, duration: 700.ms, curve: Curves.easeOutCubic);
    }).toList();
  }
  
  // Get a color for each step based on its index
  Color _getStepColor(int index) {
    final List<Color> colors = [
      const Color(0xFFFFB74D), // Orange
      const Color(0xFF7986CB), // Indigo
      const Color(0xFF4DB6AC), // Teal
      const Color(0xFFBA68C8), // Purple
      const Color(0xFF4FC3F7), // Light Blue
      const Color(0xFFAED581), // Light Green
      const Color(0xFFFFD54F), // Amber
      const Color(0xFF9575CD), // Deep Purple
      const Color(0xFF4DD0E1), // Cyan
      const Color(0xFFF06292), // Pink
    ];
    
    return colors[index % colors.length];
  }
  
  // Build decorative emoji containers
  Widget _buildFunEmojiContainer(String emoji, Color bgColor) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(
            fontSize: 28,
          ),
        ),
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(reverse: true),
    ).scale(
      duration: (2 + Random().nextDouble() * 2).seconds,
      begin: const Offset(1, 1),
      end: const Offset(1.1, 1.1),
      curve: Curves.easeInOut,
    );
  }
  
  // Animated step icon that rotates and changes color
  Widget _buildAnimatedStepIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFed3272).withOpacity(0.2), // Brand pink background
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.format_list_numbered,
        color: Color(0xFFed3272), // Brand pink icon
        size: 18,
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(reverse: false),
    ).shimmer(
      duration: 2.seconds,
      color: const Color(0xFFfd5d32), // Brand orange shimmer
    ).rotate(
      duration: 6.seconds,
      begin: -0.05,
      end: 0.05,
      curve: Curves.easeInOut,
    );
  }
} 