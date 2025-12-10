import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../core/auth/cubit/auth_cubit.dart';
import '../../../../core/auth/cubit/auth_state.dart';
import 'welcome_video_screen.dart';
import 'onboarding_screen2.dart';
import 'onboarding_fomo_stats_screen.dart';
import 'onboarding_screen3.dart';
import 'onboarding_screen4.dart';
import 'onboarding_screen5_radar.dart';
import '../../../../features/auth/presentation/screens/email_auth_screen.dart';
import 'questionnaire_screen.dart';
import '../../../../core/notifications/notification_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Reset notification session flags when starting onboarding
    NotificationService.resetOnboardingSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNext() {
    if (_currentPage < 2) { // We have 3 pages now (0, 1, 2)
      setState(() {
        _currentPage++;
      });
      _controller.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleAppleSignIn() {
    context.read<AuthCubit>().signInWithApple();
  }

  void _handleGoogleSignIn() {
    debugPrint('👆 OnboardingPage: Google Sign-In button clicked');
    
    // Trigger Google sign-in process
    context.read<AuthCubit>().signInWithGoogle().catchError((error) {
      debugPrint('❌ OnboardingPage: Google sign-in error: $error');
      
      // Only try to clear messages if the widget is still mounted
      if (mounted && (
          error.toString().toLowerCase().contains('cancel') || 
          error.toString().toLowerCase().contains('cancelled') ||
          error.toString().toLowerCase().contains('canceled'))) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
    
    // The BlocListener will handle navigation after authentication is complete
  }

  void _handleEmailSignIn() {
    // Navigate to the email authentication screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EmailAuthScreen(
          onBackPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _handleSkip() {
    // Navigate directly to OnboardingScreen5Radar
    debugPrint('⏭️ Skip from OnboardingScreen3 - navigating to radar screen');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const OnboardingScreen5Radar(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) {
        debugPrint('🎯 OnboardingPage: Previous state: $previous');
        debugPrint('🎯 OnboardingPage: Current state: $current');
        
        // Only listen for free user authentication
        // Let OnboardingScreen3 handle paid user navigation
        if (current is AuthenticatedPaidUser) {
          debugPrint('🎯 OnboardingPage: Ignoring AuthenticatedPaidUser state - letting OnboardingScreen3 handle navigation');
          return false;
        }
        
        return true; // Listen to all other state changes
      },
      listener: (context, state) {
        debugPrint('🎯 OnboardingPage: Auth state changed: $state');
        state.maybeWhen(
          // For free authenticated users, navigate to OnboardingScreen5Radar
          authenticatedFreeUser: (user) {
            debugPrint('🎯 OnboardingPage: Free user authenticated, navigating to OnboardingScreen5Radar');
            // Prevent navigation if this route is no longer the current route (e.g., a debug bypass pushed Home)
            final currentRoute = ModalRoute.of(context);
            if (currentRoute == null || !currentRoute.isCurrent) {
              debugPrint('🎯 OnboardingPage: Route not current, skipping navigation to OnboardingScreen5Radar');
              return;
            }
            // Navigate to OnboardingScreen5Radar when authenticated
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const OnboardingScreen5Radar(),
              ),
            );
          },
          // For basic authenticated state, wait for full state resolution
          authenticated: (user) {
            // Don't navigate immediately on basic authenticated state
            // Wait for the auth cubit to determine if user is paid or free
            debugPrint('🎯 OnboardingPage: Basic authentication state received, waiting for resolution');
          },
          error: (message) {
            // Check if the error is a sign-in cancellation
            if (message.contains('sign_in_canceled') || 
                message.toLowerCase().contains('cancelled') || 
                message.toLowerCase().contains('canceled') ||
                message.contains('SignInWithApple') ||
                message.contains('AuthorizationErrorCode') ||
                message.contains('error 1000')) {
              // User cancelled the sign-in, don't show error message
              debugPrint('🎯 OnboardingPage: User cancelled sign-in or Apple error, not showing error');
            } else {
              // Show error message for actual errors
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!
                        .translate('onboarding_auth_error')
                        .replaceFirst('{message}', message),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF462265),
                ),
              );
            }
          },
          orElse: () {},
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(), // Disable manual scrolling
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                // First screen - Stoppr quiz screen
                OnboardingScreen2(
                  onStartQuiz: _navigateToNext,
                ),
                
                // Second screen - FOMO stats screen
                OnboardingFomoStatsScreen(
                  onContinue: _navigateToNext,
                ),
                
                // Third screen - Authentication options
                OnboardingScreen3(
                  onContinueWithApple: _handleAppleSignIn,
                  onContinueWithGoogle: _handleGoogleSignIn,
                  onContinueWithEmail: _handleEmailSignIn,
                  onSkip: _handleSkip,
                ),
              ],
            ),
            // Show loading indicator when authenticating
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                return state.maybeWhen(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 