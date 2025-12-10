import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/nutrition/data/repositories/nutrition_repository.dart';

class EditHeightScreen extends StatefulWidget {
  const EditHeightScreen({super.key, this.initialCm, this.currentGoalWeightKg});

  final double? initialCm;
  final double? currentGoalWeightKg;

  @override
  State<EditHeightScreen> createState() => _EditHeightScreenState();
}

class _EditHeightScreenState extends State<EditHeightScreen> {
  final _repo = NutritionRepository();
  bool _isMetric = true; // Metric default (cm / inches)
  late double _cm; // canonical value
  bool _saving = false;

  // Imperial values (feet and inches)
  int _heightFt = 5;
  int _heightIn = 7;

  static const double _minCm = 120.0;
  static const double _maxCm = 220.0;

  @override
  void initState() {
    super.initState();
    // Only use a default if the user is actually editing from the height screen
    // If no initial height is provided, start with a reasonable default but don't save it automatically
    _cm = (widget.initialCm ?? 165.0).clamp(_minCm, _maxCm);
    
    // Initialize imperial values from cm
    final totalInches = (_cm / 2.54).round();
    _heightFt = totalInches ~/ 12;
    _heightIn = totalInches % 12;
    
    MixpanelService.trackPageView('Edit Height Screen');
  }

  // Conversion helpers
  int _cmFromFtIn(int ft, int inches) => (ft * 30.48 + inches * 2.54).round();
  List<int> _ftInFromCm(int cm) {
    final totalIn = (cm / 2.54).round();
    final ft = totalIn ~/ 12;
    final inches = totalIn % 12;
    return [ft, inches];
  }

  double get _displayValue => _isMetric ? _cm : _cm / 2.54;
  String get _displayUnit => _isMetric ? 'cm' : 'in';
  double get _displayMin => _isMetric ? _minCm : _minCm / 2.54;
  double get _displayMax => _isMetric ? _maxCm : _maxCm / 2.54;

  void _onDisplayChanged(double v) {
    setState(() {
      _cm = _isMetric ? v : v * 2.54;
      // Update imperial values when cm changes
      if (!_isMetric) {
        final totalInches = v.round();
        _heightFt = totalInches ~/ 12;
        _heightIn = totalInches % 12;
      }
    });
  }

  void _onImperialChanged() {
    setState(() {
      _cm = _cmFromFtIn(_heightFt, _heightIn).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(AppLocalizations.of(context)!.translate('calorieTracker_editHeight'), style: const TextStyle(color: Color(0xFF1A1A1A))),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                ChoiceChip(
                  selected: _isMetric,
                  label: Text(
                    AppLocalizations.of(context)!.translate('calorieTracker_metric'),
                    style: TextStyle(color: _isMetric ? Colors.white : const Color(0xFF1A1A1A)),
                  ),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFFed3272),
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _isMetric ? const Color(0xFFed3272) : const Color(0xFFE0E0E0))),
                  onSelected: (v) {
                    if (!_isMetric) {
                      // Converting from imperial to metric - update _cm from current ft/in values
                      setState(() {
                        _cm = _cmFromFtIn(_heightFt, _heightIn).toDouble();
                        _isMetric = true;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  selected: !_isMetric,
                  label: Text(
                    AppLocalizations.of(context)!.translate('calorieTracker_imperial'),
                    style: TextStyle(color: !_isMetric ? Colors.white : const Color(0xFF1A1A1A)),
                  ),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFFed3272),
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: !_isMetric ? const Color(0xFFed3272) : const Color(0xFFE0E0E0))),
                  onSelected: (v) {
                    if (_isMetric) {
                      // Converting from metric to imperial - update ft/in from current _cm value
                      setState(() {
                        final totalInches = (_cm / 2.54).round();
                        _heightFt = totalInches ~/ 12;
                        _heightIn = totalInches % 12;
                        _isMetric = false;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_isMetric) ...[
            // Metric display and slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${_cm.toStringAsFixed(0)} ${AppLocalizations.of(context)!.translate('unit_cm')}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFed3272),
                inactiveTrackColor: const Color(0xFFE0E0E0),
                thumbColor: const Color(0xFFed3272),
                overlayColor: const Color(0xFFed3272).withValues(alpha: 0.12),
              ),
              child: Slider(
                min: _minCm,
                max: _maxCm,
                divisions: (_maxCm - _minCm).toInt(),
                value: _cm.clamp(_minCm, _maxCm),
                label: _cm.toStringAsFixed(0),
                onChanged: (v) => setState(() => _cm = v),
              ),
            ),
          ] else ...[
            // Imperial display and pickers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('$_heightFt ${AppLocalizations.of(context)!.translate('unit_ft')} $_heightIn ${AppLocalizations.of(context)!.translate('unit_in')}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _ImperialPicker(
                      label: AppLocalizations.of(context)!.translate('unit_ft'),
                      value: _heightFt,
                      min: 3,
                      max: 8,
                      unit: AppLocalizations.of(context)!.translate('unit_ft'),
                      onChanged: (v) {
                        _heightFt = v;
                        _onImperialChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _ImperialPicker(
                      label: AppLocalizations.of(context)!.translate('unit_in'),
                      value: _heightIn,
                      min: 0,
                      max: 11,
                      unit: AppLocalizations.of(context)!.translate('unit_in'),
                      onChanged: (v) {
                        _heightIn = v;
                        _onImperialChanged();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
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
                            // Persist preference for unit
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('height_unit_metric', _isMetric);
                            // Save height only (do not touch goal weight)
                            await _repo.saveHeight(_cm);
                            MixpanelService.trackButtonTap('Log Height Save', screenName: 'Edit Height');
                            if (mounted) Navigator.pop(context, true);
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  child: Text(_saving ? AppLocalizations.of(context)!.translate('calorieTracker_saving') : AppLocalizations.of(context)!.translate('calorieTracker_saveChanges'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImperialPicker extends StatelessWidget {
  const _ImperialPicker({
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
    this.min = 0,
    this.max = 12,
  });

  final String label;
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListWheelScrollView.useDelegate(
            controller: FixedExtentScrollController(initialItem: value - min),
            onSelectedItemChanged: (i) => onChanged(i + min),
            physics: const FixedExtentScrollPhysics(),
            itemExtent: 32,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                final itemValue = index + min;
                if (itemValue < min || itemValue > max) return null;
                final selected = itemValue == value;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFAE6EC) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$itemValue $unit',
                      style: TextStyle(
                        fontSize: selected ? 18 : 16,
                        color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF8E8E93),
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

