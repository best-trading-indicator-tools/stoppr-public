import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class SugarRelationshipsScreen extends StatefulWidget {
  const SugarRelationshipsScreen({super.key});

  @override
  State<SugarRelationshipsScreen> createState() => _SugarRelationshipsScreenState();
}

class _SugarRelationshipsScreenState extends State<SugarRelationshipsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    
    // Mixpanel Page View Tracking
    MixpanelService.trackPageView('Onboarding Painpoint Sugar Relationships Screen Viewed');
    
    // Set status bar icons to light for contrast against red background
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent, // Ensure status bar is transparent
    ));
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Example duration
    );
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
                  AppLocalizations.of(context)!.translate('sugarRelationships_appBarTitle'),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Heart animation
                    Lottie.asset(
                      'assets/images/lotties/broken heart V2.json',
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
                    
                    // Title - properly centered with crossAxisAlignment.center
                    Center(
                      child: Text(
                        AppLocalizations.of(context)!.translate('sugarRelationships_title'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
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
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarRelationships_description_part1')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarRelationships_description_impact'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarRelationships_description_part2')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarRelationships_description_mood'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarRelationships_description_part3')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarRelationships_description_energy'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarRelationships_description_part4')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarRelationships_description_irritability'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarRelationships_description_part5')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarRelationships_description_fatigue'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarRelationships_description_part6')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarRelationships_description_strain'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarRelationships_description_part7')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarRelationships_description_reduce'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarRelationships_description_part8')),
                          TextSpan(
                            text: AppLocalizations.of(context)!.translate('sugarRelationships_description_connect'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: AppLocalizations.of(context)!.translate('sugarRelationships_description_part9')),
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