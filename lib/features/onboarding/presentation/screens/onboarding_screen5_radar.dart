import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/services/onboarding_audio_service.dart';
import 'package:stoppr/core/auth/cubit/auth_cubit.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_screen3.dart';
import 'package:stoppr/features/auth/presentation/screens/email_auth_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/weeks_progression_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/questionnaire_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:stoppr/features/onboarding/presentation/screens/widgets/onboarding_sound_toggle.dart';
import 'package:stoppr/features/onboarding/presentation/screens/widgets/onboarding_language_selector.dart';

// Onboarding screen showing 0% radar progress with brand styling
class OnboardingScreen5Radar extends StatefulWidget {
  final VoidCallback? onNext;
  
  const OnboardingScreen5Radar({
    super.key,
    this.onNext,
  });

  @override
  State<OnboardingScreen5Radar> createState() => 
      _OnboardingScreen5RadarState();
}

class _OnboardingScreen5RadarState extends State<OnboardingScreen5Radar>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;
  Animation<Offset>? _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Track page view
    MixpanelService.trackPageView('Onboarding Radar Progress Screen');
    
    // Auto-start onboarding music by default (respects saved pref; default ON)
    OnboardingAudioService.instance
        .startWithAssetIfEnabled('sounds/onboarding_528HZ.mp3')
        .then((_) {
      if (mounted) setState(() {});
    });
    
    // Force status bar icons to dark mode for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    
    // Initialize radar animation controller with longer duration
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    // Fade in animation (0 to 1)
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _radarController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    // Scale animation (0.8 to 1.0 for subtle bounce)
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _radarController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );
    
    // Slide up animation
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _radarController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    
    // Start animation after a brief delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _radarController.forward();
      }
    });
  }
  
  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  // Ensure audio stops on Flutter hot reload (debug-only lifecycle hook)
  @override
  void reassemble() {
    super.reassemble();
    OnboardingAudioService.instance.stop();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF1A1A1A),
              size: 24,
            ),
            onPressed: () {
              debugPrint("🔙 Back button pressed - navigating back to OnboardingScreen3");
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => OnboardingScreen3(
                    onContinueWithApple: () {
                      debugPrint('🍎 Apple sign-in from OnboardingScreen3');
                      final authCubit = context.read<AuthCubit>();
                      authCubit.signInWithApple();
                    },
                    onContinueWithGoogle: () {
                      debugPrint('🔍 Google sign-in from OnboardingScreen3');
                      context.read<AuthCubit>().signInWithGoogle();
                    },
                    onContinueWithEmail: () {
                      debugPrint('📧 Email sign-in from OnboardingScreen3');
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const EmailAuthScreen(
                            initialSignUpMode: true,
                          ),
                        ),
                      );
                    },
                    onSkip: () {
                      debugPrint('⏭️ Skip from OnboardingScreen3');
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => OnboardingScreen5Radar(
                            onNext: widget.onNext,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          actions: [
            const OnboardingSoundToggle(
              diameter: 40,
              eventName: 
                  'Onboarding Radar Progress Screen: Sound Button Tap',
            ),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: const OnboardingLanguageSelector(),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
                // "Welcome to your Journey!" text
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    top: 16.0,
                  ),
                  child: Text(
                    l10n.translate('onboarding4_goodNews'),
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Subtext
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    l10n.translate('onboarding4_progressTracked'),
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Radar chart at 0% with animations - matching weeks_progression_screen.dart size and position
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _radarController,
                        builder: (context, child) {
                          if (_fadeAnimation == null || 
                              _scaleAnimation == null || 
                              _slideAnimation == null) {
                            return child!;
                          }
                          return FadeTransition(
                            opacity: _fadeAnimation!,
                            child: SlideTransition(
                              position: _slideAnimation!,
                              child: ScaleTransition(
                                scale: _scaleAnimation!,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 350,
                          height: 350,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(350, 350),
                                painter: _RadarChartPainter(
                                  values: List<double>.filled(6, 0.0),
                                  color: const Color(0xFFE53E3E),
                                  labels: _radarDomainKeys
                                      .map((k) => l10n.translate(k))
                                      .toList(),
                                  fillFactor: 1.0,
                                ),
                              ),
                              const Text(
                                '0%',
                                style: TextStyle(
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 28,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // "Your journey is just beginning..." text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    l10n.translate('onboarding4_buildAppAroundYou'),
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Next button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFed3272),
                          Color(0xFFfd5d32),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        
                        MixpanelService.trackButtonTap(
                          'Next',
                          screenName: 'Onboarding Radar Progress Screen',
                        );
                        
                        debugPrint('🔍 Next button pressed');
                        
                        if (widget.onNext != null) {
                          try {
                            widget.onNext!();
                            return;
                          } catch (e) {
                            debugPrint('⚠️ Primary navigation failed: $e');
                          }
                        }
                        
                        try {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const WeeksProgressionScreen(),
                            ),
                            (route) => false,
                          );
                        } catch (e) {
                          debugPrint('❌ Navigation failed: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        l10n.translate('onboarding4_nextButton'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Bottom safe area padding
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }
}

// Radar domain keys (same as home_rewire_brain.dart)
const List<String> _radarDomainKeys = [
  'weeksProgression_domain_overall',
  'weeksProgression_domain_focus',
  'weeksProgression_domain_confidence',
  'weeksProgression_domain_energy',
  'weeksProgression_domain_selfControl',
  'weeksProgression_domain_mood',
];

// Radar chart painter (simplified from home_rewire_brain.dart)
class _RadarChartPainter extends CustomPainter {
  final List<double> values; // 0..1 for six axes
  final Color color;
  final List<String> labels;
  final double fillFactor; // 0..1 expansion factor for animation

  _RadarChartPainter({
    required this.values,
    required this.color,
    required this.labels,
    this.fillFactor = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 50;

    _drawGrid(canvas, center, radius);
    _drawValues(canvas, center, radius);
    _drawLabels(canvas, center, radius + 35, size);
  }

  void _drawGrid(Canvas canvas, Offset center, double radius) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1A1A1A).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final r = radius * (i / 3);
      _drawPolygon(canvas, center, r, gridPaint);
    }

    for (int i = 0; i < 6; i++) {
      final angle = (i * 2 * pi / 6) - pi / 2;
      final end = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, end, gridPaint);
    }
  }

  void _drawValues(Canvas canvas, Offset center, double radius) {
    final fill = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 2 * pi / 6) - pi / 2;
      final r = radius * 
          (values[i].clamp(0.0, 1.0) * fillFactor).clamp(0.0, 1.0);
      final p = Offset(
        center.dx + r * cos(angle),
        center.dy + r * sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawLabels(Canvas canvas, Offset center, double radius, Size size) {
    for (int i = 0; i < 6; i++) {
      final angle = (i * 2 * pi / 6) - pi / 2;
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      
      // Use smaller font size for longer labels to prevent overflow
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 12,
            fontWeight: FontWeight.w500,
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
      if (angle > pi / 4 && angle < 3 * pi / 4) {
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
      } else if (angle > -3 * pi / 4 && angle < -pi / 4) {
        // Top labels
        textOffset = Offset(
          point.dx - textPainter.width / 2,
          point.dy - textPainter.height - 8,
        );
        // Ensure doesn't go beyond top edge
        if (textOffset.dy < 5) {
          textOffset = Offset(textOffset.dx, 5);
        }
      } else if (angle >= -pi / 4 && angle <= pi / 4) {
        // Right labels - ensure they don't get clipped
        double rightOffset = point.dx + 15;
        // Prevent clipping by ensuring text doesn't go beyond right edge
        rightOffset = min(rightOffset, size.width - textPainter.width - 5);
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
        leftOffset = max(leftOffset, 5);
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

  void _drawPolygon(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 2 * pi / 6) - pi / 2;
      final p = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

