import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'dart:ui' as ui;

class SugarProgressBreakScreen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  
  const SugarProgressBreakScreen({
    super.key,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<SugarProgressBreakScreen> createState() => _SugarProgressBreakScreenState();
}

class _SugarProgressBreakScreenState extends State<SugarProgressBreakScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _backgroundController;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));
    
    // Start animation after brief delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _animationController.forward();
      }
    });
    
    // Track page view
    MixpanelService.trackPageView('Onboarding Sugar Progress Break Screen');
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white background
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white, // Clean white background
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 10),
                                  // Title
                                  Text(
                                    l10n.translate('sugarProgressBreak_title'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound', // Fixed font name
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A), // Dark text for white background
                                      height: 1.2,
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 25),
                                  
                                  // Graph title
                                  Text(
                                    l10n.translate('sugarProgressBreak_graphTitle'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF666666), // Gray text for subtitle
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  // Progress graph
                                  Container(
                                    height: 180,
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA), // Light gray background for graph
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE0E0E0), // Light gray border
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: CustomPaint(
                                      painter: ProgressGraphPainter(
                                        progress: _progressAnimation.value,
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 15),
                                
                                // Timeline labels
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Text(
                                      l10n.translate('sugarProgressBreak_3days'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF666666), // Gray text
                                      ),
                                    ),
                                    Text(
                                      l10n.translate('sugarProgressBreak_7days'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF666666), // Gray text
                                      ),
                                    ),
                                    Text(
                                      l10n.translate('sugarProgressBreak_30days'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF666666), // Gray text
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Description
                                Text(
                                  l10n.translate('sugarProgressBreak_description'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF666666), // Gray text
                                    height: 1.4,
                                  ),
                                ),
                                
                                const SizedBox(height: 40),
                                
                                // Continue button with STOPPR branding
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(0xFFed3272), // Strong pink/magenta
                                        Color(0xFFfd5d32), // Vivid orange
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      MixpanelService.trackButtonTap(
                                        'Continue',
                                        screenName: 'SugarProgressBreakScreen',
                                      );
                                      widget.onNext();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      l10n.translate('sugarProgressBreak_continueButton'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressGraphPainter extends CustomPainter {
  final double progress;
  
  ProgressGraphPainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFed3272) // Brand pink
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final fillPaint = Paint()
      ..color = const Color(0xFFed3272).withOpacity(0.2) // Brand pink with opacity
      ..style = PaintingStyle.fill;
    
    final gridPaint = Paint()
      ..color = const Color(0xFFE0E0E0) // Light gray for visibility on white background
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    // Define curve points first to align grid lines with milestones
    final points = [
      Offset(0, size.height * 0.8), // Start low (high cravings)
      Offset(size.width * 0.25, size.height * 0.7), // 3 days - slight improvement
      Offset(size.width * 0.5, size.height * 0.4), // 7 days - significant improvement
      Offset(size.width * 1.0, size.height * 0.1), // 30 days - freedom!
    ];
    
    // Draw dotted grid lines aligned with milestone points
    _drawDottedLine(canvas, Offset(0, points[1].dy), Offset(size.width, points[1].dy), gridPaint); // 3 days level
    _drawDottedLine(canvas, Offset(0, points[2].dy), Offset(size.width, points[2].dy), gridPaint); // 7 days level
    _drawDottedLine(canvas, Offset(0, points[3].dy), Offset(size.width, points[3].dy), gridPaint); // 30 days level
    
    // Create path for the curve
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    
    // Draw smooth curve through points
    for (int i = 0; i < points.length - 1; i++) {
      final currentPoint = points[i];
      final nextPoint = points[i + 1];
      final controlPoint1 = Offset(
        currentPoint.dx + (nextPoint.dx - currentPoint.dx) * 0.3,
        currentPoint.dy,
      );
      final controlPoint2 = Offset(
        currentPoint.dx + (nextPoint.dx - currentPoint.dx) * 0.7,
        nextPoint.dy,
      );
      
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        nextPoint.dx,
        nextPoint.dy,
      );
    }
    
    // Create animated path
    final animatedPath = Path();
    final pathMetrics = path.computeMetrics();
    
    for (final metric in pathMetrics) {
      final extractedPath = metric.extractPath(0, metric.length * progress);
      animatedPath.addPath(extractedPath, Offset.zero);
    }
    
    // Draw fill area under curve
    if (progress > 0) {
      final fillPath = Path.from(animatedPath);
      fillPath.lineTo(size.width * progress, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }
    
    // Draw the curve
    canvas.drawPath(animatedPath, paint);
    
    // Draw milestone dots (skip the last one - it will be replaced by trophy)
    final dotPaint = Paint()
      ..color = const Color(0xFFed3272) // Brand pink
      ..style = PaintingStyle.fill;
    
    final milestones = [0.25, 0.5]; // Only 3 days and 7 days, skip 30 days
    
    for (int i = 0; i < milestones.length; i++) {
      if (progress >= milestones[i]) {
        final point = points[i + 1];
        canvas.drawCircle(point, 6, dotPaint);
        canvas.drawCircle(point, 6, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
    }
    
    // Draw trophy at the end position (replacing the last milestone circle)
    if (progress >= 0.95) {
      final trophyPoint = points.last;
      final trophyPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.fill;
      
      // Draw yellow circle at the curve endpoint (same size as milestone circles)
      canvas.drawCircle(trophyPoint, 6, trophyPaint);
      canvas.drawCircle(trophyPoint, 6, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }
  
  // Helper method to draw dotted lines
  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashWidth = 4;
    const double dashSpace = 4;
    double distance = (end - start).distance;
    double currentDistance = 0;
    
    while (currentDistance < distance) {
      double dashEnd = currentDistance + dashWidth;
      if (dashEnd > distance) dashEnd = distance;
      
      Offset dashStart = Offset.lerp(start, end, currentDistance / distance)!;
      Offset dashEndPoint = Offset.lerp(start, end, dashEnd / distance)!;
      
      canvas.drawLine(dashStart, dashEndPoint, paint);
      currentDistance += dashWidth + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(ProgressGraphPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}