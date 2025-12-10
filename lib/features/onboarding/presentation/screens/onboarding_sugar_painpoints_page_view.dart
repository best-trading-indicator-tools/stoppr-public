import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'sugar_drug_screen.dart';
import 'sugar_relationships_screen.dart';
import 'sugar_sex_drive_screen.dart';
import 'sugar_unhappiness_screen.dart';
import 'recovery_path_screen.dart';
import 'symptoms_screen.dart';
import 'benefits_page_view.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class OnboardingSugarPainpointsPageView extends StatefulWidget {
  final int initialPage;
  
  const OnboardingSugarPainpointsPageView({
    super.key,
    this.initialPage = 0,
  });

  @override
  State<OnboardingSugarPainpointsPageView> createState() => _OnboardingSugarPainpointsPageViewState();
}

class _OnboardingSugarPainpointsPageViewState extends State<OnboardingSugarPainpointsPageView> {
  late PageController _pageController;
  int _currentPage = 0;
  
  // Track drag start position to detect swipe direction
  double _dragStartX = 0.0;
  final OnboardingProgressService _progressService = OnboardingProgressService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
    _currentPage = widget.initialPage;
    
    // Configure system UI for edge-to-edge display
    _updateSystemUIOverlayStyle();
    
    // Enable edge-to-edge display
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    
    // Save current screen and page index
    _saveCurrentScreen();
  }

  void _updateSystemUIOverlayStyle() {
    // Set navigation bar color based on current page
    final Color navBarColor = _currentPage == 4 ? const Color(0xFF033E8C) : const Color(0xFFDB052C);
    
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: navBarColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.sugarPainpointsPageView);
    await _progressService.savePainpointsPageIndex(_currentPage);
  }

  // Update page change handling to save the current page
  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    
    // Update system UI overlay style when page changes
    _updateSystemUIOverlayStyle();
    
    // Save the current page index
    _progressService.savePainpointsPageIndex(_currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Handle navigation to SymptomsScreen
  void _navigateToSymptomsScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SymptomsScreen(),
      ),
    );
  }

  // Get the current page background color
  Color _getCurrentPageColor() {
    return _currentPage == 4 ? const Color(0xFF033E8C) : const Color(0xFFDB052C);
  }

  @override
  Widget build(BuildContext context) {
    // Get the bottom padding to account for system navigation bar
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Get current page background color
    final Color currentPageColor = _getCurrentPageColor();
    
    return Scaffold(
      backgroundColor: currentPageColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Use GestureDetector to wrap PageView for custom swipe handling
          GestureDetector(
            onHorizontalDragStart: (details) {
              // Save the start position of the drag
              _dragStartX = details.globalPosition.dx;
            },
            onHorizontalDragEnd: (details) {
              // Calculate the drag distance
              final dragDistance = details.primaryVelocity ?? 0;
              
              // Check if we're on the first page and swiping right to left (negative velocity)
              if (_currentPage == 0 && dragDistance < 0) {
                // Navigate to SymptomsScreen when swiping right to left on first page
                _navigateToSymptomsScreen();
                return;
              }
            },
            child: PageView(
              controller: _pageController,
              physics: const ClampingScrollPhysics(),
              onPageChanged: (index) {
                _onPageChanged(index);
              },
              children: const [
                SugarDrugScreen(),
                SugarRelationshipsScreen(),
                SugarSexDriveScreen(),
                SugarUnhappinessScreen(),
                RecoveryPathScreen(showNextButton: false, showPageIndicators: false),
              ],
            ),
          ),
          
          // Bottom fixed area for dot indicators and button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(bottom: 20 + bottomPadding),
              color: currentPageColor,
              child: Column(
                children: [
                  // Page indicator dots (simple circles) - without background container
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: 5,
                    effect: const WormEffect(
                      dotWidth: 10,
                      dotHeight: 10,
                      spacing: 8,
                      dotColor: Colors.white54,
                      activeDotColor: Colors.white,
                      paintStyle: PaintingStyle.fill,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Next/Get Started button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () {
                        if (_currentPage < 4) {
                          // Go to next page
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          // On last page (RecoveryPathScreen), navigate to BenefitsPageView with smooth swipe
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => 
                                const BenefitsPageView(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0); // Start from right
                                const end = Offset.zero;
                                const curve = Curves.easeInOut;
                                
                                var tween = Tween(begin: begin, end: end)
                                    .chain(CurveTween(curve: curve));
                                var offsetAnimation = animation.drive(tween);
                                
                                return SlideTransition(
                                  position: offsetAnimation,
                                  child: child,
                                );
                              },
                              transitionDuration: const Duration(milliseconds: 300),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.translate('common_next'),
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                color: Color(0xFF1A051D),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF1A051D),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 