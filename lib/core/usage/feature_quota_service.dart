import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

class FeatureQuotaService {
  static final FeatureQuotaService _instance = FeatureQuotaService._internal();
  factory FeatureQuotaService() => _instance;
  FeatureQuotaService._internal();

  // Quota limits
  static const int LEARN_VIDEO_LIMIT = 1;  // Only lesson 1
  static const int PANIC_FLOW_STEPS_LIMIT = 5; // 50% of panic flow (~5 screens)
  static const int FOOD_SCAN_LIMIT = 1;    // 1 scan
  static const int RATE_MY_PLATE_LIMIT = 1; // 1 plate analysis
  static const int CHALLENGE_LIMIT = 1;    // 1 challenge/task
  static const int CHATBOT_LIMIT = 3;      // 4 messages (text/voice)

  // SharedPreferences keys (local cache/fallback)
  static const String _learnVideoCountKey = 'learn_video_plays_free';
  static const String _panicFlowStepsKey = 'panic_flow_steps_free';
  static const String _foodScanCountKey = 'food_scans_free';
  static const String _rateMyPlateCountKey = 'rate_my_plate_scans_free';
  static const String _challengeCountKey = 'challenge_tasks_free';
  static const String _chatbotCountKey = 'chatbot_messages_free';
  
  // Firestore collection for quota tracking
  static const String _quotaCollection = 'user_feature_quotas';

  // Core methods (Firestore-first with SharedPreferences fallback)
  Future<bool> canUseLearnVideo() async { 
    return await _checkQuota(_learnVideoCountKey, LEARN_VIDEO_LIMIT);
  }
  
  Future<void> recordLearnVideoUse() async { 
    await _incrementQuota(_learnVideoCountKey);
  }
  
  Future<bool> canContinuePanicFlow() async { 
    return await _checkQuota(_panicFlowStepsKey, PANIC_FLOW_STEPS_LIMIT);
  }
  
  Future<void> recordPanicFlowStep() async { 
    await _incrementQuota(_panicFlowStepsKey);
  }
  
  Future<bool> canUseFoodScan() async { 
    return await _checkQuota(_foodScanCountKey, FOOD_SCAN_LIMIT);
  }
  
  Future<void> recordFoodScanUse() async { 
    debugPrint('📊 FeatureQuotaService: Recording food scan usage');
    await _incrementQuota(_foodScanCountKey);
  }
  
  Future<bool> canUseRateMyPlate() async { 
    return await _checkQuota(_rateMyPlateCountKey, RATE_MY_PLATE_LIMIT);
  }
  
  Future<void> recordRateMyPlateUse() async { 
    debugPrint('📊 FeatureQuotaService: Recording rate my plate usage');
    await _incrementQuota(_rateMyPlateCountKey);
  }
  
  Future<bool> canUseChallenge() async { 
    return await _checkQuota(_challengeCountKey, CHALLENGE_LIMIT);
  }
  
  Future<void> recordChallengeUse() async { 
    await _incrementQuota(_challengeCountKey);
  }
  
  Future<bool> canUseChatbot() async { 
    return await _checkQuota(_chatbotCountKey, CHATBOT_LIMIT);
  }
  
  Future<void> recordChatbotUse() async { 
    await _incrementQuota(_chatbotCountKey);
  }
  
  Future<void> resetAllQuotas() async { 
    // Reset both Firestore and SharedPreferences
    await _resetFirestoreQuotas();
    await _resetSharedPreferencesQuotas();
  }
  
  // DEBUG ONLY: Force reset all quotas (for testing)
  Future<void> debugResetAllQuotas() async {
    if (!kDebugMode) {
      debugPrint('⚠️ debugResetAllQuotas() can only be called in debug mode');
      return;
    }
    
    debugPrint('🔄 DEBUG: Resetting all feature quotas...');
    
    try {
      // Reset Firestore quotas
      await _resetFirestoreQuotas();
      debugPrint('✅ DEBUG: Firestore quotas reset');
    } catch (e) {
      debugPrint('❌ DEBUG: Failed to reset Firestore quotas: $e');
    }
    
    try {
      // Reset SharedPreferences quotas
      await _resetSharedPreferencesQuotas();
      debugPrint('✅ DEBUG: SharedPreferences quotas reset');
    } catch (e) {
      debugPrint('❌ DEBUG: Failed to reset SharedPreferences quotas: $e');
    }
    
    debugPrint('🎉 DEBUG: All quotas reset successfully!');
  }
  
