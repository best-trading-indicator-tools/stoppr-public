import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/analytics/crashlytics_service.dart';
import 'package:flutter/foundation.dart';
import 'package:stoppr/core/subscription/subscription_service.dart';

enum OnboardingScreen {
  questionnaireScreen1,
  questionnaireScreen2,
  questionnaireScreen3,
  questionnaireScreen4,
  questionnaireScreen5,
  questionnaireScreen6,
  questionnaireScreen7,
  questionnaireScreen8,
  questionnaireScreen9,
  questionnaireScreen10,
  questionnaireScreen11,
  questionnaireScreen12,
  questionnaireScreen13,
  profileInfoScreen,
  symptomsScreen,
  sugarPainpointsPageView,
  benefitsPageView,
  stopprScienceBackedPlanScreen,
  referralCodeScreen,
  chooseGoalsScreen,
  current6BlocksRatingScreen,
  potentialRatingScreen,
  weeksProgressionScreen,
  prePaywallScreen,
  analysisResultScreen,
  giveUsRatingsScreen,
  benefitsImpactScreen,
  letterFromFutureScreen,
  readTheVowScreen,
  onboardingScreen4,
  welcomeVideoScreen,
  consumptionSummaryScreen,
  insightsScreen,
  mainAppReady, // Indicates user has completed onboarding and is in the main app
  // Keep the old questionnaireScreen for backward compatibility
  @Deprecated('Use questionnaireScreen1-13 instead')
  questionnaireScreen,
  // Add other screens as needed
}

class OnboardingProgressService {
  static const String _currentScreenKey = 'onboarding_current_screen';
  static const String _questionnaireIndexKey = 'onboarding_questionnaire_index';
  static const String _questionnaireAnswersKey = 'onboarding_questionnaire_answers';
  static const String _painpointsPageIndexKey = 'onboarding_painpoints_page_index';
  static const String _benefitsPageIndexKey = 'onboarding_benefits_page_index';
  static const String _onboardingCompletedKey = 'onboarding_completed'; // Flag to track completion
  
  // Configurable timeout duration for subscription verification
  static const Duration _subscriptionVerificationTimeout = Duration(seconds: 3);
  
  // Helper method to get questionnaire screen by question number (1-based)
  static OnboardingScreen getQuestionnaireScreen(int questionNumber) {
    switch (questionNumber) {
      case 1: return OnboardingScreen.questionnaireScreen1;
      case 2: return OnboardingScreen.questionnaireScreen2;
      case 3: return OnboardingScreen.questionnaireScreen3;
      case 4: return OnboardingScreen.questionnaireScreen4;
      case 5: return OnboardingScreen.questionnaireScreen5;
      case 6: return OnboardingScreen.questionnaireScreen6;
      case 7: return OnboardingScreen.questionnaireScreen7;
      case 8: return OnboardingScreen.questionnaireScreen8;
      case 9: return OnboardingScreen.questionnaireScreen9;
      case 10: return OnboardingScreen.questionnaireScreen10;
      case 11: return OnboardingScreen.questionnaireScreen11;
      case 12: return OnboardingScreen.questionnaireScreen12;
      case 13: return OnboardingScreen.questionnaireScreen13;
      default: return OnboardingScreen.questionnaireScreen1;
    }
  }
  
  // Helper method to extract question number from questionnaire screen (returns null if not a questionnaire screen)
  static int? getQuestionNumberFromScreen(OnboardingScreen screen) {
    switch (screen) {
      case OnboardingScreen.questionnaireScreen1: return 1;
      case OnboardingScreen.questionnaireScreen2: return 2;
      case OnboardingScreen.questionnaireScreen3: return 3;
      case OnboardingScreen.questionnaireScreen4: return 4;
      case OnboardingScreen.questionnaireScreen5: return 5;
      case OnboardingScreen.questionnaireScreen6: return 6;
      case OnboardingScreen.questionnaireScreen7: return 7;
      case OnboardingScreen.questionnaireScreen8: return 8;
      case OnboardingScreen.questionnaireScreen9: return 9;
      case OnboardingScreen.questionnaireScreen10: return 10;
      case OnboardingScreen.questionnaireScreen11: return 11;
      case OnboardingScreen.questionnaireScreen12: return 12;
      case OnboardingScreen.questionnaireScreen13: return 13;
      default: return null;
    }
  }
  
