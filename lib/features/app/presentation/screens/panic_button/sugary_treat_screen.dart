import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/navigation/page_transitions.dart';
import '../../widgets/info_modal.dart';
import 'feeling_now_screen.dart';
import 'congratulations_screen.dart';
import 'try_something_else_screen.dart';
import '../main_scaffold.dart';

class PanicSugaryTreatScreen extends StatefulWidget {
  const PanicSugaryTreatScreen({super.key});

  static const String screenName = 'SugaryTreatScreen';

  @override
  State<PanicSugaryTreatScreen> createState() => _PanicSugaryTreatScreenState();
}

class _PanicSugaryTreatScreenState extends State<PanicSugaryTreatScreen> {
  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('PageView: Panic Button Sugary Treat');
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
                    'Button Tap: Close Panic Button Sugary Treat',
                  );
                  bool popped = false;
                  Navigator.popUntil(context, (route) {
                    if (route.settings.name == '/home') {
                      popped = true;
                      return true;
                    }
                    return false;
                  });
                  if (!popped) {
                    Navigator.of(context).pushAndRemoveUntil(
                      TopToBottomPageRoute(
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
                const SizedBox(height: 80),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                      children: [
                        TextSpan(text: l10n.translate('panicSugaryTreat_title_part1')),
                        TextSpan(
                          text: l10n.translate('panicSugaryTreat_title_part2'),
                          style: const TextStyle(decoration: TextDecoration.underline),
                        ),
                        TextSpan(text: l10n.translate('panicSugaryTreat_title_part3')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60.0),
                  child: Text(
                    l10n.translate('panicSugaryTreat_subtitle'),
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
                  child: Lottie.asset(
                    'assets/images/lotties/panicButton/DoctorCheckMarlSign.json',
                    fit: BoxFit.contain,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  child: ElevatedButton(
                    onPressed: () {
                      MixpanelService.trackButtonTap(
                        'Button Tap: Panic Button Sugary Treat',
                      );
                      Navigator.of(context).pushAndRemoveUntil(
                        TopToBottomPageRoute(
                          child: const MainScaffold(
                            initialIndex: 0,
                            fromCongratulations: true,
                          ),
                          settings: const RouteSettings(name: '/home_panic_exit'),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5E7EB),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      l10n.translate('panicSugaryTreat_button_continue'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    'Button Tap: Panic Button Sugary Treat InfoModal',
                  );
                  showInfoModalBottomSheet(
                    context: context,
                    imageAssetPath: 'assets/images/panic_button/cookie_modal_icon.png',
                    titleKey: 'panicModal_sugaryTreat_title',
                    descriptionKey: 'panicModal_sugaryTreat_description',
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