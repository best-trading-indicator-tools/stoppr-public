import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/user_repository.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

class StreakService with WidgetsBindingObserver {
  // Singleton pattern
  static final StreakService _instance = StreakService._internal();
  
  factory StreakService() {
    return _instance;
  }
  
  StreakService._internal();
  
  // Keys for shared preferences and home_widget
  static const String _streakStartKey = 'streak_start_timestamp';
  // TODO: Replace with your app group identifier (must match ios/StreakWidgetExtension.entitlements)
  static const String _appGroupId = 'group.YOUR_BUNDLE_ID.shared';
  static const String _localizedLabelKey = 'widget_localized_label_sugar_free_since'; // New key from Swift
  static const String _subscriptionStatusKey = 'widget_has_active_subscription'; // New key for subscription status
  
  // Added Firebase Auth and User Repository instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();
  
  // Stream controller for streak updates
  final StreamController<StreakData> _streakController = StreamController<StreakData>.broadcast();
  
  // Stream of streak data that widgets can listen to
  Stream<StreakData> get streakStream => _streakController.stream;
  
  // Current streak data
  StreakData _currentStreak = const StreakData(
    days: 0,
    hours: 0,
    minutes: 0,
    seconds: 0,
    startTime: null,
  );
  
  // Get the current streak data without subscribing to updates
  StreakData get currentStreak => _currentStreak;
  
  // Timer for updating streak
  Timer? _streakTimer;
  
