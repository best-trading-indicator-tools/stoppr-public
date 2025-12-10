import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../../../core/models/food_alternative.dart';

abstract class BaseSlide extends StatelessWidget {
  final FoodAlternative alternative;
  
  const BaseSlide({
    Key? key,
    required this.alternative,
  }) : super(key: key);
  
  // Common styling for all slide cards with vibrant background
  Widget buildSlideCard({
    // title and icon parameters are no longer used directly here
    // but kept in signature for potential future use or consistency
    required String title, 
    required IconData icon,
    required Widget content,
    Color titleColor = const Color(0xFF55B6C2), // Not used for banner anymore
  }) {
    return Container(
      width: double.infinity,
      // Add consistent bottom padding to ALL slides to prevent overlap with navigation dots
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      decoration: const BoxDecoration(
        // New branding: soft pink-tinted white background
        color: Color(0xFFFDF8FA),
      ),
      // Apply staggered entrance animations to the content
      child: content,
    );
  }
  
  // Helper widget to build a pulsing info icon that appears clickable
  Widget buildPulsingInfoIcon() {
    return const Icon(
      Icons.info_outline_rounded,
      color: Color(0xFFed3272), // New branding: brand pink
      size: 18,
    ).animate(
      onPlay: (controller) => controller.repeat(reverse: true),
    ).scale(
      duration: 1.5.seconds,
      begin: const Offset(1, 1),
      end: const Offset(1.2, 1.2),
    ).shimmer(
      duration: 1.8.seconds,
    );
  }
  
  // Helper function to create staggered animated children for any slide
  List<Widget> createAnimatedChildren(List<Widget> children, {int? seed}) {
    // Use a seed to randomize the delays slightly but consistently
    final random = seed != null ? Random(seed) : Random();
    
    return List.generate(
      children.length,
      (index) {
        final delayMs = 100 + (index * 50) + random.nextInt(50);
        final durationMs = 600 + random.nextInt(200);
        
        return children[index]
          .animate()
          .fadeIn(
            duration: durationMs.ms,
            delay: delayMs.ms,
            curve: Curves.easeOutCubic,
          )
          .moveY(
            begin: 20,
            end: 0,
            delay: delayMs.ms,
            duration: (durationMs * 1.2).ms,
            curve: Curves.easeOutCubic,
          );
      },
    );
  }
} 