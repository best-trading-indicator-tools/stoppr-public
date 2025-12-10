import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/navigation/page_transitions.dart';
import 'congratulations_screen.dart'; // Assuming this is the next screen or a fallback
import 'eat_salty_screen.dart';
import '../main_scaffold.dart';
import '../../../services/panic_flow_manager.dart';

class PanicSomethingElseScreen extends StatefulWidget {
  const PanicSomethingElseScreen({super.key});

  static const String screenName = 'SomethingElseScreen';

  @override
  State<PanicSomethingElseScreen> createState() => _PanicSomethingElseScreenState();
}

class _PanicSomethingElseScreenState extends State<PanicSomethingElseScreen> {
  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('PageView: Panic Button Try Something Else');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 54),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    l10n.translate('panicSomethingElse_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: Transform.scale(
                      scale: 1.2,
                      child: Lottie.asset(
                        'assets/images/lotties/panicButton/doctorLaptopDesk.json',
                        width: 450,
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
                              'Button Tap: Panic Button Try Something Else',
                            );
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => PanicFlowManager.getNextTrickForConnector(),
                                settings: const RouteSettings(name: '/panic_trick_from_connector'),
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
                            l10n.translate('panicSomethingElse_button_letsDoIt'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // No secondary button on this screen as per the image provided
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 10.0,
              left: 16.0,
              child: InkWell(
                onTap: () {
                  MixpanelService.trackButtonTap(
                    'Button Tap: Close Panic Button Try Something Else',
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
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.close,
                    color: Color(0xFF666666),
                    size: 30,
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