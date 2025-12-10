import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stoppr/features/onboarding/presentation/screens/choose_goals_onboarding.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/services/in_app_review_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:stoppr/core/subscription/post_purchase_handler.dart';

class SlideLeftRoute extends PageRouteBuilder {
  final Widget page;
  SlideLeftRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(-1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

class GiveUsRatingsScreen extends StatefulWidget {
  const GiveUsRatingsScreen({super.key});

  @override
  State<GiveUsRatingsScreen> createState() => _GiveUsRatingsScreenState();
}

class _GiveUsRatingsScreenState extends State<GiveUsRatingsScreen> {
  final OnboardingProgressService _progressService = OnboardingProgressService();
  final InAppReviewService _reviewService = InAppReviewService();

  @override
  void initState() {
    super.initState();
    _checkAndShowRatingPrompt();
    _saveCurrentScreen();
    MixpanelService.trackPageView('Onboarding Give Us Ratings Screen');
  }

  Future<void> _checkAndShowRatingPrompt() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _reviewService.requestReviewIfAppropriate(
          screenName: 'GiveUsRatingsScreen',
          bypassSubscriptionCheck: true,
        );
      });
    });
  }

  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.giveUsRatingsScreen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white background
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // White background branding
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          l10n.translate('ratings_title'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            color: Color(0xFF1A1A1A), // Dark text on white background
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 36),
                      Center(
                        child: Column(
                          children: [
                            SvgPicture.asset(
                              'assets/images/svg/stars_laurels.svg',
                              width: 200,
                              height: 80,
                            ),
                            const SizedBox(height: 46),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontFamily: 'ElzaRound',
                                  color: Color(0xFF1A1A1A), // Dark text on white background
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(text: '${l10n.translate('ratings_appDescription_part1')} '),
                                  TextSpan(
                                    text: l10n.translate('ratings_appDescription_bold'),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(text: '.\n\n${l10n.translate('ratings_appDescription_part2')}'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/ratings/3 people image.png',
                                  height: 32,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.translate('ratings_peopleCount'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    color: Color(0xFF666666), // Gray text for secondary content
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 34),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: _buildReviewContainer(
                          l10n.translate('ratings_testimonial_sarah_name'),
                          l10n.translate('ratings_testimonial_sarah_username'),
                          l10n.translate('ratings_testimonial_sarah_review'),
                          'assets/images/ratings/sarah_profile.png',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.topLeft,
                        child: _buildReviewContainer(
                          l10n.translate('ratings_testimonial_jacob_name'),
                          l10n.translate('ratings_testimonial_jacob_username'),
                          l10n.translate('ratings_testimonial_jacob_review'),
                          'assets/images/ratings/jacob_profile.png',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.topLeft,
                        child: _buildReviewContainer(
                          l10n.translate('ratings_testimonial_emily_name'),
                          l10n.translate('ratings_testimonial_emily_username'),
                          l10n.translate('ratings_testimonial_emily_review'),
                          'assets/images/ratings/emily_profile.png',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.topLeft,
                        child: _buildReviewContainer(
                          l10n.translate('ratings_testimonial_mark_name'),
                          l10n.translate('ratings_testimonial_mark_username'),
                          l10n.translate('ratings_testimonial_mark_review'),
                          'assets/images/ratings/mark_profile.png',
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.11),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                height: 110,
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: GestureDetector(
                      onTap: () async {
                        MixpanelService.trackEvent('Give Us Ratings Continue Button Tap');
                        try {
                          final handler = PaywallPresentationHandler();

                          handler.onDismiss((paywallInfo, paywallResult) async {
                            if (!mounted) return;
                            Navigator.of(context).pushReplacement(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    const ChooseGoalsOnboardingScreen(),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOutCubic;
                                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                  return SlideTransition(position: animation.drive(tween), child: child);
                                },
                                transitionDuration: const Duration(milliseconds: 400),
                              ),
                            );
                          });

                          handler.onError((error) async {
                            if (!mounted) return;
                            Navigator.of(context).pushReplacement(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    const ChooseGoalsOnboardingScreen(),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOutCubic;
                                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                  return SlideTransition(position: animation.drive(tween), child: child);
                                },
                                transitionDuration: const Duration(milliseconds: 400),
                              ),
                            );
                          });

                          handler.onSkip((skipReason) async {
                            if (!mounted) return;
                            Navigator.of(context).pushReplacement(
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    const ChooseGoalsOnboardingScreen(),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOutCubic;
                                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                  return SlideTransition(position: animation.drive(tween), child: child);
                                },
                                transitionDuration: const Duration(milliseconds: 400),
                              ),
                            );
                          });

                          await Superwall.shared.registerPlacement(
                            'INSERT_YOUR_SOFT_PAYWALL_PLACEMENT_ID_HERE',
                            handler: handler,
                            feature: () async {
                              await PostPurchaseHandler.handlePostPurchase(context);
                            },
                          );
                        } catch (_) {
                          if (!mounted) return;
                          Navigator.of(context).pushReplacement(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  const ChooseGoalsOnboardingScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
                                const curve = Curves.easeInOutCubic;
                                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                return SlideTransition(position: animation.drive(tween), child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 400),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFed3272), // Strong pink/magenta
                              Color(0xFFfd5d32), // Vivid orange
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.translate('ratings_continueButton'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            color: Colors.white, // White text on gradient
                            fontSize: 19, // Increased from 15 to 19 for better readability
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewContainer(
    String name,
    String username,
    String reviewText,
    String profileImage,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFfae6ec).withOpacity(0.3), // Light pink accent background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFfae6ec), // Light pink accent border
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage(profileImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        color: Color(0xFF1A1A1A), // Dark text on light background
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      username,
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        color: Color(0xFF666666), // Gray text for secondary content
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 2,
                children: const [
                  Icon(Icons.star_rounded, color: Color(0xFFFFB515), size: 20),
                  Icon(Icons.star_rounded, color: Color(0xFFFFB515), size: 20),
                  Icon(Icons.star_rounded, color: Color(0xFFFFB515), size: 20),
                  Icon(Icons.star_rounded, color: Color(0xFFFFB515), size: 20),
                  Icon(Icons.star_rounded, color: Color(0xFFFFB515), size: 20),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              reviewText,
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                color: Color(0xFF1A1A1A), // Dark text on light background
                fontSize: 15.5,
                fontWeight: FontWeight.w400,
                height: 1.4,
                letterSpacing: 0.01,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 