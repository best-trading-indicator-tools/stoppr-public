import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class EditWeightScreen extends StatefulWidget {
  const EditWeightScreen({super.key, this.initialKg});

  final double? initialKg;

  @override
  State<EditWeightScreen> createState() => _EditWeightScreenState();
}

class _EditWeightScreenState extends State<EditWeightScreen> {
  final _repo = NutritionRepository();
  bool _isMetric = true; // Metric default
  late double _kg; // canonical value
  late double _goalKg; // goal weight
  bool _saving = false;

  // Ranges
  static const double _minKg = 30.0;
  static const double _maxKg = 200.0;

  @override
  void initState() {
    super.initState();
    _kg = (widget.initialKg ?? 70.0).clamp(_minKg, _maxKg);
    _goalKg = _kg; // Default goal to current weight
    MixpanelService.trackPageView('Edit Weight Screen');
    _loadGoalWeight();
  }

  bool _hasExistingGoal = false;
  
  void _loadGoalWeight() async {
    final profile = await _repo.getBodyProfile().first;
    if (profile?.goalWeightKg != null && mounted) {
      setState(() {
        _goalKg = profile!.goalWeightKg!.clamp(_minKg, _maxKg);
        _hasExistingGoal = true; // Mark that user has an existing goal
      });
    }
  }

  double get _displayValue => _isMetric ? _kg : _kg * 2.20462;
  String get _displayUnit => _isMetric ? 'kg' : 'lbs';
  double get _displayMin => _isMetric ? _minKg : _minKg * 2.20462;
  double get _displayMax => _isMetric ? _maxKg : _maxKg * 2.20462;

  double get _goalDisplayValue => _isMetric ? _goalKg : _goalKg * 2.20462;

  // Clean up floating point precision to 1 decimal
  double _snapDisplayValue(double v) {
    return double.parse(v.toStringAsFixed(1));
  }

  void _onDisplayChanged(double v) {
    // Exact 0.1 precision
    final double snapped = _snapDisplayValue(v);
    setState(() {
      _kg = _isMetric ? snapped : snapped / 2.20462;
    });
  }

