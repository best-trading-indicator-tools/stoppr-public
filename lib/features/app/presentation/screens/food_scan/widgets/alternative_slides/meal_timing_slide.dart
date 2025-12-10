import 'package:flutter/material.dart';
import '../../../../../../../core/models/food_alternative.dart';
import 'base_slide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'package:stoppr/core/localization/app_localizations.dart';

class MealTimingSlide extends BaseSlide {
  const MealTimingSlide({
    Key? key,
    required super.alternative,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (alternative.mealTiming == null) {
      return buildSlideCard(
        title: AppLocalizations.of(context)!.translate('foodScan_mealTimingTitle'),
        icon: Icons.access_time_filled_rounded,
        content: Center(child: Text(AppLocalizations.of(context)!.translate('foodScan_noMealTimingData'))),
        titleColor: const Color(0xFFed3272), // Brand pink
      );
    }
    
    return buildSlideCard(
      title: AppLocalizations.of(context)!.translate('foodScan_whenToEatTitle'),
      icon: Icons.access_time_filled_rounded,
      content: _buildMealTimingContent(context),
      titleColor: const Color(0xFFed3272), // Brand pink
    );
  }

  Widget _buildMealTimingContent(BuildContext context) {
    final mealTiming = alternative.mealTiming!;
    
    final infoCard = Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
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
      child: Row(
          children: [
             Icon(
                Icons.info_outline_rounded,
                color: const Color(0xFFed3272), // Brand pink
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                AppLocalizations.of(context)!.translate('mealTiming_description'),
                style: const TextStyle(
                  color: Color(0xFF666666), // Gray text for secondary info
                  fontFamily: 'ElzaRound',
                  fontSize: 16,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
                          ),
              ),
          ],
        ),
    );

    // Apply staggered animation
    final animatedWidgets = createAnimatedChildren([
      infoCard,
      _buildMealTimingCard(AppLocalizations.of(context)!.translate('mealTiming_breakfast'), mealTiming.breakfast, Icons.wb_sunny_outlined), 
      _buildMealTimingCard(AppLocalizations.of(context)!.translate('mealTiming_lunch'), mealTiming.lunch, Icons.lunch_dining_outlined), 
      _buildMealTimingCard(AppLocalizations.of(context)!.translate('mealTiming_dinner'), mealTiming.dinner, Icons.nights_stay_outlined), 
      _buildMealTimingCard(AppLocalizations.of(context)!.translate('mealTiming_snack'), mealTiming.snack, Icons.apple_outlined),
    ], seed: 5); // Use another seed

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         ...animatedWidgets,
         const SizedBox(height: 30), // Bottom padding
         _buildDecorativeElements(),
        ],
      ),
    );
  }

  // Build a styled card for each meal time
  Widget _buildMealTimingCard(String title, String description, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, // Clean white card background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFed3272).withOpacity(0.2), // Brand pink border
          width: 1.5,
        ),
         boxShadow: [
          BoxShadow(
            color: const Color(0xFFed3272).withOpacity(0.1), // Brand pink shadow
            blurRadius: 10,
            spreadRadius: 2,
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFed3272), size: 22), // Brand pink icons
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFed3272), // Brand pink for titles
                  fontFamily: 'ElzaRound',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description.isNotEmpty ? description : 'General impact applies.', // Fallback text
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
  
  // Add simple decorative elements
  Widget _buildDecorativeElements() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Icon(
            Icons.access_time_filled_rounded,
            color: const Color(0xFFed3272).withOpacity(0.3 + index * 0.15), // Brand pink with varying opacity
            size: 18 + index * 2,
          ),
        );
      }),
    );
  }
} 