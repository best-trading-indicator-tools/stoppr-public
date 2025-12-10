// Summary: Center the calculating title with horizontal padding and safe
// wrapping to prevent overflow in long localizations.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/onboarding/presentation/screens/analysis_result_screen.dart';

class CalculatingScreen extends StatefulWidget {
  const CalculatingScreen({
    super.key, 
  });

  @override
  State<CalculatingScreen> createState() => _CalculatingScreenState();
}

class _CalculatingScreenState extends State<CalculatingScreen> {
  double _progressValue = 0.03; // Start at 3%
  String _statusText = 'Understanding responses';
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    
    // Set status bar to dark icons for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    
    // Start the animation after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _startProgressAnimation();
    });
  }
  
  void _startProgressAnimation() {
    // Animation should take about 6 seconds (16.7% per second)
    _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_progressValue >= 1.0) {
        timer.cancel();
        // Delay slightly before moving to next screen
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const AnalysisResultScreen(),
              ),
            );
          }
        });
        return;
      }
      
      if (mounted) {
        setState(() {
          // Increase by 1% every 60ms (smoother and faster)
          _progressValue += 0.01;
          
          // Update the status text based on progress
          if (_progressValue < 0.33) {
            _statusText = AppLocalizations.of(context)!.translate('calculating_understanding_responses');
          } else if (_progressValue < 0.66) {
            _statusText = AppLocalizations.of(context)!.translate('calculating_learning_relapse_triggers');
          } else {
            _statusText = AppLocalizations.of(context)!.translate('calculating_finalizing');
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    // Restore status bar for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    _timer?.cancel();
    super.dispose();
  }

  // Get the appropriate color gradient based on progress
  List<Color> _getGradientColors() {
    // Use the brand pink-orange gradient
    return [
      const Color(0xFFed3272), // Strong pink/magenta
      const Color(0xFFfd5d32), // Vivid orange
    ];
  }
  
  // Format the progress as percentage
  String get _percentageText {
    return '${(_progressValue * 100).toInt()}%';
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Custom circular progress indicator
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CustomPaint(
                      painter: CircularProgressPainter(
                        progress: _progressValue,
                        progressColor: _getGradientColors(),
                        backgroundColor: const Color(0xFFE0E0E0), // Light gray for white background
                        strokeWidth: 15,
                      ),
                      child: Center(
                        child: Text(
                          _percentageText,
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A), // Dark text for white background
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // "Calculating" title (centered with horizontal padding)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      AppLocalizations.of(context)!
                          .translate('calculating_title'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A), // Dark text for white background
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Dynamic status text
                  Text(
                    _statusText,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666), // Dark gray for white background
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Programs Generated section with laurel icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Left laurel icon
                      Image.asset(
                        'assets/images/onboarding/left_laurel_icon.png',
                        width: 64,
                        height: 64,
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Programs Generated text
                      Column(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.translate('calculating_programs_generated'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF666666), // Dark gray for white background
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context)!.translate('calculating_programs_count'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A), // Dark text for white background
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Right laurel icon
                      Image.asset(
                        'assets/images/onboarding/right_laurel_icon.png',
                        width: 64,
                        height: 64,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for smoother gradient circle progress
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final List<Color> progressColor;
  final Color backgroundColor;
  final double strokeWidth;
  
  CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    this.strokeWidth = 10,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;
    const startAngle = -math.pi / 2; // Start from top
    
    // Paint for background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    
    // Draw background circle
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Paint for progress arc with gradient
    final progressPaint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Create gradient for progress - using rotated linear gradient for better visual effect
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    // Calculate gradient rotation to match the current progress position
    final endAngle = startAngle + (2 * math.pi * progress);
    final gradientAngle = startAngle + (endAngle - startAngle) / 2;
    
    // Calculate gradient direction based on angle
    final gradientStart = Offset(
      center.dx + math.cos(startAngle) * radius,
      center.dy + math.sin(startAngle) * radius,
    );
    
    final gradientEnd = Offset(
      center.dx + math.cos(endAngle) * radius,
      center.dy + math.sin(endAngle) * radius,
    );
    
    // Apply gradient to progress paint - linear gradient along the arc
    progressPaint.shader = LinearGradient(
      colors: progressColor,
      begin: Alignment(
        math.cos(startAngle), 
        math.sin(startAngle)
      ),
      end: Alignment(
        math.cos(gradientAngle + math.pi/2), 
        math.sin(gradientAngle + math.pi/2)
      ),
    ).createShader(rect);
    
    // Calculate sweep angle based on progress
    final sweepAngle = 2 * math.pi * progress;
    
    // Draw progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }
  
  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.progressColor != progressColor ||
           oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.strokeWidth != strokeWidth;
  }
} 