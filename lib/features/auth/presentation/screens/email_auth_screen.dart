import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/cubit/auth_cubit.dart';
import '../../../../core/auth/cubit/auth_state.dart';
import '../../../../features/onboarding/presentation/screens/onboarding_screen3.dart';
import '../../../../features/onboarding/presentation/screens/onboarding_screen4.dart';
import '../../../../features/onboarding/presentation/screens/questionnaire_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../features/app/presentation/screens/home_screen.dart';
import 'dart:async';
import '../../../../features/app/presentation/screens/main_scaffold.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/localization/app_localizations.dart';

class EmailAuthScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final bool initialSignUpMode;
  
  const EmailAuthScreen({
    super.key,
    this.onBackPressed,
    this.initialSignUpMode = true, // Default to Sign Up mode
  });

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  late bool _isSignUp;
  bool _isPasswordVisible = false;
  String? _emailError;
  String? _passwordError;
  static bool _isNavigatingToNextScreen = false; // Flag to prevent duplicate navigation
  
  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUpMode;
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  void _toggleAuthMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _emailError = null;
      _passwordError = null;
    });
  }
  
  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }
  
  bool _validateForm() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
    
    // Validate email format
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() {
        _emailError = 'Please enter a valid email address';
      });
      return false;
    }
    
    // Validate password
    if (_passwordController.text.length < 6) {
      setState(() {
        _passwordError = 'Password must be at least 6 characters';
      });
      return false;
    }
    
    return true;
  }
  
  void _submitForm() {
    if (!_validateForm()) return;
    
    // Immediately show loading state to prevent UI flicker
    setState(() {
      _isNavigatingToNextScreen = true;
    });
    
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (_isSignUp) {
      // For sign-up, use the normal flow through the bloc
      context.read<AuthCubit>().signUpWithEmailAndPassword(email, password);
    } else {
      // For sign-in, use the normal flow through the bloc
      // The AuthCubit will handle checking the subscription status
      context.read<AuthCubit>().signInWithEmailAndPassword(email, password);
    }
  }
  
  void _handleBackButton() {
    print("Back button pressed in EmailAuthScreen"); // Debug print
    // Si widget.onBackPressed est défini, l'utiliser d'abord
    if (widget.onBackPressed != null) {
      widget.onBackPressed!();
    } else {
      // Sinon, revenir directement à OnboardingScreen3 avec tous les callbacks nécessaires
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OnboardingScreen3(
            onContinueWithApple: () {
              final authCubit = context.read<AuthCubit>();
              authCubit.signInWithApple();
            },
            onContinueWithGoogle: () {
              final authCubit = context.read<AuthCubit>();
              authCubit.signInWithGoogle();
            },
            onContinueWithEmail: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EmailAuthScreen(
                    initialSignUpMode: true,
                  ),
                ),
              );
            },
            onSkip: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => OnboardingScreen4(
                    onNext: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => QuestionnaireScreen(
                            onComplete: () {
                              // Navigate to main app when questionnaire is complete
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const MainScaffold(initialIndex: 0),
                                ),
                                (route) => false,
                              );
                            },
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
      );
    }
  }
  
  void _navigateToDefaultScreen() {
    // Navigation logic based on sign-in vs. sign-up mode
    if (_isSignUp) {
      debugPrint('EmailAuthScreen: Sign up mode, navigating to OnboardingScreen4');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => OnboardingScreen4(
            onNext: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => QuestionnaireScreen(
                    onComplete: () {
                      // Navigate to main app when questionnaire is complete
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const MainScaffold(initialIndex: 0),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        (route) => false, // Remove all previous routes
      );
    } else {
      // Si c'est une connexion (sign in), redirige directement vers le questionnaire
      debugPrint('EmailAuthScreen: Sign in mode, navigating to QuestionnaireScreen');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => QuestionnaireScreen(
            onComplete: () {
              // Navigate to main app when questionnaire is complete
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainScaffold(initialIndex: 0),
                ),
                (route) => false,
              );
            },
          ),
        ),
        (route) => false, // Remove all previous routes
      );
    }
  }
  
  void _navigateToHomeScreen() {
    debugPrint('EmailAuthScreen: Navigating to MainScaffold (Home)');
    Navigator.of(context).pushAndRemoveUntil(
      MainScaffold.createRoute(
        initialIndex: 0,
        showBottomNav: true,
      ),
      (route) => false, // Remove all previous routes
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A051D)),
          onPressed: _handleBackButton,
        ),
        title: Text(
          _isSignUp ? 'Create Account' : 'Sign In',
          style: const TextStyle(
            color: Color(0xFF1A051D),
            fontFamily: 'ElzaRound',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          state.maybeWhen(
            // Direct navigation for paid users
            authenticatedPaidUser: (user) {
              // If we're already navigating, don't attempt another navigation
              if (_isNavigatingToNextScreen) {
                debugPrint('EmailAuthScreen: Preventing duplicate navigation for paid user');
                return;
              }
              
              _isNavigatingToNextScreen = true;
              debugPrint('EmailAuthScreen: Paid user authenticated, navigating to MainScaffold');
              
              // Navigate to MainScaffold for paid users
              _navigateToHomeScreen();
            },
            // Free users follow onboarding flow
            authenticatedFreeUser: (user) {
              // If we're already navigating, don't attempt another navigation
              if (_isNavigatingToNextScreen) {
                debugPrint('EmailAuthScreen: Preventing duplicate navigation for free user');
                return;
              }
              
              _isNavigatingToNextScreen = true;
              debugPrint('EmailAuthScreen: Free user authenticated, navigating to onboarding flow');
              
              // Navigation based on sign-in vs sign-up
              _navigateToDefaultScreen();
            },
            // --- ADDED: Handle basic authenticated state for initial navigation ---
            authenticated: (user) {
              // If we're already navigating, don't attempt another navigation
              if (_isNavigatingToNextScreen) {
                debugPrint('EmailAuthScreen: Preventing duplicate navigation on basic authenticated state');
                return;
              }
              
              _isNavigatingToNextScreen = true; // Mark as navigating
              debugPrint('EmailAuthScreen: Basic authenticated state detected - attempting navigation. Subscription check will refine later if needed.');

              // Use the default navigation logic initially.
              // If the user is paid, the AuthCubit's stream should eventually
              // emit authenticatedPaidUser, potentially triggering a redirect later
              // if the app is structured to handle that (e.g., in MainScaffold or splash screen).
              // For now, this ensures the user doesn't get stuck here.
              if (_isSignUp) {
                 // Newly signed up users always go through the next onboarding steps
                 debugPrint('EmailAuthScreen (basic auth): Sign up mode, navigating to OnboardingScreen4');
                 Navigator.of(context).pushAndRemoveUntil(
                   MaterialPageRoute(
                     builder: (context) => OnboardingScreen4(
                       onNext: () {
                         Navigator.of(context).pushReplacement(
                           MaterialPageRoute(
                             builder: (context) => QuestionnaireScreen(
                               onComplete: () {
                                 // Navigate to main app when questionnaire is complete
                                 Navigator.of(context).pushAndRemoveUntil(
                                   MaterialPageRoute(
                                     builder: (context) => const MainScaffold(initialIndex: 0),
                                   ),
                                   (route) => false,
                                 );
                               },
                             ),
                           ),
                         );
                       },
                     ),
                   ),
                   (route) => false, // Remove all previous routes
                 );
              } else {
                 // Existing users signing in might be paid or free.
                 // Navigate to home for now. If they are free, subsequent logic
                 // (potentially triggered by authenticatedFreeUser state or app launch checks)
                 // should handle redirecting to onboarding if needed.
                 // This prioritizes getting the user past the stuck login screen.
                 debugPrint('EmailAuthScreen (basic auth): Sign in mode, navigating to MainScaffold (Home)');
                 _navigateToHomeScreen();
              }
            },
            // --- END ADDED ---
            error: (message) {
              // Reset navigation flag
              _isNavigatingToNextScreen = false;
              
              // Show error in the form
              if (message.contains('email') || message.contains('user')) {
                setState(() {
                  _emailError = message;
                });
              } else if (message.contains('password')) {
                setState(() {
                  _passwordError = message;
                });
              } else {
                // Show general error
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: SelectableText.rich(
                      TextSpan(
                        text: 'Error: ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                        children: [
                          TextSpan(
                            text: message,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    backgroundColor: Colors.black87,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
            orElse: () {},
          );
        },
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.translate('auth_emailLabel'),
                        hintText: AppLocalizations.of(context)!.translate('auth_emailHint'),
                        errorText: _emailError,
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.translate('auth_passwordLabel'),
                        hintText: _isSignUp ? 'Create a password' : 'Enter your password',
                        errorText: _passwordError,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: _togglePasswordVisibility,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Submit button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A1355),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: BlocBuilder<AuthCubit, AuthState>(
                          builder: (context, state) {
                            return state.maybeWhen(
                              loading: () => const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                              orElse: () => Text(
                                _isSignUp ? 'Create Account' : 'Sign In',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Toggle between sign in and sign up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp
                              ? 'Already have an account?'
                              : 'Don\'t have an account?',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 14,
                            fontFamily: 'ElzaRound',
                          ),
                        ),
                        TextButton(
                          onPressed: _toggleAuthMode,
                          child: Text(
                            _isSignUp ? 'Sign In' : 'Sign Up',
                            style: const TextStyle(
                              color: Color(0xFF3A1355),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'ElzaRound',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 