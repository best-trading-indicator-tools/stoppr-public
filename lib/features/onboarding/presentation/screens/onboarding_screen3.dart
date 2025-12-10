import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/core/auth/cubit/auth_cubit.dart';
import 'package:stoppr/core/auth/cubit/auth_state.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_screen4.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_screen5_radar.dart';
import 'package:stoppr/features/auth/presentation/screens/email_auth_screen.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stoppr/features/app/presentation/screens/home_screen.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:stoppr/features/onboarding/presentation/screens/questionnaire_screen.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/superwall_utils.dart';
import 'package:stoppr/features/onboarding/presentation/screens/widgets/onboarding_sound_toggle.dart';

class OnboardingScreen3 extends StatefulWidget {
  final VoidCallback? onContinueWithApple;
  final VoidCallback? onContinueWithGoogle;
  final VoidCallback? onContinueWithEmail;
  final VoidCallback? onSkip;
  
  const OnboardingScreen3({
    super.key,
    this.onContinueWithApple,
    this.onContinueWithGoogle,
    this.onContinueWithEmail,
    this.onSkip,
  });

  @override
  State<OnboardingScreen3> createState() => _OnboardingScreen3State();
}

class _OnboardingScreen3State extends State<OnboardingScreen3> {
  bool _isAppleLoading = false;
  bool _isGoogleLoading = false;
  bool _isEmailLoading = false;
  bool _isVerifyingSubscription = false; // New flag to track subscription verification

