import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'main_scaffold.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/app_localizations.dart';

enum BreathingPhase {
  breatheIn,
  hold,
  breatheOut,
}

class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  BreathingPhase _currentPhase = BreathingPhase.breatheIn;
  
  // Duration constants
  static const int _breatheInDuration = 5; // seconds
  static const int _holdDuration = 2; // seconds
  static const int _breatheOutDuration = 5; // seconds
  static const int _totalCycleDuration = _breatheInDuration + _holdDuration + _breatheOutDuration;
  
  @override
  void initState() {
    super.initState();
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Breathing Exercise Screen');
    
    // Set system UI style to ensure proper display
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    
    // Initialize animation controller for the full cycle
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalCycleDuration),
    );
    
    // Create an animation that repeats continually
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    
    // Add a listener to update the breathing phase
    _controller.addListener(_updateBreathingPhase);
    
    // Start the animation
    _controller.repeat();
  }
  
  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Breathing Exercise Screen');
    
    final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppWebView,
        );
      } else {
        debugPrint('Could not launch help & info URL');
      }
    } catch (e) {
      debugPrint('Error launching help & info URL: $e');
    }
  }
  
  void _updateBreathingPhase() {
    // Calculate cycle progress from 0 to 1
    final cycleProgress = _controller.value;
    final newPhase = _getPhaseFromProgress(cycleProgress);
    
    if (_currentPhase != newPhase) {
      setState(() {
        _currentPhase = newPhase;
      });
    }
  }
  
  BreathingPhase _getPhaseFromProgress(double progress) {
    final breatheInEnd = _breatheInDuration / _totalCycleDuration;
    final holdEnd = (_breatheInDuration + _holdDuration) / _totalCycleDuration;
    
    if (progress < breatheInEnd) {
      return BreathingPhase.breatheIn;
    } else if (progress < holdEnd) {
      return BreathingPhase.hold;
    } else {
      return BreathingPhase.breatheOut;
    }
  }
  
  // Get the ball position based on the current animation value
  Offset _getBallPosition(double progress, Size pathSize) {
    final breatheInEnd = _breatheInDuration / _totalCycleDuration;
    final holdEnd = (_breatheInDuration + _holdDuration) / _totalCycleDuration;
    
    double normalizedProgress;
    
    if (progress < breatheInEnd) {
      // Breathe in phase (0 to breatheInEnd)
      normalizedProgress = progress / breatheInEnd; // 0 to 1
      // Ball should move from bottom left to top left
      return Offset(
        pathSize.width * 0.3 * normalizedProgress,  // 0 to width*0.3
        pathSize.height * (1 - normalizedProgress)  // height to 0
      );
    } else if (progress < holdEnd) {
      // Hold phase (breatheInEnd to holdEnd)
      // Ball should move horizontally along the flat top
      normalizedProgress = (progress - breatheInEnd) / (holdEnd - breatheInEnd); // 0 to 1
      return Offset(
        pathSize.width * (0.3 + normalizedProgress * 0.4),  // width*0.3 to width*0.7
        0  // top
      );
    } else {
      // Breathe out phase (holdEnd to 1)
      normalizedProgress = (progress - holdEnd) / (1 - holdEnd); // 0 to 1
      // Ball should move from top right to bottom right
      return Offset(
        pathSize.width * (0.7 + normalizedProgress * 0.3),  // width*0.7 to width
        pathSize.height * normalizedProgress  // 0 to height
      );
    }
  }
  
  String _getInstructionText(AppLocalizations l10n) {
    switch (_currentPhase) {
      case BreathingPhase.breatheIn:
        return l10n.translate('breathingExerciseScreen_instruction_breatheIn');
      case BreathingPhase.hold:
        return l10n.translate('breathingExerciseScreen_instruction_hold');
      case BreathingPhase.breatheOut:
        return l10n.translate('breathingExerciseScreen_instruction_breatheOut');
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A051D), // Dark purple background matching screenshots
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            l10n.translate('breathingExerciseScreen_appBarTitle'),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          actions: [
            // Help & Info icon
            IconButton(
              icon: const Icon(
                Icons.help_outline,
                color: Colors.white,
                size: 28,
              ),
              onPressed: _openMedicalInfo,
              tooltip: l10n.translate('pledgeScreen_tooltip_help'),
            ),
          ],
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Instruction text
                      Text(
                        _getInstructionText(l10n),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'ElzaRound',
                          height: 1.2,
                        ),
                      ),
                      
                      const SizedBox(height: 80),
                      
                      // Breathing animation
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          final size = MediaQuery.of(context).size;
                          final pathWidth = size.width * 0.8;
                          final pathHeight = size.height * 0.3;
                          final pathSize = Size(pathWidth, pathHeight);
                          
                          final ballPosition = _getBallPosition(_controller.value, pathSize);
                          
                          return SizedBox(
                            height: pathHeight,
                            width: pathWidth,
                            child: CustomPaint(
                              painter: TrianglePathPainter(
                                ballPosition: ballPosition,
                                intensityText: l10n.translate('breathingExerciseScreen_painter_intensity'),
                                timeText: l10n.translate('breathingExerciseScreen_painter_time'),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20.0, 
                  bottom: 40.0
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        TopToBottomPageRoute(
                          child: const MainScaffold(initialIndex: 0),
                          settings: const RouteSettings(name: '/home'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2F5C), // Dark blue
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      l10n.translate('breathingExerciseScreen_button_finish'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'ElzaRound',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrianglePathPainter extends CustomPainter {
  final Offset ballPosition;
  final String intensityText;
  final String timeText;
  
  TrianglePathPainter({
    required this.ballPosition, 
    required this.intensityText,
    required this.timeText,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF007AFF) // Blue line color matching screenshots
      ..strokeWidth = 7 // Increased from 4 to 7 for a thicker line
      ..style = PaintingStyle.stroke;
    
    // Draw the up-flat-down path instead of triangle
    final path = Path();
    
    // Start from bottom left
    path.moveTo(0, size.height);
    
    // Line going up
    path.lineTo(size.width * 0.3, 0);
    
    // Flat line across the top
    path.lineTo(size.width * 0.7, 0);
    
    // Line going down
    path.lineTo(size.width, size.height);
    
    canvas.drawPath(path, paint);
    
    // Draw the yellow ball
    final ballPaint = Paint()
      ..color = const Color(0xFFFFD700) // Bright yellow matching screenshots
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(ballPosition, 25, ballPaint);
  }
  
  @override
  bool shouldRepaint(covariant TrianglePathPainter oldDelegate) {
    return oldDelegate.ballPosition != ballPosition;
  }
} 