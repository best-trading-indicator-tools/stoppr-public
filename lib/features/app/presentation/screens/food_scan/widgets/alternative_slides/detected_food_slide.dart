import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class DetectedFoodSlide extends StatelessWidget {
  final File imageFile;
  final String detectedFoodName;
  final String detectedFoodDescription;
  final String detectedFoodHealthConcerns;
  final String title = "Scanned Food Analysis";

  const DetectedFoodSlide({
    Key? key,
    required this.imageFile,
    required this.detectedFoodName,
    required this.detectedFoodDescription,
    required this.detectedFoodHealthConcerns,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        // Removed negative margin to fix assertion error
        // padding: const EdgeInsets.only(bottom: 200), // Keeping bottom padding
        padding: const EdgeInsets.only(bottom: 200, top: 0), // Explicitly set top padding to 0
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Detected food section with image - full width for visual impact but smaller height
            SizedBox(
              width: double.infinity,
              // Keep reduced image height
              height: MediaQuery.of(context).size.height * 0.30,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image with overlay
                  ShaderMask(
                    shaderCallback: (rect) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.9),
                        ],
                        stops: const [0.3, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.srcATop,
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.cover,
                    ),
                  ).animate().fadeIn(duration: 800.ms, curve: Curves.easeOutQuad),
                  
                  // Add a shimmer overlay effect for teenage appeal
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.purple.withOpacity(0.1),
                          Colors.pink.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ).animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  ).shimmer(
                    duration: 3.seconds,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  
                  // Text overlay at bottom with improved contrast
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE57373).withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            detectedFoodName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w700,
                              fontSize: 28,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3.0,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 300.ms, duration: 600.ms).moveY(begin: 20, end: 0, delay: 300.ms, duration: 600.ms),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE57373).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            detectedFoodDescription,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'ElzaRound',
                              fontSize: 17,
                              height: 1.3,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2.0,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 500.ms, duration: 600.ms).moveY(begin: 20, end: 0, delay: 500.ms, duration: 600.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Health concerns section for the detected food
            if (detectedFoodHealthConcerns.isNotEmpty)
              Padding(
                // Keep reduced vertical padding
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFFF5252),
                          size: 20,
                        ).animate(
                          onPlay: (controller) => controller.repeat(reverse: true),
                        ).scale(
                          duration: 1.5.seconds,
                          begin: const Offset(1, 1),
                          end: const Offset(1.2, 1.2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.translate('foodAlternatives_healthConcernsTitle'),
                          style: const TextStyle(
                            color: Color(0xFFFF5252),
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w600,
                            fontSize: 22,
                          ),
                        ).animate(
                          onPlay: (controller) => controller.repeat(reverse: true),
                        ).shimmer(
                          duration: 2.seconds,
                          color: const Color(0xFFFF8A80).withOpacity(0.5),
                        ),
                      ],
                    ).animate().fadeIn(delay: 700.ms, duration: 600.ms),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(20),
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
                      child: Text(
                        detectedFoodHealthConcerns,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontFamily: 'ElzaRound',
                          fontSize: 16,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ).animate().fadeIn(delay: 900.ms, duration: 600.ms).moveY(begin: 20, end: 0, delay: 900.ms, duration: 600.ms),
                    
                    // Add swipe instructions as part of the content - moved up for better visibility
                    const SizedBox(height: 25),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient( // Add beautiful gradient background
                            colors: [
                              const Color(0xFFed3272).withOpacity(0.1), // Brand pink
                              const Color(0xFFfd5d32).withOpacity(0.1), // Brand orange
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFed3272).withOpacity(0.3), // Brand pink border
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFed3272).withOpacity(0.1), // Soft brand pink shadow
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.swipe,
                              color: Color(0xFF666666), // Gray icon visible on light background
                              size: 18,
                            ).animate(
                              onPlay: (controller) => controller.repeat(reverse: false),
                            ).moveX(
                              begin: 0,
                              end: 5,
                              duration: 800.ms,
                              curve: Curves.easeInOut,
                            ).then().moveX(
                              begin: 5,
                              end: 0,
                              duration: 800.ms,
                              curve: Curves.easeInOut,
                            ),
                            //const SizedBox(width: 2),
                            Expanded( // Wrap Text with Expanded
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0), // Add some padding if needed
                                child: Text(
                                  AppLocalizations.of(context)!.translate('foodAlternatives_swipePrompt'),
                                  textAlign: TextAlign.center, // Center text if it wraps
                                  style: TextStyle(
                                    color: const Color(0xFF1A1A1A), // Dark text visible on light background
                                    fontFamily: 'ElzaRound',
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  softWrap: true, // Ensure text wraps
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Color(0xFF666666), // Gray arrow visible on light background
                              size: 12,
                            ).animate(
                              onPlay: (controller) => controller.repeat(reverse: true),
                            ).shimmer(
                              duration: 2.seconds,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 1200.ms, duration: 800.ms),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
} 