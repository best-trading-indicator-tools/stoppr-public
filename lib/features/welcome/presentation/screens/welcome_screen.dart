import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../features/onboarding/presentation/screens/onboarding_page.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to onboarding page after a delay
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const OnboardingPage(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'STOPPR',
          style: TextStyle(
            fontFamily: 'ElzaRound',
            color: Colors.white,
            fontSize: 56.03,
            fontWeight: FontWeight.bold,
            height: 1.0, // 100% line height
            letterSpacing: -0.04 * 56.03, // -4% of font size
          ),
        ),
      ),
    );
  }
} 