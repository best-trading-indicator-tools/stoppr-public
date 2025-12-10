import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/features/onboarding/presentation/screens/give_us_ratings_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/letter_from_future_screen.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'dart:math' as math;

class SlideLeftRoute extends PageRouteBuilder {
  final Widget page;
  SlideLeftRoute({required this.page})
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

class BenefitsImpactScreen extends StatefulWidget {
  const BenefitsImpactScreen({super.key});

  @override
  State<BenefitsImpactScreen> createState() => _BenefitsImpactScreenState();
}

class _BenefitsImpactScreenState extends State<BenefitsImpactScreen> 
    with TickerProviderStateMixin {
  final OnboardingProgressService _progressService = OnboardingProgressService();
  late AnimationController _animationController;
  late AnimationController _dotAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Animation<double>? _dotAnimation;
  
  int _selectedBenefitIndex = 0;
  int _selectedWeekIndex = 5; // Default to week 6 (index 5)
  
  // Benefit data structure
  final List<BenefitData> _benefits = [
    BenefitData(
      iconData: Icons.bolt,
      titleKey: 'benefitsImpact_energy_title',
      yAxisKey: 'benefitsImpact_energy_yAxis',
      descriptionKey: 'benefitsImpact_energy_description',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_energy',
      color: const Color(0xFFFF6B35),
      weeklyValues: [0.1, 0.2, 0.4, 0.6, 0.75, 0.85, 0.9, 0.95],
      peakWeek: 5,
    ),
    BenefitData(
      iconData: Icons.wb_sunny,
      titleKey: 'benefitsImpact_mood_title',
      yAxisKey: 'benefitsImpact_mood_yAxis',
      descriptionKey: 'benefitsImpact_mood_description',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_mood',
      color: const Color(0xFFFFA726),
      weeklyValues: [0.1, 0.15, 0.25, 0.4, 0.6, 0.8, 0.9, 0.95],
      peakWeek: 5,
    ),
    BenefitData(
      iconData: Icons.psychology,
      titleKey: 'benefitsImpact_focus_title',
      yAxisKey: 'benefitsImpact_focus_yAxis',
      descriptionKey: 'benefitsImpact_focus_description',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_focus',
      color: const Color(0xFF42A5F5),
      weeklyValues: [0.1, 0.2, 0.35, 0.5, 0.7, 0.85, 0.92, 0.97],
      peakWeek: 5,
    ),
    BenefitData(
      iconData: Icons.fitness_center,
      titleKey: 'benefitsImpact_strength_title',
      yAxisKey: 'benefitsImpact_strength_yAxis',
      descriptionKey: 'benefitsImpact_strength_description',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_strength',
      color: const Color(0xFF66BB6A),
      weeklyValues: [0.1, 0.18, 0.3, 0.45, 0.65, 0.8, 0.9, 0.95],
      peakWeek: 5,
    ),
    BenefitData(
      iconData: Icons.bedtime,
      titleKey: 'benefitsImpact_sleep_title',
      yAxisKey: 'benefitsImpact_sleep_yAxis',
      descriptionKey: 'benefitsImpact_sleep_description',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_sleep',
      color: const Color(0xFF9C27B0),
      weeklyValues: [0.1, 0.25, 0.4, 0.6, 0.75, 0.85, 0.9, 0.95],
      peakWeek: 5,
    ),
    BenefitData(
      iconData: Icons.favorite,
      titleKey: 'benefitsImpact_hormones_title',
      yAxisKey: 'benefitsImpact_hormones_yAxis',
      descriptionKey: 'benefitsImpact_hormones_description',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_hormones',
      color: const Color(0xFFE91E63),
      weeklyValues: [0.1, 0.12, 0.2, 0.35, 0.55, 0.75, 0.85, 0.9],
      peakWeek: 5,
    ),
    BenefitData(
      iconData: Icons.self_improvement,
      titleKey: 'benefitsImpact_confidence_title',
      yAxisKey: 'benefitsImpact_confidence_yAxis',
      descriptionKey: 'benefitsImpact_confidence_description',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_confidence',
      color: const Color(0xFF7E57C2),
      weeklyValues: [0.1, 0.15, 0.22, 0.35, 0.5, 0.7, 0.85, 0.92],
      peakWeek: 5,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _saveCurrentScreen();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _dotAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _dotAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dotAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    _dotAnimationController.forward();
    
    // Mixpanel tracking
    MixpanelService.trackEvent('Onboarding Benefits Impact Screen: Page Viewed');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dotAnimationController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.benefitsImpactScreen);
  }

  void _selectBenefit(int index) {
    if (index == _selectedBenefitIndex) return;
    
    setState(() {
      _selectedBenefitIndex = index;
      // Reset to default week when switching benefits
      _selectedWeekIndex = 5;
    });
    
    _animationController.reset();
    _animationController.forward();
    
    // Track benefit selection
    MixpanelService.trackEvent('Onboarding Benefits Impact Screen: Benefit Selected', properties: {
      'benefit_index': index,
      'benefit_title': _benefits[index].titleKey,
    });
  }

  void _selectWeek(int weekIndex) {
    if (weekIndex == _selectedWeekIndex) return;
    
    setState(() {
      _selectedWeekIndex = weekIndex;
    });
    
    // Animate the dot movement if animation is initialized
    if (_dotAnimation != null) {
      _dotAnimationController.reset();
      _dotAnimationController.forward();
    }
    
    // Track week selection
    MixpanelService.trackEvent('Onboarding Benefits Impact Screen: Week Selected', properties: {
      'week_index': weekIndex,
      'week_number': weekIndex + 1,
      'benefit_title': _benefits[_selectedBenefitIndex].titleKey,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedBenefit = _benefits[_selectedBenefitIndex];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white background
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // White background branding
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // Title
                      Text(
                        l10n.translate('benefitsImpact_title'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Color(0xFF1A1A1A), // Dark text on white background
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Icons row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(_benefits.length, (index) {
                          final isSelected = index == _selectedBenefitIndex;
                          return GestureDetector(
                            onTap: () => _selectBenefit(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? _benefits[index].color 
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected 
                                    ? Border.all(color: _benefits[index].color, width: 2)
                                    : Border.all(color: const Color(0xFFCCCCCC), width: 1),
                                boxShadow: isSelected ? null : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _benefits[index].iconData,
                                color: isSelected ? Colors.white : Color(0xFF666666), // Gray icon for unselected
                                size: 18,
                              ),
                            ),
                          );
                        }),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Interaction instruction
                      Text(
                        l10n.translate('benefitsImpact_instruction'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Color(0xFF666666), // Gray text for instruction
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Chart container
                      AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                width: double.infinity,
                                height: 300,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFAFA), // Light gray background
                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(
                  color: const Color(0xFFCCCCCC), // Darker border for better visibility
                  width: 1.5,
                ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Chart title
                                    Text(
                                      l10n.translate(selectedBenefit.titleKey),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        color: Color(0xFF1A1A1A), // Dark text on white background
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 8),
                                    
                                    // Y-axis label as subtitle
                                    Text(
                                      l10n.translate(selectedBenefit.yAxisKey),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        color: Color(0xFF666666), // Gray text for secondary content
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Chart
                                    Expanded(
                                      child: GestureDetector(
                                        onPanUpdate: (details) {
                                          final RenderBox renderBox = context.findRenderObject() as RenderBox;
                                          final localPosition = renderBox.globalToLocal(details.globalPosition);
                                          
                                          // Calculate chart area (matching the painter's chartArea)
                                          const chartPadding = 20.0;
                                          const chartLeft = 60.0;
                                          const chartRight = 100.0;
                                          final chartWidth = renderBox.size.width - chartLeft - chartRight;
                                          
                                          // Calculate which week the user is touching
                                          final relativeX = localPosition.dx - chartLeft - chartPadding;
                                          final stepX = chartWidth / (selectedBenefit.weeklyValues.length - 1);
                                          final weekIndex = (relativeX / stepX).round().clamp(0, selectedBenefit.weeklyValues.length - 1);
                                          
                                          _selectWeek(weekIndex);
                                        },
                                        onTapDown: (details) {
                                          final RenderBox renderBox = context.findRenderObject() as RenderBox;
                                          final localPosition = renderBox.globalToLocal(details.globalPosition);
                                          
                                          // Calculate chart area (matching the painter's chartArea)
                                          const chartPadding = 20.0;
                                          const chartLeft = 60.0;
                                          const chartRight = 100.0;
                                          final chartWidth = renderBox.size.width - chartLeft - chartRight;
                                          
                                          // Calculate which week the user is touching
                                          final relativeX = localPosition.dx - chartLeft - chartPadding;
                                          final stepX = chartWidth / (selectedBenefit.weeklyValues.length - 1);
                                          final weekIndex = (relativeX / stepX).round().clamp(0, selectedBenefit.weeklyValues.length - 1);
                                          
                                          _selectWeek(weekIndex);
                                        },
                                        child: AnimatedBuilder(
                                          animation: _dotAnimation ?? _animationController,
                                          builder: (context, child) {
                                            return CustomPaint(
                                              painter: BenefitChartPainter(
                                                values: selectedBenefit.weeklyValues,
                                                color: selectedBenefit.color,
                                                peakWeek: selectedBenefit.peakWeek,
                                                selectedWeek: _selectedWeekIndex,
                                                yAxisLabel: l10n.translate(selectedBenefit.yAxisKey),
                                                animation: _fadeAnimation.value,
                                                dotAnimation: _dotAnimation?.value ?? 1.0,
                                              ),
                                              child: const SizedBox(
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: selectedBenefit.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.translate('benefitsImpact_withSTOPPR'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Color(0xFF1A1A1A), // Dark text on white background
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFF666666), // Gray for secondary legend
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.translate('benefitsImpact_withoutSTOPPR'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Color(0xFF666666), // Gray text for secondary content
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Dynamic description
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: selectedBenefit.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedBenefit.color.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _fadeAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _fadeAnimation.value,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_graph,
                                    color: selectedBenefit.color,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.0, 0.3),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        l10n.translate(selectedBenefit.getWeeklyDescriptionKey(_selectedWeekIndex)),
                                        key: ValueKey(_selectedWeekIndex),
                                        style: const TextStyle(
                                          fontFamily: 'ElzaRound',
                                          color: Color(0xFF1A1A1A), // Dark text on white background
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              
              // Continue button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.11),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                height: 110,
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: GestureDetector(
                      onTap: () {
                        MixpanelService.trackEvent('Onboarding Benefits Impact Screen: Continue Button Tap');
                        Navigator.of(context).pushReplacement(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const LetterFromFutureScreen(),
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
                            transitionDuration: const Duration(milliseconds: 400),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 60,
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
                              color: Colors.black.withOpacity(0.15),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.translate('benefitsImpact_continueButton'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            color: Colors.white, // White text on gradient
                            fontSize: 19, // Increased from 15 to 19 for better readability
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

// Data model for benefits
class BenefitData {
  final IconData iconData;
  final String titleKey;
  final String yAxisKey;
  final String descriptionKey;
  final String weeklyDescriptionKeyPrefix;
  final Color color;
  final List<double> weeklyValues;
  final int peakWeek;

  BenefitData({
    required this.iconData,
    required this.titleKey,
    required this.yAxisKey,
    required this.descriptionKey,
    required this.weeklyDescriptionKeyPrefix,
    required this.color,
    required this.weeklyValues,
    required this.peakWeek,
  });
  
  String getWeeklyDescriptionKey(int weekIndex) {
    return '${weeklyDescriptionKeyPrefix}_week${weekIndex + 1}';
  }
}

// Custom painter for the benefit chart
class BenefitChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final int peakWeek;
  final int selectedWeek;
  final String yAxisLabel;
  final double animation;
  final double dotAnimation;

  BenefitChartPainter({
    required this.values,
    required this.color,
    required this.peakWeek,
    required this.selectedWeek,
    required this.yAxisLabel,
    required this.animation,
    required this.dotAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final baselinePaint = Paint()
      ..color = const Color(0xFF666666) // Gray baseline for white background
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = const Color(0xFF1A1A1A).withOpacity(0.1) // Dark grid lines
      ..strokeWidth = 1;

    final chartArea = Rect.fromLTWH(60, 20, size.width - 100, size.height - 60);

    // Draw grid lines
    for (int i = 0; i <= 4; i++) {
      final y = chartArea.top + (chartArea.height / 4) * i;
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        gridPaint,
      );
    }

    // Draw Y-axis labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i <= 4; i++) {
      final y = chartArea.top + (chartArea.height / 4) * i;
      final value = (4 - i) * 25; // 0, 25, 50, 75, 100
      
      textPainter.text = TextSpan(
        text: '$value%',
        style: const TextStyle(
          color: Color(0xFF666666), // Gray text for Y-axis labels
          fontSize: 12,
          fontFamily: 'ElzaRound',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(15, y - textPainter.height / 2));
    }

    // Y-axis title is now displayed as subtitle above the chart

    // Draw baseline (without Stoppr) - gradual improvement
    final baselinePath = Path();
    final stepX = chartArea.width / (values.length - 1);
    final baselineValues = [0.1, 0.12, 0.15, 0.18, 0.22, 0.25, 0.28, 0.3]; // Gradual increase
    
    for (int i = 0; i < values.length; i++) {
      final x = chartArea.left + stepX * i;
      final y = chartArea.bottom - (chartArea.height * baselineValues[i]);
      
      if (i == 0) {
        baselinePath.moveTo(x, y);
      } else {
        baselinePath.lineTo(x, y);
      }
    }
    canvas.drawPath(baselinePath, baselinePaint);

    // Draw main curve (with Stoppr)
    final path = Path();
    final fillPath = Path();
    
    for (int i = 0; i < values.length; i++) {
      final x = chartArea.left + stepX * i;
      final animatedValue = values[i] * animation;
      final y = chartArea.bottom - (chartArea.height * animatedValue);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartArea.bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    // Complete fill path
    fillPath.lineTo(chartArea.right, chartArea.bottom);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw interactive selected week highlight
    if (selectedWeek < values.length) {
      final selectedX = chartArea.left + stepX * selectedWeek;
      final selectedY = chartArea.bottom - (chartArea.height * values[selectedWeek] * animation);
      
      // Draw vertical dashed line
      final dashPaint = Paint()
        ..color = color
        ..strokeWidth = 2;
      
      final dashHeight = 5;
      final dashSpace = 5;
      double currentY = chartArea.bottom;
      
      while (currentY > selectedY) {
        canvas.drawLine(
          Offset(selectedX, currentY),
          Offset(selectedX, math.max(currentY - dashHeight, selectedY)),
          dashPaint,
        );
        currentY -= dashHeight + dashSpace;
      }
      
      // Draw interactive glowing dot with enhanced light effect and animation
      final animatedScale = 0.8 + (0.2 * dotAnimation); // Scale from 0.8 to 1.0
      
      // Outermost glow (largest, most subtle)
      final outerGlowPaint = Paint()
        ..color = color.withOpacity(0.15 * dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 20 * animatedScale, outerGlowPaint);
      
      // Large glow layer
      final largeGlowPaint = Paint()
        ..color = color.withOpacity(0.25 * dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 16 * animatedScale, largeGlowPaint);
      
      // Medium glow layer
      final mediumGlowPaint = Paint()
        ..color = color.withOpacity(0.4 * dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 12 * animatedScale, mediumGlowPaint);
      
      // Inner glow layer
      final innerGlowPaint = Paint()
        ..color = color.withOpacity(0.7 * dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 8 * animatedScale, innerGlowPaint);
      
      // Core bright dot
      final corePaint = Paint()
        ..color = color.withOpacity(dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 5 * animatedScale, corePaint);
      
      // Bright white center highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.9 * dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 3 * animatedScale, highlightPaint);
      
      // Dynamic week label
      textPainter.text = TextSpan(
        text: 'Week ${selectedWeek + 1}',
        style: const TextStyle(
          color: Color(0xFF1A1A1A), // Dark text for week label on white background
          fontSize: 14,
          fontFamily: 'ElzaRound',
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(selectedX - textPainter.width / 2, chartArea.bottom + 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 