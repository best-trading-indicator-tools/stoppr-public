import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:stoppr/features/onboarding/presentation/screens/give_us_ratings_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/pre_paywall.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import '../../../../core/utils/text_sanitizer.dart';

class OnboardingCard2Screen extends StatefulWidget {
  const OnboardingCard2Screen({super.key});

  @override
  State<OnboardingCard2Screen> createState() => _OnboardingCard2ScreenState();
}

class _OnboardingCard2ScreenState extends State<OnboardingCard2Screen> with TickerProviderStateMixin {
  final UserRepository _userRepository = UserRepository();
  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late AnimationController _fireworksController;
  late Animation<Offset> _cardAnimation;
  String? _firstName;
  bool _isLoading = true;
  late String _currentDate;
  bool _dependenciesInitialized = false; // Flag to track if dependencies are initialized
  
  // Current text display state
  int _currentTextIndex = 0;
  bool _isTransitioning = false;
  double _currentTextOpacity = 1.0;
  bool _showCard = false;
  
  // List of texts to display in sequence
  late List<String> _textSequence;

  @override
  void initState() {
    super.initState();
    
    // Setup animation controller for text typing
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    
    // Setup a separate animation controller for card
    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Setup a fireworks controller with slower speed
    _fireworksController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    
    // Format current date as MM/DD
    final now = DateTime.now();
    _currentDate = DateFormat('MM/dd').format(now);
    
    // Set up card animation
    _cardAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5), // Start from below the screen
      end: Offset.zero, // End at normal position
    ).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.easeOutBack, // More dramatic curve with slight overshoot
      ),
    );
    
    // Initialize with empty list, will be populated after getting firstName
    _textSequence = [];
    
    // Load user's first name - This will only fetch data now
    _loadUserFirstName();

    // Try to initialize dependencies in case _isLoading is already false/first name not needed
    _initializeDependenciesIfReady();

    // Added log
    debugPrint('[OnboardingCard2] initState complete – waiting for _loadUserFirstName');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeDependenciesIfReady();
  }
  
  Future<void> _loadUserFirstName() async {
    debugPrint('[OnboardingCard2] _loadUserFirstName started');
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final userData = await _userRepository.getUserProfile(currentUser.uid);
        String? firstName;
        if (userData != null && userData['firstName'] != null) {
          firstName = userData['firstName'] as String;
        } else if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
          firstName = currentUser.displayName!.split(' ').first;
        }

        if (mounted) {
          setState(() {
            _firstName = firstName;
            _isLoading = false;
          });
          // Attempt to initialize once data is ready
          _initializeDependenciesIfReady();
          // Call didChangeDependencies implicitly by setState or explicitly if needed after _isLoading is false
          // Forcing a rebuild after _isLoading changes should trigger didChangeDependencies if not already run.
          debugPrint('[OnboardingCard2] _loadUserFirstName success. firstName=$_firstName, isLoading=$_isLoading');
        }
      } else {
        if (mounted) {
          setState(() {
            _firstName = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      if (mounted) {
        setState(() {
          _firstName = null;
          _isLoading = false;
        });
      }
      debugPrint('[OnboardingCard2] _loadUserFirstName error: $e');
    }
  }
  
  // Handle animation status changes
  void _handleAnimationStatus(AnimationStatus status) {
    debugPrint('[OnboardingCard2] Animation status: $status');
    if (status == AnimationStatus.completed) {
      // Guard against uninitialized dependencies
      if (!_dependenciesInitialized || _textSequence.isEmpty) {
        debugPrint('[OnboardingCard2] Animation completed but dependencies not ready');
        return;
      }
      // First text is fully displayed, wait a moment before transitioning
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          _fadeToNextText();
        }
      });
    }
  }
  
  // Transition to the next text in the sequence
  void _fadeToNextText() {
    debugPrint('[OnboardingCard2] _fadeToNextText called – currentTextIndex=$_currentTextIndex');
    
    // Guard against uninitialized dependencies or empty text sequence
    if (!_dependenciesInitialized || _textSequence.isEmpty) {
      debugPrint('[OnboardingCard2] _fadeToNextText called but dependencies not ready or text sequence empty');
      return;
    }
    
    if (_currentTextIndex >= _textSequence.length - 1) {
      // We're at the last text, wait 2 seconds before navigating to PrePaywallScreen
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => 
                  const PrePaywallScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOutCubic;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      });
      return;
    }
    
    // Start fade out animation
    setState(() {
      _isTransitioning = true;
    });
    
    // Animate fade out
    Future.delayed(const Duration(milliseconds: 10), () {
      if (mounted) {
        setState(() {
          _currentTextOpacity = 0.0;
        });
      }
    });
    
    // After fade out, change text and fade in
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        final nextTextIndex = _currentTextIndex + 1;
        
        setState(() {
          _currentTextIndex = nextTextIndex;
          
          // Check if we're transitioning to the specific text (index 2)
          // This text should be "Based on your answers,\nwe've built a plan just for you."
          if (nextTextIndex == 2 && !_showCard) {
            _showCard = true;
            // Animate the card once using the card animation controller
            _cardAnimationController.forward();
            
            // Make the text animation slower for this specific text
            _animationController.duration = const Duration(milliseconds: 2500);
          } else if (nextTextIndex == 1) {
            // Start the fireworks animation when showing the welcome text
            _fireworksController.reset();
            _fireworksController.repeat(reverse: false);
          } else {
            // Reset to normal duration for other texts
            _animationController.duration = const Duration(milliseconds: 1600);
          }
          
          // Always reset text animation controller for typing effect
          _animationController.reset();
          
          // Always restore opacity and clear transition flag
          _currentTextOpacity = 1.0;
          _isTransitioning = false;
        });
        
        // Start typing animation for new text
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.removeStatusListener(_handleAnimationStatus);
    _animationController.dispose();
    _cardAnimationController.dispose();
    _fireworksController.dispose();
    super.dispose();
  }
  
  // Build the radar chart (same as onboarding_screen5_radar.dart)
  Widget _buildCard() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SlideTransition(
        position: _cardAnimation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = (MediaQuery.of(context).size.width - 40) * 0.88;
            return SizedBox(
              height: side,
              width: side,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(side, side),
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
            );
          },
        ),
      ),
    );
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
      child: Scaffold(
        backgroundColor: Colors.white, // White background branding
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 25,
          title: const Text(''),
          automaticallyImplyLeading: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Main content column
              Column(
                children: [
                  // Text container with conditional positioning based on index
                  if (_currentTextIndex <= 1) 
                    // For first two texts (index 0 and 1), position in the middle
                    Container(
                      height: MediaQuery.of(context).size.height * 0.6, // Fixed height instead of Expanded
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          alignment: Alignment.center,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Color(0xFFed3272), // Brand pink for white background
                                )
                              : AnimatedOpacity(
                                  opacity: _currentTextOpacity,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                  child: AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, child) {
                                      // Get current text from sequence
                                      String textToDisplay = '';
                                      if (_isLoading || _textSequence.isEmpty || !_dependenciesInitialized) {
                                        textToDisplay = ''; 
                                      } else if (_currentTextIndex < _textSequence.length) {
                                        textToDisplay = _textSequence[_currentTextIndex]; // Directly use the (now potentially localized) string
                                      } else {
                                        textToDisplay = ''; 
                                      }
                                      
                                      final characterCount = (textToDisplay.length * _animationController.value).round();
                                      final visibleText = TextSanitizer.safeSubstring(
                                        textToDisplay,
                                        0,
                                        characterCount.clamp(0, textToDisplay.length),
                                      );
                                      
                                      return Text(
                                        visibleText,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'ElzaRound',
                                          color: Colors.black, // Dark text for white background
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                          height: 1.2,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ),
                    )
                  else
                    // For other texts (index 2+), position at the top
                    Padding(
                      padding: const EdgeInsets.only(top: 60.0, bottom: 20.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        alignment: Alignment.center,
                        child: AnimatedOpacity(
                          opacity: _currentTextOpacity,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              String textToDisplay = '';
                              if (_isLoading || _textSequence.isEmpty || !_dependenciesInitialized) {
                                textToDisplay = '';
                              } else if (_currentTextIndex < _textSequence.length) {
                                textToDisplay = _textSequence[_currentTextIndex]; // Directly use the (now potentially localized) string
                              } else {
                                textToDisplay = '';
                              }

                              final characterCount = (textToDisplay.length * _animationController.value).round();
                              final visibleText = TextSanitizer.safeSubstring(
                                textToDisplay,
                                0,
                                characterCount.clamp(0, textToDisplay.length),
                              );

                              return Text(
                                visibleText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'ElzaRound',
                                  color: Colors.black, // Dark text for white background
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  
                  // Spacer to push lottie to bottom
                  Expanded(child: Container()),
                  
                  // Lottie animation at the bottom - always visible
                  Container(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: Lottie.asset(
                      'assets/images/lotties/The 6 Loading Circles.json',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              
              // Radar chart with responsive absolute position - adapts to screen size
              if (_showCard) 
                Positioned(
                  top: MediaQuery.of(context).size.height < 700 
                      ? MediaQuery.of(context).size.height * 0.18  // Smaller screens (iPhone XS): 18% from top
                      : MediaQuery.of(context).size.height * 0.22, // Larger screens (iPhone 16 Plus): 22% from top
                  left: 0,
                  right: 0,
                  child: _buildCard(),
                ),
              
              // Fireworks animation - positioned to cover the entire screen
              if (_currentTextIndex == 1 && _currentTextOpacity > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.7,
                      child: Lottie.asset(
                        'assets/images/lotties/fireworksRed.json',
                        fit: BoxFit.cover,
                        controller: _fireworksController,
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

  void _initializeDependenciesIfReady() {
    if (_dependenciesInitialized || _isLoading) return;

    try {
      debugPrint('[OnboardingCard2] _initializeDependenciesIfReady triggered');
      final l10n = AppLocalizations.of(context)!;
      _textSequence = [
        l10n
            .translate('onboardingCard2_greeting')
            .replaceAll('{name}', TextSanitizer.sanitizeForDisplay(_firstName ?? l10n.translate('onboardingCard2_genericGreeting'))),
        l10n.translate('onboardingCard2_welcome'),
        l10n.translate('onboardingCard2_planBuilt'),
        l10n.translate('onboardingCard2_quitSugarForever'),
        l10n.translate('onboardingCard2_investInYourself'),
      ];

      // Verify text sequence is properly populated before proceeding
      if (_textSequence.isEmpty) {
        debugPrint('[OnboardingCard2] Error: Text sequence is empty after initialization');
        return;
      }

      MixpanelService.trackPageView('Onboarding Card 2 Screen');

      // Mark dependencies as initialized before starting animation
      _dependenciesInitialized = true;

      // Add status listener before starting animation
      _animationController.addStatusListener(_handleAnimationStatus);
      _animationController.forward();

      debugPrint('[OnboardingCard2] Dependencies initialized, animation started with ${_textSequence.length} texts');
    } catch (e, s) {
      debugPrint('[OnboardingCard2] Error initializing dependencies: $e');
      debugPrint('$s');
      // Reset initialization flag on error
      _dependenciesInitialized = false;
    }
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
    final radius = min(size.width, size.height) / 2 - 32;

    _drawGrid(canvas, center, radius);
    _drawValues(canvas, center, radius);
    _drawLabels(canvas, center, radius + 24, size);
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