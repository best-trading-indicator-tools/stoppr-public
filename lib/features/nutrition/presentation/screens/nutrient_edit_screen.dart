import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/nutrition/data/models/nutrition_goals.dart';
import 'package:stoppr/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:stoppr/features/nutrition/data/models/daily_summary.dart';
import 'dart:async';

/// Summary: Generic single-nutrient edit screen with gradient CTA and a
/// secondary Revert action that resets the value to 0.
class NutrientEditScreen extends StatefulWidget {
  const NutrientEditScreen({
    super.key,
    required this.nutrientLabelKey,
    this.unitKey,
    required this.initialValue,
  });

  final String nutrientLabelKey; // e.g. 'calorieTracker_sugar'
  final String? unitKey; // e.g. 'unit_g'; null -> no unit
  final double initialValue;

  @override
  State<NutrientEditScreen> createState() => _NutrientEditScreenState();
}

class _NutrientEditScreenState extends State<NutrientEditScreen> {
  late final TextEditingController _controller;
  final _repo = NutritionRepository();
  NutritionGoals? _goals;
  StreamSubscription<NutritionGoals?>? _goalsSub;
  DailySummary? _todaySummary;
  StreamSubscription<DailySummary?>? _summarySub;

  String _emojiForNutrientKey(String key) {
    switch (key) {
      case 'calorieTracker_protein':
        return '🥩';
      case 'calorieTracker_carbs':
        return '🌾';
      case 'calorieTracker_fat':
        return '🧈';
      case 'calorieTracker_fiber':
        return '🫐';
      case 'calorieTracker_sugar':
        return '🍬';
      case 'calorieTracker_sodium':
        return '🍚';
      default:
        return '🍽️';
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toStringAsFixed(0),
    );
    _goalsSub = _repo.getNutritionGoals().listen((g) {
      if (mounted) setState(() => _goals = g);
    });
    _summarySub = _repo.getDailySummary(DateTime.now()).listen((s) {
      if (mounted) setState(() => _todaySummary = s);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _goalsSub?.cancel();
    _summarySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nutrientName = l10n.translate(widget.nutrientLabelKey);
    final String unit = (widget.unitKey == null || widget.unitKey!.isEmpty)
        ? ''
        : l10n.translate(widget.unitKey!);
    final title = l10n
        .translate('profileScreen_editDialog_title')
        .replaceFirst('{field}', nutrientName);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        title: Text(title),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildRingWithProgress(
                        emoji: _emojiForNutrientKey(widget.nutrientLabelKey),
                        progress: _currentProgress(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          unit.isEmpty
                              ? _controller.text
                              : '${_controller.text}$unit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_leftTodayText(unit).isNotEmpty)
                    Text(
                      _leftTodayText(unit),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              autofocus: true,
              decoration: InputDecoration(
                labelText: nutrientName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFed3272), width: 2),
                ),
              ),
              cursorColor: const Color(0xFFed3272),
            onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 72),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _controller.text = '0');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      foregroundColor: const Color(0xFF1A1A1A),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    child: Text(l10n.translate('common_revert')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        final value = double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
                        Navigator.pop(context, value);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 19,
                        ),
                      ),
                      child: Text(l10n.translate('done')),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Helpers for progress ring
extension on _NutrientEditScreenState {
  String _leftTodayText(String unit) {
    final l10n = AppLocalizations.of(context)!;
    final goal = _goalForKey();
    if (goal <= 0) return '';
    final consumed = _consumedForKey();
    if (consumed > goal) {
      final over = (consumed - goal).clamp(0.0, double.infinity);
      final amountOver = unit.isEmpty ? over.toStringAsFixed(0) : '${over.toStringAsFixed(0)}$unit';
      final overT = l10n.translate('calorieTracker_overByToday');
      return overT.contains('{amount}')
          ? overT.replaceFirst('{amount}', amountOver)
          : '(${amountOver} over today)';
    }
    final left = (goal - consumed).clamp(0.0, double.infinity);
    final amount = unit.isEmpty ? left.toStringAsFixed(0) : '${left.toStringAsFixed(0)}$unit';
    final template = l10n.translate('calorieTracker_outOfLeftToday');
    return template.contains('{amount}') ? template.replaceFirst('{amount}', amount) : '($amount left today)';
  }

  double _goalForKey() {
    final g = _goals;
    switch (widget.nutrientLabelKey) {
      case 'calorieTracker_protein':
        return g?.protein ?? 150;
      case 'calorieTracker_carbs':
        return g?.carbs ?? 161;
      case 'calorieTracker_fat':
        return g?.fat ?? 46;
      case 'calorieTracker_fiber':
        return g?.fiber ?? 25;
      case 'calorieTracker_sugar':
        return g?.sugar ?? 25;
      case 'calorieTracker_sodium':
        return g?.sodium ?? 2300;
      default:
        return 100;
    }
  }

  double _currentValue() {
    return double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
  }

  double _consumedForKey() {
    final s = _todaySummary;
    if (s == null) return 0;
    switch (widget.nutrientLabelKey) {
      case 'calorieTracker_protein':
        return s.totalProtein;
      case 'calorieTracker_carbs':
        return s.totalCarbs;
      case 'calorieTracker_fat':
        return s.totalFat;
      case 'calorieTracker_fiber':
        return s.totalFiber;
      case 'calorieTracker_sugar':
        return s.totalSugar;
      case 'calorieTracker_sodium':
        return s.totalSodium;
      default:
        return 0;
    }
  }

  double _currentProgress() {
    final goal = _goalForKey();
    if (goal <= 0) return 0;
    return (_currentValue() / goal).clamp(0.0, 1.0);
  }

  Widget _buildRingWithProgress({required String emoji, required double progress}) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Track
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEFF1F5), width: 3),
            ),
          ),
          // Progress arc
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                strokeWidth: 3,
                trackColor: const Color(0x00000000),
                progressColor: const Color(0xFFed3272),
              ),
            ),
          ),
          // Inner emoji disk
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.strokeWidth, required this.trackColor, required this.progressColor});
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.57079632679, 6.28318530718, false, trackPaint);
    final sweep = 6.28318530718 * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.57079632679, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}


