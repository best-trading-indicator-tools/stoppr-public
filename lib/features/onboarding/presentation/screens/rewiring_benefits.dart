import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:stoppr/features/onboarding/presentation/screens/rewiring_benefits_2_chart.dart';
import 'package:stoppr/features/onboarding/presentation/screens/benefits_page_view.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class RewireBenefitsScreen extends StatefulWidget {
  const RewireBenefitsScreen({super.key});

  @override
  State<RewireBenefitsScreen> createState() => _RewireBenefitsScreenState();
}

class _RewireBenefitsScreenState extends State<RewireBenefitsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Mixpanel
    MixpanelService.trackPageView('Onboarding Rewiring Benefits Screen');
    
    // Force dark status bar icons for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Enforce dark status bar icons for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    return Container(
      // Clean white background matching app branding
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Scaffold(
        // Make scaffold background transparent to show gradient
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          automaticallyImplyLeading: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          title: Text(
            AppLocalizations.of(context)!.translate('rewiringBenefits_title'),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              color: Color(0xFF1A1A1A), // Dark text for white background
              fontSize: 31,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Testimonials content
              Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: ListView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 10),
                  children: const [
                    _TestimonialCard(
                      nameKey: 'rewiringBenefits_testimonial_andrew_name',
                      titleKey: 'rewiringBenefits_testimonial_andrew_title',
                      descriptionKey: 'rewiringBenefits_testimonial_andrew_description',
                      avatarAsset: 'assets/images/testimonials/andrew_huberman.jpg',
                    ),
                    SizedBox(height: 12),
                    
                    _TestimonialCard(
                      nameKey: 'rewiringBenefits_testimonial_lizzo_name',
                      titleKey: 'rewiringBenefits_testimonial_lizzo_title',
                      descriptionKey: 'rewiringBenefits_testimonial_lizzo_description',
                      avatarAsset: 'assets/images/testimonials/lizzo.jpg',
                    ),
                    SizedBox(height: 12),
                    
                    _TestimonialCard(
                      nameKey: 'rewiringBenefits_testimonial_demi_name',
                      titleKey: 'rewiringBenefits_testimonial_demi_title',
                      descriptionKey: 'rewiringBenefits_testimonial_demi_description',
                      avatarAsset: 'assets/images/testimonials/demi_lovato.jpg',
                    ),
                    SizedBox(height: 12),
                    
                    _TestimonialCard(
                      nameKey: 'rewiringBenefits_testimonial_alicia_name',
                      titleKey: 'rewiringBenefits_testimonial_alicia_title',
                      descriptionKey: 'rewiringBenefits_testimonial_alicia_description',
                      avatarAsset: 'assets/images/testimonials/alicia.jpg',
                    ),
                    SizedBox(height: 12),
                    
                    _TestimonialCard(
                      nameKey: 'rewiringBenefits_testimonial_harvey_name',
                      titleKey: 'rewiringBenefits_testimonial_harvey_title',
                      descriptionKey: 'rewiringBenefits_testimonial_harvey_description',
                      avatarAsset: 'assets/images/testimonials/harvey.jpg',
                    ),
                    SizedBox(height: 12),
                    
                    _TestimonialCard(
                      nameKey: 'rewiringBenefits_testimonial_allison_name',
                      titleKey: 'rewiringBenefits_testimonial_allison_title',
                      descriptionKey: 'rewiringBenefits_testimonial_allison_description',
                      avatarAsset: 'assets/images/testimonials/allison.jpg',
                    ),
                    SizedBox(height: 12),
                    
                    _TestimonialCard(
                      nameKey: 'rewiringBenefits_testimonial_tess_name',
                      titleKey: 'rewiringBenefits_testimonial_tess_title',
                      descriptionKey: 'rewiringBenefits_testimonial_tess_description',
                      avatarAsset: 'assets/images/testimonials/tess.jpg',
                    ),
                    SizedBox(height: 12),

                    _TestimonialCard(
                      nameKey: 'rewiringBenefits_testimonial_anonymous_name',
                      titleKey: 'rewiringBenefits_testimonial_anonymous_title',
                      descriptionKey: 'rewiringBenefits_testimonial_anonymous_description',
                      avatarAsset: 'assets/images/testimonials/stoppr_avatar.png',
                    ),
                    SizedBox(height: 12),
                    
                    _TestimonialCard(
                      nameKey: 'rewiringBenefits_testimonial_myriam_name',
                      titleKey: 'rewiringBenefits_testimonial_myriam_title',
                      descriptionKey: 'rewiringBenefits_testimonial_myriam_description',
                      avatarAsset: 'assets/images/testimonials/myriam.jpg',
                    ),
                    SizedBox(height: 12),
                    
                    _TestimonialCard(
                      nameKey: 'rewiringBenefits_testimonial_alessandro_name',
                      titleKey: 'rewiringBenefits_testimonial_alessandro_title',
                      descriptionKey: 'rewiringBenefits_testimonial_alessandro_description',
                      avatarAsset: 'assets/images/testimonials/alessandro.jpg',
                    ),
                    SizedBox(height: 12),
                  ],
                ),
              ),
              
              // White background for the bottom area
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white, // Match main background
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, -2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Continue button at bottom (positioned lower within gray area)
              Positioned(
                bottom: Platform.isAndroid ? 50 : 30, // Higher position on Android to avoid navigation overlap
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white, // Match main background
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to the chart screen with custom transition
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => 
                            const RewireBenefits2ChartScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            const begin = Offset(1.0, 0.0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOutCubic;
                            
                            var tween = Tween(begin: begin, end: end)
                                .chain(CurveTween(curve: curve));
                            
                            return SlideTransition(
                              position: animation.drive(tween),
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 400),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 56,
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
                        AppLocalizations.of(context)!.translate('rewiringBenefits_continueButton'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Colors.white, // White text on gradient
                          fontSize: 19, // Increased from 15 to 19
                          fontWeight: FontWeight.w600,
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
}

class _TestimonialCard extends StatelessWidget {
  final String nameKey;
  final String titleKey;
  final String descriptionKey;
  final String avatarAsset;

  const _TestimonialCard({
    required this.nameKey,
    required this.titleKey,
    required this.descriptionKey,
    required this.avatarAsset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Avatar and name at the top
        Padding(
          padding: const EdgeInsets.only(left: 56, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Author name
              Text(
                l10n.translate(nameKey),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  color: Color(0xFF333333), // Darker gray for better visibility
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              // Verified checkmark
              Icon(
                Icons.verified,
                color: const Color(0xFF4CAF50),
                size: 16,
              ),
            ],
          ),
        ),
        
        // Testimonial content box
        Padding(
          padding: const EdgeInsets.only(top: 32, left: 50, right: 6, bottom: 26),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, // Pure white for better contrast
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(10),
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              border: Border.all(
                color: const Color(0xFFE0E0E0), // Subtle border
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), // Slightly stronger shadow
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Testimonial title
                Text(
                  l10n.translate(titleKey),
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    color: Color(0xFF000000), // Pure black for maximum contrast
                    fontSize: 16,
                    fontWeight: FontWeight.bold, // Increased from w600 to bold
                    height: 1.41,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Testimonial description
                Text(
                  l10n.translate(descriptionKey),
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    color: Color(0xFF333333), // Darker gray for better readability
                    fontSize: 13,
                    fontWeight: FontWeight.w500, // Slightly bolder
                    height: 1.61,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Avatar positioned on top left
        Positioned(
          top: 0,
          left: -7,
          child: CircleAvatar(
            radius: 24,
            backgroundImage: AssetImage(avatarAsset),
          ),
        ),
      ],
    );
  }
} 