import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add import for haptic feedback
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/core/auth/cubit/auth_cubit.dart';
import 'package:stoppr/core/auth/cubit/auth_state.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_screen3.dart';
import 'package:stoppr/features/auth/presentation/screens/email_auth_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_page.dart';
import 'package:stoppr/features/onboarding/presentation/screens/questionnaire_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_screen5_radar.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/onboarding/presentation/screens/widgets/onboarding_sound_toggle.dart';

// Global static variable to track animation state for the entire app
// This ensures animation only plays once per app session
bool _globalAnimationPlayed = false;

class OnboardingScreen4 extends StatefulWidget {
  final VoidCallback? onNext;
  
  const OnboardingScreen4({
    super.key,
    this.onNext,
  });

  @override
  State<OnboardingScreen4> createState() => _OnboardingScreen4State();
}

class _OnboardingScreen4State extends State<OnboardingScreen4> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _cardAnimation;
  late String _currentDate;
  bool _animationStarted = false; // Track if the animation has already played
  bool _errorBannerRemovalAttempted = false;
  bool _initialErrorCleared = false;
  
  @override
  void initState() {
    super.initState();
    debugPrint('🔍 OnboardingScreen4: initState called with hashCode: ${this.hashCode}');
    // Format current date as MM/DD
    final now = DateTime.now();
    _currentDate = DateFormat('MM/dd').format(now);

    // Track page view
    MixpanelService.trackPageView('Onboarding Card Screen Post Sign Up');
    
    // Force status bar icons to white mode with explicit settings
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // iOS uses opposite naming
    ));
    
    // Make app fullscreen and immersive
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Animation duration
    );
    
    // Use Tween<Offset> to animate from bottom edge to final position
    _cardAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5), // Start from below the screen
      end: Offset.zero, // End at normal position
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack, // Curve with slight overshoot
      ),
    );
    
    // If animation has already played in this app session, skip it
    if (_globalAnimationPlayed) {
      debugPrint('🔍 OnboardingScreen4: Animation previously played in app session, setting to end state');
      _animationController.value = 1.0; // Jump to end without animating
      _animationStarted = true; // Mark as started to prevent duplicate animation
    }
    
    // Use a microtask to clear errors after build is complete
    Future.microtask(() {
      if (mounted) {
        _clearAllErrorMessages();
      }
    });
  }
  
  // Helper method to clear all error messages
  void _clearAllErrorMessages() {
    try {
      //print('🔍 OnboardingScreen4: Clearing error messages in widget with hashCode: ${this.hashCode}');
      // Clear any existing SnackBars
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).clearSnackBars();
      
      // Also emit a clean state to the auth cubit if possible
      // This helps clear any lingering error states
      final authCubit = context.read<AuthCubit>();
      final currentState = authCubit.state;
      
      // Only reset if we're in an error state
      currentState.maybeWhen(
        error: (_) {
          // Get current user and re-emit authenticated state if user exists
          final user = authCubit.getCurrentUser();
          if (user != null) {
            // We have a user but somehow are in error state
            // Force authenticated state
            debugPrint('🧹 OnboardingScreen4: Clearing error state, re-emitting authenticated state');
          }
        },
        orElse: () {},
      );
    } catch (e) {
      debugPrint('❌ Error clearing error messages: $e');
    }
  }
  
  @override
  void dispose() {
    // Restore default status bar and navigation bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only start animation if:
    // 1. This instance hasn't started animation yet (_animationStarted is false)
    // 2. App-wide animation hasn't been played yet (_globalAnimationPlayed is false)
    if (!_animationStarted && !_globalAnimationPlayed) {
      debugPrint('🔍 OnboardingScreen4: Starting animation with hashCode: ${this.hashCode}');
      _animationStarted = true;
      _globalAnimationPlayed = true; // Mark that animation has played for the entire app
      
      // Start animation as soon as the widget is fully built
      // Reset to ensure it runs from the beginning
      _animationController.reset();
      _animationController.forward();
      
      // Also clear any error messages when dependencies change
      _clearAllErrorMessages();
    } else {
      if (_globalAnimationPlayed) {
        debugPrint('🔍 OnboardingScreen4: Animation already played in app session, skipping animation with hashCode: ${this.hashCode}');
      } else {
        debugPrint('🔍 OnboardingScreen4: Animation already started in this instance, skipping animation with hashCode: ${this.hashCode}');
      }
      
      // Still clear error messages even if we don't run the animation
      _clearAllErrorMessages();
    }
  }
  
  // Force clear the red error banner that might be at the bottom of the screen
  void _removeErrorBanner() {
    // Hide all SnackBars first
    _clearAllErrorMessages();
    
    // WidgetsBinding is needed to ensure this happens after the frame is built
    // IMPORTANT: Only do this once, not on every build
    if (!_errorBannerRemovalAttempted) {
      _errorBannerRemovalAttempted = true;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            // Get the current scaffold messenger
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            
            // Clear any existing snackbars
            scaffoldMessenger.hideCurrentSnackBar();
            scaffoldMessenger.clearSnackBars();
            
            // Log for debugging but don't cause state update
            debugPrint('🧹 OnboardingScreen4: Removed error banner once');
          } catch (e) {
            debugPrint('⚠️ OnboardingScreen4: Error clearing error banner: $e');
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only clear once on initial build, not every time
    if (!_initialErrorCleared) {
      _initialErrorCleared = true;
      _clearAllErrorMessages();
      _removeErrorBanner();
    }
    
    return Container(
      decoration: const BoxDecoration(
        // Clean white background that matches app colors
        color: Colors.white,
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // Dark icons for white background
          statusBarBrightness: Brightness.light, // For iOS
        ),
        child: BlocListener<AuthCubit, AuthState>(
          listenWhen: (previous, current) {
            debugPrint('🎯 OnboardingScreen4 ${this.hashCode}: Previous state: $previous');
            debugPrint('🎯 OnboardingScreen4 ${this.hashCode}: Current state: $current');
            
            // Don't listen for authenticatedPaidUser state - that should be handled by other screens
            // This screen should only appear for free users
            if (current is AuthenticatedPaidUser) {
              debugPrint('🎯 OnboardingScreen4 ${this.hashCode}: Ignoring AuthenticatedPaidUser state - not relevant for this screen');
              return false;
            }
            
            // Don't listen for error states that contain cancellation messages
            bool shouldListen = true;
            
            current.maybeWhen(
              error: (message) {
                final lowercaseMessage = message.toLowerCase();
                if (lowercaseMessage.contains('cancel') || 
                    lowercaseMessage.contains('cancelled') || 
                    lowercaseMessage.contains('canceled') ||
                    lowercaseMessage.contains('popup_closed') ||
                    lowercaseMessage.contains('sign in') ||
                    lowercaseMessage.contains('sign_in') ||
                    lowercaseMessage.contains('account not found')) { // Also ignore "account not found" errors
                  debugPrint('🎯 OnboardingScreen4: Ignoring specific error state change: $message');
                  shouldListen = false;
                }
              },
              orElse: () {},
            );
            
            return shouldListen; // Listen to all other state changes
          },
          listener: (context, state) {
            debugPrint('🎯 OnboardingScreen4 ${this.hashCode}: Auth state changed: $state');
            // Only handle errors here
            state.maybeWhen(
              error: (message) {
                debugPrint('🎯 OnboardingScreen4 ${this.hashCode}: Authentication error: $message');
                
                // Don't show error for sign-in cancelled cases or account not found
                if (message.contains('Sign in cancelled') || 
                    message.contains('canceled') || 
                    message.contains('cancelled') ||
                    message.contains('popup_closed_by_user') ||
                    message.contains('user_cancelled') ||
                    message.toLowerCase().contains('cancel') ||
                    message.toLowerCase().contains('account not found')) {
                  debugPrint('🎯 OnboardingScreen4 ${this.hashCode}: Ignoring specific error: $message');
                  
                  // Use microtask to clear snackbars safely
                  Future.microtask(() {
                    if (mounted) {
                      _clearAllErrorMessages();
                    }
                  });
                  return;
                }
                
                // Show error message safely with microtask
                Future.microtask(() {
                  if (mounted) {
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.translate('onboarding4_authErrorPrefix') + message),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } catch (e) {
                      debugPrint('Error showing error SnackBar: $e');
                    }
                  }
                });
              },
              // Also handle authenticated state to ensure we're in a clean state
              authenticated: (user) {
                debugPrint('🎯 OnboardingScreen4 ${this.hashCode}: User authenticated: ${user.uid}');
                // Clear any error messages when authenticated
                _clearAllErrorMessages();
              },
              // Handle authenticatedFreeUser specifically - this is the normal case for this screen
              authenticatedFreeUser: (user) {
                debugPrint('🎯 OnboardingScreen4 ${this.hashCode}: Free user authenticated: ${user.uid}');
                // Clear any error messages
                _clearAllErrorMessages();
              },
              orElse: () {},
            );
          },
          child: Builder(
            builder: (builderContext) {
              // Use a Builder to get the most current context
              return Scaffold(
                backgroundColor: Colors.transparent, // Changed to transparent
                extendBody: true, // Added for edge-to-edge
                extendBodyBehindAppBar: true, // Added for edge-to-edge
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  systemOverlayStyle: const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                    statusBarBrightness: Brightness.light,
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: const OnboardingSoundToggle(
                        diameter: 40,
                        eventName: 'Onboarding Card Screen Post Sign Up: Sound Button Tap',
                      ),
                    ),
                  ],
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
                    onPressed: () {
                      debugPrint("🔙 Back button pressed - navigating to OnboardingScreen3");
                      
                      // Simple navigation back to OnboardingScreen3
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => OnboardingScreen3(
                            onContinueWithApple: () {
                              debugPrint('🍎 Apple sign-in from OnboardingScreen3');
                              final authCubit = context.read<AuthCubit>();
                              authCubit.signInWithApple();
                            },
                            onContinueWithGoogle: () {
                              debugPrint('🔍 Google sign-in from OnboardingScreen3');
                              context.read<AuthCubit>().signInWithGoogle();
                            },
                            onContinueWithEmail: () {
                              debugPrint('📧 Email sign-in from OnboardingScreen3');
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const EmailAuthScreen(
                                    initialSignUpMode: true,
                                  ),
                                ),
                              );
                            },
                            onSkip: () {
                              debugPrint('⏭️ Skip from OnboardingScreen3');
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => OnboardingScreen4(
                                    onNext: widget.onNext,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                body: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Padding(
                    padding: EdgeInsets.only(top: 70),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "Good news!" text
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            AppLocalizations.of(context)!.translate('onboarding4_goodNews'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A), // Dark text for white background
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8), // Reduced from 12
                        // Subtext
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            AppLocalizations.of(context)!.translate('onboarding4_profileBuilt'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 16,
                              color: Color(0xFF666666), // Darker gray for white background
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            AppLocalizations.of(context)!.translate('onboarding4_progressTracked'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 16,
                              color: Color(0xFF666666), // Darker gray for white background
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16), // Reduced from 30
                        
                        // Stars above the card - smaller size
                        Padding(
                          padding: const EdgeInsets.only(right: 30.0, bottom: 0), // Removed bottom padding
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SvgPicture.asset(
                              'assets/images/svg/onboarding-4-stars.svg',
                              width: 45, // Further reduced from 50 to 45
                              height: 58, // Further reduced from 65 to 58
                            ),
                          ),
                        ),
                        
                        // Card container with exact Figma dimensions
                        Center(
                          child: SlideTransition(
                            position: _cardAnimation,
                            child: Container(
                              width: 288, // Exact width from Figma
                              height: 362, // Exact height from Figma
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3), // Increased shadow for dark background
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  // Orange to light blue gradient section
                                  Expanded(
                                    flex: 7, // 70% of the space
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Color(0xFFed3272), // Strong pink/magenta
                                            Color(0xFFfd5d32), // Vivid orange
                                          ],
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          // "STPR" logo with transparent background and white border
                                          Positioned(
                                            top: 16,
                                            left: 24,
                                            child: Container(
                                              width: 49,
                                              height: 49,
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                borderRadius: BorderRadius.circular(28),
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2.0,
                                                ),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  'ST\nPR',
                                                  style: TextStyle(
                                                    fontFamily: 'ElzaRound',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    height: 1.0,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ),
                                          
                                          // Bookmark SVG icon without background
                                          Positioned(
                                            top: 24,
                                            right: 24,
                                            child: SvgPicture.asset(
                                              'assets/images/svg/onboarding-4-bookmark.svg',
                                              width: 30,
                                              height: 23,
                                            ),
                                          ),
                                          
                                          // Active Streak text
                                          Positioned(
                                            top: 150,
                                            left: 36,
                                            child: Text(
                                              AppLocalizations.of(context)!.translate('onboarding4_activeStreak'),
                                              style: const TextStyle(
                                                fontFamily: 'ElzaRound',
                                                fontSize: 14,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                          
                                          // Days count
                                          Positioned(
                                            top: 170,
                                            left: 36,
                                            child: Text(
                                              '0 ${AppLocalizations.of(context)!.translate('onboarding4_daysUnit')}',
                                              style: const TextStyle(
                                                fontFamily: 'ElzaRound',
                                                fontSize: 24,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // White section - creates perfect contrast with gradient
                                  Expanded(
                                    flex: 3, // 30% of the space
                                    child: Container(
                                      width: double.infinity,
                                      color: Colors.white, // Clean white background
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  AppLocalizations.of(context)!.translate('onboarding4_freeSince'),
                                                  style: const TextStyle(
                                                    fontFamily: 'ElzaRound',
                                                    fontSize: 18,
                                                    color: Color(0xFF666666), // Dark gray for light pink background
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _currentDate,
                                                  style: const TextStyle(
                                                    fontFamily: 'ElzaRound',
                                                    fontSize: 32,
                                                    color: Color(0xFF1A1A1A), // Dark text for light pink background
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
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
                        ),
                        
                        // Responsive spacing below card - slightly larger on tall screens
                        SizedBox(
                          height: MediaQuery.of(context).size.height >= 800
                              ? MediaQuery.of(context).size.height * 0.05
                              : MediaQuery.of(context).size.height * 0.04,
                        ),
                        
                        // "Now, let's build the app around you." text below the card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            AppLocalizations.of(context)!.translate('onboarding4_buildAppAroundYou'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 15,
                              color: Color(0xFF666666), // Darker gray for white background
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        // Responsive spacing that adapts to screen size - slightly larger on tall screens
                        SizedBox(
                          height: MediaQuery.of(context).size.height >= 800
                              ? MediaQuery.of(context).size.height * 0.04
                              : MediaQuery.of(context).size.height * 0.03,
                        ),
                        
                        // Next button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                // Add haptic feedback for next button
                                HapticFeedback.lightImpact();
                                
                                // Store context reference before any async operations
                                final navigatorContext = context;
                                
                                // Clear any existing snackbars
                                ScaffoldMessenger.of(navigatorContext).clearSnackBars();
                                
                                debugPrint('🔍 Next button pressed in OnboardingScreen4 with hashCode: ${this.hashCode}');
                                
                                // First try the normal callback
                                if (widget.onNext != null) {
                                  try {
                                    debugPrint('🔍 Executing onNext callback in widget with hashCode: ${this.hashCode}');
                                    // Execute callback directly without any additional context references
                                    widget.onNext!();
                                    return; // Exit if successful
                                  } catch (e) {
                                    // Log the error but continue to fallback
                                    debugPrint('⚠️ Primary navigation failed: $e');
                                    // Don't show error yet, try fallback first
                                  }
                                } else {
                                  debugPrint('⚠️ onNext callback is null in widget with hashCode: ${this.hashCode}, using fallback navigation');
                                }
                                
                                // Fallback navigation to radar screen
                                try {
                                  debugPrint('🔍 Attempting fallback navigation to radar screen');
                                  Navigator.of(navigatorContext).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => OnboardingScreen5Radar(
                                        onNext: widget.onNext,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint('❌ Fallback navigation failed: $e');
                                  
                                  // Only now show error to user if we've tried everything
                                  try {
                                    ScaffoldMessenger.of(navigatorContext).showSnackBar(
                                      SnackBar(
                                        content: Text(AppLocalizations.of(context)!.translate('onboarding4_proceedError')),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  } catch (snackbarError) {
                                    debugPrint('❌ Even showing error message failed: $snackbarError');
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.translate('onboarding4_nextButton'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Skip button
                        GestureDetector(
                          onTap: () {
                            // Add haptic feedback
                            HapticFeedback.lightImpact();
                            
                            // Track skip action
                            MixpanelService.trackButtonTap(
                              'Skip',
                              screenName: 'Onboarding Card Screen Post Sign Up',
                            );
                            
                            debugPrint('⏭️ Skip button pressed in OnboardingScreen4');
                            
                            // Navigate to radar screen
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => OnboardingScreen5Radar(
                                  onNext: widget.onNext,
                                ),
                              ),
                            );
                          },
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(
                                  text: AppLocalizations.of(context)!.translate('onboarding3_wantToSkip'),
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                  ),
                                ),
                                TextSpan(
                                  text: AppLocalizations.of(context)!.translate('onboarding3_skipLink'),
                                  style: const TextStyle(
                                    color: Color(0xFFed3272),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Responsive bottom spacing: much smaller on tall screens to place button lower
                        Container(
                          height: MediaQuery.of(context).size.height < 700 
                              ? 20   // Smaller screens: fixed 20px
                              : 24,  // Larger screens: reduced from 200 to 24px to lower content
                        ),
                        
                        // Add generous bottom safe area padding to keep text away from bottom edge
                        SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                      ],
                    ),
                  ),
                    ),
                    // Removed floating toggle overlay; moved into AppBar.actions
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
} 