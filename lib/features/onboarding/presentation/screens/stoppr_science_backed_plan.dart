import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stoppr/features/onboarding/presentation/screens/give_us_ratings_screen.dart';
// Summary: Hide the triple down arrows permanently after the first downward
// scroll on this screen so they don't reappear when scrolling back to top.

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

class StopprScienceBackedPlanScreen extends StatefulWidget {
  const StopprScienceBackedPlanScreen({super.key});

  @override
  State<StopprScienceBackedPlanScreen> createState() => _StopprScienceBackedPlanScreenState();
}

class _StopprScienceBackedPlanScreenState extends State<StopprScienceBackedPlanScreen> {
  final OnboardingProgressService _progressService = OnboardingProgressService();
  ScrollController? _scrollController;
  bool _showScrollIndicator = true;

  @override
  void initState() {
    super.initState();
    
    _scrollController = ScrollController();
    _scrollController!.addListener(_onScroll);

    // Save current screen state
    _saveCurrentScreen();

    // Mixpanel
    MixpanelService.trackPageView('Onboarding STOPPR Science Backed Plan Screen');
    
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
    // Hide permanently after first downward scroll
    if (_showScrollIndicator && _scrollController!.offset > 2) {
      if (mounted) {
        setState(() {
          _showScrollIndicator = false;
        });
      }
    }
  }

  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.stopprScienceBackedPlanScreen);
  }

  Widget _buildScrollIndicator() {
    return Positioned(
      bottom: 180,
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
              // Main content
              Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: ListView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    const SizedBox(height: 20),
                    
                    // Statistics section with wings at top
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _StatisticCard(
                            numberKey: 'stopprScienceBackedPlan_googleScholar_number',
                            labelKey: 'stopprScienceBackedPlan_googleScholar_label',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatisticCard(
                            numberKey: 'stopprScienceBackedPlan_nyTimes_number',
                            labelKey: 'stopprScienceBackedPlan_nyTimes_label',
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Harvard research block
                    _ResearchBlock(
                      logoPath: 'assets/images/onboarding/harvard.png',
                      quoteKey: 'stopprScienceBackedPlan_harvard_quote',
                      sourceKey: 'stopprScienceBackedPlan_harvard_source',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // UCL research block
                    _ResearchBlock(
                      logoPath: 'assets/images/onboarding/ucl.png',
                      quoteKey: 'stopprScienceBackedPlan_ucl_quote',
                      sourceKey: 'stopprScienceBackedPlan_ucl_source',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Atomic Habits research block
                    _ResearchBlock(
                      logoPath: 'assets/images/onboarding/atomic_habits.png',
                      quoteKey: 'stopprScienceBackedPlan_atomicHabits_quote',
                      sourceKey: 'stopprScienceBackedPlan_atomicHabits_source',
                    ),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
              
              // Scroll indicator
              _buildScrollIndicator(),
              
              // Continue button at bottom
              Positioned(
                bottom: Platform.isAndroid ? 50 : 30,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const GiveUsRatingsScreen(),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.translate('stopprScienceBackedPlan_nextButton'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Colors.white,
                              fontSize: 19, // Increased from 15 to 19
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '→',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

class _ResearchBlock extends StatelessWidget {
  final String logoPath;
  final String quoteKey;
  final String sourceKey;

  const _ResearchBlock({
    required this.logoPath,
    required this.quoteKey,
    required this.sourceKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA), // Light gray background for contrast
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE0E0E0), // Light gray border
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          SizedBox(
            width: 60,
            height: 60,
            child: Image.asset(
              logoPath,
              fit: BoxFit.contain,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Quote and source
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quote
                Text(
                  l10n.translate(quoteKey),
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    color: Color(0xFF1A1A1A), // Dark text for light background
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Source
                Text(
                  l10n.translate(sourceKey),
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    color: Color(0xFF666666), // Dark gray for light background
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

class _StatisticCard extends StatelessWidget {
  final String numberKey;
  final String labelKey;

  const _StatisticCard({
    required this.numberKey,
    required this.labelKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      child: Column(
        children: [
          // Wing decorations and numbers
          Stack(
            alignment: Alignment.center,
            children: [
              // Laurel decorations
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left laurel
                  Image.asset(
                    'assets/images/onboarding/left_laurel_icon.png',
                    width: 48,
                    height: 48,
                  ),
                  
                  // Right laurel
                  Image.asset(
                    'assets/images/onboarding/right_laurel_icon.png',
                    width: 48,
                    height: 48,
                  ),
                ],
              ),
              
              // Number text on top
              Text(
                l10n.translate(numberKey),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  color: Color(0xFF1A1A1A), // Dark text for white background
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Label
          Text(
            l10n.translate(labelKey),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              color: Color(0xFF666666), // Dark gray for white background
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
} 