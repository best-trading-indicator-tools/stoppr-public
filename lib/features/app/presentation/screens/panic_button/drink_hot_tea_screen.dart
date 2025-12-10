import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/navigation/page_transitions.dart';
import '../../widgets/info_modal.dart';
import 'feeling_now_screen.dart';
import 'congratulations_screen.dart';
import 'other_trick_screen.dart';
import 'dark_chocolate_screen.dart';
import '../main_scaffold.dart';
import '../../../services/panic_flow_manager.dart';

class PanicDrinkHotTeaScreen extends StatefulWidget {
  const PanicDrinkHotTeaScreen({super.key});

  static const String screenName = 'DrinkHotTeaScreen';

  @override
  State<PanicDrinkHotTeaScreen> createState() => _PanicDrinkHotTeaScreenState();
}

class _PanicDrinkHotTeaScreenState extends State<PanicDrinkHotTeaScreen> {
  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('PageView: Panic Button ${PanicDrinkHotTeaScreen.screenName}');
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
                    'Button Tap: Close Panic Button ${PanicDrinkHotTeaScreen.screenName}',
                  );
                  // Try to pop until we find the home route
                  bool foundHome = false;
                  try {
                    Navigator.popUntil(context, (route) {
                      if (route.settings.name == '/home' || route.settings.name == '/' || route.isFirst) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    l10n.translate('panicDrinkTea_title'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 72.0),
                  child: Text(
                    l10n.translate('panicDrinkTea_subtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Lottie.asset(
                    'assets/images/lotties/panicButton/TeaCup.json',
                    fit: BoxFit.contain,
                  ),
                ),
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
                              'Button Tap: Panic Button ${PanicDrinkHotTeaScreen.screenName} I Did it',
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
                            l10n.translate('panicDrinkTea_button_didIt'),
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
                            'Button Tap: Panic Button ${PanicDrinkHotTeaScreen.screenName} Feeling Better',
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
            Positioned(
              top: 16.0,
              right: 16.0,
              child: InkWell(
                onTap: () {
                  MixpanelService.trackButtonTap(
                    'Button Tap: Panic Button Drink Hot Tea InfoModal',
                  );
                  showInfoModalBottomSheet(
                    context: context,
                    imageAssetPath: 'assets/images/panic_button/hot_tea_modal_icon.png',
                    titleKey: 'panicModal_tea_title',
                    descriptionKey: 'panicModal_tea_description',
                    buttonTextKey: 'common_dismiss',
                  );
                },
                customBorder: const CircleBorder(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5E5E5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      height: 22/24,
                      letterSpacing: -0.408,
                      color: Colors.white,
                      fontStyle: FontStyle.normal,
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