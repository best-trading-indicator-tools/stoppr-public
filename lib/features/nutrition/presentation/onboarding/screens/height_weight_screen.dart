import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/nutrition/presentation/onboarding/screens/workouts_per_week_screen.dart';
import 'package:stoppr/features/nutrition/presentation/onboarding/screens/goal_selection_screen.dart';

class HeightWeightScreen extends StatefulWidget {
  const HeightWeightScreen({
    super.key,
    required this.activity,
    this.isOnboarding = true,
  });
  final String activity; // light|moderate|active
  final bool isOnboarding;

  @override
  State<HeightWeightScreen> createState() => _HeightWeightScreenState();
}

class _HeightWeightScreenState extends State<HeightWeightScreen> {
  bool _metric = true;

  int _heightCm = 171;
  int _weightKg = 79;

  int _heightFt = 5;
  int _heightIn = 7;
  int _weightLb = 174;

  int _cmFromFtIn(int ft, int inch) => (ft * 30.48 + inch * 2.54).round();
  List<int> _ftInFromCm(int cm) {
    final totalIn = (cm / 2.54).round();
    final ft = totalIn ~/ 12;
    final inch = totalIn % 12;
    return [ft, inch];
  }
  int _kgFromLb(int lb) => (lb / 2.20462).round();
  int _lbFromKg(int kg) => (kg * 2.20462).round();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFB),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const WorkoutsPerWeekScreen(),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 2 / 4, // Step 2 of 4
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E5EA),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFed3272)),
            ),
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('calorieOnboarding_heightWeight_title'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.translate('calorieOnboarding_heightWeight_subtitle'),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
              ),
              const SizedBox(height: 32),

              // Unit toggle row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.translate('calorieOnboarding_imperial'),
                    style: TextStyle(
                      color: _metric ? Colors.grey.shade400 : Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _metric,
                    activeColor: const Color(0xFFed3272),
                    trackColor: MaterialStateProperty.resolveWith((states) {
                      if (states.contains(MaterialState.selected)) {
                        return const Color(0xFFed3272); // when Metric selected
                      }
                      return const Color(0xFFE6E6E6); // Imperial selected
                    }),
                    thumbColor: const MaterialStatePropertyAll<Color>(Colors.white),
                    onChanged: (v) {
                      setState(() {
                        if (v) {
                          // imperial -> metric
                          _heightCm = _cmFromFtIn(_heightFt, _heightIn);
                          _weightKg = _kgFromLb(_weightLb);
                        } else {
                          // metric -> imperial
                          final pair = _ftInFromCm(_heightCm);
                          _heightFt = pair[0];
                          _heightIn = pair[1];
                          _weightLb = _lbFromKg(_weightKg);
                        }
                        _metric = v;
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.translate('calorieOnboarding_metric'),
                    style: TextStyle(
                      color: _metric ? Colors.black : Colors.grey.shade400,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              if (_metric)
                Row(
                  children: [
                    Expanded(
                      child: _PickerColumn(
                        label: l10n.translate('calorieOnboarding_height_label'),
                        value: _heightCm,
                        min: 120,
                        max: 220,
                        unit: l10n.translate('unit_cm'),
                        onChanged: (v) => setState(() => _heightCm = v),
                        labelPaddingLeft: 50,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _PickerColumn(
                        label: l10n.translate('calorieOnboarding_weight_label'),
                        value: _weightKg,
                        min: 30,
                        max: 200,
                        unit: l10n.translate('unit_kg'),
                        onChanged: (v) => setState(() => _weightKg = v),
                        labelPaddingLeft: 41,
                      ),
                    ),
                  ],
                )
              else ...[
                // Labels row: Height over first two columns, Weight over last column
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 76),
                        child: Text(
                          l10n.translate('calorieOnboarding_height_label'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          l10n.translate('calorieOnboarding_weight_label'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PickerColumn(
                        label: '',
                        value: _heightFt,
                        min: 2,
                        max: 7,
                        unit: l10n.translate('unit_ft'),
                        onChanged: (v) => setState(() => _heightFt = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerColumn(
                        label: '',
                        value: _heightIn,
                        min: 0,
                        max: 11,
                        unit: l10n.translate('unit_in'),
                        onChanged: (v) => setState(() => _heightIn = v),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _PickerColumn(
                        label: '',
                        value: _weightLb,
                        min: 80,
                        max: 300,
                        unit: l10n.translate('unit_lb'),
                        onChanged: (v) => setState(() => _weightLb = v),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFed3272), // Brand pink
                    Color(0xFFfd5d32), // Brand orange
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: ElevatedButton(
              onPressed: () {
                final heightCm = _metric ? _heightCm : _cmFromFtIn(_heightFt, _heightIn);
                final weightKg = _metric ? _weightKg : _kgFromLb(_weightLb);
                
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GoalSelectionScreen(
                      activity: widget.activity,
                      heightCm: heightCm,
                      weightKg: weightKg,
                      isMetric: _metric,
                      isOnboarding: widget.isOnboarding,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Text(
                l10n.translate('calorieOnboarding_next'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerColumn extends StatelessWidget {
  const _PickerColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
    this.min = 0,
    this.max = 250,
    this.isSmallLabel = false,
    this.labelPaddingLeft,
  });

  final String label;
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool isSmallLabel;
  final double? labelPaddingLeft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(left: labelPaddingLeft ?? 0),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 200,
          child: ListWheelScrollView.useDelegate(
            controller: FixedExtentScrollController(initialItem: value),
            onSelectedItemChanged: (i) => onChanged(i),
            physics: const FixedExtentScrollPhysics(),
            itemExtent: 36,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < min || index > max) return null;
                final selected = index == value;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFAE6EC) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '$index $unit',
                      style: TextStyle(
                        fontSize: selected ? 20 : 18,
                        color: selected ? Colors.black : Colors.grey.shade400,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}


