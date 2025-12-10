import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'symptoms_screen.dart'; // Import SymptomsScreen
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class SugarDrugScreen extends StatefulWidget {
  const SugarDrugScreen({super.key});

  @override
  State<SugarDrugScreen> createState() => _SugarDrugScreenState();
}

class _SugarDrugScreenState extends State<SugarDrugScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    
    // Mixpanel Page View Tracking
    MixpanelService.trackPageView('Onboarding Painpoint Sugar As Drug Screen Viewed');
    
    // Set status bar icons to light for contrast against red background
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent, // Ensure status bar is transparent
    ));
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Example duration
    );
    
    // Start the animation when initialized
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Enforce white status bar icons on each build
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    
    return Scaffold(
      backgroundColor: const Color(0xFFDB052C), // Red background color
      extendBody: true, // Added for edge-to-edge
      extendBodyBehindAppBar: true, // Added for edge-to-edge
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // Effectively hides the app bar visually but keeps overlay style
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar with back button and centered Stoppr title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: Text(
                  AppLocalizations.of(context)!.translate('sugarDrug_appBarTitle'),
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.0, // 100% line height
                    letterSpacing: -0.04 * 24, // -4% letter spacing of font size
                  ),
                ),
              ),
            ),
            
            // Expanded area for content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    // Brain animation - no looping
                    Lottie.asset(
                      'assets/images/lotties/Brain.json',
                      controller: _animationController,
                      repeat: false,
                      onLoaded: (composition) {
                        // Start the animation once loaded
                        _animationController.forward();
                      },
                      width: 210,
                      height: 210,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Title
                    Text(
                      AppLocalizations.of(context)!.translate('sugarDrug_title'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Description text with bold words
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.7, // Increased from 1.4 to 1.7 for more line spacing
                        ),
                        children: <TextSpan>[
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarDrug_description_part1')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarDrug_description_dopamine'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarDrug_description_part2')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarDrug_description_good'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarDrug_description_part3')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarDrug_description_pleasure'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarDrug_description_part4')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Empty space for the page indicators and next button that will be provided by the container
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
} 