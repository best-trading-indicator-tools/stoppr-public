import 'package:flutter/material.dart';
import 'dart:async';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/nutrition/data/models/body_profile.dart';
import 'package:stoppr/features/nutrition/data/models/weight_entry.dart';
import 'package:stoppr/features/nutrition/data/repositories/nutrition_repository.dart';

class BmiInfoScreen extends StatefulWidget {
  const BmiInfoScreen({super.key});

  @override
  State<BmiInfoScreen> createState() => _BmiInfoScreenState();
}

class _BmiInfoScreenState extends State<BmiInfoScreen> {
  final _repo = NutritionRepository();
  BodyProfile? _profile;
  WeightEntry? _latestWeight;
  StreamSubscription<BodyProfile?>? _profileSub;
  StreamSubscription<WeightEntry?>? _weightSub;

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('BMI Info Screen');
    _profileSub = _repo.getBodyProfile().listen((p) {
      if (!mounted) return;
      setState(() => _profile = p);
    });
    _weightSub = _repo.streamLatestWeight().listen((w) {
      if (!mounted) return;
      setState(() => _latestWeight = w);
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _weightSub?.cancel();
    super.dispose();
  }

  double? _computeBmi() {
    final h = _profile?.heightCm;
    final w = _latestWeight?.weightKg;
    if (h == null || w == null || h <= 0) return null;
    final m = h / 100.0;
    return w / (m * m);
  }

  String _bmiStatus(double bmi) {
    if (bmi < 18.5) {
      return AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_underweight');
    } else if (bmi < 25) {
      return AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_healthy');
    } else if (bmi < 30) {
      return AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_overweight');
    } else {
      return AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_obese');
    }
  }

  // Map BMI (approx 15..40) to 0..1 for marker position on gradient bar
  double _bmiPosition(double bmi) {
    const min = 15.0;
    const max = 40.0;
    final clamped = bmi.clamp(min, max);
    return ((clamped - min) / (max - min)).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final bmi = _computeBmi();
    final status = bmi == null ? '' : _bmiStatus(bmi);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      MixpanelService.trackButtonTap('BMI Info Screen: Back Button');
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.translate('calorieTracker_bmi'),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (bmi != null) ...[
                Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.translate('bmiScreen_yourWeightIs'),
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F8EA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(bmi.toStringAsFixed(1), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _BmiGradientBar(position: _bmiPosition(bmi)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Legend(text: AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_underweight'), color: const Color(0xFF1E90FF)),
                    _Legend(text: AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_healthy'), color: const Color(0xFF00C853)),
                    _Legend(text: AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_overweight'), color: const Color(0xFFFFC107)),
                    _Legend(text: AppLocalizations.of(context)!.translate('calorieTracker_bmi_status_obese'), color: const Color(0xFFFF5252)),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              Text(
                AppLocalizations.of(context)!.translate('bmiScreen_disclaimerTitle'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.translate('bmiScreen_disclaimerParagraph'),
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.translate('bmiScreen_whyMatterTitle'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.translate('bmiScreen_whyMatterParagraph'),
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BmiGradientBar extends StatelessWidget {
  const _BmiGradientBar({required this.position});
  final double position; // 0..1

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E90FF), Color(0xFF00C853), Color(0xFFFFC107), Color(0xFFFF5252)]),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        Positioned(
          left: (MediaQuery.of(context).size.width - 40) * position, // padding accounted roughly
          top: 0,
          bottom: 0,
          child: Container(width: 2, color: Colors.black),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}