  void _onGoalChanged(double v) {
    // Exact 0.1 precision
    final double snapped = _snapDisplayValue(v);
    setState(() {
      _goalKg = _isMetric ? snapped : snapped / 2.20462;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fraction across the ruler (0.0 -> left, 1.0 -> right)
    final double _valueFraction = ((_displayValue - _displayMin) /
            (_displayMax - _displayMin))
        .clamp(0.0, 1.0);
    final double _goalFraction = ((_goalDisplayValue - _displayMin) /
            (_displayMax - _displayMin))
        .clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - Fixed size
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Color(0xFF1A1A1A),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.translate('calorieTracker_editWeight'),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Unit Toggle - Fixed size
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.translate('calorieTracker_imperial'),
                        style: TextStyle(
                          fontSize: 18,
                          color: _isMetric
                              ? const Color(0xFF8E8E93)
                              : Colors.black,
                          fontWeight:
                              _isMetric ? FontWeight.w600 : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Transform.scale(
                        scale: 1.2,
                        child: CupertinoSwitch(
                          value: _isMetric,
                          onChanged: (v) async {
                            setState(() {
                              // Convert the current weight when switching units
                              if (v != _isMetric) {
                                // Values remain the same in kg (canonical), display changes
                                _isMetric = v;
                              }
                            });
                            final prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setBool('weight_unit_metric', _isMetric);
                          },
                          activeColor: const Color(0xFFed3272),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        AppLocalizations.of(context)!.translate('calorieTracker_metric'),
                        style: TextStyle(
                          fontSize: 18,
                          color: _isMetric
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFF8E8E93),
                          fontWeight:
                              _isMetric ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Expandable section for current weight
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.translate('calorieTracker_currentWeight'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _displayValue.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2.0,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          TextSpan(
                            text: ' ${_displayUnit}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Ruler section - Expanded (moved slightly up by adjusting surrounding flex)
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(double.infinity, 100),
                      painter: _CenteredRulerPainter(),
                    ),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (details) {
                          // Reduce sensitivity by factor of 3
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final double width = box.size.width;
                          final double delta = details.delta.dx / width * (_displayMax - _displayMin) / 3;
                          final double newValue = (_displayValue + delta).clamp(_displayMin, _displayMax);
                          _onDisplayChanged(newValue);
                        },
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 0,
                            activeTrackColor: Colors.transparent,
                            inactiveTrackColor: Colors.transparent,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 0,
                            ),
                            overlayShape: SliderComponentShape.noThumb,
                          ),
                          child: IgnorePointer(
                            child: Slider(
                              min: _displayMin,
                              max: _displayMax,
                              divisions:
                                  ((_displayMax - _displayMin) * 10).toInt(),
                              value: _displayValue
                                  .clamp(_displayMin, _displayMax),
                              onChanged: null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: true,
                      child: Align(
                        alignment: Alignment(
                          -1.0 + (_valueFraction * 2.0),
                          0,
                        ),
                        child: Container(
                          width: 3,
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color(0xFFed3272),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Goal weight section - Expanded
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.translate('calorieTracker_goalWeightLabel'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _goalDisplayValue.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          TextSpan(
                            text: ' ${_displayUnit}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    // Goal weight ruler selector (same interaction as current weight)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                      child: SizedBox(
                        height: 72,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(double.infinity, 64),
                              painter: _CenteredRulerPainter(),
                            ),
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onPanUpdate: (details) {
                                  // Reduce sensitivity by factor of 3
                                  final RenderBox box = context.findRenderObject() as RenderBox;
                                  final double width = box.size.width;
                                  final double delta = details.delta.dx / width * (_displayMax - _displayMin) / 3;
                                  final double newValue = (_goalDisplayValue + delta).clamp(_displayMin, _displayMax);
                                  _onGoalChanged(newValue);
                                },
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 0,
                                    activeTrackColor: Colors.transparent,
                                    inactiveTrackColor: Colors.transparent,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 0,
                                    ),
                                    overlayShape: SliderComponentShape.noThumb,
                                  ),
                                  child: IgnorePointer(
                                    child: Slider(
                                      min: _displayMin,
                                      max: _displayMax,
                                      divisions: ((_displayMax - _displayMin) * 10).toInt(),
                                      value: _goalDisplayValue
                                          .clamp(_displayMin, _displayMax),
                                      onChanged: null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              ignoring: true,
                              child: Align(
                                alignment: Alignment(
                                  -1.0 + (_goalFraction * 2.0),
                                  0,
                                ),
                                child: Container(
                                  width: 3,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFed3272),
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Save button - Fixed at bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SizedBox(
                height: 60,
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
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFed3272).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            try {
                              // Save current weight entry
                              await _repo.addWeightEntry(_kg);
                              
                              // Only save goal weight if:
                              // 1. User already had a goal weight (preserve/update existing), OR
                              // 2. User explicitly set a goal different from their current weight
                              if (_hasExistingGoal || _goalKg != _kg) {
                                await _repo.saveGoalWeight(_goalKg);
                              }
                              
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setDouble('last_weight_kg', _kg);
                              await prefs.setBool('weight_unit_metric', _isMetric);
                              MixpanelService.trackButtonTap('Log Weight Save', screenName: 'Edit Weight');
                              if (mounted) Navigator.pop(context, true);
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                    child: Text(
                      _saving 
                        ? AppLocalizations.of(context)!.translate('calorieTracker_saving') 
                        : AppLocalizations.of(context)!.translate('calorieTracker_saveChanges'), 
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 20, 
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
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
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({required this.min, required this.max});
  final double min;
  final double max;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87..strokeWidth = 1;
    final big = 24.0;
    final med = 16.0;
    final small = 8.0;
    final total = max - min;
    if (total <= 0) return;
    final step = size.width / total; // 1 unit per step
    for (double v = 0; v <= total; v += 1) {
      final x = v * step;
      final isBig = (v % 10 == 0);
      final isMed = (v % 5 == 0) && !isBig;
      final h = isBig ? big : (isMed ? med : small);
      canvas.drawLine(Offset(x, size.height), Offset(x, size.height - h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _CenteredRulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2;

    const double leftPadding = 12;
    const double rightPadding = 12;
    final double usableWidth = size.width - leftPadding - rightPadding;
    if (usableWidth <= 0) return;

    const double small = 12;
    const double medium = 24;
    const double big = 36;
    const double spacing = 8; // visual tick spacing in px

    final int ticks = (usableWidth / spacing).floor();
    final double centerX = size.width / 2;

    for (int i = 0; i <= ticks; i++) {
      final double x = leftPadding + i * spacing;

      // Skip drawing the center tick; the marker widget draws it
      if ((x - centerX).abs() < 0.5) continue;

      final bool isBig = i % 10 == 0;
      final bool isMed = i % 5 == 0 && !isBig;
      final double h = isBig ? big : (isMed ? medium : small);
      
      // Use thicker strokes for bigger ticks
      final strokeWidth = isBig ? 3.0 : (isMed ? 2.5 : 2.0);
      paint.strokeWidth = strokeWidth;

      canvas.drawLine(
        Offset(x, size.height - 15),
        Offset(x, size.height - 15 - h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

