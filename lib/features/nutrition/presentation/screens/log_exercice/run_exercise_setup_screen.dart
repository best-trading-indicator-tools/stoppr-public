import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/analytics/mixpanel_service.dart';
import 'calorie_burned_result_screen.dart';
import '../../../data/models/workout_log.dart';
import '../../../data/repositories/nutrition_repository.dart';

class RunExerciseSetupScreen extends StatefulWidget {
  const RunExerciseSetupScreen({super.key, required this.targetDate, this.editingWorkout});
  
  final DateTime targetDate;
  final WorkoutLog? editingWorkout;

  @override
  State<RunExerciseSetupScreen> createState() => _RunExerciseSetupScreenState();
}

class _RunExerciseSetupScreenState extends State<RunExerciseSetupScreen> {
  String _selectedIntensity = 'medium';
  int _selectedDuration = 15;
  final TextEditingController _durationController = TextEditingController();
  
  final List<int> _durationOptions = [15, 30, 60, 90];

  int _intensityToIndex(String intensity) {
    switch (intensity) {
      case 'low':
        return 0;
      case 'medium':
        return 1;
      case 'high':
        return 2;
      default:
        return 1;
    }
  }

  String _indexToIntensity(int index) {
    if (index <= 0) return 'low';
    if (index == 1) return 'medium';
    return 'high';
  }

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('Run Exercise Setup Screen');
    if (widget.editingWorkout != null) {
      _selectedIntensity = widget.editingWorkout!.intensity;
      _selectedDuration = widget.editingWorkout!.duration;
    }
    _durationController.text = _selectedDuration.toString();
  }

  @override
  void dispose() {
    _durationController.dispose();
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
                      MixpanelService.trackButtonTap('Run Exercise Setup Screen: Back Button');
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
                      l10n.translate('exercise_run'),
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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // Intensity selector - new design with single card and vertical slider
                  _buildIntensitySelector(l10n),
                  const SizedBox(height: 24),
                  
                  // Duration selector
                  _buildDurationSelector(l10n),
                ],
              ),
            ),
            
            // Continue button
            Padding(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: () {
                  MixpanelService.trackButtonTap(
                    'Run Exercise Setup Screen: Continue',
                    additionalProps: {
                      'intensity': _selectedIntensity,
                      'duration': _selectedDuration,
                    },
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CalorieBurnedResultScreen(
                        exerciseType: l10n.translate('exercise_run'),
                        intensity: _selectedIntensity,
                        duration: _selectedDuration,
                        targetDate: widget.targetDate,
                        editingWorkoutId: widget.editingWorkout?.id,
                      ),
                    ),
                  );
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
                      l10n.translate('button_continue'),
                      style: const TextStyle(
                        color: Colors.white,
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

  Widget _buildIntensitySelector(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('exercise_set_intensity'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Intensity labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntensityOption('high', l10n),
                    const SizedBox(height: 24),
                    _buildIntensityOption('medium', l10n),
                    const SizedBox(height: 24),
                    _buildIntensityOption('low', l10n),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Vertical slider
              SizedBox(
                height: 140,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      activeTrackColor: const Color(0xFFed3272), // Brand pink
                      inactiveTrackColor: const Color(0xFFE5E5EA),
                      thumbColor: const Color(0xFFfd5d32), // Brand orange
                      overlayColor: const Color(0xFFed3272).withOpacity(0.1),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 20,
                      ),
                    ),
                    child: Slider(
                      value: _intensityToIndex(_selectedIntensity).toDouble(),
                      min: 0,
                      max: 2,
                      divisions: 2,
                      onChanged: (value) {
                        setState(() {
                          _selectedIntensity = _indexToIntensity(value.round());
                        });
                        MixpanelService.trackButtonTap(
                          'Run Exercise Intensity Slider',
                          additionalProps: {'intensity': _selectedIntensity},
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntensityOption(String intensity, AppLocalizations l10n) {
    final isSelected = _selectedIntensity == intensity;
    
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('exercise_intensity_$intensity'),
              style: TextStyle(
                fontSize: isSelected && intensity == 'medium' ? 18 : 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.translate('exercise_intensity_${intensity}_desc'),
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF666666),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationSelector(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('exercise_duration'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(_durationOptions.length, (index) {
            final int duration = _durationOptions[index];
            final bool isSelected = _selectedDuration == duration;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < _durationOptions.length - 1 ? 12 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDuration = duration;
                      _durationController.text = duration.toString();
                    });
                    MixpanelService.trackButtonTap(
                      'Run Exercise Duration Selection',
                      additionalProps: {'duration': duration},
                    );
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? null
                          : Border.all(color: const Color(0xFFE5E5EA)),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFed3272).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$duration ${l10n.translate('unit_mins')}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        // Custom duration input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    hintText: l10n.translate('exercise_custom_duration'),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final duration = int.tryParse(value);
                    if (duration != null && duration > 0) {
                      setState(() {
                        _selectedDuration = duration;
                      });
                    }
                  },
                ),
              ),
              Text(
                l10n.translate('unit_mins'),
                style: TextStyle(
                  color: const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ],
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
                                  'from': 'run_exercise_setup',
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
