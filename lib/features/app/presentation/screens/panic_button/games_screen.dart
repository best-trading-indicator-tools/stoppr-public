import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/congratulations_screen.dart';
import 'package:stoppr/features/app/presentation/screens/panic_button/feeling_now_screen.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:stoppr/features/app/services/panic_flow_manager.dart';

class PanicGamesScreen extends StatefulWidget {
  const PanicGamesScreen({super.key});

  static const String screenName = 'TrickGamesScreen';

  @override
  State<PanicGamesScreen> createState() => _PanicGamesScreenState();
}

class _PanicGamesScreenState extends State<PanicGamesScreen> {
  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('PageView: Panic Button ${PanicGamesScreen.screenName}');
  }

  // Open Gamezop games with robust fallback to external browser on iOS
  Future<void> _openGames() async {
    final Uri url = Uri.parse('https://10836.play.gamezop.com');
    try {
      if (await canLaunchUrl(url)) {
        try {
          await launchUrl(url, mode: LaunchMode.inAppWebView);
          return;
        } on PlatformException catch (e) {
          debugPrint('PlatformException launching games URL: \\${e.message}');
        } catch (e) {
          debugPrint('Error launching games URL (inAppWebView): \\${e.toString()}');
        }

        // Fallback: open in external browser if in-app fails
        try {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        } catch (e) {
          debugPrint('Error launching games URL (externalApplication): \\${e.toString()}');
        }
      }
    } catch (e) {
      debugPrint('Unexpected error before launching games URL: \\${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 10.0,
              left: 16.0,
              child: InkWell(
                onTap: () {
                  MixpanelService.trackButtonTap(
                    'Button Tap: Close Panic Button ${PanicGamesScreen.screenName}',
                  );
                  bool foundHome = false;
                  try {
                    Navigator.popUntil(context, (route) {
                      if (route.settings.name == '/home' || route.settings.name == '/' || route.isFirst) {
                        foundHome = true;
                        return true;
                      }
                      return false;
                    });
                  } catch (_) {
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 86,
                    height: 86,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 4.0,
                      ),
                    ),
                    child: Lottie.asset(
                      'assets/images/lotties/panicButton/doctorDeskBook.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Text(
                    l10n.translate('panicTrickGames_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    l10n.translate('panicTrickGames_subtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Lottie.asset(
                          'assets/images/lotties/CuteAnimalGames.json',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Special gradient Play Now button with enhanced glow
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFed3272), // Strong pink/magenta
                                Color(0xFFfd5d32), // Vivid orange
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(35),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFed3272).withOpacity(0.4),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: const Color(0xFFfd5d32).withOpacity(0.3),
                                blurRadius: 35,
                                offset: const Offset(0, 15),
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              MixpanelService.trackButtonTap(
                                'Button Tap: Panic Button ${PanicGamesScreen.screenName} Play Now',
                              );
                              await _openGames();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(35),
                              ),
                            ),
                            child: Text(
                              l10n.translate('panicTrickGames_button_playNow'),
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Regular Continue button
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
                              'Button Tap: Panic Button ${PanicGamesScreen.screenName} Continue',
                            );
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => PanicFlowManager.getNextScreen(),
                                settings: const RouteSettings(name: '/panic_feeling_now'),
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
                            l10n.translate('panicTrickGames_button_nextExercise'),
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
                            'Button Tap: Panic Button ${PanicGamesScreen.screenName} Feeling Better',
                          );
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const CongratulationsScreen(),
                              settings: const RouteSettings(name: '/panic_congrats'),
                            ),
                          );
                        },
                        child: Text(
                          l10n.translate('panicWhatHappening_button_feelingBetter'),
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
          ],
        ),
      ),
    );
  }
}


