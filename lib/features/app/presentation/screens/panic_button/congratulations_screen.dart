import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/navigation/page_transitions.dart';
import '../../../../../core/services/in_app_review_service.dart';
import 'breathing_animation_screen.dart';
import '../../screens/main_scaffold.dart';

class CongratulationsScreen extends StatefulWidget {
  const CongratulationsScreen({Key? key}) : super(key: key);

  static const String screenName = 'Panic Button CongratulationsScreen';

  @override
  State<CongratulationsScreen> createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends State<CongratulationsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fireworksController;
  final InAppReviewService _reviewService = InAppReviewService();

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView(CongratulationsScreen.screenName);
    _fireworksController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _fireworksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    l10n.translate('panicCongrats_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Text(
                        l10n.translate('panicCongrats_line1'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Icon(Icons.arrow_downward, color: Color(0xFF666666)),
                      const SizedBox(height: 4),
                      Text(
                        l10n.translate('panicCongrats_line2'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: Transform.scale(
                      scale: 1.2,
                      child: Lottie.asset(
                        'assets/images/lotties/panicButton/doctorApplauds.json',
                        width: 400,
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
                          onPressed: () async {
                            MixpanelService.trackButtonTap(
                              'Button Tap: Panic Button \\${CongratulationsScreen.screenName} panicCongrats_button_continue',
                              screenName: CongratulationsScreen.screenName,
                            );
                            await _reviewService.requestReviewIfAppropriate(screenName: CongratulationsScreen.screenName);

                            if (!mounted) return;

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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            l10n.translate('panicCongrats_button_continue'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Fireworks overlay - positioned outside SafeArea for true full screen coverage
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Lottie.asset(
                'assets/images/lotties/panicButton/FireworksGreen.json',
                controller: _fireworksController,
                fit: BoxFit.cover,
                onLoaded: (composition) {
                  _fireworksController
                    ..duration = composition.duration
                    ..forward();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
} 