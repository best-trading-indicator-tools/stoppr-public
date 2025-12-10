import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/navigation/page_transitions.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../main_scaffold.dart';
import 'what_happening_screen.dart';

class BreathingAnimationScreen extends StatefulWidget {
  const BreathingAnimationScreen({Key? key}) : super(key: key);

  static const String screenName = 'BreathingAnimationScreen';

  @override
  State<BreathingAnimationScreen> createState() => _BreathingAnimationScreenState();
}

class _BreathingAnimationScreenState extends State<BreathingAnimationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView(BreathingAnimationScreen.screenName);

    // Force status bar to be light for immersive experience
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    _lottieController = AnimationController(vsync: this);

    _lottieController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNextScreen();
      }
    });
  }

  void _navigateToNextScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const WhatHappeningScreen(),
        settings: const RouteSettings(name: '/what_happening_from_breathing'),
      ),
    );
  }

  void _navigateToHome() {
    bool foundHome = false;
    try {
      Navigator.popUntil(context, (route) {
        if (route.settings.name == '/home' || 
            route.settings.name == '/' ||
            route.isFirst) {
          foundHome = true;
          return true;
        }
        return false;
      });
    } catch (e) {
      foundHome = false;
    }
    if (!foundHome) {
      Navigator.of(context).pushAndRemoveUntil(
        BottomToTopDismissPageRoute(
          child: const MainScaffold(initialIndex: 0),
          settings: const RouteSettings(name: '/home'),
        ),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Full-screen breathing Lottie
            Positioned.fill(
              child: Lottie.asset(
                'assets/images/lotties/panicButton/Breathe.json',
                fit: BoxFit.contain,
                alignment: Alignment.center,
                controller: _lottieController,
                onLoaded: (composition) {
                  _lottieController
                    ..duration = composition.duration
                    ..forward();
                },
              ),
            ),
            // Close button (X) top left
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.grey[700], size: 30),
                onPressed: () {
                  MixpanelService.trackButtonTap(
                    'Breathing Animation Screen Close Tap',
                     screenName: BreathingAnimationScreen.screenName,
                  );
                  if (_lottieController.isAnimating) {
                    _lottieController.stop();
                  }
                  _navigateToHome();
                },
              ),
            ),
            // Skip button overlay
            Positioned(
              bottom: 30, // Adjusted padding from bottom
              left: 0,
              right: 0,
              child: Center(
                child: TextButton(
                  onPressed: () {
                    MixpanelService.trackButtonTap(
                      'Breathing Exercice Panic Button Skip Tap',
                      screenName: BreathingAnimationScreen.screenName,
                    );
                    if (_lottieController.isAnimating) {
                      _lottieController.stop();
                    }
                    _navigateToHome();
                  },
                  child: Text(
                    l10n.translate('panicBreathingScreen_button_skip'), // New localization key
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700], // Color for visibility on white background
                      fontFamily: 'ElzaRound',
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