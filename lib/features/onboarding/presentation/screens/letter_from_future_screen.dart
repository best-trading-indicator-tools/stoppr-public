import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/features/onboarding/presentation/screens/give_us_ratings_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/read_the_vow_screen.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';

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

class LetterFromFutureScreen extends StatefulWidget {
  const LetterFromFutureScreen({super.key});

  @override
  State<LetterFromFutureScreen> createState() => _LetterFromFutureScreenState();
}

class _LetterFromFutureScreenState extends State<LetterFromFutureScreen> {
  final OnboardingProgressService _progressService = OnboardingProgressService();
  String _currentDate = '';
  int _currentYear = 0;
  String _firstName = 'You'; // Default fallback

  @override
  void initState() {
    super.initState();
    
    // Format current date like "4 Jul 2025" and get current year
    final now = DateTime.now();
    _currentDate = DateFormat('d MMM yyyy').format(now);
    _currentYear = now.year;

    // Load user first name
    _loadUserData();

    // Save current screen state
    _saveCurrentScreen();

    // Mixpanel tracking
    MixpanelService.trackEvent('Onboarding Letter From Future Screen: Page Viewed');
  }

  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.letterFromFutureScreen);
  }

  Future<void> _loadUserData() async {
    try {
      // Try to get name from SharedPreferences first
      final prefs = await SharedPreferences.getInstance();
      final savedFirstName = prefs.getString('user_first_name');
      
      if (savedFirstName != null && savedFirstName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _firstName = savedFirstName;
          });
        }
        return; // Exit if we found a name
      }
      
      // Fallback to Firebase Auth if name not in SharedPreferences
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
        final displayNameParts = currentUser.displayName!.split(' ');
        if (displayNameParts.isNotEmpty) {
          if (mounted) {
            setState(() {
              _firstName = displayNameParts[0]; // Get first name from display name
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      // Keep default fallback 'You'
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white background
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // White background branding
        body: SafeArea(
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.only(bottom: 120),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    const SizedBox(height: 20),
                    
                    // Title
                    Text(
                      l10n.translate('letterFromFuture_title'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        color: Color(0xFF1A1A1A), // Dark text on white background
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Letter card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA), // Light gray background
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.4), // Darker border
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
                        children: [
                          // Header with emoji and sender info
                          Row(
                            children: [
                              Text(
                                l10n.translate('letterFromFuture_itsMe'),
                                style: const TextStyle(
                                  fontFamily: 'ElzaRound',
                                  color: Color(0xFF1A1A1A), // Dark text on light background
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '👉',
                                style: TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Sender info and date
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.4), // Darker border to match letter card
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF666666), // Gray icon for light background
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.translate('letterFromFuture_futureYou'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    color: Color(0xFF1A1A1A), // Dark text on light background
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                _currentDate,
                                style: const TextStyle(
                                  fontFamily: 'ElzaRound',
                                  color: Color(0xFF666666), // Gray text for secondary content
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Letter content
                          Text(
                            l10n.translate('letterFromFuture_intro')
                                .replaceAll('{firstName}', _firstName)
                                .replaceAll('{currentYear}', _currentYear.toString()),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Color(0xFF1A1A1A), // Dark text on light background
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                color: Color(0xFF1A1A1A), // Dark text on light background
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(
                                  text: l10n.translate('letterFromFuture_datePrefix').replaceAll('{currentDate}', _currentDate),
                                ),
                                TextSpan(
                                  text: l10n.translate('letterFromFuture_turnedThingsAround'),
                                  style: const TextStyle(
                                    color: Color(0xFFed3272), // Brand pink for highlight
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            l10n.translate('letterFromFuture_thriving'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Color(0xFF1A1A1A), // Dark text on light background
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Signature
                          Text(
                            l10n.translate('letterFromFuture_seeYouSoon'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Color(0xFF666666), // Gray text for secondary content
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                          Text(
                            l10n.translate('letterFromFuture_futureYou'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Color(0xFF666666), // Gray text for secondary content
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
              
              // Continue button at bottom
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GestureDetector(
                    onTap: () {
                      MixpanelService.trackEvent('Onboarding Letter From Future Screen: Button Tap');
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const ReadTheVowScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            const begin = Offset(1.0, 0.0);
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
                        l10n.translate('letterFromFuture_continueButton'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Colors.white, // White text on gradient
                          fontSize: 19, // Increased from 15 to 19 for better readability
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