  // Helper method to check if a screen is a questionnaire screen
  static bool isQuestionnaireScreen(OnboardingScreen screen) {
    return getQuestionNumberFromScreen(screen) != null;
  }
  
  // Save current questionnaire screen with question number
  Future<void> saveCurrentQuestionnaireScreen(int questionNumber) async {
    final screen = getQuestionnaireScreen(questionNumber);
    await saveCurrentScreen(screen);
  }
  
  // Example usage:
  // To save that user is on question 3: await saveCurrentQuestionnaireScreen(3);
  // This will save OnboardingScreen.questionnaireScreen3
  // 
  // To check current question: 
  // final currentScreen = await getCurrentScreen();
  // final questionNumber = getQuestionNumberFromScreen(currentScreen);
  // if (questionNumber != null) {
  //   print('User is on question $questionNumber');
  // }
  
  // Save current onboarding screen
  Future<void> saveCurrentScreen(OnboardingScreen screen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentScreenKey, screen.toString());
    
    // Si un user Firebase existe, sauvegarder aussi dans Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'lastOnboardingScreen': screen.toString()}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('❌ Error saving lastOnboardingScreen to Firestore: $e');
      }
    }
    
    // If we're saving mainAppReady, also set the completion flag
    if (screen == OnboardingScreen.mainAppReady) {
      await prefs.setBool(_onboardingCompletedKey, true);
      print('✅ Saved onboarding as COMPLETED - user is in main app');
    }
  }
  
  // Get current onboarding screen
  Future<OnboardingScreen?> getCurrentScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final screenString = prefs.getString(_currentScreenKey);
    
    debugPrint('🔥 OnboardingProgressService: Read screenString from SharedPrefs: $screenString');
    
    // Si on a une valeur en local, on l'utilise
    if (screenString != null) {
      final result = OnboardingScreen.values.firstWhere(
        (e) => e.toString() == screenString,
        orElse: () => OnboardingScreen.questionnaireScreen1, // Default
      );
      debugPrint('🔥 OnboardingProgressService: Returning screen from SharedPrefs: $result');
      return result;
    }
    
    // Si pas de valeur locale, essayer de récupérer depuis Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        debugPrint('🔥 OnboardingProgressService: SharedPrefs empty, trying Firestore...');
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (doc.exists && doc.data()?['lastOnboardingScreen'] != null) {
          final firestoreScreen = doc.data()!['lastOnboardingScreen'] as String;
          debugPrint('🔥 OnboardingProgressService: Found screen in Firestore: $firestoreScreen');
          
          // Re-sauvegarder en local pour la prochaine fois
          await prefs.setString(_currentScreenKey, firestoreScreen);
          
          final result = OnboardingScreen.values.firstWhere(
            (e) => e.toString() == firestoreScreen,
            orElse: () => OnboardingScreen.questionnaireScreen1,
          );
          
          debugPrint('🔥 OnboardingProgressService: Returning screen from Firestore: $result');
          return result;
        }
      } catch (e) {
        debugPrint('🔥 OnboardingProgressService: Error reading from Firestore: $e');
      }
    }
    
    debugPrint('🔥 OnboardingProgressService: No saved screen found anywhere, returning null');
    return null;
  }
  
  // Mark onboarding as complete and ready for main app
  Future<void> markOnboardingComplete([String? userId]) async {
    // SECURITY: Verify user actually paid before marking complete
    try {
      // Debug/TestFlight bypass to allow developer QA
      bool isTf = false;
      try { isTf = await MixpanelService.isTestFlight(); } catch (_) {}
      if (kDebugMode || isTf) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_onboardingCompletedKey, true);
        await saveCurrentScreen(OnboardingScreen.mainAppReady);
        if (userId != null && userId.trim().isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .set({'onboardingCompleted': true}, SetOptions(merge: true));
          } catch (_) {}
        }
        debugPrint('✅ OnboardingProgressService: Bypass markOnboardingComplete for debug/TestFlight');
        return;
      }

      // Validate userId is not null or empty before calling subscription service
      if (userId == null || userId.trim().isEmpty) {
        debugPrint('🔒 OnboardingProgressService: Invalid userId provided, cannot verify subscription');
        
        // Log to Crashlytics for monitoring
        CrashlyticsService.setCustomKey('onboarding_error_type', 'invalid_user_id');
        CrashlyticsService.logException(
          Exception('Invalid userId provided for onboarding completion'),
          StackTrace.current,
          reason: 'Onboarding Complete - Invalid User ID',
        );
        
        // MIXPANEL_COST_CUT: Removed error tracking - use Crashlytics
        return; // Don't mark complete for invalid user ID
      }
      
      final subscriptionService = SubscriptionService();
      final isPaid = await subscriptionService.isPaidSubscriber(userId).timeout(
        _subscriptionVerificationTimeout,
        onTimeout: () => false, // Default to unpaid on timeout
      );
      
      if (!isPaid) {
        debugPrint('🔒 OnboardingProgressService: Blocked markOnboardingComplete for non-paid user (userId: $userId)');
        
        // Log to Crashlytics for monitoring
        CrashlyticsService.setCustomKey('onboarding_error_type', 'subscription_verification_failed');
        CrashlyticsService.setCustomKey('user_id', userId);
        CrashlyticsService.logException(
          Exception('Non-paid user attempted to complete onboarding'),
          StackTrace.current,
          reason: 'Onboarding Complete - Subscription Verification Failed',
        );
        
        // MIXPANEL_COST_CUT: Removed error tracking - use Crashlytics
        return; // Don't mark complete for free users
      }
      
      debugPrint('✅ OnboardingProgressService: Payment verified, proceeding with markOnboardingComplete');
    } on SocketException catch (e) {
      debugPrint('🔴 OnboardingProgressService: Network error during payment verification: $e');
      
      // Network error during subscription verification - not sent to Crashlytics
      
      // MIXPANEL_COST_CUT: Removed network error tracking - use Crashlytics
      return;
    } on TimeoutException catch (e) {
      debugPrint('🔴 OnboardingProgressService: Timeout during payment verification: $e');
      
      // Timeout during subscription verification - not sent to Crashlytics
      
      // MIXPANEL_COST_CUT: Removed timeout error tracking - use Crashlytics
      return;
    } on FirebaseException catch (e) {
      debugPrint('🔴 OnboardingProgressService: Firebase error during payment verification: $e');
      
      // Log to Crashlytics for monitoring
      CrashlyticsService.setCustomKey('onboarding_error_type', 'firebase_error');
      CrashlyticsService.setCustomKey('user_id', userId);
      CrashlyticsService.setCustomKey('firebase_error_code', e.code);
      CrashlyticsService.logException(
        e,
        StackTrace.current,
        reason: 'Onboarding Complete - Firebase Error During Subscription Verification',
      );
      
      // MIXPANEL_COST_CUT: Removed Firebase error tracking - use Crashlytics
      return;
    } catch (e) {
      debugPrint('🔴 OnboardingProgressService: Unexpected error during payment verification: $e');
      
      // Log to Crashlytics for monitoring
      CrashlyticsService.setCustomKey('onboarding_error_type', 'unexpected_error');
      CrashlyticsService.setCustomKey('user_id', userId);
      CrashlyticsService.logException(
        e,
        StackTrace.current,
        reason: 'Onboarding Complete - Unexpected Error During Subscription Verification',
      );
      
      // On error, don't mark complete to be safe
      // MIXPANEL_COST_CUT: Removed verification error tracking - use Crashlytics
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    await saveCurrentScreen(OnboardingScreen.mainAppReady);
    
    // MIXPANEL_COST_CUT: Removed system flag tracking - operational noise
    
    // Also store in Firestore for persistence across reinstalls
    if (userId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({'onboardingCompleted': true}, SetOptions(merge: true));
            
        // MIXPANEL_COST_CUT: Removed Firebase flag tracking - operational noise
            
        print('✅ Marked onboarding as COMPLETED in Firestore for user: $userId');
      } catch (e) {
        // MIXPANEL_COST_CUT: Removed Firebase error tracking - use Crashlytics
        print('❌ Failed to mark onboarding complete in Firestore: $e');
      }
    }
    
    if (userId != null) {
      print('✅ Marked onboarding as COMPLETED for user: $userId');
    } else {
      print('✅ Marked onboarding as COMPLETED');
    }
  }
  
  // Check if onboarding is completed in SharedPreferences
  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_onboardingCompletedKey) ?? false;
    
    // Track check in Mixpanel
    /*MixpanelService.trackEvent('Onboarding Status Check Performed', properties: {
      'storage': 'SharedPreferences',
      'isOnboardingComplete': completed,
    });*/
    
    return completed;
  }
  
  // Check if onboarding is completed in Firestore
  Future<bool> isOnboardingCompletedInFirestore(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
          
      bool completed = false;
      if (userDoc.exists && userDoc.data() != null) {
        completed = userDoc.data()!['onboardingCompleted'] ?? false;
        
      } 
      
      return completed;
    } catch (e) {
      // MIXPANEL_COST_CUT: Removed status check error tracking - use Crashlytics
      print('❌ Error checking Firestore onboarding status: $e');
      return false;
    }
  }
  
  // Save questionnaire progress
  Future<void> saveQuestionnaireProgress(int questionIndex, Map<int, String> answers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_questionnaireIndexKey, questionIndex);
    
    // Convert int keys to string keys for proper JSON encoding
    final Map<String, String> stringKeyMap = {};
    answers.forEach((key, value) {
      stringKeyMap[key.toString()] = value;
    });
    
    await prefs.setString(_questionnaireAnswersKey, jsonEncode(stringKeyMap));
  }
  
  // Get questionnaire index
  Future<int> getQuestionnaireIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_questionnaireIndexKey) ?? 0;
  }
  
  // Get questionnaire answers
  Future<Map<int, String>> getQuestionnaireAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final answersString = prefs.getString(_questionnaireAnswersKey);
    
    if (answersString == null) return {};
    
    final Map<String, dynamic> decodedMap = jsonDecode(answersString);
    final Map<int, String> typedMap = {};
    
    decodedMap.forEach((key, value) {
      typedMap[int.parse(key)] = value.toString();
    });
    
    return typedMap;
  }
  
  // Save painpoints page index
  Future<void> savePainpointsPageIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_painpointsPageIndexKey, index);
  }
  
  // Get painpoints page index
  Future<int> getPainpointsPageIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_painpointsPageIndexKey) ?? 0;
  }
  
  // Save benefits page index
  Future<void> saveBenefitsPageIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_benefitsPageIndexKey, index);
  }
  
  // Get benefits page index
  Future<int> getBenefitsPageIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_benefitsPageIndexKey) ?? 0;
  }
  
  // Clear onboarding progress (to be called when onboarding is completed)
  Future<void> clearOnboardingProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentScreenKey);
    await prefs.remove(_questionnaireIndexKey);
    await prefs.remove(_questionnaireAnswersKey);
    await prefs.remove(_painpointsPageIndexKey);
    await prefs.remove(_benefitsPageIndexKey);
    await prefs.remove(_onboardingCompletedKey); // Also clear the completion flag
  }
} 