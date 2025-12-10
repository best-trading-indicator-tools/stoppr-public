import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'home_screen.dart'; // Commented out
import 'home_screen.dart';
import 'home_rewire_brain.dart';
import 'profile/user_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/features/community/presentation/screens/community_screen.dart';
import '../../../../core/quick_actions/quick_actions_service.dart';
// import 'home_learn_screen.dart'; // Commented out
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/features/learn/presentation/screens/learn_video_list_screen.dart'; // Added import
import 'package:stoppr/core/services/onboarding_audio_service.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;
  final bool showCheckInOnLoad;
  final bool showBottomNav;
  final bool fromCongratulations;
  
  const MainScaffold({
    super.key, 
    this.initialIndex = 0,
    this.showCheckInOnLoad = false,
    this.showBottomNav = true,
    this.fromCongratulations = false,
  });

  // Static method to create a route with consistent animations
  static PageRoute createRoute({
    int initialIndex = 0, 
    bool showCheckInOnLoad = false,
    bool showBottomNav = true,
    bool fromCongratulations = false,
  }) {
    return FadePageRoute(
      child: MainScaffold(
        initialIndex: initialIndex,
        showCheckInOnLoad: showCheckInOnLoad,
        showBottomNav: showBottomNav,
        fromCongratulations: fromCongratulations,
      ),
      settings: const RouteSettings(name: '/home'),
      transitionDuration: fromCongratulations ? Duration.zero : const Duration(milliseconds: 300),
      reverseTransitionDuration: fromCongratulations ? Duration.zero : const Duration(milliseconds: 300),
    );
  }

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late int _currentIndex;
  int _previousIndex = 0;
  bool _hideBars = false; // Track when to hide navigation bars
  final OnboardingProgressService _progressService = OnboardingProgressService();
  
  // Initialize screens directly to prevent late initialization errors
  List<Widget> _screens = [];

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<Offset> _currentScreenAnimation;
  late Animation<Offset> _nextScreenAnimation;
  bool _isAnimating = false;
  
  // List of screen names for analytics tracking
  final List<String> _screenNames = [
    'Home Screen', // Updated for index 0
    'Learn Videos Screen', // Updated for index 1
    'Rewire Brain Screen',
    'Community Screen',
    'User Profile Screen',
  ];
  
  // Services
  final QuickActionsService _quickActionsService = QuickActionsService();
  
  // GlobalKey to access HomeScreen for dismissing overlays
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  
  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Main Scaffold');
    
    final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppWebView,
        );
      } else {
        debugPrint('Could not launch help & info URL');
      }
    } catch (e) {
      debugPrint('Error launching help & info URL: $e');
    }
  }
  
  @override
  void initState() {
    super.initState();
    // Ensure onboarding music is stopped when entering main scaffold (paid app)
    OnboardingAudioService.instance.stop();
    
    // Register WidgetsBindingObserver to detect app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    _currentIndex = widget.initialIndex;
    
    // Initialize the animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Initialize animations (will be updated when transitioning)
    _currentScreenAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _nextScreenAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Create screens in initState - aligned with bottom nav
    _screens = [
      HomeScreen(
        key: _homeScreenKey,
        // Disabled check-in on load for debug testing
        showCheckInOnLoad: false,
        onOverlayVisibilityChanged: _handleOverlayVisibilityChanged,
      ),
      const LearnVideoListScreen(), // Index 1: New Learn Video List Screen
      const HomeRewireBrainScreen(),
      const CommunityScreen(),
      const UserProfileScreen(),
    ];
    
    // Ensure status bar is properly configured
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    
    // Mark onboarding as complete since we're now in the main app
    _markOnboardingComplete();
    
    // Listen for notifications or check for pending pledge check-ins
    _checkForActiveOverlays();
    
    // Set context for quick actions and process any initial action at several points
    // to ensure it's captured (important for iOS quick actions)
    _quickActionsService.setLastValidContext(context);
    _quickActionsService.checkPendingActions();
    
    // Add multiple post-frame callbacks to catch quick actions at different points
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _quickActionsService.setLastValidContext(context);
        _quickActionsService.processInitialAction(context);
      }
    });
    
    // Add a slightly delayed callback to catch actions after first render
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _quickActionsService.setLastValidContext(context);
        _quickActionsService.checkPendingActions();
      }
    });
    
    // Add a longer delay for iOS which sometimes needs more time
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _quickActionsService.setLastValidContext(context);
        _quickActionsService.checkPendingActions();
      }
    });
    
    // Track the initial tab view after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only track the initial view once the UI is fully rendered
      _trackActiveTabPageView();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache the HomeScreen background image - this might need to be removed or updated if HomeScreen is gone
    // precacheImage(const AssetImage('assets/images/home_night_bg.jpg'), context);
  }
  
  @override
  void dispose() {
    // Remove the observer when disposing
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }
  
  // Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app becomes visible again
    if (state == AppLifecycleState.resumed) {
      // Force process any pending actions
      if (mounted) {
        _quickActionsService.setLastValidContext(context);
        _quickActionsService.checkPendingActions();
        _quickActionsService.forcePendingAction();
      }
    }
  }
  
  // Track the currently active tab's page view
  void _trackActiveTabPageView() {
    if (_currentIndex >= 0 && _currentIndex < _screenNames.length) {
      debugPrint('📊 Tracking active tab page view: ${_screenNames[_currentIndex]}');
      MixpanelService.trackPageView(_screenNames[_currentIndex], 
        additionalProps: {'Source': 'Tab Navigation', 'Tab Index': _currentIndex});
    }
  }
  
  // Mark onboarding as complete
  Future<void> _markOnboardingComplete() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      // Only attempt to mark complete if user is logged in
      if (userId != null && userId.isNotEmpty) {
        await _progressService.markOnboardingComplete(userId);
        debugPrint('✅ MainScaffold: Marked onboarding as complete for user: $userId');
      } else {
        debugPrint('⚠️ MainScaffold: Skipping onboarding completion - no authenticated user (likely debug navigation)');
      }
    } catch (e) {
      debugPrint('❌ MainScaffold: Error marking onboarding as complete: $e');
    }
  }
  
  Future<void> _checkForActiveOverlays() async {
    // Check if there's a pending pledge check-in
    final prefs = await SharedPreferences.getInstance();
    final hasPendingCheckIn = prefs.getBool('pending_pledge_check_in') ?? false;
    
    if (hasPendingCheckIn && mounted) {
      // Use microtask to avoid setState during build
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _hideBars = true;
          });
        }
      });
    }
  }
  
  // Method to handle overlay visibility changes
  void _handleOverlayVisibilityChanged(bool isVisible) {
    // This method was tied to the old HomeScreen. 
    // If LearnVideoListScreen needs similar logic, it has to be implemented there.
    // For now, keeping it here but it won't be called by LearnVideoListScreen.
    if (mounted && _hideBars != isVisible) {
      // Use microtask to avoid setState during build
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _hideBars = isVisible;
          });
        }
      });
    }
  }

  void _onNavigationTap(int index) {
    if (_currentIndex == index || _isAnimating) return;
    
    // Add defensive check to prevent rapid tapping
    if (!mounted) return;
    
    // Dismiss any overlays from HomeScreen when switching away from index 0
    if (_currentIndex == 0 && index != 0) {
      _homeScreenKey.currentState?.dismissAllOverlays();
    }
    
    setState(() {
      _isAnimating = true;
      _previousIndex = _currentIndex;
    });
    
    // Determine slide direction based on tab positions
    final bool slideLeft = index > _currentIndex;
    
    // Set up animations for both screens
    _currentScreenAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(slideLeft ? -1.0 : 1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _nextScreenAnimation = Tween<Offset>(
      begin: Offset(slideLeft ? 1.0 : -1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Update current index and start animation
    setState(() {
      _currentIndex = index;
    });
    
    _animationController.forward().then((_) {
      // Use post-frame callback to ensure safe state update
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
          
          // Reset animation controller after state update
          _animationController.reset();
          
          // Track the new page view when tab changes
          _trackActiveTabPageView();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the bottom padding to account for home indicator on iOS
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Use consistent white background and brand-compliant border per style guide
    final Color navBarBackgroundColor = Colors.white;
    final Color navBarBorderColor = const Color(0xFFE0E0E0); // Light gray from brand guidelines
    
    return Scaffold(
      backgroundColor: Colors.black, // Prevent flash during transition
      // Use Stack with SlideTransitions for smooth direct transitions between tabs
      body: Stack(
        children: [
          // When not animating, show current screen directly
          if (!_isAnimating) _screens[_currentIndex],
          
          // During animation, only show the animated screens
          if (_isAnimating) ...[
            // Previous screen sliding out
            SlideTransition(
              position: _currentScreenAnimation,
              child: _screens[_previousIndex],
            ),
            // New screen sliding in
            SlideTransition(
              position: _nextScreenAnimation,
              child: _screens[_currentIndex],
            ),
          ],
        ],
      ),
      extendBody: true,
      bottomNavigationBar: (widget.showBottomNav && !_hideBars) ? Container(
        height: 60 + bottomPadding,
        decoration: BoxDecoration(
          color: navBarBackgroundColor, // Updated background color
          border: Border(
            top: BorderSide(
              color: navBarBorderColor, // Updated border color
              width: 0.5,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavBarItem(0, Icons.grid_view),
              _buildNavBarItem(1, Icons.library_books),
              _buildNavBarItem(2, Icons.bar_chart),
              _buildNavBarItem(3, Icons.forum),
              _buildNavBarItem(4, Icons.menu),
            ],
          ),
        ),
      ) : null,
    );
  }
  
  Widget _buildNavBarItem(int index, IconData icon) {
    final bool isSelected = index == _currentIndex;

    // Use brand-compliant colors: dark text for selected, gray for unselected
    final Color iconColor = isSelected 
      ? const Color(0xFF1A1A1A)  // Dark text from brand guidelines
      : const Color(0xFF666666); // Gray text from brand guidelines
    
    return InkWell(
      onTap: () => _onNavigationTap(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        child: index == 0
            ? SvgPicture.asset(
                'assets/images/global/home_menu_icon.svg',
                width: 30,
                height: 30,
                color: iconColor,
              )
            : index == 1
                ? Image.asset(
                    'assets/images/learn/learn_menu_icon.png',
                    width: 30,
                    height: 30,
                    color: iconColor,
                  )
                : Icon(
                    icon,
                    size: 30,
                    color: iconColor,
                  ),
      ),
    );
  }
} 