import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/analytics/mixpanel_service.dart';
import 'calorie_burned_result_screen.dart';
import '../../../data/models/workout_log.dart';
import '../../../data/repositories/nutrition_repository.dart';

class ManualExerciseSetupScreen extends StatefulWidget {
  const ManualExerciseSetupScreen({super.key, required this.targetDate, this.editingWorkout});
  
  final DateTime targetDate;
  final WorkoutLog? editingWorkout;

  @override
  State<ManualExerciseSetupScreen> createState() => _ManualExerciseSetupScreenState();
}

class _ManualExerciseSetupScreenState extends State<ManualExerciseSetupScreen> {
  final TextEditingController _caloriesController = TextEditingController();
  int _manualCalories = 0;

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('Manual Exercise Setup Screen');
    if (widget.editingWorkout != null) {
      _manualCalories = widget.editingWorkout!.caloriesBurned;
      _caloriesController.text = _manualCalories.toString();
    }
  }

  @override
  void dispose() {
    _caloriesController.dispose();
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
                      MixpanelService.trackButtonTap('Manual Exercise Setup Screen: Back Button');
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
                  Expanded(
                    child: Text(
                      l10n.translate('exercise_manual'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.editingWorkout != null)
                    GestureDetector(
                      onTap: () => _showDeleteDialog(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
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
                          Icons.more_horiz,
                          color: Color(0xFF1A1A1A),
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('exercise_burnedCalories'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Calorie input with circular progress indicator
                    Row(
                      children: [
                        // Circular progress indicator - updates based on calories
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: _manualCalories > 0 ? (_manualCalories / 1000.0).clamp(0.0, 1.0) : 0.0,
                                strokeWidth: 6,
                                backgroundColor: const Color(0xFFE5E5EA),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFed3272)),
                              ),
                            ),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '🔥',
                                  style: TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        
                        // Calorie input field
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E5EA)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _caloriesController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.translate('exercise_burnedCalories'),
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _manualCalories = int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                  ],
                ),
              ),
            ),
            
            // Add button
            Padding(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: _manualCalories > 0 ? () {
                  MixpanelService.trackButtonTap(
                    'Manual Exercise Setup Screen: Add',
                    additionalProps: {
                      'manual_calories': _manualCalories,
                    },
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CalorieBurnedResultScreen(
                        exerciseType: l10n.translate('exercise_manual'),
                        intensity: 'medium', // Default for manual entry
                        duration: 0, // Not applicable for manual
                        targetDate: widget.targetDate,
                        manualCalories: _manualCalories,
                        editingWorkoutId: widget.editingWorkout?.id,
                      ),
                    ),
                  );
                } : null,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _manualCalories > 0 ? const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272), // Brand pink
                        Color(0xFFfd5d32), // Brand orange
                      ],
                    ) : null,
                    color: _manualCalories <= 0 ? Colors.grey[300] : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      l10n.translate('common_add'),
                      style: TextStyle(
                        color: _manualCalories > 0 ? Colors.white : Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.translate('delete_exercise'),
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.translate('delete_exercise_confirmation'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)!.translate('common_cancel'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final localizations = AppLocalizations.of(context)!;
                          
                          navigator.pop(); // Close dialog
                          
                          if (widget.editingWorkout?.id != null) {
                            try {
                              MixpanelService.trackButtonTap(
                                localizations.translate('delete_exercise'),
                                additionalProps: {
                                  'exercise_type': widget.editingWorkout!.exerciseType,
                                  'from': 'manual_exercise_setup',
                                },
                              );
                              
                              // Show loading
                              if (mounted) {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext dialogContext) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                );
                              }
                              
                              final repository = NutritionRepository();
                              await repository.deleteWorkoutLog(widget.editingWorkout!.id!);
                              
                              if (mounted) {
                                navigator.pop(); // Close loading
                                navigator.pop(); // Go back to dashboard
                              }
                            } catch (e) {
                              debugPrint('Error deleting workout: $e');
                              if (mounted) {
                                // Try to close loading dialog if it's open
                                try {
                                  navigator.pop();
                                } catch (_) {}
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(localizations.translate('error_occurred')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFed3272), // Brand pink
                                Color(0xFFfd5d32), // Brand orange
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)!.translate('common_delete'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
