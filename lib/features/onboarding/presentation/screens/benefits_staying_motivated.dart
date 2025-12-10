import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class BenefitsStayingMotivatedScreen extends StatefulWidget {
  const BenefitsStayingMotivatedScreen({super.key});

  @override
  State<BenefitsStayingMotivatedScreen> createState() => _BenefitsStayingMotivatedScreenState();
}

class _BenefitsStayingMotivatedScreenState extends State<BenefitsStayingMotivatedScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();
    
    // Mixpanel Page View Tracking
    MixpanelService.trackPageView('Onboarding Benefits Staying Motivated Screen Viewed');
    
    // Force white status bar icons
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark, // For iOS
    ));
    
    // Initialize animation controller for main lottie
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
                fit: BoxFit.cover, // Full screen coverage
                repeat: true,
                onLoaded: (composition) {
                  _backgroundController.duration = composition.duration;
                  _backgroundController.repeat();
                },
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // App Bar with centered Stoppr title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                
                // Expanded area for content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 50), // Adjusted spacing at top
                          
                          // Main animation
                          Lottie.asset(
                            'assets/images/lotties/StayMotivated.json',
                            controller: _animationController,
                            repeat: true,
                            height: 300, // Slightly larger
                            width: 320, // Slightly larger
                            onLoaded: (composition) {
                              // Set up the controller with the composition duration
                              _animationController.duration = composition.duration;
                              _animationController.repeat();
                            },
                          ),
                          
                          //const SizedBox(height: 30), // Adjusted spacing before title
                          
                          // Title
                          Text(
                            AppLocalizations.of(context)!.translate('benefitsMotivated_title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          
                          const SizedBox(height: 16), // Adjusted spacing after title
                          
                          // Description text
                          Text(
                            AppLocalizations.of(context)!.translate('benefitsMotivated_description'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.7, // Line spacing
                            ),
                          ),
                          
                          const SizedBox(height: 120), // Bottom padding for page indicators
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 