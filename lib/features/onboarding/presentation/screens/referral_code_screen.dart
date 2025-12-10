import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/features/onboarding/presentation/screens/letter_from_future_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/give_us_ratings_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/potential_rating_screen.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/subscription/subscription_service.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stoppr/features/onboarding/presentation/screens/congratulations/congratulations_screen_1.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'dart:io';
import 'dart:async';

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

class ReferralCodeScreen extends StatefulWidget {
  const ReferralCodeScreen({super.key});

  @override
  State<ReferralCodeScreen> createState() => _ReferralCodeScreenState();
}

class _ReferralCodeScreenState extends State<ReferralCodeScreen> {
  final TextEditingController _referralController = TextEditingController();
  bool _isReferralCodeEmpty = true;
  final OnboardingProgressService _progressService = OnboardingProgressService();
  final UserRepository _userRepository = UserRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();

  // Toast banner state (same style as HomeScreen info bubble)
  bool _showToast = false;
  String _toastMessage = '';
  bool _toastIsError = false;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _referralController.addListener(_updateButtonText);
    _saveCurrentScreen();
    // Mixpanel
    MixpanelService.trackPageView('Onboarding Referral Code Screen');
  }

  void _updateButtonText() {
    final isEmpty = _referralController.text.trim().isEmpty;
    if (isEmpty != _isReferralCodeEmpty) {
      setState(() {
        _isReferralCodeEmpty = isEmpty;
      });
    }
  }

  // ATT request moved to OnboardingScreen2

  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.referralCodeScreen);
  }

  // Method to save referral code to Firestore
  Future<void> _saveReferralCode(String referralCode) async {
    try {
      // Get current user
      final user = _auth.currentUser;
      
      if (user != null && referralCode.isNotEmpty) {
        // Check if it's the Apple promo code
        if (referralCode == "6JF9J7JMFE4M") {
          debugPrint('Apple promo code detected: $referralCode');
          
          // 1. Update Firestore - mark as partner and paid
          try {
            // Save the referral code first
            await _userRepository.saveReferralCode(user.uid, referralCode);
            
            // Update additional fields with direct Firestore update
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'partnerUser': true,
              'partnerSource': 'apple_promo',
              'onboardingCompleted': true,
            }, SetOptions(merge: true));
            
            debugPrint('✅ Successfully updated user as partner in Firestore');
          } catch (e) {
            debugPrint('❌ Error updating user in Firestore: $e');
          }
          
          // Update subscription status to paid
          try {
            await _subscriptionService.updateSubscriptionStatus(
              user.uid, 
              SubscriptionType.free_apple_promo,
              productId: 'apple_promo_code'
            );
            debugPrint('✅ Successfully updated subscription status');
          } catch (e) {
            debugPrint('❌ Error updating subscription status: $e');
          }
          
          // 2. Save to SharedPreferences
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_partner_user', true);
            await prefs.setBool('onboarding_completed', true);
            debugPrint('✅ Successfully saved partner status to SharedPreferences');
          } catch (e) {
            debugPrint('❌ Error saving to SharedPreferences: $e');
          }
          
          // 3. Track in analytics with the requested user properties
          // MIXPANEL_COST_CUT: Removed promo tracking - use Firebase/Firestore instead
          
          // 4. Mark onboarding as complete
          try {
            await _progressService.markOnboardingComplete(user.uid);
            debugPrint('✅ Successfully marked onboarding as complete');
          } catch (e) {
            debugPrint('❌ Error marking onboarding as complete: $e');
          }
          
          // 5. Navigate directly to CongratulationsScreen1
          if (mounted) {
            debugPrint('🚀 Navigating to CongratulationsScreen1 now...');
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const CongratulationsScreen1(),
              ),
              (route) => false,
            );
            
            // Additional processing can happen in background
            _processApplePromoCode(user.uid, referralCode);
          }
          return; // Exit early to skip normal flow
        }
        
        // Regular referral code handling
        await _userRepository.saveReferralCode(user.uid, referralCode);
        
        // MIXPANEL_COST_CUT: Removed referral entered tracking - noise
      }
    } catch (e) {
      debugPrint('❌ Error saving referral code: $e');
      // Continue with the app flow even if saving fails
    }
  }

  // Background processing for Apple promo code to avoid blocking UI
  Future<void> _processApplePromoCode(String uid, String referralCode) async {
    try {
      debugPrint('🏃 Running background processing for promo code');
      
      // Get user to check if anonymous
      final user = _auth.currentUser;
      final bool isAnonymous = user?.isAnonymous ?? true;
      
      // Update subscription status to paid - now done directly in Firestore
      try {
        // Instead of using SubscriptionService, ensure Firestore has correct fields
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'subscriptionStatus': 'free_apple_promo',
          'subscriptionProductId': 'apple_promo_code',
          'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Successfully updated subscription status in background process');
      } catch (e) {
        debugPrint('❌ Error updating subscription status: $e');
      }
      
      // Save to SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_partner_user', true);
        await prefs.setBool('onboarding_completed', true);
        debugPrint('✅ Successfully saved partner status to SharedPreferences');
      } catch (e) {
        debugPrint('❌ Error saving to SharedPreferences: $e');
      }
      
      // MIXPANEL_COST_CUT: Removed Apple promo tracking - use Firebase/Firestore instead
      
      // Mark onboarding as complete
      try {
        await _progressService.markOnboardingComplete(uid);
        debugPrint('✅ Successfully marked onboarding as complete');
      } catch (e) {
        debugPrint('❌ Error marking onboarding as complete: $e');
      }
      
      debugPrint('✅ Background processing completed successfully');
    } catch (e) {
      debugPrint('❌ Error in background processing: $e');
    }
  }

  @override
  void dispose() {
    _referralController.removeListener(_updateButtonText);
    _referralController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToastBanner(String message, {bool isError = false}) {
    _toastTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _toastMessage = message;
      _toastIsError = isError;
      _showToast = true;
    });
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showToast = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Force dark status bar icons for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white, // White background branding
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 25,
          automaticallyImplyLeading: false,
          title: const Text(''),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Title
                      Text(
                        l10n.translate('referralCode_title'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Color(0xFF1A1A1A), // Dark text for white background
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Skip text
                      Text(
                        l10n.translate('referralCode_subtitle'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Color(0xFF666666), // Dark gray text for white background
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Add a spacer to push content down
                      const Spacer(),
                      // Referral code input
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5), // Light gray background for input
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: TextField(
                            controller: _referralController,
                            textAlignVertical: TextAlignVertical.center,
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Color(0xFF1A1A1A), // Dark text for input
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.0,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 0,
                              ),
                              isDense: true,
                              hintText: l10n.translate('referralCode_hintText'),
                              hintStyle: const TextStyle(
                                fontFamily: 'ElzaRound',
                                color: Color(0xFF999999), // Dark gray hint text
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Add a spacer to push content up
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              // Bottom container with continue button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white, // White background to match main background
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05), // Lighter shadow for white background
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                height: 110,
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: GestureDetector(
                      onTap: () async {
                        final referralCode = _referralController.text.trim();
                        final l10n = AppLocalizations.of(context)!;
                        debugPrint('👉 Continue button clicked with code: ${referralCode.isEmpty ? "None" : referralCode}');
                        var user = _auth.currentUser;

                        // 1. APPLE PROMO CODE "6JF9J7JMFE4M"
                        if (referralCode == "6JF9J7JMFE4M") {
                          debugPrint('🍎 Apple promo code detected in button handler');
                          if (user == null) {
                            try {
                              debugPrint('🔑 Creating anonymous user for Apple promo code access');
                              final userCredential = await _auth.signInAnonymously();
                              user = userCredential.user;
                              debugPrint('✅ Anonymous user created for Apple promo: ${user?.uid}');
                            } catch (e) {
                              debugPrint('❌ Error creating anonymous user for Apple promo: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.translate('referralCode_error_creatingAccount'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFDC2626), // Darker red for critical errors
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                              return;
                            }
                          }
                          
                          if (user != null) {
                            try {
                              debugPrint('🔑 Processing Apple promo for user: ${user.uid}');
                              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                'uid': user.uid,
                                'isAnonymous': user.isAnonymous,
                                'referralCode': referralCode,
                                'partnerUser': true,
                                'partnerSource': 'apple_promo',
                                'onboardingCompleted': true,
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                                'subscriptionStatus': 'free_apple_promo',
                                'subscriptionProductId': 'apple_promo_code',
                              }, SetOptions(merge: true));
                              debugPrint('✅ User marked as partner in Firestore for Apple Promo');
                              
                              // Save to SharedPreferences (as per original _saveReferralCode and _processApplePromoCode)
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('is_partner_user', true);
                              await prefs.setBool('onboarding_completed', true);
                              debugPrint('✅ Saved Apple promo partner status to SharedPreferences');

                              // MIXPANEL_COST_CUT: Removed Apple promo tracking - use Firebase/Firestore instead
                              
                              if (mounted) {
                                debugPrint('🚀 Navigating to CongratulationsScreen1 for Apple Promo user...');
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const CongratulationsScreen1()),
                                  (route) => false,
                                );
                                _processApplePromoCode(user.uid, referralCode); // Handles further background tasks
                              }
                            } catch (e) {
                              debugPrint('❌ ERROR IN BUTTON HANDLER (Processing Apple Promo): $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.translate('referralCode_error_processingPromo'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFDC2626), // Darker red for critical errors
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            }
                          }
                          return;
                        }
                        // 1b. ANDROID-ONLY PROMO CODE "6DU52TH63PJ5WPKTRF6YFQN"
                        else if (referralCode == "6DU52TH63PJ5WPKTRF6YFQN" && Platform.isAndroid) {
                          debugPrint('🤖 Android promo code detected in button handler');
                          if (user == null) {
                            try {
                              debugPrint('🔑 Creating anonymous user for Android promo code access');
                              final userCredential = await _auth.signInAnonymously();
                              user = userCredential.user;
                              debugPrint('✅ Anonymous user created for Android promo: ${user?.uid}');
                            } catch (e) {
                              debugPrint('❌ Error creating anonymous user for Android promo: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.translate('referralCode_error_creatingAccount'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFDC2626), // Darker red for critical errors
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                              return;
                            }
                          }
                          if (user != null) {
                            try {
                              debugPrint('🔑 Processing Android promo for user: ${user.uid}');
                              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                'uid': user.uid,
                                'isAnonymous': user.isAnonymous,
                                'referralCode': referralCode,
                                'partnerUser': true,
                                'partnerSource': 'android_promo',
                                'onboardingCompleted': true,
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                                'subscriptionStatus': 'free_android_promo',
                                'subscriptionProductId': 'android_promo_code',
                              }, SetOptions(merge: true));
                              debugPrint('✅ User marked as partner in Firestore for Android Promo');

                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('is_partner_user', true);
                              await prefs.setBool('onboarding_completed', true);
                              debugPrint('✅ Saved Android promo partner status to SharedPreferences');

                              // MIXPANEL_COST_CUT: Removed Android promo tracking - use Firebase/Firestore instead

                              if (mounted) {
                                debugPrint('🚀 Navigating to HomeScreen for Android Promo user...');
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const MainScaffold()),
                                  (route) => false,
                                );
                              }
                            } catch (e) {
                              debugPrint('❌ ERROR IN BUTTON HANDLER (Processing Android Promo): $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.translate('referralCode_error_processingPromo'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFDC2626), // Darker red for critical errors
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            }
                          }
                          return;
                        }
                        // 2. PARTNER REFERRAL CODES (SUPP80, KLOE80, SARAH80, GLOW80, POPPY80, SAYLOR80)
                        else if (const ['SUPP80', "EVELINA", "HANAJANA"].contains(referralCode)) {
                          // Define partner code configurations
                          const partnerCodes = {
                            'SUPP80': {
                              'source': 'supple_sense',
                              'event': 'Onboarding Referral Supp80 Entered',
                            },
                            'EVELINA': {
                              'source': 'evelina_greek',
                              'event': 'Onboarding Referral Evelina Entered',
                            },
                            'HANAJANA': {
                              'source': 'hanajana',
                              'event': 'Onboarding Referral HanaJana Entered',
                            },
                           
                          };

                          final config = partnerCodes[referralCode]!;
                          debugPrint('🧑‍💻 ${referralCode} code entered. Processing...');
                          
                          if (user == null) {
                            try {
                              debugPrint('🔑 Creating anonymous user for ${referralCode} code access');
                              final userCredential = await _auth.signInAnonymously();
                              user = userCredential.user;
                              debugPrint('✅ Anonymous user created for ${referralCode}: ${user?.uid}');
                            } catch (e) {
                              debugPrint('❌ Error creating anonymous user for ${referralCode}: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.translate('referralCode_error_creatingAccount'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFDC2626), // Darker red for critical errors
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                              return;
                            }
                          }

                          if (user != null) {
                            try {
                              debugPrint('🔑 Processing ${referralCode} for user: ${user.uid}');
                              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                'uid': user.uid,
                                'isAnonymous': user.isAnonymous,
                                'referralCode': referralCode,
                                'partnerUser': true,
                                'partnerSource': config['source'],
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                              debugPrint('✅ User updated in Firestore for ${referralCode} code');

                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('is_partner_user', true);
                              debugPrint('✅ Saved ${referralCode} partner status to SharedPreferences');

                              // Show success toast banner
                              _showToastBanner(
                                l10n.translate('referralCode_success_valid'),
                                isError: false,
                              );

                              // MIXPANEL_COST_CUT: Removed partner source tracking - use Firebase/Firestore instead

                            } catch (e) {
                              debugPrint('❌ Error updating Firestore/Mixpanel for ${referralCode}: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.translate('referralCode_error_processingPromo'),
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFDC2626), // Darker red for critical errors
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                              return; 
                            }
                          }
                          
                          if (mounted) {
                            // Briefly show success toast before navigating
                            await Future.delayed(const Duration(milliseconds: 900));
                            if (!mounted) return;
                            debugPrint('🚀 Navigating to LetterFromFutureScreen for ${referralCode} user...');
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const LetterFromFutureScreen(),
                              ),
                            );
                          }
                          return;
                        }
                        // 3. EMPTY CODE (SKIP BEHAVIOR)
                        else if (referralCode.isEmpty) {
                          debugPrint('💨 Skip (empty code). Navigating to LetterFromFutureScreen.');
                          // MIXPANEL_COST_CUT: Removed skip tracking - use Firebase Analytics instead
                          // No Firestore save for empty code
                          if (mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const LetterFromFutureScreen(),
                              ),
                            );
                          }
                          return;
                        }
                        // 4. OTHER NON-EMPTY CODES (INVALID PROMO CODE)
                        else { 
                          debugPrint('⚠️ Invalid promo code entered: $referralCode');
                          // Show error toast banner instead of SnackBar
                          _showToastBanner(
                            l10n.translate('referralCode_error_invalidPromo'),
                            isError: true,
                          );
                          return;
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 60,
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
                          _isReferralCodeEmpty ? l10n.translate('referralCode_button_skip') : l10n.translate('referralCode_button_continue'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            color: Colors.white, // White text on gradient
                            fontSize: 19, // Increased from 15 to 19 for Gen-Z friendly
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ],
            ),

              // Toast banner overlay (styled similar to HomeScreen info bubble)
              if (_showToast)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 96,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (_toastIsError
                                ? const Color(0xFFed3272)
                                : const Color(0xFFed3272))
                            .withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFfae6ec).withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _toastIsError ? Icons.error_outline : Icons.check_circle_outline,
                            color: _toastIsError
                                ? const Color(0xFFed3272)
                                : Colors.green,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _toastMessage,
                            maxLines: 3,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 16,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }
} 