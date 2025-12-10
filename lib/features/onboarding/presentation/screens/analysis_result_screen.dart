import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'symptoms_screen.dart';
import 'sugar_drug_screen.dart';
import 'onboarding_sugar_painpoints_page_view.dart';
import 'current_6_blocks_rating_screen.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class AnalysisResultScreen extends StatefulWidget {
  final VoidCallback? onCheckSymptoms;
  
  const AnalysisResultScreen({
    super.key,
    this.onCheckSymptoms,
  });

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final OnboardingProgressService _progressService = OnboardingProgressService();
  
  @override
  void initState() {
    super.initState();
    
    // Set status bar to dark icons for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600), // Slower animation for better visual impact
    );
    
    // Create animation with a bounce effect at the end
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    // Mixpanel
    MixpanelService.trackPageView('Onboarding Analysis Result Screen');
    
    // Start the animation after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _animationController.forward();
    });
    
    // Save current screen state
    _saveCurrentScreen();
    

  }
  
  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.analysisResultScreen);
  }
  
  @override
  void dispose() {
    // Restore status bar for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    _animationController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white background
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            color: Colors.white, // Clean white background matching app branding
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              // Using LayoutBuilder to be responsive to available height
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate if we're on a small screen
                  final isSmallScreen = constraints.maxHeight < 600;
                  
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Title with checkmark - centered now
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.translate('analysisResult_title'),
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound',
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A1A1A), // Dark text for white background
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SvgPicture.asset(
                                    'assets/images/svg/green-checkmark.svg',
                                    width: 20,
                                    height: 20,
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: isSmallScreen ? 2 : 4),
                              
                              // Subtitle - centered with white color
                              Center(
                                child:                                   Text(
                                  AppLocalizations.of(context)!.translate('analysisResult_subtitle'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF666666), // Dark gray for white background
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              
                              SizedBox(height: isSmallScreen ? 16 : 24),
                              
                              // Chart content without background container
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.translate('analysisResult_dependenceIndication'),
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A), // Dark text for white background
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  // Chart comparison with animations
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Chart bars
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          // Your score bar - animate from 0 to full height
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Fixed height container to prevent layout shifts
                                              SizedBox(
                                                height: isSmallScreen ? 200 : 250,
                                                child: ClipRect(
                                                  child: AnimatedBuilder(
                                                    animation: _animation,
                                                    builder: (context, child) {
                                                      return Align(
                                                        alignment: Alignment.bottomCenter,
                                                        child: Container(
                                                          width: 64,
                                                          height: (isSmallScreen ? 200 : 250) * _animation.value,
                                                          decoration: const BoxDecoration(
                                                            gradient: LinearGradient(
                                                              begin: Alignment.bottomCenter,
                                                              end: Alignment.topCenter,
                                                              colors: [
                                                                Color(0xFFFF4583),
                                                                Color(0xFFEA4335),
                                                              ],
                                                            ),
                                                            borderRadius: BorderRadius.vertical(
                                                              top: Radius.circular(12),
                                                              bottom: Radius.circular(12),
                                                            ),
                                                          ),
                                                                                                                  child: const Padding(
                                                            padding: EdgeInsets.only(top: 16.0),
                                                            child: Align(
                                                              alignment: Alignment.topCenter,
                                                              child: Text(
                                                                '73%',
                                                                style: TextStyle(
                                                                  fontFamily: 'ElzaRound',
                                                                  fontSize: 18,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                AppLocalizations.of(context)!.translate('analysisResult_yourScore'),
                                                style: const TextStyle(
                                                  fontFamily: 'ElzaRound',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF1A1A1A), // Dark text for white background
                                                ),
                                              ),
                                            ],
                                          ),
                                          
                                          const SizedBox(width: 24),
                                          
                                          // Average score bar - smaller and animated
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Fixed height container to prevent layout shifts
                                              SizedBox(
                                                height: isSmallScreen ? 200 : 250,
                                                child: ClipRect(
                                                  child: AnimatedBuilder(
                                                    animation: _animation,
                                                    builder: (context, child) {
                                                      return Align(
                                                        alignment: Alignment.bottomCenter,
                                                        child: Container(
                                                          width: 64,
                                                          height: (isSmallScreen ? 88 : 110) * _animation.value,
                                                          decoration: const BoxDecoration(
                                                            gradient: LinearGradient(
                                                              begin: Alignment.bottomCenter,
                                                              end: Alignment.topCenter,
                                                              colors: [
                                                                Color(0xFF1FA28C),
                                                                Color(0xFF309967),
                                                              ],
                                                            ),
                                                            borderRadius: BorderRadius.vertical(
                                                              top: Radius.circular(12),
                                                              bottom: Radius.circular(12),
                                                            ),
                                                          ),
                                                                                                                  child: const Padding(
                                                            padding: EdgeInsets.only(top: 16.0),
                                                            child: Align(
                                                              alignment: Alignment.topCenter,
                                                              child: Text(
                                                                '32%',
                                                                style: TextStyle(
                                                                  fontFamily: 'ElzaRound',
                                                                  fontSize: 18,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                AppLocalizations.of(context)!.translate('analysisResult_averageScore'),
                                                style: const TextStyle(
                                                  fontFamily: 'ElzaRound',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF1A1A1A), // Dark text for white background
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      // New overlay: dashed line drawn ABOVE the bars
                                      Positioned(
                                        top: (isSmallScreen ? 200 : 250) * 0.35,
                                        left: 40,
                                        right: 40,
                                        child: SizedBox(
                                          height: 3,
                                          child: CustomPaint(
                                            painter: DashedLinePainter(
                                              color: const Color(0xFF666666), // Dark gray for white background
                                              strokeWidth: 3.0,
                                              dashLength: 8.0,
                                              spaceLength: 4.0,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // New overlay: safety line text above the dashed line
                                      Positioned(
                                        top: (isSmallScreen ? 200 : 250) * 0.35 - 45,
                                        right: 40,
                                        child:                                           Text(
                                          AppLocalizations.of(context)!.translate('analysisResult_safetyLine'),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontFamily: 'ElzaRound',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1A1A1A), // Dark text for white background
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: isSmallScreen ? 20 : 28),
                              
                              // Percentage higher text with chart down emoji - now centered
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '41%',
                                      style: TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF5555),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppLocalizations.of(context)!.translate('analysisResult_higherDependence'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A1A), // Dark text for white background
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      '📉',
                                      style: TextStyle(
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Reduced spacing before disclaimer
                              SizedBox(height: isSmallScreen ? 12 : 20),
                              
                              // Disclaimer text - now centered and with updated style
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Center(
                                  child: Text(
                                    AppLocalizations.of(context)!.translate('analysisResult_disclaimer'),
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF666666), // Dark gray for white background
                                      height: 1.5,
                                      letterSpacing: 0.1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              
                              // Reduced space after disclaimer to fit content better
                              SizedBox(height: isSmallScreen ? 20 : 40),
                            ],
                          ),
                        ),
                      ),
                      
                      // Reduced spacing before button
                      const SizedBox(height: 8),
                      
                      // Check symptoms button - now orange theme
                      GestureDetector(
                        onTap: () {
                          debugPrint('🔍 AnalysisResultScreen: Navigating to SymptomsScreen');
                          
                          // Track button tap
                          MixpanelService.trackEvent('Onboarding Analysis Result Screen: Button Tap', properties: {
                            'button': 'check_symptoms',
                            'destination': 'symptoms_screen',
                          });
                          
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SymptomsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFed3272), // Strong pink/magenta
                                Color(0xFFfd5d32), // Vivid orange
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)!.translate('analysisResult_checkSymptomsButton'),
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                fontSize: 19, // Increased from 15 to 19
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Only keep a minimal bottom spacing
                      const SizedBox(height: 8),
                    ],
                  );
                }
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double spaceLength;

  DashedLinePainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.dashLength = 5.0,
    this.spaceLength = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double currentX = 0;
    while (currentX < size.width) {
      canvas.drawLine(
        Offset(currentX, size.height / 2),
        Offset(currentX + dashLength, size.height / 2),
        paint,
      );
      currentX += dashLength + spaceLength;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
} 