  // Summary: Adds a confirmation dialog when the user taps Skip to ensure
  // they see the new localized message before proceeding with the current
  // skip flow to the card page.
  Future<void> _confirmSkip() async {
    debugPrint('🔔 _confirmSkip() called, widget.onSkip is null: ${widget.onSkip == null}');
    final String title = AppLocalizations.of(context)!
        .translate('questionnaire_skipConfirmation_title');
    final String message = AppLocalizations.of(context)!
        .translate('questionnaire_skipConfirmation_message');
    final String cancel = AppLocalizations.of(context)!
        .translate('questionnaire_skipConfirmation_cancel');
    final String skip = AppLocalizations.of(context)!
        .translate('questionnaire_skipConfirmation_skip');

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontFamily: 'ElzaRound',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontFamily: 'ElzaRound',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                  child: Column(
                    children: [
                      // Skip button - secondary gray background
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            debugPrint('💡 Skip button in dialog pressed');
                            Navigator.of(dialogContext).pop(true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            skip,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontFamily: 'ElzaRound',
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Cancel button - primary CTA with brand gradient
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFed3272),
                              Color(0xFFfd5d32),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            debugPrint('❌ Cancel button in dialog pressed');
                            Navigator.of(dialogContext).pop(false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            cancel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'ElzaRound',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      debugPrint('✅ Skip confirmed in dialog');
      debugPrint('🔍 widget.onSkip is null: ${widget.onSkip == null}');
      MixpanelService.trackEvent(
        'Onboarding Screen Sign up Skip for now Tap',
      );
      if (widget.onSkip != null) {
        debugPrint('🚀 Calling widget.onSkip()...');
        widget.onSkip!();
        debugPrint('✅ widget.onSkip() completed');
      } else {
        debugPrint('❌ widget.onSkip is null, cannot skip');
      }
    } else {
      debugPrint('❌ Skip cancelled or dialog dismissed (confirmed: $confirmed)');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Method to check if user exists and has paid subscription
    Future<void> checkUserSubscriptionBeforeAuth(String email, Function performAuth) async {
      if (email.isEmpty) {
        // If no email provided, just perform auth directly
        performAuth();
        return;
      }
      
      try {
        // Query Firestore for user with matching email
        final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
          
        if (snapshot.docs.isNotEmpty) {
          final userData = snapshot.docs.first.data();
          final subscriptionStatus = userData['subscriptionStatus'];
          
          if (subscriptionStatus == 'paid_standard' || subscriptionStatus == 'paid_gift') {
            debugPrint('📝 Found existing paid user with email: $email');
            // We know this is a paid user, proceed with auth
            performAuth();
            return;
          }
        }
        
        // No paid user found, still proceed with auth
        performAuth();
      } catch (error) {
        debugPrint('❌ Error pre-checking user by email: $error');
        // Proceed with auth anyway on error
        performAuth();
      }
    }
    
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        debugPrint('🎯 OnboardingScreen3: Auth state changed: $state');
        
        // Reset loading states immediately whenever the state is NOT Loading
        // This ensures spinners stop even if navigation happens elsewhere or is ignored.
        if (state is! Loading) {
          setState(() {
            _isAppleLoading = false;
            _isGoogleLoading = false;
            _isEmailLoading = false;
          });
        }
        
        // --- ADDED: Prioritize Apple Reviewer Navigation --- 
        if (state is AuthenticatedPaidUser && (state.user.email == 'applereviews2025@gmail.com' || state.user.email == 'hello@stoppr.app')) {
          debugPrint('🎯 OnboardingScreen3: Apple Reviewer or Admin account detected (via PaidUser state), ensuring navigation to MainScaffold');
          try {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const MainScaffold(
                  initialIndex: 0,
                  showBottomNav: true,
                ),
              ),
              (route) => false, // Remove all previous routes
            );
            debugPrint('✅ OnboardingScreen3: Navigation to MainScaffold for Apple Reviewer executed successfully');
          } catch (e) {
            debugPrint('❌ OnboardingScreen3: Error during navigation to MainScaffold for Apple Reviewer: $e');
            // Optional: Show error
          }
          return; // IMPORTANT: Stop processing further state checks for this event
        }
        // --- END ADDED ---
        
        // Handle navigation only for relevant states for this screen
        state.maybeWhen(
          // For paid users (NON-REVIEWER), navigate directly to MainScaffold
          authenticatedPaidUser: (user) {
            // This block will now only be reached if it's NOT the Apple Reviewer
            debugPrint('🎯 OnboardingScreen3: Paid user authenticated (Non-Reviewer), navigating to MainScaffold');
            
            // Clear verification loading state
            setState(() {
              _isVerifyingSubscription = false;
            });
            
            // Navigate to MainScaffold for paid users
            try {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainScaffold(
                    initialIndex: 0,
                    showBottomNav: true,
                  ),
                ),
                (route) => false, // Remove all previous routes
              );
              debugPrint('✅ OnboardingScreen3: Navigation to MainScaffold executed successfully');
            } catch (e) {
              debugPrint('❌ OnboardingScreen3: Error during navigation to MainScaffold: $e');
              // Show error if navigation failed
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.translate('onboarding3_navigationError')),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          // For free users, navigate to radar screen
          authenticatedFreeUser: (user) {
            debugPrint('🎯 OnboardingScreen3: Free user authenticated, navigating to OnboardingScreen5Radar');
            
            // Clear verification loading state
            setState(() {
              _isVerifyingSubscription = false;
            });
            
            // Navigate to OnboardingScreen5Radar when this listener receives the state
            try {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const OnboardingScreen5Radar(),
                ),
              );
              debugPrint('✅ OnboardingScreen3: Navigation to OnboardingScreen5Radar executed successfully');
            } catch (e) {
              debugPrint('❌ OnboardingScreen3: Error during navigation to OnboardingScreen5Radar: $e');
              // Optionally show an error message if navigation fails
            }
          },
          authenticated: (user) async {
            debugPrint('🎯 OnboardingScreen3: User authenticated: ${user.uid}');
            
            // Show loading overlay while subscription is being verified
            setState(() {
              _isVerifyingSubscription = true;
              _isAppleLoading = false;
              _isGoogleLoading = false;
              _isEmailLoading = false;
            });
            
            // No special cases - all navigation will be handled by proper auth states
            // Just track sign up events and store user data
            
            // Determine sign up type from providerId
            String signupType = 'Unknown';
            if (user.providerId != null) {
              if (user.providerId!.contains('apple')) {
                signupType = 'Apple';
              } else if (user.providerId!.contains('google')) {
                signupType = 'Google';
              } else if (user.providerId!.contains('password')) {
                signupType = 'Email';
              }
            }
            
            // Track sign up event with Mixpanel
            MixpanelService.trackSignUp(signupType);
            
            // Identify user with Mixpanel
            MixpanelService.identifyUser(
              user.uid,
              email: user.email,
              name: user.displayName,
            );
            
            // Identify user with Superwall
            Superwall.shared.identify(user.uid);
            
            // Set Superwall user attributes for audience filtering
            String? firstName;
            if (user.displayName != null && user.displayName!.isNotEmpty) {
              firstName = user.displayName!.split(' ')[0];
            }
            await SuperwallUtils.setUserAttributes(
              firstName: firstName,
              email: user.email,
            );
            
            // Save user's first name to SharedPreferences
            if (user.displayName != null && user.displayName!.isNotEmpty) {
              final firstName = user.displayName!.split(' ')[0];
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('user_first_name', firstName);
                debugPrint('✅ OnboardingScreen3: Saved first name to SharedPreferences: $firstName');
              });
            }
            
            // For basic authenticated state, wait for the subscription check
            // to complete and emit authenticatedPaidUser or authenticatedFreeUser
            debugPrint('🎯 OnboardingScreen3: Basic authenticated state - waiting for subscription check to complete before navigation');
          },
          error: (message) {
            // Clear verification loading state on error
            setState(() {
              _isVerifyingSubscription = false;
            });
            
            // Only show errors that are not related to sign-in cancellations
            if (!(message.contains('sign_in_canceled') || 
                message.toLowerCase().contains('cancelled') || 
                message.toLowerCase().contains('canceled') ||
                message.toLowerCase().contains('the interaction was cancelled'))) {
              
              // Show error message for actual errors
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.translate('onboarding3_authErrorPrefix') + message,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF462265),
                ),
              );
            } else {
              debugPrint('🎯 OnboardingScreen3: User cancelled sign-in, not showing error');
            }
          },
          orElse: () {},
        );
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            extendBody: true,
            extendBodyBehindAppBar: true,
            body: Stack(
              children: [
                // Top-right sound toggle below status bar
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  right: 12,
                  child: const OnboardingSoundToggle(
                    eventName: 'Onboarding Screen Sign up: Sound Button Tap',
                  ),
                ),
                Column(
                  children: [
                    Container(
                      color: Colors.white,
                      width: double.infinity,
                      child: SafeArea(
                        top: false,
                        bottom: false,
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/onboarding/onboarding-screen3-coach.png',
                              width: double.infinity,
                              height: MediaQuery.of(context).size.width * 0.8 + MediaQuery.of(context).padding.top,
                              fit: BoxFit.cover,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.translate('onboarding3_title'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 25,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                    letterSpacing: -0.02 * 25,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  AppLocalizations.of(context)!.translate('onboarding3_subtitle'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF666666),
                                    height: 1.4,
                                  ),
                                ),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                                // Only show Apple Sign In button on iOS
                                if (Platform.isIOS)
                                  Container(
                                    width: MediaQuery.of(context).size.width * 0.85,
                                    height: 56,
                                    child: OutlinedButton(
                                      onPressed: _isAppleLoading || _isGoogleLoading || _isEmailLoading ? null : () {
                                        setState(() {
                                          _isAppleLoading = true;
                                        });
                                        if (widget.onContinueWithApple != null) {
                                          widget.onContinueWithApple!();
                                        } else {
                                          final authCubit = context.read<AuthCubit>();
                                          final performAuth = () {
                                            authCubit.signInWithApple().then((_) {}).catchError((_) {
                                              setState(() {
                                                _isAppleLoading = false;
                                              });
                                            });
                                          };
                                          performAuth();
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF1A1A1A), width: 2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(28),
                                        ),
                                        backgroundColor: Colors.white,
                                      ),
                                      child: _isAppleLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF1A1A1A),
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Transform.translate(
                                                  offset: const Offset(-7.0, 0),
                                                  child: Icon(
                                                    Icons.apple,
                                                    color: Colors.black,
                                                    size: 28,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  AppLocalizations.of(context)!.translate('onboarding3_continueWithApple'),
                                                  style: const TextStyle(
                                                    fontFamily: 'ElzaRound',
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w600,
                                                    height: 0.9,
                                                    letterSpacing: 0,
                                                    color: Color(0xFF1A1A1A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                if (Platform.isIOS) const SizedBox(height: 16),
                                Container(
                                  width: MediaQuery.of(context).size.width * 0.85,
                                  height: 56,
                                  child: OutlinedButton(
                                    onPressed: _isAppleLoading || _isGoogleLoading || _isEmailLoading ? null : () {
                                      setState(() {
                                        _isGoogleLoading = true;
                                      });
                                      if (widget.onContinueWithGoogle != null) {
                                        widget.onContinueWithGoogle!();
                                      } else {
                                        final authCubit = context.read<AuthCubit>();
                                        final performAuth = () {
                                          authCubit.signInWithGoogle().then((_) {}).catchError((_) {
                                            setState(() {
                                              _isGoogleLoading = false;
                                            });
                                          });
                                        };
                                        performAuth();
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF1A1A1A), width: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      backgroundColor: Colors.white,
                                    ),
                                    child: _isGoogleLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF1A1A1A),
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Transform.translate(
                                                offset: const Offset(4, 0),
                                                child: SvgPicture.asset(
                                                  'assets/images/svg/google_g_logo.svg',
                                                  width: 25,
                                                  height: 25,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                AppLocalizations.of(context)!.translate('onboarding3_continueWithGoogle'),
                                                style: const TextStyle(
                                                  fontFamily: 'ElzaRound',
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w600,
                                                  height: 0.9,
                                                  letterSpacing: 0,
                                                  color: Color(0xFF1A1A1A),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: MediaQuery.of(context).size.width * 0.85,
                                  height: 56,
                                  child: OutlinedButton(
                                    onPressed: _isAppleLoading || _isGoogleLoading || _isEmailLoading ? null : (widget.onContinueWithEmail ?? () {
                                      setState(() {
                                        _isEmailLoading = true;
                                      });
                                      Navigator.of(context)
                                          .push(
                                            MaterialPageRoute(
                                              builder: (context) => const EmailAuthScreen(
                                                initialSignUpMode: true,
                                              ),
                                            ),
                                          )
                                          .then((_) {
                                        setState(() {
                                          _isEmailLoading = false;
                                        });
                                      });
                                    }),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF1A1A1A), width: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      backgroundColor: Colors.white,
                                    ),
                                    child: _isEmailLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF1A1A1A),
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Transform.translate(
                                                offset: const Offset(-2.0, 0),
                                                child: const Icon(
                                                  Icons.email_outlined,
                                                  color: Color(0xFF1A1A1A),
                                                  size: 25,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                AppLocalizations.of(context)!.translate('onboarding3_continueWithEmail'),
                                                style: const TextStyle(
                                                  fontFamily: 'ElzaRound',
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w600,
                                                  height: 0.9,
                                                  letterSpacing: 0,
                                                  color: Color(0xFF1A1A1A),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                                Container(
                                  width: MediaQuery.of(context).size.width * 0.85,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(0xFFed3272),
                                        Color(0xFFfd5d32),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _confirmSkip();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!.translate('onboarding3_skipForNow'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontFamily: 'ElzaRound',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(
                                          Icons.arrow_forward,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isVerifyingSubscription)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFFed3272),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.translate('onboarding3_verifyingSubscription'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 