import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:stoppr/features/onboarding/presentation/screens/give_us_ratings_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/referral_code_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/potential_rating_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/questionnaire_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/symptoms_screen.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

class SlideRightRoute extends PageRouteBuilder {
  final Widget page;
  SlideRightRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(-1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

class WeeksProgressionScreen extends StatefulWidget {
  const WeeksProgressionScreen({super.key});

  @override
  State<WeeksProgressionScreen> createState() => _WeeksProgressionScreenState();
}

class _WeeksProgressionScreenState extends State<WeeksProgressionScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  late AnimationController _chartAnimationController;
  late Animation<double> _chartAnimation;
  final OnboardingProgressService _progressService = OnboardingProgressService();

  // Define progression data for each step
  final List<ProgressionStep> _progressionSteps = [
    ProgressionStep(
      weekTitle: 'weeksProgression_week1_title',
      description: 'weeksProgression_week1_description',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 7)),
      backgroundColor: const Color(0xFFE53E3E), // Red
      values: [0.35, 0.45, 0.40, 0.42, 0.36, 0.54], // More extended values for week 1
    ),
    ProgressionStep(
      weekTitle: 'weeksProgression_week5_title',
      description: 'weeksProgression_week5_description',
      startDate: DateTime.now().add(const Duration(days: 28)),
      endDate: DateTime.now().add(const Duration(days: 35)),
      backgroundColor: const Color(0xFFED8936), // Orange
      values: [0.6, 0.65, 0.58, 0.62, 0.55, 0.68], // Medium values for week 5
    ),
    ProgressionStep(
      weekTitle: 'weeksProgression_week10_title',
      description: 'weeksProgression_week10_description',
      startDate: DateTime.now().add(const Duration(days: 63)),
      endDate: DateTime.now().add(const Duration(days: 70)),
      backgroundColor: const Color(0xFF6B46C1), // Purple 
      values: [0.82, 0.78, 0.85, 0.75, 0.80, 0.83], // 70-85% values for week 10
    ),
    ProgressionStep(
      weekTitle: 'weeksProgression_week13_title',
      description: 'weeksProgression_week13_description',
      startDate: DateTime.now().add(const Duration(days: 84)),
      endDate: DateTime.now().add(const Duration(days: 91)),
      backgroundColor: const Color(0xFF38A169), // Green
      values: [0.97, 0.98, 0.96, 0.96, 0.97, 0.97], // Maxed out values for week 13 (90 days)
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    // Force white status bar icons
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));
    
    // Save current screen state
    _saveCurrentScreen();

    // Initialize animation controller
    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _chartAnimation = CurvedAnimation(
      parent: _chartAnimationController,
      curve: Curves.easeInOutCubic,
    );

    // Start initial animation
    _chartAnimationController.forward();

    // Mixpanel
    MixpanelService.trackEvent('Onboarding Weeks Progression Screen: Page Viewed');
  }

  @override
  void dispose() {
    _chartAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.weeksProgressionScreen);
  }

  void _nextStep() {
    // Track button tap event
    MixpanelService.trackEvent('Onboarding Weeks Progression Screen: Button Tap', properties: {
      'current_step': _currentStep + 1,
      'week_title': _progressionSteps[_currentStep].weekTitle,
      'is_final_step': _currentStep == _progressionSteps.length - 1,
    });

    if (_currentStep < _progressionSteps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
      _chartAnimationController.reset();
      _chartAnimationController.forward();
    } else {
      // Navigate to Questionnaire Screen (Question 1)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => QuestionnaireScreen(
            onComplete: () {
              debugPrint('🔍 QuestionnaireScreen completed');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainScaffold(
                    initialIndex: 0,
                  ),
                ),
                (route) => false,
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _progressionSteps[_currentStep].backgroundColor,
            const Color(0xFF09050C),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 25,
          automaticallyImplyLeading: false,
          title: const Text(''),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header with week title and description
              Transform.translate(
                offset: const Offset(-8, 0),
                child: Padding(
                  padding: const EdgeInsets.only(left: 24, right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Week title
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.spa,
                              color: _progressionSteps[_currentStep].backgroundColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              l10n.translate(_progressionSteps[_currentStep].weekTitle),
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Date range
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${DateFormat('MMM d').format(_progressionSteps[_currentStep].startDate)} to ${DateFormat('MMM d').format(_progressionSteps[_currentStep].endDate)}',
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Description
                      Text(
                        l10n.translate(_progressionSteps[_currentStep].description),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Hexagonal chart
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentStep = index;
                      });
                      _chartAnimationController.reset();
                      _chartAnimationController.forward();
                    },
                    itemCount: _progressionSteps.length,
                    itemBuilder: (context, index) {
                      return Center(
                        child: _HexagonalChart(
                          values: _progressionSteps[index].values,
                          animation: _chartAnimation,
                          color: _progressionSteps[index].backgroundColor,
                          l10n: l10n,
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              // Bottom button
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C171F),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.11),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                height: 120,
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 10,
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: GestureDetector(
                      onTap: _nextStep,
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.translate('weeksProgression_continueButton'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            color: Color(0xFF231132),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

class ProgressionStep {
  final String weekTitle;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final Color backgroundColor;
  final List<double> values; // 6 values for the 6 domains

  ProgressionStep({
    required this.weekTitle,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.backgroundColor,
    required this.values,
  });
}

class _HexagonalChart extends StatelessWidget {
  final List<double> values;
  final Animation<double> animation;
  final Color color;
  final AppLocalizations l10n;

  const _HexagonalChart({
    required this.values,
    required this.animation,
    required this.color,
    required this.l10n,
  });

  static const List<String> domainKeys = [
    'weeksProgression_domain_overall',
    'weeksProgression_domain_focus',
    'weeksProgression_domain_confidence',
    'weeksProgression_domain_energy',
    'weeksProgression_domain_selfControl',
    'weeksProgression_domain_mood',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: 350,
          height: 350,
          child: CustomPaint(
            painter: _HexagonChartPainter(
              values: values.map((v) => v * animation.value).toList(),
              color: color,
              labels: domainKeys.map((key) => l10n.translate(key)).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _HexagonChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final List<String> labels;

  _HexagonChartPainter({
    required this.values,
    required this.color,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 50;
    
    // Draw background hexagon grid
    _drawHexagonGrid(canvas, center, radius);
    
    // Draw value hexagon
    _drawValueHexagon(canvas, center, radius);
    
    // Draw labels
    _drawLabels(canvas, center, radius + 35, size);
  }

  void _drawHexagonGrid(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw 3 concentric hexagons
    for (int i = 1; i <= 3; i++) {
      final currentRadius = radius * (i / 3);
      _drawHexagon(canvas, center, currentRadius, paint);
    }

    // Draw lines from center to vertices
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi * 2 / 6) - math.pi / 2;
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, endPoint, paint);
    }
  }

  void _drawValueHexagon(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    
    for (int i = 0; i < values.length; i++) {
      final angle = (i * math.pi * 2 / 6) - math.pi / 2;
      final valueRadius = radius * values[i];
      final point = Offset(
        center.dx + valueRadius * math.cos(angle),
        center.dy + valueRadius * math.sin(angle),
      );
      
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi * 2 / 6) - math.pi / 2;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }

  void _drawLabels(Canvas canvas, Offset center, double radius, Size size) {
    for (int i = 0; i < labels.length; i++) {
      final angle = (i * math.pi * 2 / 6) - math.pi / 2;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      // Use smaller font size for longer labels to prevent overflow
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'ElzaRound',
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
      );
      textPainter.layout(maxWidth: size.width * 0.25);
      
      // Adjust text position based on angle to prevent overlap and clipping
      Offset textOffset = point;
      if (angle > math.pi / 4 && angle < 3 * math.pi / 4) {
        // Bottom labels
        textOffset = Offset(
          point.dx - textPainter.width / 2,
          point.dy + 8,
        );
        // Ensure doesn't go beyond bottom edge
        if (textOffset.dy + textPainter.height > size.height - 5) {
          textOffset = Offset(
            textOffset.dx,
            size.height - textPainter.height - 5,
          );
        }
      } else if (angle > -3 * math.pi / 4 && angle < -math.pi / 4) {
        // Top labels
        textOffset = Offset(
          point.dx - textPainter.width / 2,
          point.dy - textPainter.height - 8,
        );
        // Ensure doesn't go beyond top edge
        if (textOffset.dy < 5) {
          textOffset = Offset(textOffset.dx, 5);
        }
      } else if (angle >= -math.pi / 4 && angle <= math.pi / 4) {
        // Right labels - ensure they don't get clipped
        double rightOffset = point.dx + 15;
        // Prevent clipping by ensuring text doesn't go beyond right edge
        rightOffset = math.min(rightOffset, size.width - textPainter.width - 5);
        textOffset = Offset(rightOffset, point.dy - textPainter.height / 2);
        // Ensure doesn't go beyond vertical edges
        if (textOffset.dy < 5) {
          textOffset = Offset(textOffset.dx, 5);
        } else if (textOffset.dy + textPainter.height > size.height - 5) {
          textOffset = Offset(
            textOffset.dx,
            size.height - textPainter.height - 5,
          );
        }
      } else {
        // Left labels - ensure they don't get clipped
        double leftOffset = point.dx - textPainter.width - 15;
        // Prevent clipping by ensuring minimum distance from left edge
        leftOffset = math.max(leftOffset, 5);
        textOffset = Offset(leftOffset, point.dy - textPainter.height / 2);
        // Ensure doesn't go beyond vertical edges
        if (textOffset.dy < 5) {
          textOffset = Offset(textOffset.dx, 5);
        } else if (textOffset.dy + textPainter.height > size.height - 5) {
          textOffset = Offset(
            textOffset.dx,
            size.height - textPainter.height - 5,
          );
        }
      }
      
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 