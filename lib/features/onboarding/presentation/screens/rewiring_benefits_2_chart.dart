import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:stoppr/features/onboarding/presentation/screens/choose_goals_onboarding.dart';
import 'package:stoppr/features/onboarding/presentation/screens/rewiring_benefits.dart';
import 'package:stoppr/features/onboarding/presentation/screens/mockup_ob_accountability_screen.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SlideRightRoute extends PageRouteBuilder {
  final Widget page;
  SlideRightRoute({required this.page})
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

class RewireBenefits2ChartScreen extends StatefulWidget {
  const RewireBenefits2ChartScreen({super.key});

  @override
  State<RewireBenefits2ChartScreen> createState() => _RewireBenefits2ChartScreenState();
}

class _RewireBenefits2ChartScreenState extends State<RewireBenefits2ChartScreen> {
  ScrollController? _scrollController;
  bool _showScrollIndicator = true;

  @override
  void initState() {
    super.initState();
    
    _scrollController = ScrollController();
    _scrollController!.addListener(_onScroll);

    // Mixpanel
    MixpanelService.trackPageView('Onboarding Rewiring Benefits 2 Chart Screen');
    
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
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController == null) return;
    // Hide arrows when scrolled down OR when at/near the bottom
    final maxScroll = _scrollController!.position.maxScrollExtent;
    final currentScroll = _scrollController!.offset;
    // Consider "at bottom" if within 200px of the bottom or if there's minimal scroll space
    final isAtBottom = maxScroll < 100 || currentScroll >= (maxScroll - 200);
    final shouldShow = currentScroll <= 100 && !isAtBottom;
    if (_showScrollIndicator != shouldShow) {
      setState(() {
        _showScrollIndicator = shouldShow;
      });
    }
  }

  Widget _buildScrollIndicator() {
    return Positioned(
      bottom: 180, // Position above the continue button
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _showScrollIndicator ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black,
                size: 40,
              ),
              SizedBox(height: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black,
                size: 40,
              ),
              SizedBox(height: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black,
                size: 40,
              ),
            ],
          ).animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          ).moveY(
            begin: -8,
            end: 8,
            duration: 1.5.seconds,
            curve: Curves.easeInOut,
          ).fadeIn(duration: 600.ms),
        ),
      ),
    );
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
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Chart content
              Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: ListView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  children: [
                    // Reduced space at the top
                    const SizedBox(height: 20),
                    
                    // STOPPR message above chart
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: AppLocalizations.of(context)!.translate('rewiringBenefitsChart_message_part1'),
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                color: Color(0xFF1A1A1A), // Dark text for white background
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            TextSpan(
                              text: AppLocalizations.of(context)!.translate('rewiringBenefitsChart_message_part2'),
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                color: Color(0xFF1A1A1A), // Dark text for white background
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Clean image display without surrounding elements
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/onboarding/rewiring_benefits_chart_3.png',
                            width: double.infinity,
                            height: 320,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    
                    // Benefit blocks section
                    const SizedBox(height: 16),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          // First row of benefits
                          Row(
                            children: [
                              Expanded(
                                child: _BenefitCard(
                                  titleKey: 'rewiringBenefitsChart_benefit_1_title',
                                  percentageKey: 'rewiringBenefitsChart_benefit_1_percentage',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _BenefitCard(
                                  titleKey: 'rewiringBenefitsChart_benefit_2_title',
                                  percentageKey: 'rewiringBenefitsChart_benefit_2_percentage',
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Second row of benefits
                          Row(
                            children: [
                              Expanded(
                                child: _BenefitCard(
                                  titleKey: 'rewiringBenefitsChart_benefit_3_title',
                                  percentageKey: 'rewiringBenefitsChart_benefit_3_percentage',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _BenefitCard(
                                  titleKey: 'rewiringBenefitsChart_benefit_4_title',
                                  percentageKey: 'rewiringBenefitsChart_benefit_4_percentage',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Scientific research section
                    const SizedBox(height: 30),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA), // Light gray background
                          border: Border.all(
                            color: const Color(0xFFE0E0E0), // Gray border for white background
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Scientific research title
                            Text(
                              AppLocalizations.of(context)!.translate('rewiringBenefitsChart_scientificResearch_title'),
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                color: Color(0xFF1A1A1A), // Dark text for light background
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Research items
                            _ResearchItem(
                              titleKey: 'rewiringBenefitsChart_research_1_title',
                              urlKey: 'rewiringBenefitsChart_research_1_url',
                            ),
                            
                            _ResearchItem(
                              titleKey: 'rewiringBenefitsChart_research_2_title',
                              urlKey: 'rewiringBenefitsChart_research_2_url',
                            ),
                            
                            _ResearchItem(
                              titleKey: 'rewiringBenefitsChart_research_3_title',
                              urlKey: 'rewiringBenefitsChart_research_3_url',
                            ),
                            
                            _ResearchItem(
                              titleKey: 'rewiringBenefitsChart_research_4_title',
                              urlKey: 'rewiringBenefitsChart_research_4_url',
                            ),
                            
                            _ResearchItem(
                              titleKey: 'rewiringBenefitsChart_research_5_title',
                              urlKey: 'rewiringBenefitsChart_research_5_url',
                            ),
                            
                            _ResearchItem(
                              titleKey: 'rewiringBenefitsChart_research_6_title',
                              urlKey: 'rewiringBenefitsChart_research_6_url',
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Add space at the end
                    const SizedBox(height: 30),
                  ],
                ),
              ),
              
              // Scroll indicator
              _buildScrollIndicator(),
              
              // Continue button at bottom (positioned lower within gray area)
              Positioned(
                bottom: Platform.isAndroid ? 50 : 30, // Higher position on Android to avoid navigation overlap
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to the next screen using a custom page transition
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => 
                            const MockupObAccountabilityScreen(),
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
                        AppLocalizations.of(context)!.translate('rewiringBenefitsChart_continueButton'),
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

class _ResearchItem extends StatelessWidget {
  final String titleKey;
  final String urlKey;

  const _ResearchItem({
    required this.titleKey,
    required this.urlKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brain icon
          Container(
            margin: const EdgeInsets.only(top: 4, right: 12),
            child: Icon(
              Icons.psychology,
              color: const Color(0xFF666666), // Gray icon for white background
              size: 16,
            ),
          ),
          
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Research title
                Text(
                  l10n.translate(titleKey),
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    color: Color(0xFF1A1A1A), // Dark text for light background
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // URL
                Text(
                  l10n.translate(urlKey),
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    color: Color(0xFFfd5d32), // Brand orange for URLs
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final String titleKey;
  final String percentageKey;

  const _BenefitCard({
    required this.titleKey,
    required this.percentageKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    
    return Container(
      height: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA), // Light gray background for contrast
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE0E0E0), // Subtle border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.translate(titleKey),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              color: Color(0xFF1A1A1A), // Dark text for light background
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l10n.translate(percentageKey),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  color: Color(0xFFed3272), // Pink color for percentage
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '↑',
                  style: TextStyle(
                    color: Color(0xFFed3272), // Pink color for arrow
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 