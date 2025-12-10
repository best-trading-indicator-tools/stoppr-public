import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/navigation/page_transitions.dart';
import '../main_scaffold.dart';
import '../../../../../core/utils/text_sanitizer.dart';
import 'congratulations_screen.dart';
import 'tricks_intro_screen.dart';

import '../../../../../core/localization/app_localizations.dart';

class WhatHappeningScreen extends StatefulWidget {
  const WhatHappeningScreen({Key? key}) : super(key: key);

  static const String screenName = 'WhatHappeningScreen';

  @override
  State<WhatHappeningScreen> createState() => _WhatHappeningScreenState();
}

class _WhatHappeningScreenState extends State<WhatHappeningScreen> {
  String? _firstName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('PageView: Panic Button WhatsHappening');
    _loadFirstName();
  }

  Future<void> _loadFirstName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_first_name');
    if (mounted) {
      setState(() {
        _firstName = name;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String firstNameText = (_firstName == null || _firstName!.isEmpty)
        ? ''
        : TextSanitizer.sanitizeForDisplay(_firstName!);
    final titleText = l10n
        .translate('panicWhatHappening_title')
        .replaceAll('{firstName}', firstNameText);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 78),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          titleText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'ElzaRound',
                            color: Color(0xFF1A1A1A),
                            height: 44 / 34, // 1.294117647
                            letterSpacing: -0.41,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Center(
                          child: Transform.scale(
                            scale: 1.2,
                            child: Lottie.asset(
                              'assets/images/lotties/panicButton/doctorThinking.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
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
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  MixpanelService.trackButtonTap(
                                    'Button Tap: Panic Button WhatsHappening',
                                  );
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const PanicTricksIntroScreen(),
                                      settings: const RouteSettings(name: '/panic_tricks_intro'),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  l10n.translate(
                                      'panicWhatHappening_button_hungrySugaryFoods'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontFamily: 'ElzaRound',
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.41,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                MixpanelService.trackButtonTap(
                                  'Button Tap: Panic Button WhatsHappening Feeling Better',
                                );
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const CongratulationsScreen(),
                                    settings: const RouteSettings(name: '/panic_congrats'),
                                  ),
                                );
                              },
                              child: Text(
                                l10n.translate(
                                    'panicWhatHappening_button_feelingBetter'),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.0,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 16.0,
                    left: 16.0,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Color(0xFF666666),
                        size: 30.0,
                      ),
                      onPressed: () {
                        MixpanelService.trackButtonTap(
                          'Button Tap: Close Panic Button WhatsHappening',
                        );
                        
                                                 // Try to pop until we find the home route
                         bool foundHome = false;
                         try {
                           Navigator.popUntil(context, (route) {
                             // Check for home route by name, if it's the first route, or if it looks like a main route
                             if (route.settings.name == '/home' || 
                                 route.settings.name == '/' ||
                                 route.isFirst) {
                               foundHome = true;
                               return true;
                             }
                             return false;
                           });
                         } catch (e) {
                           // If popUntil fails (no matching route found), foundHome will remain false
                           foundHome = false;
                         }
                        
                                                 // If we couldn't find home in the stack, navigate to it with bottom-to-top animation
                         // This creates the visual effect of the current screen sliding out top-to-bottom
                         if (!foundHome) {
                           Navigator.of(context).pushAndRemoveUntil(
                             BottomToTopDismissPageRoute(
                               child: const MainScaffold(initialIndex: 0),
                               settings: const RouteSettings(name: '/home'),
                             ),
                             (route) => false,
                           );
                         }
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
} 