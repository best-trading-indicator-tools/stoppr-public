import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/localization/app_localizations.dart';

class BreathingExercisePanicScreen extends StatelessWidget {
  const BreathingExercisePanicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // White background with dark status-bar icons
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark, // Black icons on iOS/Android
        statusBarBrightness: Brightness.light, // For iOS (opposite naming)
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      icon: Image.asset(
                        'assets/images/panic_button/question_mark_panic.png',
                        width: 32,
                        height: 32,
                      ),
                      onPressed: null, // No action as per instructions
                    ),
                  ),
                ),
              ),
              // Top pill label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  l10n.translate('panicBreathingScreen_breathe3times'),
                  style: const TextStyle(
                    color: Color(0xFF0E223D),
                    fontWeight: FontWeight.w700,
                    fontFamily: 'ElzaRound',
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Center(
                  child: LottieBuilder.asset(
                    'assets/images/lotties/panicButton/respirationV2.json',
                    repeat: true,
                    animate: true,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 