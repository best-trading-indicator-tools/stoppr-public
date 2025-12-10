import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/navigation/page_transitions.dart';
import '../../widgets/info_modal.dart';
import 'congratulations_screen.dart';
import 'feeling_now_screen.dart';
import 'other_trick_screen.dart';
import 'brush_teeth_screen.dart';
import '../main_scaffold.dart';
import '../../../services/panic_flow_manager.dart';

class PanicEatSaltyScreen extends StatefulWidget {
  const PanicEatSaltyScreen({super.key});

  static const String screenName = 'Panic Button EatSaltyScreen';

  @override
  State<PanicEatSaltyScreen> createState() => _PanicEatSaltyScreenState();
}

class _PanicEatSaltyScreenState extends State<PanicEatSaltyScreen> {
  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView(PanicEatSaltyScreen.screenName);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final saltyOptions = [
      _SaltyOption(
        name: l10n.translate('panicEatSalty_avocado'),
        imagePath: 'assets/images/panic_button/avocado_icon.png',
      ),
      _SaltyOption(
        name: l10n.translate('panicEatSalty_cheeseDices'),
        imagePath: 'assets/images/panic_button/cheese_icon.png',
      ),
      _SaltyOption(
        name: l10n.translate('panicEatSalty_tuna'),
        imagePath: 'assets/images/panic_button/tuna_icon.png',
      ),
      _SaltyOption(
        name: l10n.translate('panicEatSalty_omelet'),
        imagePath: 'assets/images/panic_button/eggs_icon.png',
      ),
      _SaltyOption(
        name: l10n.translate('panicEatSalty_hummus'),
        imagePath: 'assets/images/panic_button/hummus_icon.png',
      ),
      _SaltyOption(
        name: l10n.translate('panicEatSalty_pickles'),
        imagePath: 'assets/images/panic_button/pickles_icon.png',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48.0),
                    child: Text(
                      l10n.translate('panicEatSalty_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 35/32, // Line height 35px / font size 32px
                        letterSpacing: -0.41,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48.0),
                    child: Text(
                      l10n.translate('panicEatSalty_subtitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimationLimiter(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 0.0,
                        mainAxisSpacing: 0.0,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: saltyOptions.length,
                      itemBuilder: (context, index) {
                        final option = saltyOptions[index];
                        return AnimationConfiguration.staggeredGrid(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          columnCount: 2,
                          child: ScaleAnimation(
                            child: FadeInAnimation(
                              child: _SaltyOptionCard(option: option),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                                'Button Tap: Panic Button Eat Salty',
                                screenName: PanicEatSaltyScreen.screenName,
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              l10n.translate('panicEatSalty_button_didIt'),
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            MixpanelService.trackButtonTap(
                              'Button Tap: Panic Button Eat Salty Feeling Better',
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
                              fontSize: 15,
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
            ),
            Positioned(
              top: 16.0,
              right: 16.0,
              child: InkWell(
                onTap: () {
                  MixpanelService.trackButtonTap(
                    'Button Tap: Panic Button Eat Salty InfoModal',
                  );
                  showInfoModalBottomSheet(
                    context: context,
                    imageAssetPath: 'assets/images/panic_button/salty_food_modal_icon.png',
                    titleKey: 'panicModal_salty_title',
                    descriptionKey: 'panicModal_salty_description',
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
                      fontWeight: FontWeight.w500, // closest to 510
                      height: 22/24, // 91.667%
                      letterSpacing: -0.408,
                      color: Colors.white,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10.0,
              left: 16.0,
              child: InkWell(
                onTap: () {
                  MixpanelService.trackButtonTap(
                    'Button Tap: Close Panic Button Eat Salty',
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
          ],
        ),
      ),
    );
  }
}

class _SaltyOption {
  final String name;
  final String imagePath;

  _SaltyOption({required this.name, required this.imagePath});
}

class _SaltyOptionCard extends StatelessWidget {
  final _SaltyOption option;

  const _SaltyOptionCard({Key? key, required this.option}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              option.imagePath,
              height: 52,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 32.0,
              child: Text(
                option.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 0.9, // 90% line height
                  letterSpacing: 0.0,
                  color: Color(0xFFA1A1AA),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 