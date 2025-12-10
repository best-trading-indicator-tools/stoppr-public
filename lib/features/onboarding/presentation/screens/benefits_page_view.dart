import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'benefits_welcome_to_stoppr.dart';
import 'benefits_rewire_brain.dart';
import 'benefits_staying_motivated.dart';
import 'benefits_avoid_setbacks.dart';
import 'benefits_conquer_yourself.dart';
import 'benefits_level_up_life.dart';
import 'onboarding_sugar_painpoints_page_view.dart';
import 'rewiring_benefits.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class BenefitsPageView extends StatefulWidget {
  final int initialPage;
  
  const BenefitsPageView({
    super.key,
    this.initialPage = 0,
  });

  @override
  State<BenefitsPageView> createState() => _BenefitsPageViewState();
}

class _BenefitsPageViewState extends State<BenefitsPageView> with WidgetsBindingObserver {
  late final PageController _pageController;
  int _currentPage = 0;
  
  // Track drag start position to detect swipe direction
  double _dragStartX = 0.0;
  double _screenWidth = 0.0;
  bool _isLastPageSwiping = false;
  bool _isNavigatingBetweenPages = false; // Flag to prevent multiple navigations
  final OnboardingProgressService _progressService = OnboardingProgressService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
    _currentPage = widget.initialPage;
    
    // Apply edge-to-edge UI mode to show status bar but let content flow under it
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    // Ensure status bar is transparent with white icons
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // Required for iOS to show white icons
        systemNavigationBarColor: Color(0xFF1A051D), // Set navigation bar color
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    WidgetsBinding.instance.addObserver(this);
    
    // Save current screen and page index
    _saveCurrentScreen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-apply system UI settings when app is resumed
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark, // Required for iOS to show white icons
          systemNavigationBarColor: Color(0xFF1A051D), // Set navigation bar color
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.benefitsPageView);
    await _progressService.saveBenefitsPageIndex(_currentPage);
  }

  // Update page change handling to save the current page
  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    
    // Save the current page index
    _progressService.saveBenefitsPageIndex(_currentPage);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }
  
  void _navigateToRewireBenefitsScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RewireBenefitsScreen(),
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

  // Removed legacy soft paywall flow; this screen now only handles paging UI

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // Required for iOS to show white icons
        systemNavigationBarColor: Color(0xFF1A051D),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A051D),
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // PageView with custom gesture detection
            NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                return false; // Allow the scroll to continue
              },
              child: GestureDetector(
                onHorizontalDragStart: (details) {
                  // Save the start position of the drag
                  _dragStartX = details.globalPosition.dx;
                  debugPrint('Drag start at $_dragStartX (screen width: $_screenWidth)');
                },
                onHorizontalDragUpdate: (details) {
                  if (_currentPage == 5) {
                    // For debugging
                    debugPrint('Drag update on last page: ${details.globalPosition.dx}');
                  }
                },
                onHorizontalDragEnd: (details) {
                  // Prevent duplicate navigation while a navigation is in progress
                  if (_isNavigatingBetweenPages) {
                    debugPrint('Navigation already in progress, ignoring drag');
                    return;
                  }

                  final dragEndX = details.primaryVelocity ?? 0;
                  final dragDistance = _dragStartX - (details.primaryVelocity ?? 0);
                  
                  debugPrint('Drag end velocity: $dragEndX, current page: $_currentPage');
                  
                  // Small threshold for detecting swipes
                  if (dragEndX.abs() < 100 && dragDistance.abs() < 20) {
                    debugPrint('Swipe too small, ignoring');
                    return;
                  }
                  
                  // Handle last page specifically
                  if (_currentPage == 5) {
                    debugPrint('Processing drag on last page');
                    
                    // Check for right-to-left swipe (right edge to left)
                    if (dragEndX < 0 || (_dragStartX > _screenWidth * 0.7 && dragDistance > 0)) {
                      debugPrint('Detected left swipe on last page - navigating to RewireBenefitsScreen');
                      
                      setState(() {
                        _isNavigatingBetweenPages = true;
                      });
                      
                      _navigateToRewireBenefitsScreen();
                      return;
                    } else if (dragEndX > 0) {
                      // Left-to-right swipe - go back to previous page
                      debugPrint('Detected right swipe on last page - going to previous page');
                      
                      setState(() {
                        _isNavigatingBetweenPages = true;
                      });
                      
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                      ).then((_) {
                        if (mounted) {
                          setState(() {
                            _isNavigatingBetweenPages = false;
                          });
                        }
                      });
                      return;
                    }
                  }
                  
                  // Handle swipe right on first page - navigate back to OnboardingSugarPainpointsPageView
                  if (_currentPage == 0 && dragEndX > 0) {
                    debugPrint('Detected right swipe on first page');
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => 
                          const OnboardingSugarPainpointsPageView(initialPage: 4),
                        settings: const RouteSettings(
                          arguments: 'fromBenefits',
                          name: 'RecoveryPathScreen',
                        ),
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
                        transitionDuration: const Duration(milliseconds: 400),
                      ),
                    );
                    return;
                  }
                  
                  // Handle swipe left on first page - navigate back (same as swipe right)
                  if (_currentPage == 0 && dragEndX < 0) {
                    debugPrint('Detected left swipe on first page - navigating back');
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => 
                          const OnboardingSugarPainpointsPageView(initialPage: 4),
                        settings: const RouteSettings(
                          arguments: 'fromBenefits',
                          name: 'RecoveryPathScreen',
                        ),
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
                        transitionDuration: const Duration(milliseconds: 400),
                      ),
                    );
                    return;
                  }
                  
                  // Handle normal page swipes for other pages
                  if (dragEndX < 0 && _currentPage < 5 && _currentPage > 0) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  } else if (dragEndX > 0 && _currentPage > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                },
                child: PageView(
                  controller: _pageController,
                  physics: const ClampingScrollPhysics(),
                  onPageChanged: (index) {
                    _onPageChanged(index);
                  },
                  children: const [
                    BenefitsWelcomeToStopprScreen(),
                    BenefitsRewireBrainScreen(),
                    BenefitsStayingMotivatedScreen(),
                    BenefitsAvoidSetbacksScreen(),
                    BenefitsConquerYourselfScreen(),
                    BenefitsLevelUpLifeScreen(),
                  ],
                ),
              ),
            ),
            
            // Bottom section container for dots and button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(bottom: bottomPadding), // Add padding for system navigation bar
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Navigation dots
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40.0), // Space between dots and button
                      child: SmoothPageIndicator(
                        controller: _pageController,
                        count: 6,
                        effect: const WormEffect(
                          dotWidth: 10,
                          dotHeight: 10,
                          spacing: 8,
                          dotColor: Colors.white54,
                          activeDotColor: Colors.white,
                          paintStyle: PaintingStyle.fill,
                        ),
                      ),
                    ),
                    
                    // Next button
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20), // Adjust bottom padding
                      child: GestureDetector(
                        onTap: () {
                          // Prevent duplicate navigation while a navigation is in progress
                          if (_isNavigatingBetweenPages) {
                            return;
                          }
                          
                          setState(() {
                            _isNavigatingBetweenPages = true;
                          });
                          
                          if (_currentPage < 5) {
                            // Go to next page
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOutCubic,
                            ).then((_) {
                              if (mounted) {
                                setState(() {
                                  _isNavigatingBetweenPages = false;
                                });
                              }
                            });
                          } else {
                            // On last page, navigate to the RewireBenefitsScreen
                            _navigateToRewireBenefitsScreen();
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
                              SizedBox(width: 8),
                              Icon(
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
      ),
    );
  }
} 