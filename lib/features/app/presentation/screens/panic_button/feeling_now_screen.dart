import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/navigation/page_transitions.dart';
import '../main_scaffold.dart';
import 'congratulations_screen.dart';
import 'try_something_else_screen.dart';

class PanicFeelingNowScreen extends StatefulWidget {
  final Widget nextScreen;
  const PanicFeelingNowScreen({super.key, required this.nextScreen});

  static const String screenName = 'FeelingNowScreen';

  @override
  State<PanicFeelingNowScreen> createState() => _PanicFeelingNowScreenState();
}

class _PanicFeelingNowScreenState extends State<PanicFeelingNowScreen> {
  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('PageView: Panic Button Feeling Now');
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
                const SizedBox(height: 78),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    l10n.translate('panicFeelingNow_title'),
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
                        'assets/images/lotties/panicButton/doctorMagnifyingGlass.json',
                        width: 450,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
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
                              'Button Tap: Panic Button Feeling Now Feeling Better',
                            );
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const CongratulationsScreen(),
                                settings: const RouteSettings(name: '/panic_congrats'),
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
                            l10n.translate('panicFeelingNow_button_feelingBetter'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          MixpanelService.trackButtonTap(
                            'Button Tap: Panic Button Feeling Now Need More Help',
                          );
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => widget.nextScreen,
                              settings: RouteSettings(name: '/panic_next_trick_from_feeling_now_${widget.nextScreen.runtimeType}'),
                            ),
                          );
                        },
                        child: Text(
                          l10n.translate('panicFeelingNow_button_needMoreHelp'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
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
                  color: Color(0xFFE5E5E5),
                  size: 30.0,
                ),
                onPressed: () {
                  MixpanelService.trackButtonTap(
                    'Button Tap: Close Panic Button Feeling Now',
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