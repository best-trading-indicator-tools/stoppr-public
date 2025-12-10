import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/features/nutrition/presentation/screens/log_exercice/run_exercise_setup_screen.dart';
import 'package:stoppr/features/nutrition/presentation/screens/log_exercice/weight_lifting_setup_screen.dart';
import 'package:stoppr/features/nutrition/presentation/screens/log_exercice/manual_exercise_setup_screen.dart';

class ExerciseTypeScreen extends StatelessWidget {
  const ExerciseTypeScreen({super.key, required this.targetDate});

  final DateTime targetDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    MixpanelService.trackPageView('Exercise Type Screen');
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A1A)),
          onPressed: () {
            MixpanelService.trackButtonTap('Exercise Type Back');
            Navigator.pop(context);
          },
        ),
        title: Text(
          l10n.translate('exerciseType_title'),
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildExerciseOption(
                context: context,
                icon: Icons.directions_run,
                title: l10n.translate('exerciseType_run'),
                subtitle: l10n.translate('exerciseType_runSubtitle'),
                onTap: () {
                  MixpanelService.trackButtonTap('Exercise Type: Run');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RunExerciseSetupScreen(
                        targetDate: targetDate,
                      ),
                      settings: const RouteSettings(name: '/run_exercise_setup'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildExerciseOption(
                context: context,
                icon: Icons.fitness_center,
                title: l10n.translate('exerciseType_weightLifting'),
                subtitle: l10n.translate('exerciseType_weightLiftingSubtitle'),
                onTap: () {
                  MixpanelService.trackButtonTap('Exercise Type: Weight Lifting');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => WeightLiftingSetupScreen(
                        targetDate: targetDate,
                      ),
                      settings: const RouteSettings(name: '/weight_lifting_setup'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildExerciseOption(
                context: context,
                icon: Icons.edit_outlined,
                title: l10n.translate('exerciseType_manual'),
                subtitle: l10n.translate('exerciseType_manualSubtitle'),
                onTap: () {
                  MixpanelService.trackButtonTap('Exercise Type: Manual');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ManualExerciseSetupScreen(
                        targetDate: targetDate,
                      ),
                      settings: const RouteSettings(name: '/manual_exercise_setup'),
                    ),
                  );
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      fontFamily: 'ElzaRound',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF666666),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Coming Soon!',
            style: TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          content: Text(
            '$feature will be available in a future update. Stay tuned!',
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w400,
              color: Color(0xFF666666),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}


