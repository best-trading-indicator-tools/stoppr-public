import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:stoppr/app/theme/app_theme.dart'; // Ensure AppTheme is imported if used
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart'; // Add this import

class SugarUnhappinessScreen extends StatefulWidget {
  const SugarUnhappinessScreen({super.key});

  @override
  State<SugarUnhappinessScreen> createState() => _SugarUnhappinessScreenState();
}

class _SugarUnhappinessScreenState extends State<SugarUnhappinessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    
    // Mixpanel Page View Tracking
    MixpanelService.trackPageView('Onboarding Painpoint Sugar Unhappiness Screen Viewed');
    
    // Set status bar icons to white for contrast against red background
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Increased duration for half speed
    );
    
    _animationController.repeat(); // Standard looping
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
            // App Bar with centered Stoppr title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: Text(
                  AppLocalizations.of(context)!.translate('sugarUnhappiness_appBarTitle'),
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
                    // Gender Symbols animation with half speed
                    Lottie.asset(
                      'assets/images/lotties/Unhappy.json',
                      controller: _animationController,
                      repeat: true,
                      width: 210,
                      height: 210,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Title - "Feeling unhappy?"
                    Text(
                      AppLocalizations.of(context)!.translate('sugarUnhappiness_title'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Description text with bold words and increased line spacing
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
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarUnhappiness_description_part1')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarUnhappiness_description_dopamineLevels'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarUnhappiness_description_part2')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarUnhappiness_description_feelGood'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarUnhappiness_description_part3')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarUnhappiness_description_heavyConsumers'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarUnhappiness_description_part4')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarUnhappiness_description_symptoms'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarUnhappiness_description_part5')),
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