  // Get user identifier for both authenticated and anonymous users
  Future<String?> _getUserIdentifier() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Both authenticated and Firebase anonymous users have UIDs
      return user.uid;
    } else {
      // No Firebase user - create anonymous user (same pattern as main.dart and profile_info_screen.dart)
      try {
        debugPrint('🆔 FeatureQuotaService: No Firebase user found, creating anonymous user...');
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        final uid = userCredential.user?.uid;
        
        if (uid != null) {
          debugPrint('🆔 FeatureQuotaService: Created Firebase anonymous user: $uid');
          
          // Identify with Superwall (same as other parts of app)
          await Superwall.shared.identify(uid);
          
          return uid;
        } else {
          debugPrint('❌ FeatureQuotaService: Anonymous user creation succeeded but uid is null');
          throw Exception('Anonymous user creation failed - null UID');
        }
      } catch (e) {
        debugPrint('❌ FeatureQuotaService: Failed to create Firebase anonymous user: $e');
        
        // Fallback to device-specific ID only if Firebase completely fails
        final prefs = await SharedPreferences.getInstance();
        String? anonymousId = prefs.getString('anonymous_user_id');
        
        if (anonymousId == null) {
          anonymousId = 'anon_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 10000)}';
          await prefs.setString('anonymous_user_id', anonymousId);
          debugPrint('🆔 FeatureQuotaService: Created fallback device ID: $anonymousId');
        }
        
        return anonymousId;
      }
    }
  }

  // Get current usage count for a feature (useful for UI display)
  Future<int> getCurrentUsage(String featureKey) async {
    try {
      // Try Firestore first
      return await _getFirestoreQuota(featureKey);
    } catch (e) {
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(featureKey) ?? 0;
    }
  }
  
  // Private helper methods
  Future<bool> _checkQuota(String key, int limit) async {
    try {
      // 1. Try Firestore first
      final count = await _getFirestoreQuota(key);
      return count < limit;
    } catch (e) {
      debugPrint('FeatureQuotaService: Firestore check failed for $key, using SharedPreferences fallback: $e');
      // 2. Fallback to SharedPreferences if Firestore fails
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(key) ?? 0;
      return count < limit;
    }
  }
  
  Future<void> _incrementQuota(String key) async {
    debugPrint('🔄 FeatureQuotaService: _incrementQuota called for $key');
    try {
      // 1. Update Firestore first
      await _incrementFirestoreQuota(key);
      // 2. Update SharedPreferences as backup
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, currentCount + 1);
      debugPrint('✅ FeatureQuotaService: Successfully incremented $key (Firestore + SharedPreferences)');
    } catch (e) {
      debugPrint('❌ FeatureQuotaService: Firestore increment failed for $key, using SharedPreferences only: $e');
      // If Firestore fails, at least update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, currentCount + 1);
      debugPrint('✅ FeatureQuotaService: Successfully incremented $key (SharedPreferences only)');
    }
  }
  
  Future<int> _getFirestoreQuota(String key) async {
    final uid = await _getUserIdentifier();
    if (uid == null) throw Exception('No user identifier available');
    
    final doc = await FirebaseFirestore.instance
        .collection(_quotaCollection)
        .doc(uid)
        .get();
    
    return doc.data()?[key] ?? 0;
  }
  
  Future<void> _incrementFirestoreQuota(String key) async {
    final uid = await _getUserIdentifier();
    if (uid == null) {
      debugPrint('❌ FeatureQuotaService: No user identifier available for $key');
      throw Exception('No user identifier available');
    }
    
    debugPrint('🔄 FeatureQuotaService: Incrementing $key for user $uid');
    
    try {
      await FirebaseFirestore.instance
          .collection(_quotaCollection)
          .doc(uid)
          .set({
            key: FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      debugPrint('✅ FeatureQuotaService: Successfully incremented $key in Firestore');
    } catch (e) {
      debugPrint('❌ FeatureQuotaService: Failed to increment $key in Firestore: $e');
      rethrow;
    }
  }
  
  Future<void> _resetFirestoreQuotas() async {
    try {
      final uid = await _getUserIdentifier();
      if (uid == null) return;
      
      await FirebaseFirestore.instance
          .collection(_quotaCollection)
          .doc(uid)
          .set({
            _learnVideoCountKey: 0,
            _panicFlowStepsKey: 0,
            _foodScanCountKey: 0,
            _rateMyPlateCountKey: 0,
            _challengeCountKey: 0,
            _chatbotCountKey: 0,
            'resetAt': FieldValue.serverTimestamp(),
          });
      debugPrint('FeatureQuotaService: Firestore quotas reset');
    } catch (e) {
      debugPrint('FeatureQuotaService: Failed to reset Firestore quotas: $e');
    }
  }
  
  Future<void> _resetSharedPreferencesQuotas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_learnVideoCountKey);
      await prefs.remove(_panicFlowStepsKey);
      await prefs.remove(_foodScanCountKey);
      await prefs.remove(_rateMyPlateCountKey);
      await prefs.remove(_challengeCountKey);
      await prefs.remove(_chatbotCountKey);
      debugPrint('FeatureQuotaService: SharedPreferences quotas reset');
    } catch (e) {
      debugPrint('FeatureQuotaService: Failed to reset SharedPreferences quotas: $e');
    }
  }
} 