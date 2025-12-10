 import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../data/models/workout_log.dart';
import '../../../data/models/weight_entry.dart';
import '../../../data/models/body_profile.dart';
import '../../../data/repositories/nutrition_repository.dart';
import '../calorie_tracker_dashboard.dart';

class CalorieBurnedResultScreen extends StatefulWidget {
  const CalorieBurnedResultScreen({
    super.key,
    required this.exerciseType,
    required this.intensity,
    required this.duration,
    required this.targetDate,
    this.manualCalories,
    this.editingWorkoutId,
  });

  final String exerciseType;
  final String intensity;
  final int duration;
  final DateTime targetDate;
  final int? manualCalories;
  final String? editingWorkoutId;

  @override
  State<CalorieBurnedResultScreen> createState() => _CalorieBurnedResultScreenState();
}

class _CalorieBurnedResultScreenState extends State<CalorieBurnedResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  final NutritionRepository _nutritionRepository = NutritionRepository();
  double? _userWeightKg;
  double? _userHeightCm;
  
  int get _calculateCalories {
    // Return manual calories if provided
    if (widget.manualCalories != null) {
      return widget.manualCalories!;
    }
    
    // Exercise-specific calorie calculation using MET values
    // MET formula: METs * weight(kg) * 0.0175 * time(minutes)
    // Use actual user weight if available, otherwise default to 70kg
    final double weightKg = _userWeightKg ?? 70.0;
    
    double metValue;
    
    if (widget.exerciseType.toLowerCase().contains('run')) {
      // Running MET values (based on research)
      switch (widget.intensity) {
        case 'low':
          metValue = 6.0; // Light jogging (~4 mph)
          break;
        case 'medium':
          metValue = 8.0; // Moderate running (~5 mph)
          break;
        case 'high':
          metValue = 11.0; // Fast running (~6.5 mph)
          break;
        default:
          metValue = 8.0;
      }
    } else if (widget.exerciseType.toLowerCase().contains('weight')) {
      // Weight lifting MET values (based on research)
      switch (widget.intensity) {
        case 'low':
          metValue = 3.0; // Light weight lifting
          break;
        case 'medium':
          metValue = 4.0; // Moderate weight lifting (was too low at 5.0)
          break;
        case 'high':
          metValue = 6.0; // Vigorous weight lifting
          break;
        default:
          metValue = 4.0;
      }
    } else {
      // Default exercise MET values
      switch (widget.intensity) {
        case 'low':
          metValue = 4.0;
          break;
        case 'medium':
          metValue = 6.0;
          break;
        case 'high':
          metValue = 8.0;
          break;
        default:
          metValue = 6.0;
      }
    }
    
    // MET formula: METs * weight(kg) * 0.0175 * time(minutes)
    final calories = metValue * weightKg * 0.0175 * widget.duration;
    return calories.round();
  }

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('Calorie Burned Result Screen');
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 0.8, // 80% of circle
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _loadUserMetrics();
  }

  Future<void> _loadUserMetrics() async {
    try {
      // Get latest weight
      final latestWeight = await _nutritionRepository.streamLatestWeight().first;
      if (latestWeight != null) {
        setState(() {
          _userWeightKg = latestWeight.weightKg;
        });
      }
      
      // Get body profile for height
      final bodyProfile = await _nutritionRepository.getBodyProfile().first;
      if (bodyProfile != null) {
        setState(() {
          _userHeightCm = bodyProfile.heightCm;
        });
      }
    } catch (e) {
      debugPrint('Error loading user metrics: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      MixpanelService.trackButtonTap('Calorie Burned Result Screen: Back Button');
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF1A1A1A),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    l10n.translate('exercise_result_title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Progress Ring
                  _buildProgressRing(),
                  const SizedBox(height: 48),
                  
                  // Exercise details
                  Text(
                    '${widget.duration} ${l10n.translate('unit_mins')} • ${l10n.translate('exercise_intensity_${widget.intensity}')}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Motivational message
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      l10n.translate('exercise_complete_message'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Continue button
                  GestureDetector(
                    onTap: () async {
                      MixpanelService.trackButtonTap('Calorie Burned Result Screen: Save and Continue');
                      
                      try {
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFed3272)),
                              ),
                            );
                          },
                        );
                        
                        await _saveWorkoutLog();
                        
                        if (mounted) {
                          // Pop loading dialog
                          Navigator.pop(context);
                          
                          // Navigate back to calorie tracker dashboard with the target date
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => CalorieTrackerDashboard(
                                initialDate: widget.targetDate,
                              ),
                            ),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context); // Pop loading dialog
                          // Show error snackbar
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.translate('exercise_logError')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          l10n.translate('exercise_log'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRing() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: _ArcRingPainter(
                  progress: _progressAnimation.value,
                  strokeWidth: 14,
                  trackColor: const Color(0xFFEFF1F5),
                  gradientColors: const [Color(0xFFed3272), Color(0xFFfd5d32)],
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🔥',
                  style: TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_calculateCalories',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: const Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.translate('unit_calories'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveWorkoutLog() async {
    final nutritionRepository = NutritionRepository();
    
    if (widget.editingWorkoutId != null) {
      // Update existing workout
      final workoutLog = WorkoutLog(
        id: widget.editingWorkoutId,
        exerciseType: widget.exerciseType,
        intensity: widget.intensity,
        duration: widget.duration,
        caloriesBurned: _calculateCalories,
        loggedAt: widget.targetDate,
        createdAt: DateTime.now(), // This will be ignored in update
        updatedAt: DateTime.now(),
      );
      
      await nutritionRepository.updateWorkoutLog(widget.editingWorkoutId!, workoutLog);
    } else {
      // Create new workout
      final workoutLog = WorkoutLog(
        exerciseType: widget.exerciseType,
        intensity: widget.intensity,
        duration: widget.duration,
        caloriesBurned: _calculateCalories,
        loggedAt: widget.targetDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await nutritionRepository.addWorkoutLog(workoutLog);
    }
  }
}

// Move painter class outside of the state class
class _ArcRingPainter extends CustomPainter {
  const _ArcRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.gradientColors,
  });

  final double progress; // 0..1
  final double strokeWidth;
  final Color trackColor;
  final List<Color> gradientColors;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double inset = strokeWidth / 2;
    final Rect arcRect = Rect.fromLTWH(
      rect.left + inset,
      rect.top + inset,
      rect.width - strokeWidth,
      rect.height - strokeWidth,
    );

    // Use a partial arc (80% of circle)
    const double startAngle = 0.8 * math.pi; // Start at ~145 degrees
    const double maxSweep = 1.6 * math.pi; // 80% of full circle

    // Draw track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, startAngle, maxSweep, false, trackPaint);

    // Draw gradient progress
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + maxSweep,
      colors: gradientColors,
    );

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(arcRect);

    final double sweep = maxSweep * progress.clamp(0.0, 1.0);
    canvas.drawArc(arcRect, startAngle, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.gradientColors != gradientColors;
  }
}
