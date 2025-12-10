import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:io' show Platform; // Import Platform

import 'benefits_rewire_brain.dart';
// Removed back navigation to Sugar Painpoints flow
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class BenefitsWelcomeToStopprScreen extends StatefulWidget {
  const BenefitsWelcomeToStopprScreen({super.key});

  @override
  State<BenefitsWelcomeToStopprScreen> createState() => _BenefitsWelcomeToStopprScreenState();
}

class _BenefitsWelcomeToStopprScreenState extends State<BenefitsWelcomeToStopprScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();

    // Mixpanel
    MixpanelService.trackPageView('Onboarding Benefits Welcome to Stoppr Screen');
    
    // Force white status bar icons
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark, // For iOS
    ));
    
    // Initialize animation controller for Brain lottie
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Initialize background animation controller
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    
    // Start the animations when initialized
    _animationController.forward();
    _backgroundController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Enforce white status bar icons on each build
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark, // For iOS
    ));
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background color/gradient overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1C072E), // Purple mask color at top
                    Color(0xFF09050C), // Darker color at bottom
                  ],
                ),
              ),
            ),
          ),
          
          // Lottie background with opacity - positioned UNDER the gradient
          Positioned.fill(
            child: Opacity(
              opacity: 0.26,
              child: Lottie.asset(
                'assets/images/lotties/DarkForestBackground.json',
                controller: _backgroundController,
                fit: BoxFit.cover, // Changed from contain to cover for full screen coverage
                repeat: true,
                onLoaded: (composition) {
                  _backgroundController.duration = composition.duration;
                  _backgroundController.repeat();
                },
              ),
            ),
          ),
          
          // Content layer
          SafeArea(
            child: Column(
              children: [
                // App Bar with centered Stoppr title (no back button)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context)!.translate('benefitsWelcome_appBarTitle'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                              letterSpacing: -0.04 * 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                
                // Expanded area for content - Now using SingleChildScrollView to prevent overflow
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Brain animation - removed top spacing
                          Lottie.asset(
                            'assets/images/lotties/superHeroReversed.json',
                            controller: _animationController,
                            repeat: true,
                            onLoaded: (composition) {
                              // Configure for continuous looping
                              _animationController.duration = composition.duration;
                              _animationController.repeat();
                            },
                            width: 350,
                            height: 290, // Reduced height from 300 to 240
                          ),
                          
                          // Title - "Welcome to Stoppr"
                          Text(
                            AppLocalizations.of(context)!.translate('benefitsWelcome_title'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          
                          const SizedBox(height: 16),  // Reduced from 46 to bring description closer to title
                          
                          // Description with bold words
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.7, // Line spacing
                              ),
                              children: Platform.isAndroid 
                                ? <TextSpan>[ // Android version
                                    TextSpan(text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_android_part1')),
                                    TextSpan(
                                      text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_android_effective'),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_android_part2')),
                                    TextSpan(
                                      text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_android_research'),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_android_part3')),
                                    TextSpan(
                                      text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_android_userInteraction'),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ] 
                                : <TextSpan>[ // iOS version (original)
                                    TextSpan(text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_ios_part1')),
                                    TextSpan(
                                      text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_ios_users'),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_ios_part2')),
                                    TextSpan(
                                      text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_ios_classLeading'),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_ios_part3')),
                                    TextSpan(
                                      text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_ios_research'),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_ios_part4')),
                                    TextSpan(
                                      text: AppLocalizations.of(context)!.translate('benefitsWelcome_description_ios_userInteraction'),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Space at bottom for page view's indicators and buttons
                const SizedBox(height: 120),  // Reduced from 150
              ],
            ),
          ),
        ],
      ),
    );
  }
} 