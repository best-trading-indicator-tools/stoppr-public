import 'package:flutter/material.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/nutrition/data/repositories/nutrition_repository.dart';

class EditWorkoutHabitsScreen extends StatefulWidget {
  const EditWorkoutHabitsScreen({super.key});

  @override
  State<EditWorkoutHabitsScreen> createState() => _EditWorkoutHabitsScreenState();
}

class _EditWorkoutHabitsScreenState extends State<EditWorkoutHabitsScreen> {
  final _repo = NutritionRepository();

  double _workoutsPerWeek = 3;
  int _avgMinutes = 45;
  String _style = 'mixed';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('Edit Workout Habits Screen');
    _repo.streamBodyProfileRaw().listen((data) {
      if (!mounted || data == null) return;
      setState(() {
        if (data['workoutsPerWeek'] != null) {
          final v = data['workoutsPerWeek'];
          _workoutsPerWeek = (v is num) ? v.toDouble() : double.tryParse('$v') ?? _workoutsPerWeek;
        }
        if (data['avgWorkoutMinutes'] != null) {
          final v = data['avgWorkoutMinutes'];
          _avgMinutes = (v is num) ? v.toInt() : int.tryParse('$v') ?? _avgMinutes;
        }
        if (data['workoutStyle'] != null) {
          _style = data['workoutStyle'] as String? ?? _style;
        }
      });
    });
  }

  int get _weeklyMinutes => (_workoutsPerWeek * _avgMinutes).round();

  String _activityLabel(double wpw) {
    if (wpw <= 1) return 'Sedentary (1.2)';
    if (wpw <= 3) return 'Lightly active (1.375)';
    if (wpw <= 5) return 'Moderately active (1.55)';
    if (wpw <= 7) return 'Very active (1.725)';
    return 'Extra active (1.9)';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(AppLocalizations.of(context)!.translate('workout_edit_title'), style: const TextStyle(color: Colors.black)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.translate('workout_workoutsPerWeek'), style: const TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFed3272),
                      inactiveTrackColor: const Color(0xFFEAEAEA),
                      thumbColor: const Color(0xFFed3272),
                      overlayColor: const Color(0xFFed3272).withValues(alpha: 0.12),
                      valueIndicatorColor: const Color(0xFFed3272),
                      valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    child: Slider(
                      min: 0,
                      max: 10,
                      divisions: 20,
                      value: _workoutsPerWeek.clamp(0, 10),
                      label: _workoutsPerWeek.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _workoutsPerWeek = v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_workoutsPerWeek.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),

            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.translate('workout_avgDuration'), style: const TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFed3272),
                      inactiveTrackColor: const Color(0xFFEAEAEA),
                      thumbColor: const Color(0xFFed3272),
                      overlayColor: const Color(0xFFed3272).withValues(alpha: 0.12),
                      valueIndicatorColor: const Color(0xFFed3272),
                      valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    child: Slider(
                      min: 10,
                      max: 180,
                      divisions: 170,
                      value: _avgMinutes.toDouble().clamp(10, 180),
                      label: _avgMinutes.toString(),
                      onChanged: (v) => setState(() => _avgMinutes = v.round()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${_avgMinutes} ${AppLocalizations.of(context)!.translate('workout_unit_min')}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),

            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.translate('workout_style'), style: const TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StyleChip(label: 'cardio', selected: _style == 'cardio', onTap: () => setState(() => _style = 'cardio')),
                _StyleChip(label: 'strength', selected: _style == 'strength', onTap: () => setState(() => _style = 'strength')),
                _StyleChip(label: 'hiit', selected: _style == 'hiit', onTap: () => setState(() => _style = 'hiit')),
                _StyleChip(label: 'yoga', selected: _style == 'yoga', onTap: () => setState(() => _style = 'yoga')),
                _StyleChip(label: 'mixed', selected: _style == 'mixed', onTap: () => setState(() => _style = 'mixed')),
              ],
            ),

            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${AppLocalizations.of(context)!.translate('workout_weeklyMinutes')}: $_weeklyMinutes ${AppLocalizations.of(context)!.translate('workout_unit_min')}', style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('${AppLocalizations.of(context)!.translate('workout_activityLevel')}: ${_activityLabel(_workoutsPerWeek)}'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: Container(
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
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await _repo.saveWorkoutHabits(
                              workoutsPerWeek: _workoutsPerWeek,
                              avgWorkoutMinutes: _avgMinutes,
                              workoutStyle: _style,
                            );
                            MixpanelService.trackButtonTap('Workout Habits Save', screenName: 'Edit Workout Habits');
                            if (mounted) Navigator.pop(context, true);
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  child: Text(
                    _saving
                        ? AppLocalizations.of(context)!.translate('calorieTracker_saving')
                        : AppLocalizations.of(context)!.translate('calorieTracker_saveChanges'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = {
      'cardio': AppLocalizations.of(context)!.translate('workout_style_cardio'),
      'strength': AppLocalizations.of(context)!.translate('workout_style_strength'),
      'hiit': AppLocalizations.of(context)!.translate('workout_style_hiit'),
      'yoga': AppLocalizations.of(context)!.translate('workout_style_yoga'),
      'mixed': AppLocalizations.of(context)!.translate('workout_style_mixed'),
    }[label] ?? label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? null : Colors.white,
          gradient: selected ? const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFed3272), // Strong pink/magenta
              Color(0xFFfd5d32), // Vivid orange
            ],
          ) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.transparent : const Color(0xFFed3272)),
        ),
        child: Text(text, style: TextStyle(color: selected ? Colors.white : const Color(0xFFed3272), fontWeight: FontWeight.w700)),
      ),
    );
  }
}