  // Initialize the streak service
  Future<void> initialize() async {
    await _loadStreakCounter();
    
    // Configure HomeWidget
    await HomeWidget.setAppGroupId(_appGroupId);

    // Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Start timer to update streak counter every second
    _updateStreakCounter(); // Initial update
    _streakTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateStreakCounter();
    });

    // Backup check: Ensure widget subscription status is properly set for existing users
    await _checkAndUpdateWidgetSubscriptionStatus();
  }
  
  // Load streak data from shared preferences
  Future<void> _loadStreakCounter() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;
    
    DateTime? startTime;
    
    // For logged-in users, check if they have a subscription and try Firestore first
    if (user != null) {
      try {
        // Check if user has active subscription via RevenueCat
        final customerInfo = await Purchases.getCustomerInfo();
        final hasActiveSubscription = customerInfo.activeSubscriptions.isNotEmpty || 
                                     customerInfo.entitlements.active.isNotEmpty;
        
        if (hasActiveSubscription) {
          debugPrint('🔍 User has active subscription - checking Firestore for streak data first');
          
          // Try to get streak from Firestore first
          final firestoreStartTime = await _userRepository.getUserStreakStartDate(user.uid);
          
          if (firestoreStartTime != null) {
            debugPrint('✅ Using streak from Firestore: $firestoreStartTime');
            startTime = firestoreStartTime;
            
            // Update SharedPreferences with Firestore value to keep them in sync
            await prefs.setInt(_streakStartKey, firestoreStartTime.millisecondsSinceEpoch);
            
            // Update HomeWidget with the Firestore data
            await _updateHomeWidgetData(startTime);
            
            _currentStreak = _currentStreak.copyWith(startTime: startTime);
            return; // Exit early, we have our data
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error checking subscription or Firestore: $e. Falling back to SharedPreferences');
      }
    }
    
    // Fallback to SharedPreferences when RC/Firestore load path above didn't return
    // IMPORTANT (prod): Do not auto-create a start time here for real users.
    final streakStartTimestamp = prefs.getInt(_streakStartKey);
    if (streakStartTimestamp != null) {
      startTime = DateTime.fromMillisecondsSinceEpoch(streakStartTimestamp);
      // Best-effort sync to widget; avoid writing to Firestore unless user is logged in
      await _updateHomeWidgetData(startTime);
      if (user != null) {
        await _updateStreakInFirestore(startTime);
      }
    } else {
      // No local value and we didn't manage to get Firestore above.
      // For debug/TestFlight builds only, seed a start time so developers can test the full flow.
      bool isTestFlight = false;
      try {
        isTestFlight = await MixpanelService.isTestFlight();
      } catch (_) {}
      if (kDebugMode || isTestFlight) {
        final seeded = DateTime.now();
        await prefs.setInt(_streakStartKey, seeded.millisecondsSinceEpoch);
        startTime = seeded;
        await _updateHomeWidgetData(startTime);
      } else {
        // Production: leave as null, UI shows 0 until user sets/earns a streak.
        startTime = null;
        await _updateHomeWidgetData(startTime);
      }
    }
    
    _currentStreak = _currentStreak.copyWith(startTime: startTime);
  }
  
  // Update streak counter calculations
  void _updateStreakCounter() {
    if (_currentStreak.startTime != null) {
      final difference = DateTime.now().difference(_currentStreak.startTime!);
      
      _currentStreak = StreakData(
        days: difference.inDays,
        hours: difference.inHours % 24,
        minutes: difference.inMinutes % 60,
        seconds: difference.inSeconds % 60,
        startTime: _currentStreak.startTime,
      );
      
      // Notify listeners of the updated streak
      _streakController.add(_currentStreak);
    }
  }
  
  // Reset streak counter
  Future<void> resetStreakCounter() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    
    // Save new start time
    await prefs.setInt(_streakStartKey, now.millisecondsSinceEpoch);
    
    // Update streak data
    _currentStreak = StreakData(
      days: 0,
      hours: 0,
      minutes: 0,
      seconds: 0,
      startTime: now,
    );
    
    // Notify listeners of the reset
    _streakController.add(_currentStreak);
    
    // Added: Update Firestore
    await _updateStreakInFirestore(now);
    // Update HomeWidget
    await _updateHomeWidgetData(now);
  }
  
  // Set a custom start date for the streak
  Future<void> setCustomStreakStartDate(DateTime startDate) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save the custom start date
    await prefs.setInt(_streakStartKey, startDate.millisecondsSinceEpoch);
    
    // Calculate the time difference from now to the custom start date
    final difference = DateTime.now().difference(startDate);
    
    // Update streak data with the custom date
    _currentStreak = StreakData(
      days: difference.inDays,
      hours: difference.inHours % 24,
      minutes: difference.inMinutes % 60,
      seconds: difference.inSeconds % 60,
      startTime: startDate,
    );
    
    // Notify listeners of the updated streak
    _streakController.add(_currentStreak);
    
    // Added: Update Firestore
    await _updateStreakInFirestore(startDate);
    // Update HomeWidget
    await _updateHomeWidgetData(startDate);
  }
  
  // Added: Helper method to update streak data in Firestore
  Future<void> _updateStreakInFirestore(DateTime? startTime) async {
    final user = _auth.currentUser;
    if (user == null) {
      // Only update Firestore if user is logged in
      debugPrint('User not logged in, skipping Firestore streak update.');
      return;
    }
    // It's important that _updateHomeWidgetData is called AFTER potential streak changes
    // so it has the latest startTime. The label update is independent of startTime but should be bundled.
    await _userRepository.updateUserStreakData(user.uid, startTime);
  }
  
  // Placeholder method to get current language code - IMPLEMENT THIS
  Future<String> _getCurrentLanguageCode() async {
    // Example: Load from SharedPreferences if you save it there when user changes language
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_selected_language_code') ?? 'en'; // Default to 'en' if not found
  }
  
  // Added: Helper method to update HomeWidget data
  Future<void> _updateHomeWidgetData(DateTime? startTime) async {
    try {
      // Always set App Group ID before any widget update
      await HomeWidget.setAppGroupId(_appGroupId);
      // Get current language code (you'll need to implement this logic)
      // This is a placeholder. Replace with your actual language fetching logic.
      final String currentLangCode = await _getCurrentLanguageCode(); 

      // Load the AppLocalizations for the current language
      final locale = Locale(currentLangCode);
      final AppLocalizations l10n = AppLocalizations(locale);
      await l10n.load(); // Make sure translations are loaded

      final String localizedLabel = l10n.translate('widget_sugarFreeSince');
      final String subscribePrompt = l10n.translate('widget_subscribeToTrackStreak');

      // Save the timestamp (or 0 if null) using the same key the widget expects
      // IMPORTANT: Must save as long (not int) to match Android's getLong() call
      final int timestampValue = startTime?.millisecondsSinceEpoch ?? 0;
      await HomeWidget.saveWidgetData<int>(_streakStartKey, timestampValue);
      
      // Debug logging to track widget updates
      debugPrint('📱 Widget Update: Saving timestamp: $timestampValue (${startTime?.toIso8601String() ?? "null"})');
      // Save the localized label
      await HomeWidget.saveWidgetData<String>(_localizedLabelKey, localizedLabel);
      // Save the localized subscribe prompt
      await HomeWidget.saveWidgetData<String>('widget_subscribeToTrackStreak', subscribePrompt);

      // Note: Subscription status is managed by updateWidgetSubscriptionStatus method
      // called from SuperwallPurchaseController - don't override it here

      // Ask the widget to reload its timeline
      await HomeWidget.updateWidget(
        name: 'StreakWidget', // Ensure this matches the widget's Kind in Swift
        iOSName: 'StreakWidget', // Use the same Kind for iOS
      );
      debugPrint('HomeWidget data saved and update requested.');
    } catch (e) {
      debugPrint('Error updating HomeWidget data: $e');
    }
  }
  
  // Public method to force sync widget data
  Future<void> syncWidgetData() async {
    debugPrint('🔄 Manually syncing widget data...');
    await _updateHomeWidgetData(_currentStreak.startTime);
  }
  
  // Public method to force refresh streak from Firestore
  Future<void> refreshStreakFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in, cannot refresh from Firestore');
      return;
    }
    
    try {
      debugPrint('🔄 Force refreshing streak from Firestore...');
      final firestoreStartTime = await _userRepository.getUserStreakStartDate(user.uid);
      
      if (firestoreStartTime != null) {
        debugPrint('✅ Refreshed streak from Firestore: $firestoreStartTime');
        
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_streakStartKey, firestoreStartTime.millisecondsSinceEpoch);
        
        // Update current streak
        _currentStreak = _currentStreak.copyWith(startTime: firestoreStartTime);
        
        // Update the widget
        await _updateHomeWidgetData(firestoreStartTime);
        
        // Force update the streak counter
        _updateStreakCounter();
      } else {
        debugPrint('⚠️ No streak data found in Firestore for user');
      }
    } catch (e) {
      debugPrint('❌ Error refreshing streak from Firestore: $e');
    }
  }
  
  // Public method to update subscription status for the widget
  Future<void> updateWidgetSubscriptionStatus(bool hasActiveSubscription) async {
    try {
      // Check if the current user is the Apple reviewer
      final user = _auth.currentUser;
      bool isAppleReviewer = false;
      if (user != null && (user.email == 'applereviews2025@gmail.com' || user.email == 'hello@stoppr.app')) {
        isAppleReviewer = true;
        debugPrint('🍎 Detected Apple reviewer account - forcing widget to show active subscription');
      }
      // Allow debug and TestFlight users to behave as subscribed
      bool isTestFlight = false;
      try {
        isTestFlight = await MixpanelService.isTestFlight();
      } catch (_) {}
      
      // Always set App Group ID before any widget update
      await HomeWidget.setAppGroupId(_appGroupId);
      
      // Save the subscription status - force true for Apple reviewer
      final bool forceActive = kDebugMode || isAppleReviewer || isTestFlight;
      await HomeWidget.saveWidgetData<bool>(_subscriptionStatusKey, forceActive || hasActiveSubscription);
      
      // Ask the widget to reload its timeline
      await HomeWidget.updateWidget(
        name: 'StreakWidget',
        iOSName: 'StreakWidget',
      );
      
      debugPrint('Widget subscription status updated to: ${forceActive || hasActiveSubscription} (debug: $kDebugMode, testflight: $isTestFlight, appleReviewer: $isAppleReviewer)');
    } catch (e) {
      debugPrint('Error updating widget subscription status: $e');
    }
  }

  // Backup method to check subscription status for existing users
  Future<void> _checkAndUpdateWidgetSubscriptionStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check if user has active subscription via RevenueCat
      final customerInfo = await Purchases.getCustomerInfo();
      final hasActiveSubscription = customerInfo.activeSubscriptions.isNotEmpty || 
                                   customerInfo.entitlements.active.isNotEmpty;
      
      debugPrint('🔍 StreakService backup check: User has active subscription: $hasActiveSubscription');
      
      // Update widget subscription status (debug/TestFlight will be allowed inside)
      await updateWidgetSubscriptionStatus(hasActiveSubscription);
      
    } catch (e) {
      debugPrint('⚠️ Error in backup subscription check: $e');
      // Don't throw error - this is a backup check
    }
  }
  
  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground - immediately update streak to show current time
        debugPrint('App resumed - immediately updating streak counter');
        _updateStreakCounter();
        // Force update widget data when app resumes to ensure Android widget is in sync
        _updateHomeWidgetData(_currentStreak.startTime);
        
        // For paying users, also refresh from Firestore to ensure we have latest data
        _checkAndRefreshForPayingUsers();
        break;
      case AppLifecycleState.paused:
        // App going to background - update widget before app pauses
        debugPrint('App paused - updating widget with current streak data');
        _updateHomeWidgetData(_currentStreak.startTime);
        break;
      case AppLifecycleState.detached:
        // App is being terminated - save current state
        _updateHomeWidgetData(_currentStreak.startTime);
        break;
      default:
        break;
    }
  }
  
  // Helper method to check if user is paying and refresh from Firestore
  Future<void> _checkAndRefreshForPayingUsers() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      // Check if user has active subscription
      final customerInfo = await Purchases.getCustomerInfo();
      final hasActiveSubscription = customerInfo.activeSubscriptions.isNotEmpty || 
                                   customerInfo.entitlements.active.isNotEmpty;
      
      if (hasActiveSubscription) {
        debugPrint('🔄 Paying user detected on app resume - refreshing streak from Firestore');
        await refreshStreakFromFirestore();
      }
    } catch (e) {
      debugPrint('⚠️ Error checking subscription on resume: $e');
    }
  }

  // Dispose resources
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streakTimer?.cancel();
    _streakController.close();
  }
}

// Immutable class to hold streak data
@immutable
class StreakData {
  final int days;
  final int hours;
  final int minutes;
  final int seconds;
  final DateTime? startTime;
  
  const StreakData({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.startTime,
  });
  
  // Create a copy with updated values
  StreakData copyWith({
    int? days,
    int? hours,
    int? minutes,
    int? seconds,
    DateTime? startTime,
  }) {
    return StreakData(
      days: days ?? this.days,
      hours: hours ?? this.hours,
      minutes: minutes ?? this.minutes,
      seconds: seconds ?? this.seconds,
      startTime: startTime ?? this.startTime,
    );
  }
} 