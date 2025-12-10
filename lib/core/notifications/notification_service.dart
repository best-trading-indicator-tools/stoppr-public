import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/services/app_update_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import '../../features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../streak/app_open_streak_service.dart';
import 'package:stoppr/core/user/user_attributes_service.dart';

// Enum to define user subscription status type
enum NotificationAudienceType {
  subscriber,
  nonSubscriber
}

// Enum to define notification types
enum NotificationType {
  checkupReminders,
  streakGoals,
  morningMotivation,
  appUpdate,
  chatNotifications,
  marketingOffers,
  trialOffer,
  timeSensitive,
  mealCalorieTracking,
  breakfastReminder,
  lunchReminder,
  dinnerReminder,
  relapseChallengeDaily,
}

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  // Keys for SharedPreferences
  static const String notificationsEnabledKey = 'notifications_enabled_key';
  static const String checkupRemindersEnabledKey = 'checkup_reminders_enabled_key';
  static const String streakGoalsEnabledKey = 'streak_goals_enabled_key';
  static const String morningMotivationEnabledKey = 'morning_motivation_enabled_key';
  static const String appUpdateEnabledKey = 'app_update_enabled_key';
  static const String chatNotificationsEnabledKey = 'chat_notifications_enabled_key';
  static const String marketingOffersEnabledKey = 'marketing_offers_enabled_key';
  static const String lastMarketingNotificationKey = 'last_marketing_notification_timestamp';
  static const String trialOfferEnabledKey = 'trial_offer_enabled_key';
  static const String lastTrialNotificationKey = 'last_trial_notification_timestamp';
  static const String timeSensitiveEnabledKey = 'time_sensitive_enabled_key';
  static const String lastTimeSensitiveNotificationKey = 'last_time_sensitive_notification_timestamp';
  static const String mealCalorieTrackingEnabledKey = 'meal_calorie_tracking_enabled_key';
  // Breakfast reminders removed
  // static const String breakfastReminderEnabledKey = 'breakfast_reminder_enabled_key';
  static const String lunchReminderEnabledKey = 'lunch_reminder_enabled_key';
  static const String dinnerReminderEnabledKey = 'dinner_reminder_enabled_key';
  static const String breakfastReminderTimeKey = 'breakfast_reminder_time_key';
  static const String lunchReminderTimeKey = 'lunch_reminder_time_key';
  static const String dinnerReminderTimeKey = 'dinner_reminder_time_key';
  static const String motivationReminderTimeKey = 'motivation_reminder_time_key';
  static const String pledgeReminderTimeKey = 'pledge_reminder_time_key';
  static const String fastingEndReminderLeadMinutesKey = 'fasting_end_reminder_lead_minutes_key';
  
  // Global daily cap and spacing
  static const int maxNotificationsPerDay = 3;
  static const int minMinutesBetweenNotifications = 180; // 3 hours
  static const String _dailyScheduledDateKey = 'daily_scheduled_date_key';
  static const String _dailyScheduledCountKey = 'daily_scheduled_count_key';
  static const String _lastScheduledAtKey = 'last_scheduled_at_key_ms';
  
  // Notification IDs
  static const int checkupRemindersId = 10;
  static const int streakGoalsId = 20;
  static const int morningMotivationId = 30;
  static const int appUpdateId = 40;
  static const int chatNotificationsId = 50;
  static const int marketingOffersId = 60;
  static const int trialOfferId = 70;
  static const int timeSensitiveId = 80;
  static const int mealCalorieTrackingId = 90;
  // static const int breakfastReminderId = 100; // removed
  static const int lunchReminderId = 110;
  static const int dinnerReminderId = 120;
  static const int relapseChallengeDailyIdBase = 130; // offset by day
  static const int fastingEndReminderId = 260; // single-id for current fast end reminder
  static const int fasting4hReminderId = 270; // 4 hours before fast ends
  static const int fasting2hReminderId = 271; // 2 hours before fast ends
  static const int fastingCompleteId = 272; // when fast completes
  
  // Android notification channel IDs
  static const String defaultChannelId = 'default_channel';
  static const String checkupChannelId = 'checkup_reminders_channel';
  static const String streakGoalsChannelId = 'streak_goals_channel';
  static const String morningMotivationChannelId = 'morning_motivation_channel';
  static const String appUpdateChannelId = 'app_update_channel';
  static const String chatNotificationsChannelId = 'chat_notifications_channel';
  static const String marketingOffersChannelId = 'marketing_offers_channel';
  static const String trialOfferChannelId = 'trial_offer_channel';
  static const String timeSensitiveChannelId = 'time_sensitive_channel';
  static const String mealCalorieTrackingChannelId = 'meal_calorie_tracking_channel';
  // static const String breakfastReminderChannelId = 'breakfast_reminder_channel';
  static const String lunchReminderChannelId = 'lunch_reminder_channel';
  static const String dinnerReminderChannelId = 'dinner_reminder_channel';
  static const String relapseChallengeChannelId = 'relapse_challenge_channel';
  
  // FlutterLocalNotificationsPlugin instance
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  // Random number generator
  final Random _random = Random();
  
  // Cache for localized strings with language tracking
  Map<String, String>? _cachedLocalizedStrings;
  String? _cachedLanguageCode;
  
  // Session-level flag to track if permissions have been requested during onboarding
  static bool _onboardingPermissionsRequested = false;
  
  // Session-level flag to track if onboarding notifications have been initialized
  static bool _onboardingNotificationsInitialized = false;

  // One-shot retry flags for onboarding scheduling when RC becomes ready later
  static bool _onboardingSchedulingDeferred = false;
  static bool _onboardingRCOneShotTried = false;

  // RevenueCat readiness flag to avoid calling Purchases before configuration
  static bool _revenueCatReady = false;
  static void setRevenueCatReady(bool ready) {
    _revenueCatReady = ready;
    debugPrint('NotificationService: RevenueCat ready = $ready');
    if (ready) {
      // One-shot retry if we previously deferred onboarding scheduling due to RC not ready
      // Run asynchronously without capturing unnecessary state inline
      unawaited(_oneShotRetryAfterRevenueCatReady());
    }
  }

  static Future<void> _oneShotRetryAfterRevenueCatReady() async {
    try {
      if (_onboardingSchedulingDeferred && !_onboardingRCOneShotTried) {
        final service = NotificationService();
        await service.initialize();
        final bool granted = await service._isNotificationPermissionGranted();
        final bool enabled = await service.areNotificationsEnabled();
        if (granted && enabled) {
          await service._scheduleOnboardingNotifications();
          debugPrint('NotificationService: One-shot onboarding scheduling executed after RC became ready');
        } else {
          debugPrint('NotificationService: One-shot onboarding scheduling skipped (granted=$granted enabled=$enabled)');
        }
        _onboardingRCOneShotTried = true;
        _onboardingSchedulingDeferred = false;
        _onboardingNotificationsInitialized = true;
      }
    } catch (e) {
      debugPrint('NotificationService: One-shot onboarding scheduling error: $e');
    }
  }

  // Superwall readiness flag to avoid calling Superwall before configuration
  static bool _superwallReady = false;
  static void setSuperwallReady(bool ready) {
    _superwallReady = ready;
    debugPrint('NotificationService: Superwall ready = $ready');
  }

  // Public getter to check Superwall readiness safely
  static bool get isSuperwallReady => _superwallReady;

  // Wait for RevenueCat readiness with bounded timeout
  Future<bool> _waitForRevenueCatReady({Duration timeout = const Duration(seconds: 5)}) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      if (_revenueCatReady) return true;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return _revenueCatReady;
  }
  
  // Reset onboarding session flags (call this when starting a new onboarding session)
  static void resetOnboardingSession() {
    _onboardingPermissionsRequested = false;
    _onboardingNotificationsInitialized = false;
    _onboardingSchedulingDeferred = false;
    _onboardingRCOneShotTried = false;
    debugPrint('NotificationService: Onboarding session flags reset');
  }
  
  // Public method to invalidate localized strings cache (call when language changes)
  void invalidateLocalizationCache() {
    _clearLocalizedStringsCache();
    debugPrint('NotificationService: Localization cache invalidated');
  }
  
  // Centralized onboarding notification initialization to prevent duplicates
  Future<bool> initializeOnboardingNotifications({
    String context = 'onboarding',
    bool forceRequest = false,
  }) async {
    // If already initialized and not forcing, return previous result
    if (_onboardingNotificationsInitialized && !forceRequest) {
      debugPrint('NotificationService: Onboarding notifications already initialized, skipping');
      final isGranted = await _isNotificationPermissionGranted();
      return isGranted;
    }
    
    debugPrint('NotificationService: Starting onboarding notification initialization for context: $context');
    
    try {
      // Initialize notification service
      await initialize();
      debugPrint('NotificationService: Service initialized successfully');
      
      bool isGranted = false;
      
      // Check current permission status
      isGranted = await _isNotificationPermissionGranted();
      debugPrint('NotificationService: Current permission status: $isGranted');
      
      // Only request permissions if not already granted and not already requested in this session
      if (!isGranted && (!_onboardingPermissionsRequested || forceRequest)) {
        debugPrint('NotificationService: Requesting notification permissions for context: $context');
        
        // Mark that we've requested permissions in this session
        _onboardingPermissionsRequested = true;
        
        // Request permissions
        isGranted = await requestAllNotificationPermissions(context: context);
        debugPrint('NotificationService: Permission request result: $isGranted');
      } else if (_onboardingPermissionsRequested && !isGranted) {
        debugPrint('NotificationService: Permissions already requested in this session but denied');
      }
      
      // Schedule notifications if permission is granted
      if (isGranted) {
        // Persist the global toggle so settings UI reflects permission grant
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(notificationsEnabledKey, true);
        } catch (e) {
          debugPrint('NotificationService: Failed to save notificationsEnabledKey: $e');
        }
        // Gate onboarding scheduling behind RevenueCat readiness to avoid misclassifying trial users
        if (!_revenueCatReady) {
          final rcReady = await _waitForRevenueCatReady();
          if (!rcReady) {
            debugPrint('NotificationService: RC not ready after wait → skip onboarding scheduling this session');
            _onboardingSchedulingDeferred = true; // mark for one-shot retry when RC becomes ready
            _onboardingNotificationsInitialized = true;
            return isGranted;
          }
        }
        await _scheduleOnboardingNotifications();
        debugPrint('NotificationService: Onboarding notifications scheduled successfully');
      } else {
        debugPrint('NotificationService: Notifications not scheduled due to missing permissions');
      }
      
      // Mark initialization as complete
      _onboardingNotificationsInitialized = true;
      
      return isGranted;
    } catch (e) {
      debugPrint('NotificationService: Error during onboarding initialization: $e');
      return false;
    }
  }
  
  // Helper method to check notification permission status
  Future<bool> _isNotificationPermissionGranted() async {
    try {
      // Check system-level permissions first
      final systemEnabled = await areSystemNotificationsEnabled();
      if (!systemEnabled) {
        return false;
      }
      
      // If system reports enabled, treat as granted regardless of prior local flag.
      // This covers cases where the user enabled notifications directly in iOS Settings.
      return true;
    } catch (e) {
      debugPrint('NotificationService: Error checking permission status: $e');
      return false;
    }
  }
  
  // Helper method to schedule notifications during onboarding
  Future<void> _scheduleOnboardingNotifications() async {
    try {
      // Check if user is on trial - trial users get NO notifications at all
      final bool isOnTrial = await _isUserOnTrial();
      if (isOnTrial) {
        debugPrint('NotificationService (_scheduleOnboardingNotifications): User is on trial. Skipping ALL onboarding notifications.');
        return;
      }
      
      // Determine subscription status
      final isSubscribed = await isQualifiedSubscriber();
      final audienceType = isSubscribed 
          ? NotificationAudienceType.subscriber 
          : NotificationAudienceType.nonSubscriber;
      
      debugPrint('NotificationService: Scheduling notifications for audience type: $audienceType');
      
      // Schedule all notifications
      await updateAllNotifications(
        audienceType: audienceType,
        hour: 7, // Morning motivation (onboarding default)
        minute: 35,
      );
      
      // Save that user has granted notifications
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_granted_notifications', true);
      
    } catch (e) {
      debugPrint('NotificationService: Error scheduling onboarding notifications: $e');
    }
  }
  
  // Get day-based random index to ensure different messages each day
  int _getDayBasedRandomIndex(List<String> list) {
    if (list.isEmpty) {
      debugPrint('ERROR: Empty notification message list provided to _getDayBasedRandomIndex');
      throw ArgumentError('Notification message list cannot be empty');
    }
    
    final now = DateTime.now();
    // Use year + dayOfYear as seed to ensure different selection each day
    final dayBasedSeed = now.year * 1000 + now.difference(DateTime(now.year, 1, 1)).inDays;
    final dayRandom = Random(dayBasedSeed);
    return dayRandom.nextInt(list.length);
  }
  
  // Load localized strings with smart caching and language change detection
  Future<Map<String, String>> _loadLocalizedStrings() async {
    try {
      final currentLanguageCode = await _getAppLanguageCode();
      
      // Check if we can use cached data
      if (_cachedLocalizedStrings != null && 
          _cachedLanguageCode == currentLanguageCode) {
        debugPrint('NotificationService: Using cached localized strings for language: $currentLanguageCode');
        return _cachedLocalizedStrings!;
      }
      
      // Cache miss or language changed - reload strings
      debugPrint('NotificationService: Loading fresh localized strings for language: $currentLanguageCode');
      
      final String jsonString = await rootBundle.loadString('assets/l10n/$currentLanguageCode.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      
      final localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
      
      // Update cache
      _cachedLocalizedStrings = localizedStrings;
      _cachedLanguageCode = currentLanguageCode;
      
      debugPrint('NotificationService: Successfully loaded and cached ${localizedStrings.length} localized strings');
      return localizedStrings;
    } catch (e) {
      debugPrint('NotificationService: Error loading localized strings: $e');
      // Fallback to English if there's an error
      try {
        debugPrint('NotificationService: Falling back to English');
        final String jsonString = await rootBundle.loadString('assets/l10n/en.json');
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        final fallbackStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
        
        // Cache the fallback strings with 'en' as language code
        _cachedLocalizedStrings = fallbackStrings;
        _cachedLanguageCode = 'en';
        
        return fallbackStrings;
      } catch (fallbackError) {
        debugPrint('NotificationService: Error loading English fallback: $fallbackError');
        return {};
      }
    }
  }
  
  // Clear localized strings cache (useful for language changes or debugging)
  void _clearLocalizedStringsCache() {
    _cachedLocalizedStrings = null;
    _cachedLanguageCode = null;
    debugPrint('NotificationService: Cleared localized strings cache');
  }

  // ---------------- Personalization helpers ----------------
  Future<String?> _getUserFirstName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('user_first_name');
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Try Firestore profile first for explicit firstName field
        try {
          final repo = UserRepository();
          final data = await repo.getUserProfile(currentUser.uid);
          final fn = data?['firstName'];
          if (fn != null && fn.toString().trim().isNotEmpty) {
            return fn.toString().trim();
          }
        } catch (e) {
          debugPrint('NotificationService: error fetching firstName from Firestore: $e');
        }

        // Fallback to Auth displayName first token
        final display = currentUser.displayName;
        if (display != null && display.trim().isNotEmpty) {
          final parts = display.trim().split(' ');
          if (parts.isNotEmpty && parts.first.isNotEmpty) {
            return parts.first;
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationService: error resolving user first name: $e');
    }
    return null;
  }

  Future<String> _maybePrefixWithName(String text) async {
    try {
      final name = await _getUserFirstName();
      if (name == null || name.isEmpty) return text;
      final trimmed = text.trimLeft();
      if (trimmed.startsWith(name)) return text;
      // Try localized friendly greeting; fallback to 'Hey'
      String hey = await _getLocalizedString('notification_hey');
      if (hey == 'notification_hey' || hey.trim().isEmpty) {
        hey = 'Hey';
      }
      return '$hey $name, $text';
    } catch (_) {
      return text;
    }
  }

  // ---------------- Daily cap helpers ----------------
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  Future<DateTime?> _reserveNotificationSlot(DateTime desiredTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String desiredYmd = _ymd(desiredTime);

      final String? storedYmd = prefs.getString(_dailyScheduledDateKey);
      int count = prefs.getInt(_dailyScheduledCountKey) ?? 0;
      int lastMs = prefs.getInt(_lastScheduledAtKey) ?? 0;

      // Guard: reset if timezone offset changed mid-day (DST or manual change)
      try {
        const tzOffsetKey = '_last_tz_offset_minutes';
        final int currentOffset = DateTime.now().timeZoneOffset.inMinutes;
        final int prevOffset = prefs.getInt(tzOffsetKey) ?? currentOffset;
        if (prevOffset != currentOffset) {
          await prefs.setInt(tzOffsetKey, currentOffset);
          await prefs.setString(_dailyScheduledDateKey, desiredYmd);
          await prefs.setInt(_dailyScheduledCountKey, 0);
          await prefs.remove(_lastScheduledAtKey);
          count = 0;
          lastMs = 0;
          debugPrint('Cap: Timezone offset changed; daily counters reset');
        }
      } catch (_) {}

      // Reset counters when the target day changes
      if (storedYmd != desiredYmd) {
        await prefs.setString(_dailyScheduledDateKey, desiredYmd);
        count = 0;
        await prefs.setInt(_dailyScheduledCountKey, count);
        await prefs.remove(_lastScheduledAtKey);
        lastMs = 0;
      }

      if (count >= maxNotificationsPerDay) {
        debugPrint('Cap: Reached daily cap ($maxNotificationsPerDay) for $desiredYmd. Skip scheduling.');
        return null;
      }

      DateTime scheduledTime = desiredTime;
      if (lastMs > 0) {
        final DateTime last = DateTime.fromMillisecondsSinceEpoch(lastMs);
        final int diff = scheduledTime.difference(last).inMinutes;
        if (diff < minMinutesBetweenNotifications) {
          scheduledTime = last.add(const Duration(minutes: minMinutesBetweenNotifications));
        }
      }

      // Do not push into the next day; if spacing crosses midnight, skip
      if (_ymd(scheduledTime) != desiredYmd) {
        debugPrint('Cap: Adjusted time crosses to next day; skipping to respect daily cap for $desiredYmd.');
        return null;
      }

      // Persist reservation
      await prefs.setInt(_dailyScheduledCountKey, count + 1);
      await prefs.setInt(_lastScheduledAtKey, scheduledTime.millisecondsSinceEpoch);

      return scheduledTime;
    } catch (e) {
      debugPrint('Cap: Error reserving slot: $e');
      return desiredTime; // Fail-open to avoid crashes
    }
  }

  Future<void> _scheduleCapped({
    required int id,
    required String? title,
    required String? body,
    required DateTime desiredTime,
    required NotificationDetails details,
    DateTimeComponents? matchDateTimeComponents,
    AndroidScheduleMode androidScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle,
    String? payload,
  }) async {
    final DateTime? reserved = await _reserveNotificationSlot(desiredTime);
    if (reserved == null) {
      debugPrint('Cap: Slot not reserved for id=$id, payload=$payload. Skipping scheduling.');
      return;
    }
    final tz.TZDateTime tzTime = tz.TZDateTime.from(reserved, tz.local);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: androidScheduleMode,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
    );
  }

  // Read today's scheduled count without modifying state
  Future<int> _getTodayScheduledCount() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = _ymd(DateTime.now());
    final String? storedYmd = prefs.getString(_dailyScheduledDateKey);
    if (storedYmd != today) return 0;
    return prefs.getInt(_dailyScheduledCountKey) ?? 0;
  }

  // Reset daily cap counters for today (used when we cancel and rebuild plan)
  Future<void> _resetTodayCapCounters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyScheduledDateKey, _ymd(DateTime.now()));
    await prefs.setInt(_dailyScheduledCountKey, 0);
    await prefs.remove(_lastScheduledAtKey);
  }
  
  // Get localized string
  Future<String> _getLocalizedString(String key) async {
    final localizedStrings = await _loadLocalizedStrings();
    final result = localizedStrings[key] ?? key;
    debugPrint('NotificationService: Translated "$key" to "$result"');
    return result;
  }
  
  // Collection of morning motivation title keys for subscribers
  final List<String> _morningMotivationTitleKeys = [
    'notification_morningMotivation_title_1',
    'notification_morningMotivation_title_2',
    'notification_morningMotivation_title_3',
    'notification_morningMotivation_title_4',
    'notification_morningMotivation_title_5',
    'notification_morningMotivation_title_6',
    'notification_morningMotivation_title_7',
    'notification_morningMotivation_title_8',
    'notification_morningMotivation_title_9',
    'notification_morningMotivation_title_10',
    'notification_morningMotivation_title_11',
    'notification_morningMotivation_title_12',
    'notification_morningMotivation_title_13',
    'notification_morningMotivation_title_14',
    'notification_morningMotivation_title_15',
    'notification_morningMotivation_title_16',
    'notification_morningMotivation_title_17',
    'notification_morningMotivation_title_18',
    'notification_morningMotivation_title_19',
    'notification_morningMotivation_title_20',
  ];
  
  // Collection of morning motivation message keys for subscribers
  final List<String> _morningMotivationMessageKeys = [
    'notification_morningMotivation_message_1',
    'notification_morningMotivation_message_2',
    'notification_morningMotivation_message_3',
    'notification_morningMotivation_message_4',
    'notification_morningMotivation_message_5',
    'notification_morningMotivation_message_6',
    'notification_morningMotivation_message_7',
    'notification_morningMotivation_message_8',
    'notification_morningMotivation_message_9',
    'notification_morningMotivation_message_10',
    'notification_morningMotivation_message_11',
    'notification_morningMotivation_message_12',
    'notification_morningMotivation_message_13',
    'notification_morningMotivation_message_14',
    'notification_morningMotivation_message_15',
    'notification_morningMotivation_message_16',
    'notification_morningMotivation_message_17',
    'notification_morningMotivation_message_18',
    'notification_morningMotivation_message_19',
    'notification_morningMotivation_message_20',
  ];
  
  // Collection of checkup reminder title keys for subscribers
  final List<String> _checkupReminderTitleKeys = [
    'notification_checkupReminder_title_1',
    'notification_checkupReminder_title_2',
    'notification_checkupReminder_title_3',
    'notification_checkupReminder_title_4',
    'notification_checkupReminder_title_5',
    'notification_checkupReminder_title_6',
    'notification_checkupReminder_title_7',
    'notification_checkupReminder_title_8',
    'notification_checkupReminder_title_9',
    'notification_checkupReminder_title_10',
    'notification_checkupReminder_title_11',
    'notification_checkupReminder_title_12',
    'notification_checkupReminder_title_13',
    'notification_checkupReminder_title_14',
    'notification_checkupReminder_title_15',
    'notification_checkupReminder_title_16',
    'notification_checkupReminder_title_17',
    'notification_checkupReminder_title_18',
    'notification_checkupReminder_title_19',
    'notification_checkupReminder_title_20',
  ];
  
  // Collection of checkup reminder message keys for subscribers
  final List<String> _checkupReminderMessageKeys = [
    'notification_checkupReminder_message_1',
    'notification_checkupReminder_message_2',
    'notification_checkupReminder_message_3',
    'notification_checkupReminder_message_4',
    'notification_checkupReminder_message_5',
    'notification_checkupReminder_message_6',
    'notification_checkupReminder_message_7',
    'notification_checkupReminder_message_8',
    'notification_checkupReminder_message_9',
    'notification_checkupReminder_message_10',
    'notification_checkupReminder_message_11',
    'notification_checkupReminder_message_12',
    'notification_checkupReminder_message_13',
    'notification_checkupReminder_message_14',
    'notification_checkupReminder_message_15',
    'notification_checkupReminder_message_16',
    'notification_checkupReminder_message_17',
    'notification_checkupReminder_message_18',
    'notification_checkupReminder_message_19',
    'notification_checkupReminder_message_20',
  ];
  
  // Collection of motivational title keys for non-subscribers
  final List<String> _nonSubscriberTitleKeys = [
    'notification_nonSubscriber_title_1',
    'notification_nonSubscriber_title_2',
    'notification_nonSubscriber_title_3',
    'notification_nonSubscriber_title_4',
    'notification_nonSubscriber_title_5',
    'notification_nonSubscriber_title_6',
    'notification_nonSubscriber_title_7',
    'notification_nonSubscriber_title_8',
    'notification_nonSubscriber_title_9',
    'notification_nonSubscriber_title_10',
    'notification_nonSubscriber_title_11',
    'notification_nonSubscriber_title_12',
    'notification_nonSubscriber_title_13',
    'notification_nonSubscriber_title_14',
    'notification_nonSubscriber_title_15',
  ];
  
  // Collection of motivational message keys for non-subscribers
  final List<String> _nonSubscriberMessageKeys = [
    'notification_nonSubscriber_message_1',
    'notification_nonSubscriber_message_2',
    'notification_nonSubscriber_message_3',
    'notification_nonSubscriber_message_4',
    'notification_nonSubscriber_message_5',
    'notification_nonSubscriber_message_6',
    'notification_nonSubscriber_message_7',
    'notification_nonSubscriber_message_8',
    'notification_nonSubscriber_message_9',
    'notification_nonSubscriber_message_10',
    'notification_nonSubscriber_message_11',
    'notification_nonSubscriber_message_12',
    'notification_nonSubscriber_message_13',
    'notification_nonSubscriber_message_14',
    'notification_nonSubscriber_message_15',
    'notification_nonSubscriber_message_16',
    'notification_nonSubscriber_message_17',
    'notification_nonSubscriber_message_18',
    'notification_nonSubscriber_message_19',
    'notification_nonSubscriber_message_20',
  ];
  
  // Collection of streak goal title keys for subscribers
  final List<String> _streakGoalTitleKeys = [
    'notification_streakGoals_title_1',
    'notification_streakGoals_title_2',
    'notification_streakGoals_title_3',
    'notification_streakGoals_title_4',
    'notification_streakGoals_title_5',
    'notification_streakGoals_title_6',
    'notification_streakGoals_title_7',
    'notification_streakGoals_title_8',
    'notification_streakGoals_title_9',
    'notification_streakGoals_title_10',
  ];
  
  // Collection of streak goal message keys for subscribers
  final List<String> _streakGoalMessageKeys = [
    'notification_streakGoals_message_1',
    'notification_streakGoals_message_2',
    'notification_streakGoals_message_3',
    'notification_streakGoals_message_4',
    'notification_streakGoals_message_5',
    'notification_streakGoals_message_6',
    'notification_streakGoals_message_7',
    'notification_streakGoals_message_8',
    'notification_streakGoals_message_9',
    'notification_streakGoals_message_10',
  ];
  
  // Collection of app update notification title keys
  final List<String> _appUpdateTitleKeys = [
    'notification_appUpdate_title',
  ];
  
  // Collection of app update notification message keys
  final List<String> _appUpdateMessageKeys = [
    'notification_appUpdate_message',
  ];
  
  // Collection of marketing offer title keys
  final List<String> _marketingOfferTitleKeys = [
    'notification_marketingOffer_title',
  ];
  
  // Collection of marketing offer message keys
  final List<String> _marketingOfferMessageKeys = [
    'notification_marketingOffer_message',
  ];
  
  // Collection of trial offer title keys
  final List<String> _trialOfferTitleKeys = [
    'notification_trialOffer_title',
  ];
  
  // Collection of trial offer message keys
  final List<String> _trialOfferMessageKeys = [
    'notification_trialOffer_message',
  ];
  
  // Collection of time-sensitive notification title keys
  final List<String> _timeSensitiveTitleKeys = [
    'notification_timeSensitive_title_1',
    'notification_timeSensitive_title_2',
    'notification_timeSensitive_title_3',
  ];
  
  // Collection of time-sensitive notification message keys
  final List<String> _timeSensitiveMessageKeys = [
    'notification_timeSensitive_message_1',
    'notification_timeSensitive_message_2',
    'notification_timeSensitive_message_3',
  ];
  
  // Initialize notification settings
  Future<void> initialize() async {
    // Initialize timezone data
    tz.initializeTimeZones();
    try {
      final String localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
      debugPrint('NotificationService: Set local timezone to $localTz');
    } catch (e) {
      debugPrint('NotificationService: Failed to determine local timezone, using tz.local. Error: $e');
      // Consider using UTC or a default timezone as fallback
      tz.setLocalLocation(tz.UTC);
      debugPrint('NotificationService: Using UTC as fallback timezone');
    }
    
    // Define iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS = 
        DarwinInitializationSettings(
      requestAlertPermission: false, // We'll request permissions separately
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // Define Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Define initialization settings for the plugin
    const InitializationSettings initializationSettings = InitializationSettings(
      iOS: initializationSettingsIOS,
      android: initializationSettingsAndroid,
    );
    
    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // Create Android notification channels
    await _initializeAndroidNotificationChannels();
  }
  
  // Initialize Android notification channels
  Future<void> _initializeAndroidNotificationChannels() async {
    if (Platform.isAndroid) {
      // Default channel
      const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
        defaultChannelId,
        'Default Notifications',
        description: 'Default notification channel for general notifications',
        importance: Importance.high,
      );

      // Checkup reminders channel
      const AndroidNotificationChannel checkupChannel = AndroidNotificationChannel(
        checkupChannelId,
        'Checkup Reminders',
        description: 'Reminders to check in on your progress daily',
        importance: Importance.high,
      );

      // Streak goals channel
      const AndroidNotificationChannel streakChannel = AndroidNotificationChannel(
        streakGoalsChannelId,
        'Streak Updates',
        description: 'Updates about your streak progress and achievements',
        importance: Importance.high,
      );

      // Morning motivation channel
      const AndroidNotificationChannel motivationChannel = AndroidNotificationChannel(
        morningMotivationChannelId,
        'Morning Motivations',
        description: 'Daily morning motivation to keep you inspired',
        importance: Importance.high,
      );

      // App update channel
      const AndroidNotificationChannel appUpdateChannel = AndroidNotificationChannel(
        appUpdateChannelId,
        'App Updates',
        description: 'Notifications about app updates and new features',
        importance: Importance.high,
      );

      // Chat notifications channel
      const AndroidNotificationChannel chatNotificationsChannel = AndroidNotificationChannel(
        chatNotificationsChannelId,
        'Chat Notifications',
        description: 'Notifications about new chat messages',
        importance: Importance.high,
      );

      // Marketing offers channel
      const AndroidNotificationChannel marketingOffersChannel = AndroidNotificationChannel(
        marketingOffersChannelId,
        'Special Offers',
        description: 'Limited time offers and exclusive deals',
        importance: Importance.high,
      );

      // Trial offer channel
      const AndroidNotificationChannel trialOfferChannel = AndroidNotificationChannel(
        trialOfferChannelId,
        'Trial Offers',
        description: 'Limited time trial offers for new users',
        importance: Importance.high,
      );

      // Time-sensitive channel
      const AndroidNotificationChannel timeSensitiveChannel = AndroidNotificationChannel(
        timeSensitiveChannelId,
        'Time-Sensitive Reminders',
        description: 'Important reminders for inactive users',
        importance: Importance.max,
      );

      // Meal calorie tracking channel
      const AndroidNotificationChannel mealCalorieTrackingChannel = AndroidNotificationChannel(
        mealCalorieTrackingChannelId,
        'Meal Calorie Tracking',
        description: 'Notifications when food scan analysis is complete',
        importance: Importance.high,
      );


      // Lunch reminder channel
      const AndroidNotificationChannel lunchReminderChannel = AndroidNotificationChannel(
        lunchReminderChannelId,
        'Lunch Reminders',
        description: 'Reminders to track your lunch',
        importance: Importance.high,
      );

      // Dinner reminder channel
      const AndroidNotificationChannel dinnerReminderChannel = AndroidNotificationChannel(
        dinnerReminderChannelId,
        'Dinner Reminders',
        description: 'Reminders to track your dinner',
        importance: Importance.high,
      );

      // Create the channels one by one since createNotificationChannels is no longer available
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
              
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(defaultChannel);
        await androidPlugin.createNotificationChannel(checkupChannel);
        await androidPlugin.createNotificationChannel(streakChannel);
        await androidPlugin.createNotificationChannel(motivationChannel);
        await androidPlugin.createNotificationChannel(appUpdateChannel);
        await androidPlugin.createNotificationChannel(chatNotificationsChannel);
        await androidPlugin.createNotificationChannel(marketingOffersChannel);
        await androidPlugin.createNotificationChannel(trialOfferChannel);
        await androidPlugin.createNotificationChannel(timeSensitiveChannel);
        await androidPlugin.createNotificationChannel(mealCalorieTrackingChannel);
        // Breakfast channel removed
        await androidPlugin.createNotificationChannel(lunchReminderChannel);
        await androidPlugin.createNotificationChannel(dinnerReminderChannel);
        // Relapse challenge channel
        const AndroidNotificationChannel relapseChallengeChannel = AndroidNotificationChannel(
          relapseChallengeChannelId,
          'Relapse Challenge',
          description: 'Daily congrats and days-left during your challenge',
          importance: Importance.high,
        );
        await androidPlugin.createNotificationChannel(relapseChallengeChannel);
      }
    }
  }
  
  // Handle notification response
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    // Track notification tap in Mixpanel
    final String? payload = response.payload;
    final String notificationType = payload ?? 'unknown';
    
    // Track the notification tap event
    MixpanelService.trackNotificationTapped(notificationType, 
      notificationId: response.id.toString(),
      actionId: response.actionId,
    );
    
    // Handle notification tap/action based on payload
    debugPrint('Notification tapped with payload: $payload');
    
    // Safely handle navigation using a microtask to ensure we don't interfere with current UI operations
    if (payload != null) {
      // Use a delayed execution to ensure initialization is complete
      Future.microtask(() {
        _handleNotificationNavigation(payload);
      });
    }
  }
  
  // Handle notification navigation safely
  void _handleNotificationNavigation(String payload) {
    try {
      debugPrint('Handling notification navigation for payload: $payload');
      
      // Use async method to handle the payload processing
      _processNotificationPayload(payload);
    } catch (e) {
      debugPrint('Error handling notification navigation: $e');
    }
  }
  
  // Process notification payload asynchronously
  Future<void> _processNotificationPayload(String payload) async {
    try {
      // For non-paying users who have seen pre-paywall, modify payload to redirect to pre-paywall
      String finalPayload = payload;
      
      try {
        // Check if user is a qualified subscriber (paying)
        final isQualifiedSub = await isQualifiedSubscriber();
        debugPrint('NotificationService: User is qualified subscriber: $isQualifiedSub');
        
        // Only modify behavior for non-paying users
        if (!isQualifiedSub) {
          debugPrint('NotificationService: Non-paying user detected, checking last saved screen');
          
          // Check last saved screen from onboarding progress
          final OnboardingProgressService onboardingService = OnboardingProgressService();
          final OnboardingScreen? lastScreen = await onboardingService.getCurrentScreen();
          
          debugPrint('NotificationService: Last saved screen: $lastScreen');
          
          // Guard: preserve explicit Superwall placement for trial
          if (payload == 'notification_push_trial') {
            finalPayload = payload;
            debugPrint('NotificationService: Preserving trial notification placement payload');
          } else {
            // If last screen was pre-paywall, trigger standard paywall
            if (lastScreen == OnboardingScreen.prePaywallScreen) {
              finalPayload = 'trigger_standard_paywall_$payload';
              debugPrint('NotificationService: Modified payload to trigger standard paywall: $finalPayload');
            } else {
              debugPrint('NotificationService: Last screen was not pre-paywall, keeping current behavior');
            }
          }
        } else {
          debugPrint('NotificationService: Qualified subscriber, keeping current behavior');
        }
      } catch (e) {
        debugPrint('NotificationService: Error checking subscription/onboarding status: $e');
        // Keep original payload on error
      }
      
      // Store the final payload in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_notification_payload', finalPayload);
      await prefs.setBool('notification_pending_processing', true);
      await prefs.setInt('notification_tap_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('Saved notification payload for later processing: $finalPayload');
    } catch (e) {
      debugPrint('Error processing notification payload: $e');
    }
  }
  
  // Request permissions for iOS
  Future<bool> requestIOSPermissions() async {
    if (!Platform.isIOS) {
      return false;
    }
    
    // Request permissions through the plugin
    final bool? result = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        
    final bool granted = result ?? false;
    return granted;
  }
  
  // Request permissions for Android (API 33+/Android 13+)
  Future<bool> requestAndroidPermissions() async {
    if (!Platform.isAndroid) {
      return false;
    }
    
    // Request notification permissions for Android 13+ (API 33+)
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      // requestPermission() is no longer available, use requestNotificationsPermission instead
      final bool? granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    
    return false;
  }
  
  // Request permissions based on platform
  Future<bool> requestNotificationPermissions() async {
    if (Platform.isIOS) {
      return await requestIOSPermissions();
    } else if (Platform.isAndroid) {
      return await requestAndroidPermissions();
    }
    return false;
  }
  
  // Request all notification permissions including Firebase Messaging
  Future<bool> requestAllNotificationPermissions({String context = 'unknown'}) async {
    bool granted = false;
    
    try {
      debugPrint('📱 Starting coordinated notification permission requests for platform: ${Platform.operatingSystem}');
      // First, request local notification permissions
      granted = await requestNotificationPermissions();
      debugPrint('📱 Local notification permissions result: $granted');
      
      // Then, request Firebase Messaging permissions
      // For iOS, we use the Firebase Messaging specific request
      if (Platform.isIOS) {
        debugPrint('📱 iOS: Requesting Firebase Messaging permissions');
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        
        // Update granted status based on Firebase Messaging permission result
        granted = settings.authorizationStatus == AuthorizationStatus.authorized || 
                  settings.authorizationStatus == AuthorizationStatus.provisional;
                  
        debugPrint('📱 iOS: Firebase Messaging permissions granted: $granted');
      } 
      // For Android, we also need to call Firebase Messaging permission request
      else if (Platform.isAndroid) {
        // Explicitly request Android permissions again to ensure we get the dialog
        final localPermission = await requestAndroidPermissions();
        debugPrint('📱 Android: Explicit Android permission request result: $localPermission');
        
        // Then, also request Firebase Messaging permission on Android
        debugPrint('📱 Android: Requesting Firebase Messaging permissions');
        final settings = await FirebaseMessaging.instance.requestPermission();
        
        // For Android, we consider permission granted if either method returns true
        final firebasePermission = settings.authorizationStatus == AuthorizationStatus.authorized;
        granted = granted || localPermission || firebasePermission;
        
        debugPrint('📱 Android notification permissions: local=$localPermission, firebase=$firebasePermission, final=$granted');
      }
      
      // Track permission request in analytics with context
      final eventName = context == 'onboarding' 
          ? 'Onboarding Notification Permissions Requested'
          : context == 'onboarding_permission_screen'
              ? 'Onboarding Notification Permissions Requested'
          : context == 'onboarding_screen2'
              ? 'Onboarding Screen 2 Notification Permissions Requested'
          : context == 'pre_paywall'
              ? 'Pre Paywall Notification Permissions Requested'
          : context == 'settings'
              ? 'User Settings Notification Permissions Requested' 
              : 'Notification Permissions Requested';
      
      MixpanelService.trackEvent(eventName, properties: {
        'platform': Platform.operatingSystem,
        'granted': granted,
        'context': context,
        'is_retry': context == 'pre_paywall', // Track if this is a retry after initial denial
      });
    } catch (e) {
      debugPrint('❌ Error requesting notification permissions: $e');
      // Default to false if there's an error
      granted = false;
    }
    
    return granted;
  }
  
  // Check if system notifications are enabled for the app
  Future<bool> areSystemNotificationsEnabled() async {
    try {
      if (Platform.isIOS) {
        // Primary: permission_handler check
        final status = await Permission.notification.status;
        final bool phGranted =
            status.isGranted || status.isLimited || status.isProvisional;
        if (phGranted) return true;
        // Fallback: Firebase Messaging settings can reflect runtime changes
        try {
          final settings = await FirebaseMessaging.instance.getNotificationSettings();
          final bool fmGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
          if (fmGranted) return true;
        } catch (e) {
          debugPrint('areSystemNotificationsEnabled: FM fallback error: $e');
        }
        return false;
      } else if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidPlugin != null) {
          final granted = await androidPlugin.areNotificationsEnabled() ?? false;
          return granted;
        }
      }
      
      return true; // Default if we can't determine
    } catch (e) {
      debugPrint('Error checking system notification permissions: $e');
      return true; // Default to true if there's an error to avoid showing false warnings
    }
  }
  
  // Check if notifications are enabled in user preferences
  Future<bool> areNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(notificationsEnabledKey) ?? true; // Default to true if not set
    } catch (e) {
      debugPrint('Error checking notification settings: $e');
      return true; // Default to enabled if there's an error
    }
  }
  
  // Check if a specific notification type is enabled
  Future<bool> isNotificationTypeEnabled(NotificationType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // First check if all notifications are disabled
      final allEnabled = prefs.getBool(notificationsEnabledKey) ?? true;
      if (!allEnabled) return false;
      
      // Then check the specific type
      switch (type) {
        case NotificationType.checkupReminders:
          return prefs.getBool(checkupRemindersEnabledKey) ?? true;
        case NotificationType.streakGoals:
          return prefs.getBool(streakGoalsEnabledKey) ?? true;
        case NotificationType.morningMotivation:
          return prefs.getBool(morningMotivationEnabledKey) ?? true;
        case NotificationType.appUpdate:
          return prefs.getBool(appUpdateEnabledKey) ?? true;
        case NotificationType.chatNotifications:
          return prefs.getBool(chatNotificationsEnabledKey) ?? false;
        case NotificationType.marketingOffers:
          return prefs.getBool(marketingOffersEnabledKey) ?? true;
        case NotificationType.trialOffer:
          return prefs.getBool(trialOfferEnabledKey) ?? false;
        case NotificationType.timeSensitive:
          return prefs.getBool(timeSensitiveEnabledKey) ?? true;
        case NotificationType.mealCalorieTracking:
          return prefs.getBool(mealCalorieTrackingEnabledKey) ?? true;
        case NotificationType.breakfastReminder:
          return false; // breakfast removed
        case NotificationType.lunchReminder:
          return prefs.getBool(lunchReminderEnabledKey) ?? true;
        case NotificationType.dinnerReminder:
          return prefs.getBool(dinnerReminderEnabledKey) ?? true;
        case NotificationType.relapseChallengeDaily:
          // Follows global notifications toggle; no separate toggle in settings yet
          return true;
      }
    } catch (e) {
      debugPrint('Error checking notification type settings: $e');
      return true; // Default to enabled if there's an error
    }
  }
  
  // Set a specific notification type enabled/disabled
  Future<void> setNotificationTypeEnabled(NotificationType type, bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      switch (type) {
        case NotificationType.checkupReminders:
          await prefs.setBool(checkupRemindersEnabledKey, enabled);
          break;
        case NotificationType.streakGoals:
          await prefs.setBool(streakGoalsEnabledKey, enabled);
          break;
        case NotificationType.morningMotivation:
          await prefs.setBool(morningMotivationEnabledKey, enabled);
          break;
        case NotificationType.appUpdate:
          await prefs.setBool(appUpdateEnabledKey, enabled);
          break;
        case NotificationType.chatNotifications:
          await prefs.setBool(chatNotificationsEnabledKey, enabled);
          break;
        case NotificationType.marketingOffers:
          await prefs.setBool(marketingOffersEnabledKey, enabled);
          break;
        case NotificationType.trialOffer:
          await prefs.setBool(trialOfferEnabledKey, enabled);
          break;
        case NotificationType.timeSensitive:
          await prefs.setBool(timeSensitiveEnabledKey, enabled);
          break;
        case NotificationType.mealCalorieTracking:
          await prefs.setBool(mealCalorieTrackingEnabledKey, enabled);
          break;
        case NotificationType.breakfastReminder:
          break; // breakfast removed
        case NotificationType.lunchReminder:
          await prefs.setBool(lunchReminderEnabledKey, enabled);
          break;
        case NotificationType.dinnerReminder:
          await prefs.setBool(dinnerReminderEnabledKey, enabled);
          break;
        case NotificationType.relapseChallengeDaily:
          // No persisted toggle yet; scheduling is controlled by flow
          break;
      }
      
      // Apply changes immediately
      await updateAllNotifications();
      
    } catch (e) {
      debugPrint('Error setting notification type: $e');
    }
  }
  
  // Schedule daily meditation reminder based on subscription status
  Future<void> scheduleDailyMeditationReminder({
    required int hour,
    required int minute,
    required NotificationAudienceType audienceType,
  }) async {
    // Check if user is on trial - trial users get NO notifications at all
    final bool isOnTrial = await _isUserOnTrial();
    if (isOnTrial) {
      debugPrint('NotificationService (scheduleDailyMeditationReminder): User is on trial. Skipping notification.');
      return;
    }
    
    // Check if notifications and morning motivation are enabled
    final prefs = await SharedPreferences.getInstance();
    final bool notificationsEnabled = prefs.getBool(notificationsEnabledKey) ?? true; // Default to true
    final bool morningMotivationEnabled = prefs.getBool(morningMotivationEnabledKey) ?? true; // Default to true
    debugPrint('NotificationService (scheduleDailyMeditationReminder): Checking preferences - Global Enabled: $notificationsEnabled, Morning Motivation Enabled: $morningMotivationEnabled');
    
    if (!notificationsEnabled || !morningMotivationEnabled) {
      debugPrint('NotificationService (scheduleDailyMeditationReminder): Scheduling skipped due to preferences.'); // Updated log
      return;
    }
    
    String title;
    String body;
    
    // Get notification content based on subscription status
    if (audienceType == NotificationAudienceType.subscriber) {
      // Select a day-based random title and message from morning motivation collections for subscribers
      title = await _getLocalizedString(_morningMotivationTitleKeys[_getDayBasedRandomIndex(_morningMotivationTitleKeys)]);
      body = await _getLocalizedString(_morningMotivationMessageKeys[_getDayBasedRandomIndex(_morningMotivationMessageKeys)]);
    } else {
      // Select a day-based random title and message for non-subscribers to ensure different content each day
      title = await _getLocalizedString(_nonSubscriberTitleKeys[_getDayBasedRandomIndex(_nonSubscriberTitleKeys)]);
      body = await _getLocalizedString(_nonSubscriberMessageKeys[_getDayBasedRandomIndex(_nonSubscriberMessageKeys)]);
    }
    // Friendly prefix for non-subscribers
    if (audienceType == NotificationAudienceType.nonSubscriber) {
      body = await _maybePrefixWithName(body);
    }
    
    // Create notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
      android: AndroidNotificationDetails(
        morningMotivationChannelId,
        'Morning Motivations',
        channelDescription: 'Daily morning motivation to keep you inspired',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Morning Motivation',
      ),
    );
    
    // Calculate next notification time
    final now = DateTime.now();
    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    // Convert to TZ format
    final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    
    // Schedule the notification (capped)
    await _scheduleCapped(
      id: morningMotivationId,
      title: title,
      body: body,
      desiredTime: scheduledDate,
      details: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'morning_motivation',
    );
    
    // Track notification scheduling in Mixpanel
    MixpanelService.trackNotificationScheduled(
      'morning_motivation',
      scheduledTime: scheduledDate,
      title: title,
      audienceType: audienceType.toString(),
    );
    
    debugPrint('NotificationService: Scheduled morning motivation notification for ${scheduledDate.toString()}');
  }

  // ---------------- Fasting end reminder (custom lead time) ----------------
  Future<int> getFastingEndReminderLeadMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt(fastingEndReminderLeadMinutesKey);
      return (v == null || v <= 0) ? 30 : v;
    } catch (_) {
      return 30;
    }
  }

  Future<void> setFastingEndReminderLeadMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(fastingEndReminderLeadMinutesKey, minutes);
    debugPrint('NotificationService: Set fasting end reminder lead minutes=$minutes');
  }

  Future<void> cancelFastingEndReminder() async {
    await flutterLocalNotificationsPlugin.cancel(fastingEndReminderId);
    debugPrint('NotificationService: Cancelled fasting end reminder (id=$fastingEndReminderId)');
  }

  Future<void> scheduleFastingEndReminder({
    required DateTime endAt,
    int? leadMinutes,
  }) async {
    // Guard: notifications enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) {
      debugPrint('NotificationService: Global notifications disabled, skip fasting end reminder');
      return;
    }

    // Respect checkup reminders toggle (reuse this category)
    final bool checkupEnabled = await isNotificationTypeEnabled(NotificationType.checkupReminders);
    if (!checkupEnabled) {
      debugPrint('NotificationService: Checkup reminders disabled, skip fasting end reminder');
      return;
    }

    final int lead = leadMinutes ?? await getFastingEndReminderLeadMinutes();
    final DateTime fireTime = endAt.subtract(Duration(minutes: lead));
    final DateTime now = DateTime.now();
    if (!fireTime.isAfter(now)) {
      debugPrint('NotificationService: Computed reminder time is in the past, skip (endAt=$endAt lead=$lead)');
      return;
    }

    // Localized strings
    final String title = await _getLocalizedString('fasting_end_reminder_title');
    final String bodyTemplate = await _getLocalizedString('fasting_end_reminder_body_template');
    final String body = bodyTemplate.replaceAll('{minutes}', lead.toString());

    const NotificationDetails details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
      android: AndroidNotificationDetails(
        checkupChannelId,
        'Checkup Reminders',
        channelDescription: 'Reminders to check in on your progress daily',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Fasting End Reminder',
      ),
    );

    // Convert to TZ
    final tz.TZDateTime tzTime = tz.TZDateTime.from(fireTime, tz.local);

    // Ensure a single scheduled reminder for current fast
    await flutterLocalNotificationsPlugin.cancel(fastingEndReminderId);
    await _scheduleCapped(
      id: fastingEndReminderId,
      title: title,
      body: body,
      desiredTime: fireTime,
      details: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'fasting_end_reminder',
    );

    MixpanelService.trackNotificationScheduled(
      'fasting_end_reminder',
      scheduledTime: fireTime,
      title: title,
      additionalProps: {
        'lead_minutes': lead,
      },
    );

    debugPrint('NotificationService: Scheduled fasting end reminder at ${fireTime.toIso8601String()} (lead=$lead)');
  }

  // Schedule motivational fasting notifications (4h, 2h, complete) - BYPASSES daily cap
  Future<void> scheduleFastingMotivationalNotifications({
    required DateTime endAt,
  }) async {
    // Cancel any existing fasting motivational notifications
    await cancelFastingMotivationalNotifications();

    // Guard: notifications enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) {
      debugPrint('NotificationService: Global notifications disabled, skip fasting motivational notifications');
      return;
    }

    // Respect checkup reminders toggle (reuse this category for fasting notifications)
    final bool checkupEnabled = await isNotificationTypeEnabled(NotificationType.checkupReminders);
    if (!checkupEnabled) {
      debugPrint('NotificationService: Checkup reminders disabled, skip fasting motivational notifications');
      return;
    }

    final DateTime now = DateTime.now();

    // 1. Schedule 4-hour reminder
    final DateTime fourHourTime = endAt.subtract(const Duration(hours: 4));
    if (fourHourTime.isAfter(now)) {
      final String title4h = await _getLocalizedString('fasting_4h_reminder_title');
      String body4h = await _getLocalizedString('fasting_4h_reminder_body');
      body4h = await _maybePrefixWithName(body4h);

      const NotificationDetails details4h = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
        android: AndroidNotificationDetails(
          checkupChannelId,
          'Checkup Reminders',
          channelDescription: 'Reminders to check in on your progress daily',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Fasting Motivation',
        ),
      );

      final tz.TZDateTime tzTime4h = tz.TZDateTime.from(fourHourTime, tz.local);
      await flutterLocalNotificationsPlugin.zonedSchedule(
        fasting4hReminderId,
        title4h,
        body4h,
        tzTime4h,
        details4h,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'fasting_4h_motivation',
      );

      // Mark date as high-priority to prevent other notifications from overlapping
      await _markHighPriorityOnDate(fourHourTime);

      MixpanelService.trackNotificationScheduled(
        'fasting_4h_motivation',
        scheduledTime: fourHourTime,
        title: title4h,
      );

      debugPrint('NotificationService: Scheduled 4h fasting motivation at ${fourHourTime.toIso8601String()}');
    }

    // 2. Schedule 2-hour reminder
    final DateTime twoHourTime = endAt.subtract(const Duration(hours: 2));
    if (twoHourTime.isAfter(now)) {
      final String title2h = await _getLocalizedString('fasting_2h_reminder_title');
      String body2h = await _getLocalizedString('fasting_2h_reminder_body');
      body2h = await _maybePrefixWithName(body2h);

      const NotificationDetails details2h = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
        android: AndroidNotificationDetails(
          checkupChannelId,
          'Checkup Reminders',
          channelDescription: 'Reminders to check in on your progress daily',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Fasting Motivation',
        ),
      );

      final tz.TZDateTime tzTime2h = tz.TZDateTime.from(twoHourTime, tz.local);
      await flutterLocalNotificationsPlugin.zonedSchedule(
        fasting2hReminderId,
        title2h,
        body2h,
        tzTime2h,
        details2h,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'fasting_2h_motivation',
      );

      // Mark date as high-priority
      await _markHighPriorityOnDate(twoHourTime);

      MixpanelService.trackNotificationScheduled(
        'fasting_2h_motivation',
        scheduledTime: twoHourTime,
        title: title2h,
      );

      debugPrint('NotificationService: Scheduled 2h fasting motivation at ${twoHourTime.toIso8601String()}');
    }

    // 3. Schedule completion notification
    if (endAt.isAfter(now)) {
      final String titleComplete = await _getLocalizedString('fasting_complete_title');
      String bodyComplete = await _getLocalizedString('fasting_complete_body');
      bodyComplete = await _maybePrefixWithName(bodyComplete);

      const NotificationDetails detailsComplete = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
        android: AndroidNotificationDetails(
          checkupChannelId,
          'Checkup Reminders',
          channelDescription: 'Reminders to check in on your progress daily',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Fasting Complete',
        ),
      );

      final tz.TZDateTime tzTimeComplete = tz.TZDateTime.from(endAt, tz.local);
      await flutterLocalNotificationsPlugin.zonedSchedule(
        fastingCompleteId,
        titleComplete,
        bodyComplete,
        tzTimeComplete,
        detailsComplete,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'fasting_complete',
      );

      // Mark date as high-priority
      await _markHighPriorityOnDate(endAt);

      MixpanelService.trackNotificationScheduled(
        'fasting_complete',
        scheduledTime: endAt,
        title: titleComplete,
      );

      debugPrint('NotificationService: Scheduled fasting complete notification at ${endAt.toIso8601String()}');
    }

    debugPrint('NotificationService: All fasting motivational notifications scheduled for fast ending at ${endAt.toIso8601String()}');
  }

  // Cancel all fasting motivational notifications
  Future<void> cancelFastingMotivationalNotifications() async {
    await flutterLocalNotificationsPlugin.cancel(fasting4hReminderId);
    await flutterLocalNotificationsPlugin.cancel(fasting2hReminderId);
    await flutterLocalNotificationsPlugin.cancel(fastingCompleteId);
    debugPrint('NotificationService: Cancelled all fasting motivational notifications');
  }
  
  // Schedule checkup reminders notification
  Future<void> scheduleCheckupReminder({
    required int hour,
    required int minute,
    NotificationAudienceType audienceType = NotificationAudienceType.subscriber,
  }) async {
    // Check if notifications and checkup reminders are enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    final bool checkupRemindersEnabled = await isNotificationTypeEnabled(NotificationType.checkupReminders);
    
    if (!notificationsEnabled || !checkupRemindersEnabled) {
      debugPrint('Checkup reminders disabled. Not scheduling notification.');
      return;
    }
    
    String title;
    String body;
    
    // Get notification content based on audience type
    if (audienceType == NotificationAudienceType.subscriber) {
      // Select a day-based random title and message for subscribers
      title = await _getLocalizedString(_checkupReminderTitleKeys[_getDayBasedRandomIndex(_checkupReminderTitleKeys)]);
      body = await _getLocalizedString(_checkupReminderMessageKeys[_getDayBasedRandomIndex(_checkupReminderMessageKeys)]);
    } else {
      // Default message for non-subscribers
      title = await _getLocalizedString('notification_checkup_nonSubscriber_title');
      body = await _getLocalizedString('notification_checkup_nonSubscriber_message');
    }
    
    // Create notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
      android: AndroidNotificationDetails(
        checkupChannelId,
        'Checkup Reminders',
        channelDescription: 'Reminders to check in on your progress daily',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Checkup Reminder',
      ),
    );
    
    // Calculate next notification time
    final now = DateTime.now();
    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    // Convert to TZ format
    final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    
    // Schedule the notification
    await _scheduleCapped(
      id: checkupRemindersId,
      title: title,
      body: body,
      desiredTime: scheduledDate,
      details: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'checkup_reminder',
    );
    
    // Track notification scheduling in Mixpanel
    MixpanelService.trackNotificationScheduled(
      'checkup_reminder',
      scheduledTime: scheduledDate,
      title: title,
      audienceType: audienceType.toString(),
    );
    
    debugPrint('Scheduled checkup reminder notification for ${scheduledDate.toString()}');
  }
  
  // Schedule streak goals notification
  Future<void> scheduleStreakGoalsNotification({
    required int hour,
    required int minute,
    int currentStreak = 0,
    NotificationAudienceType audienceType = NotificationAudienceType.subscriber,
  }) async {
    // Streak goals are only for subscribers
    if (audienceType != NotificationAudienceType.subscriber) {
      debugPrint('Streak goals notifications are for subscribers only. Not scheduling notification.');
      return;
    }
    
    // Check if notifications and streak goals are enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    final bool streakGoalsEnabled = await isNotificationTypeEnabled(NotificationType.streakGoals);
    
    if (!notificationsEnabled || !streakGoalsEnabled) {
      debugPrint('Streak goals notifications disabled. Not scheduling notification.');
      return;
    }
    
    // Default title and message using day-based randomization
    String title = await _getLocalizedString(_streakGoalTitleKeys[_getDayBasedRandomIndex(_streakGoalTitleKeys)]);
    String body = await _getLocalizedString(_streakGoalMessageKeys[_getDayBasedRandomIndex(_streakGoalMessageKeys)]);
    
    // Modify message if we're at or near a milestone
    if (currentStreak > 0) {
      // List milestone days and their corresponding achievement names
      final milestones = [
        (1, 'Seed'),
        (3, 'Sprout'),
        (7, 'Pioneer'),
        (10, 'Momentum'),
        (14, 'Fortress'),
        (30, 'Guardian'),
        (45, 'Trailblazer'),
        (60, 'Ascendant'),
        (90, 'Nirvana'),
      ];
      
      // Find the next milestone
      var nextMilestone = milestones.firstWhere(
        (m) => m.$1 > currentStreak,
        orElse: () => (0, ''),
      );
      
      // If we found a next milestone
      if (nextMilestone.$1 > 0) {
        final daysUntilMilestone = nextMilestone.$1 - currentStreak;
        final nextAchievementName = nextMilestone.$2;
        
        if (daysUntilMilestone <= 3) {
          // We're close to a milestone
          final dayWord = await _getNotificationDayWord(daysUntilMilestone);
          title = (await _getLocalizedString('notification_achievement_approaching_title_template'))
              .replaceAll('{achievementName}', nextAchievementName);
          body = (await _getLocalizedString('notification_achievement_approaching_message_template'))
              .replaceAll('{daysUntilMilestone}', daysUntilMilestone.toString())
              .replaceAll('{dayWord}', dayWord)
              .replaceAll('{nextAchievementName}', nextAchievementName);
        }
      }
      
      // Check if user just reached a milestone
      final currentMilestone = milestones.where((m) => m.$1 == currentStreak).toList();
              if (currentMilestone.isNotEmpty) {
          final achievementName = currentMilestone.first.$2;
          // We've just reached a milestone
          title = (await _getLocalizedString('notification_achievement_unlocked_title_template'))
              .replaceAll('{achievementName}', achievementName);
          body = (await _getLocalizedString('notification_achievement_unlocked_message_template'))
              .replaceAll('{achievementName}', achievementName)
              .replaceAll('{currentStreak}', currentStreak.toString());
        }
    }
    
    // Create notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
      android: AndroidNotificationDetails(
        streakGoalsChannelId,
        'Streak Updates',
        channelDescription: 'Updates about your streak progress and achievements',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Streak Update',
      ),
    );
    
    // Calculate next notification time
    final now = DateTime.now();
    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    // Convert to TZ format
    final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    
    // Schedule the notification
    await _scheduleCapped(
      id: streakGoalsId,
      title: title,
      body: body,
      desiredTime: scheduledDate,
      details: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'streak_update',
    );
    
    // Track notification scheduling in Mixpanel
    MixpanelService.trackNotificationScheduled(
      'streak_goals',
      scheduledTime: scheduledDate,
      title: title,
      audienceType: audienceType.toString(),
      additionalProps: {'current_streak': currentStreak},
    );
    
    debugPrint('Scheduled streak goals notification for ${scheduledDate.toString()}');
  }
  
  // Schedule app update notification (bypasses daily cap, sent at 9:12 PM)
  Future<void> scheduleAppUpdateNotification({
    required String version,
  }) async {
    try {
      // Check if notifications are enabled
      final bool notificationsEnabled = await areNotificationsEnabled();
      if (!notificationsEnabled) {
        debugPrint('NotificationService: Notifications disabled. Skipping app update notification.');
        return;
      }
      
      // Check if user is on trial - trial users get NO notifications at all
      final bool isOnTrial = await _isUserOnTrial();
      if (isOnTrial) {
        debugPrint('NotificationService: User is on trial. Skipping app update notification.');
        return;
      }
      
      // Check if we've already sent notification for this version
      final prefs = await SharedPreferences.getInstance();
      final lastNotifiedVersion = prefs.getString('last_app_update_notified_version');
      if (lastNotifiedVersion == version) {
        debugPrint('NotificationService: Already sent app update notification for version $version');
        return;
      }
      
      // Get localized strings
      final title = await _getLocalizedString('appUpdate_banner_title');
      final message = await _getLocalizedString('appUpdate_banner_message');
      final body = message.replaceAll('{version}', version);
      
      // Create notification details
      const NotificationDetails notificationDetails = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
        android: AndroidNotificationDetails(
          appUpdateChannelId,
          'App Updates',
          channelDescription: 'Notifications about new app versions',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'App Update Available',
        ),
      );
      
      // Calculate notification time (9:12 PM today or tomorrow - 1h+ spacing from last notification)
      final now = DateTime.now();
      DateTime scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        21, // 9 PM
        12, // 12 minutes
      );
      
      // If 9:12 PM has passed todayr, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      
      // Convert to TZ format
      final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      
      // Cancel any existing app update notification
      await flutterLocalNotificationsPlugin.cancel(appUpdateId);
      
      // Schedule the notification (bypasses daily cap - doesn't use _scheduleCapped)
      await flutterLocalNotificationsPlugin.zonedSchedule(
        appUpdateId,
        title,
        body,
        scheduledTzDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'app_update_available',
      );
      
      // Mark this version as notified
      await prefs.setString('last_app_update_notified_version', version);
      
      // Track notification scheduling
      MixpanelService.trackNotificationScheduled(
        'app_update_available',
        scheduledTime: scheduledDate,
        title: title,
        additionalProps: {'version': version},
      );
      
      debugPrint('NotificationService: Scheduled app update notification for version $version at ${scheduledDate.toString()}');
    } catch (e) {
      debugPrint('NotificationService: Error scheduling app update notification: $e');
    }
  }
  
  // OLD FUNCTION - TO BE REMOVED
  Future<void> _oldScheduleAppUpdateNotification({
    int hour = 19,
    int minute = 0,
    NotificationAudienceType audienceType = NotificationAudienceType.subscriber,
  }) async {
    // DISABLED: Old function - replaced with new version-based implementation
    debugPrint('AppUpdate: old function disabled');
    return;
    // Skip for free users who never had a trial
    try {
      final isFree = await _isFreeNonTrial();
      if (isFree) {
        debugPrint('AppUpdate: free non-trial user - skip app update notification');
        return;
      }
    } catch (_) {}
    // Remove the subscriber-only restriction - app updates are for everyone
    // if (audienceType != NotificationAudienceType.subscriber) {
    //   debugPrint('App update notifications are for subscribers only. Not scheduling notification.');
    //   return;
    // }
    
    // Check if notifications and app update notifications are enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    final bool appUpdateEnabled = await isNotificationTypeEnabled(NotificationType.appUpdate);
    
    if (!notificationsEnabled || !appUpdateEnabled) {
      debugPrint('App update notifications disabled. Not scheduling notification.');
      return;
    }
    
    // Check if user needs an app update using the AppUpdateService
    try {
      final AppUpdateService updateService = AppUpdateService();
      final updateInfo = await updateService.checkForUpdate();
      
      if (!updateInfo.hasUpdate) {
        debugPrint('No app update available. Not scheduling app update notification.');
        return;
      }
      
      debugPrint('App update available: ${updateInfo.currentVersion} -> ${updateInfo.latestVersion}');
    } catch (e) {
      debugPrint('Error checking for app update: $e');
      return;
    }
    
    // Select day-based random title and message
    final title = await _getLocalizedString(_appUpdateTitleKeys[_getDayBasedRandomIndex(_appUpdateTitleKeys)]);
    final body = await _getLocalizedString(_appUpdateMessageKeys[_getDayBasedRandomIndex(_appUpdateMessageKeys)]);
    
    // Create notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
      android: AndroidNotificationDetails(
        appUpdateChannelId,
        'App Updates',
        channelDescription: 'Notifications about app updates and new features',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'App Update Available',
      ),
    );
    
    // Calculate next notification time
    final now = DateTime.now();
    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    // Convert to TZ format
    final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    
    // Schedule the notification
    await _scheduleCapped(
      id: appUpdateId,
      title: title,
      body: body,
      desiredTime: scheduledDate,
      details: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'app_update',
    );
    
    // Track notification scheduling in Mixpanel
    MixpanelService.trackNotificationScheduled(
      'app_update',
      scheduledTime: scheduledDate,
      title: title,
      audienceType: audienceType.toString(),
    );
    
    debugPrint('Scheduled app update notification for ${scheduledDate.toString()}');
  }
  
  // Check and schedule app update notification if needed (can be called manually)
  Future<void> checkAndScheduleAppUpdateNotification() async {
    try {
      // DISABLED: App update notifications removed per request
      debugPrint('AppUpdate: check disabled');
      return;
      // Skip for free users who never had a trial
      debugPrint('start checkAndScheduleAppUpdateNotification');
      // Guard: avoid calling subscription/trial checks before SDKs are ready
      if (_superwallReady && _revenueCatReady) {
        if (await _isFreeNonTrial()) {
          debugPrint('AppUpdate: free non-trial user - skip daily app update checks');
          return;
        }
      } else {
        debugPrint('AppUpdate: SDKs not fully ready (rcReady=' + _revenueCatReady.toString() + ', superwallReady=' + _superwallReady.toString() + '), skipping free-non-trial short-circuit');
      }
      // Check if notifications and app update notifications are enabled
      final bool notificationsEnabled = await areNotificationsEnabled();
      final bool appUpdateEnabled = await isNotificationTypeEnabled(NotificationType.appUpdate);
      
      if (!notificationsEnabled || !appUpdateEnabled) {
        debugPrint('App update notifications disabled. Skipping check.');
        return;
      }
      debugPrint('AppUpdate readiness: rcReady=' + _revenueCatReady.toString() + ' superwallReady=' + _superwallReady.toString());
      
      // Check if user needs an app update
      final AppUpdateService updateService = AppUpdateService();
      final updateInfo = await updateService.checkForUpdate();
      
      if (updateInfo.hasUpdate) {
        debugPrint('App update available - notification now handled by home_screen.dart');
      } else {
        debugPrint('No app update available, not scheduling notification');
      }
    } catch (e) {
      debugPrint('Error checking and scheduling app update notification: $e');
    }
  }
  
  // Schedule daily app update checks at 7 PM for all users
  Future<void> scheduleDailyAppUpdateChecks() async {
    try {
      // DISABLED: App update notifications removed per request
      debugPrint('AppUpdate: daily checks disabled');
      return;
      // Check if notifications and app update notifications are enabled
      final bool notificationsEnabled = await areNotificationsEnabled();
      final bool appUpdateEnabled = await isNotificationTypeEnabled(NotificationType.appUpdate);
      
      if (!notificationsEnabled || !appUpdateEnabled) {
        debugPrint('App update notifications disabled. Not scheduling daily checks.');
        return;
      }
      
      // This will be called daily to check for updates and notify if available
      // The actual scheduling happens in updateAllNotifications, this is for standalone scheduling
      await checkAndScheduleAppUpdateNotification();
      
      debugPrint('Daily app update check scheduled');
    } catch (e) {
      debugPrint('Error scheduling daily app update checks: $e');
    }
  }
  
  // Helper method to check if user is currently on trial
  Future<bool> _isUserOnTrial() async {
    try {
      debugPrint('start _isUserOnTrial');
      // Guard: avoid calling RevenueCat too early or in unsafe lifecycle states
      if (!_revenueCatReady) {
        debugPrint('NotificationService: RevenueCat not ready, treating as not-on-trial');
        return false;
      }
      // Small timeout to avoid hanging if SDK stalls
      Future<T> _withTimeout<T>(Future<T> future) => future.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('RevenueCat getCustomerInfo timed out');
            },
          );
      // Use Purchases to get customer info for most accurate trial status
      final customerInfo = await _withTimeout(Purchases.getCustomerInfo());
      debugPrint('after isUserOnTrial Purchases.getCustomerInfo');
      
      // First check if user has any trial product
      bool hasTrialProduct = false;
      
      // Check if any active entitlement is from a trial product
      for (final entitlement in customerInfo.entitlements.active.values) {
        final productId = entitlement.productIdentifier;
        
        // Check if product ID contains "trial" (case insensitive)
        if (productId.toLowerCase().contains('trial')) {
          hasTrialProduct = true;
          break;
        }
      }
      
      // Also check active subscriptions for trial products
      if (!hasTrialProduct) {
        for (final productId in customerInfo.activeSubscriptions) {
          if (productId.toLowerCase().contains('trial')) {
            hasTrialProduct = true;
            break;
          }
        }
      }
      
      // If no trial product found, they're not on trial
      if (!hasTrialProduct) {
        return false;
      }
      
      // If they have a trial product, check if it has expired/converted via RevenueCat
      try {
        // Check trial status directly from RevenueCat CustomerInfo
        final activeEntitlements = customerInfo.entitlements.active;
        if (activeEntitlements.isNotEmpty) {
          // Get the first active entitlement (should be the trial)
          final entitlement = activeEntitlements.values.first;
          final willRenew = entitlement.willRenew;
          final expirationDate = entitlement.expirationDate;
          
          // Check if trial has expired (converted to paid subscription)
          if (expirationDate != null) {
            try {
              final trialExpiration = DateTime.parse(expirationDate);
              final now = DateTime.now();
              
              if (now.isAfter(trialExpiration)) {
                // Trial has expired - if user still has active subscription, they converted to paid
                debugPrint('NotificationService: Trial expired on $trialExpiration, user has converted to paid - allowing subscriber notifications');
                return false;
              }
            } catch (e) {
              debugPrint('NotificationService: Error parsing trial expiration date: $e');
            }
          }
          
          // If trial is still active, check if they cancelled it
          if (!willRenew) {
            // User has cancelled their trial via RevenueCat - allow notifications for re-engagement
            debugPrint('NotificationService: Active trial user has cancelled (RevenueCat willRenew=false), allowing notifications for re-engagement');
            return false;
          }
        }
      } catch (e) {
        debugPrint('NotificationService: Error checking RevenueCat trial status: $e');
        // If we can't determine trial status, treat as active trial
      }
      
      // Active trial user who hasn't cancelled - block notifications
      debugPrint('NotificationService: Active trial user detected who hasn\'t cancelled - blocking notifications');
      return true;
      
    } catch (e) {
      debugPrint('NotificationService: Error checking trial status (guarded): $e');
      return false; // Default to non-trial if check fails
    }
  }

  // Helper method to determine if user is a qualified subscriber (paid user who accepted notifications)
  Future<bool> isQualifiedSubscriber() async {
    try {
      // Determine paid status independent of notification consent
      
      //debugPrint('isQualifiedSubscriber: rcReady=$_revenueCatReady superwallReady=$_superwallReady');
      // Check if user is on trial - trial users should not receive subscriber notifications
      // Guard: if RevenueCat not ready yet, skip trial check to avoid crash
      final bool isOnTrial = _revenueCatReady ? await _isUserOnTrial() : false;
      if (isOnTrial) {
        debugPrint('NotificationService: User is on trial, not a qualified subscriber for notifications');
        return false;
      }
      
      // Check Superwall subscription status only if Superwall is configured
      bool isPaidViaWall = false;
      try {
        if (_superwallReady) {
          debugPrint('NotificationService: Superwall ready, checking subscription status');
          final status = await Superwall.shared.getSubscriptionStatus();
          isPaidViaWall = status is SubscriptionStatusActive;
          if (isPaidViaWall) {
            debugPrint('NotificationService: User has active Superwall subscription, is a qualified subscriber');
          }
        } else {
          debugPrint('NotificationService: Superwall not ready, skipping getSubscriptionStatus');
        }
      } catch (e) {
        debugPrint('NotificationService: Error checking Superwall status: $e');
      }
      
      // Check Firebase subscription status if not already determined to be a paid user
      bool isPaidViaFirebase = false;
      if (!isPaidViaWall) {
        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final UserRepository userRepository = UserRepository();
            final userData = await userRepository.getUserProfile(currentUser.uid);
            final subscriptionStatus = userData?['subscriptionStatus'] ?? '';
            isPaidViaFirebase = subscriptionStatus.isNotEmpty && subscriptionStatus != 'free';
            
            if (isPaidViaFirebase) {
              debugPrint('NotificationService: User has paid Firebase subscription status: $subscriptionStatus');
            }
          }
        } catch (e) {
          debugPrint('NotificationService: Error checking Firebase subscription status: $e');
        }
      }
      
      // User is a qualified subscriber if they have paid via either method and are not on trial
      final isQualified = (isPaidViaWall || isPaidViaFirebase) && !isOnTrial;
      debugPrint('NotificationService: User is${isQualified ? '' : ' not'} a qualified subscriber');
      return isQualified;
      
    } catch (e) {
      debugPrint('NotificationService: Error determining qualified subscriber status: $e');
      return false;
    }
  }
  
  // Modified method to use the new helper
  Future<void> updateNotificationsBasedOnSubscription({
    bool? isSubscribed, // Now optional
    int hour = 9,
    int minute = 0,
  }) async {
    // First check if notifications are enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) {
      debugPrint('Notifications are disabled by user. Not updating any notifications.');
      return;
    }
    
    // Cancel existing notifications first
    await cancelAllNotifications();
    
    // If isSubscribed was not provided, determine it automatically
    final bool subscriberStatus = isSubscribed ?? await isQualifiedSubscriber();
    
    // Schedule the appropriate notification based on subscription status
    final audienceType = subscriberStatus 
        ? NotificationAudienceType.subscriber 
        : NotificationAudienceType.nonSubscriber;
    
    debugPrint('Updating notifications with audience type: ${audienceType.toString()}');
    
    // Update all types of notifications
    await updateAllNotifications(audienceType: audienceType, hour: hour, minute: minute);
  }
  
  // Update all notification types
  Future<void> updateAllNotifications({
    NotificationAudienceType audienceType = NotificationAudienceType.subscriber,
    int hour = 8,
    int minute = 42,
    int currentStreak = 0,
  }) async {
    // First check if global notifications are enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) {
      debugPrint('NotificationService: Notifications are disabled by user. Not updating any notifications.');
      return;
    }
    
    // Check if user is on trial - trial users get NO notifications at all
    final bool isOnTrial = await _isUserOnTrial();
    if (isOnTrial) {
      debugPrint('NotificationService: User is on trial. Skipping ALL notifications (0 notifications for trial users).');
      await cancelAllNotifications(); // Cancel any existing notifications
      return;
    }

    // High-priority day: allow only challenge/pledge flows (scheduled elsewhere). Skip all routine/marketing/trial/meals here.
    final bool isHighPriority = await _isHighPriorityDate(DateTime.now());
    if (isHighPriority) {
      debugPrint('NotificationService: High-priority day → skipping routine scheduling (marketing/trial/morning/evening/meals).');
      return;
    }
    
    // Cancel existing notifications first to avoid duplicates and reset cap
    await cancelAllNotifications();
    await _resetTodayCapCounters();
    
    // App update notifications are scheduled separately and don't count toward daily cap
    bool appUpdateScheduled = false;
    
    // Build candidate list by priority and schedule only top 3
    final List<Future<void> Function()> candidates = [];

    Future<void> addIf(bool cond, Future<void> Function() fn) async {
      if (cond) candidates.add(fn);
    }

    final bool isSubscriber = audienceType == NotificationAudienceType.subscriber;
    final bool isHp = await _isHighPriorityDate(DateTime.now());
    if (isHp) {
      debugPrint('NotificationService: High-priority day → no routine candidates.');
      return;
    }

    // 1) Time-sensitive inactive (subscribers only)
    await addIf(
      isSubscriber,
      () async => await checkAndScheduleTimeSensitiveNotification(),
    );

    // 2) Morning/evening or streak goals
    if (isSubscriber) {
      await addIf(
        await isNotificationTypeEnabled(NotificationType.morningMotivation),
        () async => await scheduleDailyMeditationReminder(
          hour: hour,
          minute: minute,
          audienceType: audienceType,
        ),
      );
      await addIf(
        !appUpdateScheduled &&
            await isNotificationTypeEnabled(NotificationType.streakGoals),
        () async => await scheduleStreakGoalsNotification(
          hour: 19,
          minute: 23,
          currentStreak: currentStreak,
          audienceType: audienceType,
        ),
      );
    } else {
      await addIf(
        await isNotificationTypeEnabled(NotificationType.morningMotivation),
        () async => await scheduleDailyMeditationReminder(
          hour: 8,
          minute: 38,
          audienceType: audienceType,
        ),
      );
      await addIf(
        !appUpdateScheduled &&
            await isNotificationTypeEnabled(NotificationType.morningMotivation),
        () async => await scheduleDailyMeditationReminder(
          hour: 19,
          minute: 49,
          audienceType: audienceType,
        ),
      );
    }

    // 3) Marketing offers (80% discount for everyone)
    await addIf(true, () async => await scheduleMarketingOfferNotification());

    // 4) Meal reminders (lunch, dinner) as separate candidates
    await addIf(
      await isNotificationTypeEnabled(NotificationType.lunchReminder) &&
          (await getMealReminderTime(NotificationType.lunchReminder)) != null,
      () async {
        final t = await getMealReminderTime(NotificationType.lunchReminder);
        if (t != null) {
          await _scheduleMealReminder(NotificationType.lunchReminder, t);
        }
      },
    );

    await addIf(
      await isNotificationTypeEnabled(NotificationType.dinnerReminder) &&
          (await getMealReminderTime(NotificationType.dinnerReminder)) != null,
      () async {
        final t = await getMealReminderTime(NotificationType.dinnerReminder);
        if (t != null) {
          await _scheduleMealReminder(NotificationType.dinnerReminder, t);
        }
      },
    );

    // Execute in order until 3 scheduled today
    int scheduled = await _getTodayScheduledCount();
    for (final task in candidates) {
      if (scheduled >= maxNotificationsPerDay) break;
      final before = await _getTodayScheduledCount();
      await task();
      final after = await _getTodayScheduledCount();
      if (after > before) scheduled += (after - before);
      if (scheduled >= maxNotificationsPerDay) break;
    }
  }
  
  // Schedule a pledge check notification
  Future<void> schedulePledgeCheckNotification({
    required DateTime checkTime,
    required String title,
    required String body,
  }) async {
    // First check if notifications and checkup reminders are enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    final bool checkupRemindersEnabled = await isNotificationTypeEnabled(NotificationType.checkupReminders);
    
    if (!notificationsEnabled || !checkupRemindersEnabled) {
      debugPrint('Checkup reminders disabled. Not scheduling pledge check notification.');
      return;
    }
    
    try {
      // Create notification details
      const NotificationDetails notificationDetails = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
        android: AndroidNotificationDetails(
          checkupChannelId,
          'Checkup Reminders',
          channelDescription: 'Reminders to check in on your progress daily',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Pledge Completed',
        ),
      );
      
      // Convert to TZ format
      final scheduledTzDate = tz.TZDateTime.from(checkTime, tz.local);
      
      // Use a notification ID specific to pledge checks (different from daily reminders)
      const int notificationId = 100;
      
      // Schedule the notification
      await _scheduleCapped(
        id: notificationId,
        title: title,
        body: await _maybePrefixWithName(body),
        desiredTime: checkTime,
        details: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      
      // Track notification scheduling in Mixpanel
      MixpanelService.trackNotificationScheduled(
        'pledge_check',
        scheduledTime: checkTime,
        title: title,
      );
      
      debugPrint('Scheduled pledge check notification for ${checkTime.toString()}');
      // Mark date as high-priority
      await _markHighPriorityOnDate(checkTime);
    } catch (e) {
      debugPrint('Error scheduling pledge check notification: $e');
    }
  }
  
  // Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // ========== Accountability partner notifications (immediate, outside daily cap) ==========
  Future<void> sendAccountabilityRequestReceived({
    required String fromName,
  }) async {
    try {
      await initialize();

      final String title = (await _getLocalizedString('accountability_request_title'))
          .replaceAll('{name}', fromName);
      final String body = await _getLocalizedString('accountability_request_message');

      const NotificationDetails details = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
        android: AndroidNotificationDetails(
          streakGoalsChannelId,
          'Streak Updates',
          channelDescription: 'Updates about your streak progress and achievements',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Accountability Request',
        ),
      );

      await flutterLocalNotificationsPlugin.show(
        99101,
        title,
        body,
        details,
        payload: 'accountability_request',
      );
    } catch (e) {
      debugPrint('NotificationService: Error sending accountability request notification: $e');
    }
  }

  Future<void> sendAccountabilityPaired({
    required String partnerName,
  }) async {
    try {
      await initialize();

      final String title = await _getLocalizedString('accountability_paired_title');
      final String body = (await _getLocalizedString('accountability_paired_body'))
          .replaceAll('{name}', partnerName);

      const NotificationDetails details = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
        android: AndroidNotificationDetails(
          streakGoalsChannelId,
          'Streak Updates',
          channelDescription: 'Updates about your streak progress and achievements',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Partnership Paired',
        ),
      );

      await flutterLocalNotificationsPlugin.show(
        99102,
        title,
        body,
        details,
        payload: 'accountability_paired',
      );
    } catch (e) {
      debugPrint('NotificationService: Error sending accountability paired notification: $e');
    }
  }
  
  // Cancel a specific notification type
  Future<void> cancelNotificationType(NotificationType type) async {
    switch (type) {
      case NotificationType.checkupReminders:
        await flutterLocalNotificationsPlugin.cancel(checkupRemindersId);
        break;
      case NotificationType.streakGoals:
        await flutterLocalNotificationsPlugin.cancel(streakGoalsId);
        break;
      case NotificationType.morningMotivation:
        await flutterLocalNotificationsPlugin.cancel(morningMotivationId);
        break;
      case NotificationType.appUpdate:
        await flutterLocalNotificationsPlugin.cancel(appUpdateId);
        break;
      case NotificationType.chatNotifications:
        await flutterLocalNotificationsPlugin.cancel(chatNotificationsId);
        break;
      case NotificationType.marketingOffers:
        await flutterLocalNotificationsPlugin.cancel(marketingOffersId);
        break;
      case NotificationType.trialOffer:
        await flutterLocalNotificationsPlugin.cancel(trialOfferId);
        break;
      case NotificationType.timeSensitive:
        await flutterLocalNotificationsPlugin.cancel(timeSensitiveId);
        break;
      case NotificationType.mealCalorieTracking:
        await flutterLocalNotificationsPlugin.cancel(mealCalorieTrackingId);
        break;
      case NotificationType.breakfastReminder:
        // breakfast reminders removed
        break;
      case NotificationType.lunchReminder:
        await flutterLocalNotificationsPlugin.cancel(lunchReminderId);
        break;
      case NotificationType.dinnerReminder:
        await flutterLocalNotificationsPlugin.cancel(dinnerReminderId);
        break;
      case NotificationType.relapseChallengeDaily:
        // Cancel a range of potential IDs used for the challenge
        for (int i = 0; i < 120; i++) {
          await flutterLocalNotificationsPlugin.cancel(relapseChallengeDailyIdBase + i);
        }
        break;
    }
  }

  // Schedule daily congratulation notifications for relapse challenge
  Future<void> scheduleRelapseChallengeNotifications({required int totalDays}) async {
  // Include trial users as requested
    // Ensure channels/timezones are initialized before any checks or scheduling
    try {
      await initialize();
    } catch (e) {
      debugPrint('RelapseChallenge: initialization failed: $e');
      return;
    }
    
    // Global enable check
    if (!await areNotificationsEnabled()) {
      debugPrint('RelapseChallenge: notifications disabled');
      return;
    }
    // Cancel previous challenge notifications
    await cancelNotificationType(NotificationType.relapseChallengeDaily);

    // Skip for non-subscribers who never had a trial (no app access)
    try {
      final bool isSub = await isQualifiedSubscriber();
      final bool isTrial = await _isUserOnTrial();
      final bool isCancelledTrial = await _isCancelledTrialUser();
      final bool isFreeNeverTrial = !isSub && !isTrial && !isCancelledTrial;
      if (isFreeNeverTrial) {
        debugPrint('RelapseChallenge: free non-trial user - skip scheduling');
        return;
      }
    } catch (_) {}

    // Determine audience/category: active trial, cancelled trial, subscriber, or non-subscriber
    final bool isActiveTrial = await _isUserOnTrial();
    final bool isCancelledTrial = await _isCancelledTrialUser();
    final bool isSubscriber = await isQualifiedSubscriber();

    // Choose a non-overlapping time slot
    final TimeOfDay relapseTime = isActiveTrial && !isCancelledTrial
        // Active trial users don't receive other daily notifications in our system
        ? const TimeOfDay(hour: 9, minute: 0)
        : await _findNonOverlappingRelapseTime(isSubscriber: isSubscriber);

    // Localized strings
    final titleBase = await _getLocalizedString('relapse_challenge_congrats_title');
    final bodyTemplate = await _getLocalizedString('relapse_challenge_congrats_body');

    // Daily at selected time starting tomorrow (Day 1 = next day)
    final int hour = relapseTime.hour;
    final int minute = relapseTime.minute;
    final DateTime now = DateTime.now();
    final DateTime baseTomorrow = DateTime(now.year, now.month, now.day, hour, minute)
        .add(const Duration(days: 1));

    for (int dayIndex = 0; dayIndex < totalDays; dayIndex++) {
      final int daysLeft = (totalDays - 1) - dayIndex;
      DateTime scheduledDate = baseTomorrow.add(Duration(days: dayIndex));

      final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      final String title = titleBase;
      final String dayWord = await _getNotificationDayWord(daysLeft == 0 ? 1 : daysLeft);
      final String body = bodyTemplate
          .replaceAll('{days_left}', daysLeft.toString())
          .replaceAll('{day_word}', daysLeft == 0 ? await _getLocalizedString('notification_day_singular') : dayWord);

      const NotificationDetails details = NotificationDetails(
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        android: AndroidNotificationDetails(
          relapseChallengeChannelId,
          'Relapse Challenge',
          channelDescription: 'Daily congrats and days-left during your challenge',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

      await _scheduleCapped(
        id: relapseChallengeDailyIdBase + dayIndex,
        title: title,
        body: await _maybePrefixWithName(body),
        desiredTime: scheduledDate,
        details: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      // Mark date as high-priority
      await _markHighPriorityOnDate(scheduledDate);
    }

    debugPrint('RelapseChallenge: scheduled $totalDays daily notifications');
  }

  // Pick a relapse notification time that avoids overlaps with other regular daily notifications
  Future<TimeOfDay> _findNonOverlappingRelapseTime({required bool isSubscriber}) async {
    final reserved = await _getReservedDailyMinutes(isSubscriber: isSubscriber);

    // Ensure at least 3 hours distance from any reserved time
    const int minSeparation = 180; // minutes

    // Start from 09:12 and try 15-minute increments over the day
    int bestCandidate = -1;
    int bestDistance = -1;
    for (int minutesOfDay = 9 * 60 + 12; minutesOfDay < 24 * 60; minutesOfDay += 15) {
      int minDist = _minAbsDistanceMinutes(minutesOfDay, reserved);
      if (minDist >= minSeparation) {
        final int candidateHour = (minutesOfDay ~/ 60) % 24;
        final int candidateMinute = minutesOfDay % 60;
        debugPrint('RelapseChallenge: selected time (>=3h from others): '
            '${candidateHour.toString().padLeft(2, '0')}:${candidateMinute.toString().padLeft(2, '0')}');
        return TimeOfDay(hour: candidateHour, minute: candidateMinute);
      }
      if (minDist > bestDistance) {
        bestDistance = minDist;
        bestCandidate = minutesOfDay;
      }
    }

    // Fallback to the farthest candidate if none meet the 3h rule
    final int candidateHour = (bestCandidate ~/ 60) % 24;
    final int candidateMinute = bestCandidate % 60;
    debugPrint('RelapseChallenge: fallback farthest time (distance=${bestDistance}m): '
        '${candidateHour.toString().padLeft(2, '0')}:${candidateMinute.toString().padLeft(2, '0')}');
    return TimeOfDay(hour: candidateHour, minute: candidateMinute);
  }

  // Build a set of reserved minutes-of-day where other notifications are typically scheduled
  Future<Set<int>> _getReservedDailyMinutes({required bool isSubscriber}) async {
    final Set<int> reserved = {};

    // Known fixed schedules
    // Morning motivation: 08:42 for subscribers, 08:38 for non-subscribers
    reserved.add((isSubscriber ? 8 : 8) * 60 + (isSubscriber ? 42 : 38));
    // Evening engagement: 19:23 for subs via streak, 19:49 for non-subs
    reserved.add(19 * 60 + (isSubscriber ? 23 : 49));

    // Meal reminders (use configured times if set and enabled)
    Future<void> addMealIfEnabled(NotificationType mealType) async {
      final enabled = await isNotificationTypeEnabled(mealType);
      if (!enabled) return;
      final time = await getMealReminderTime(mealType);
      if (time != null) {
        reserved.add(time.hour * 60 + time.minute);
      }
    }

    // Breakfast removed
    await addMealIfEnabled(NotificationType.lunchReminder);
    await addMealIfEnabled(NotificationType.dinnerReminder);

    return reserved;
  }

  // Compute minimal absolute distance in minutes from candidate to any reserved time (circular day not considered)
  int _minAbsDistanceMinutes(int candidateMinutes, Set<int> reserved) {
    if (reserved.isEmpty) return 24 * 60; // effectively infinite
    int minDist = 24 * 60;
    for (final r in reserved) {
      final int d = (candidateMinutes - r).abs();
      if (d < minDist) minDist = d;
    }
    return minDist;
  }
  
  // ---------------- High-priority (pledge/relapse) day flags ----------------
  Future<void> _markHighPriorityOnDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hp_${_ymd(date)}', true);
    } catch (_) {}
  }

  Future<bool> _isHighPriorityDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('hp_${_ymd(date)}') ?? false;
    } catch (_) {
      return false;
    }
  }
  
  // Send notification for completed food scan
  // NOTE: This is intentionally NOT blocked for trial users since it's a direct response to user action
  Future<void> sendFoodScanCompleteNotification({
    required String foodName,
    required double calories,
  }) async {
    try {
      // Ensure notification service is initialized before showing notification
      await initialize();
      
      // Validate input parameters
      if (foodName.trim().isEmpty) {
        debugPrint('NotificationService: Food name is empty, skipping notification');
        return;
      }
      
      // First check if notifications and meal calorie tracking are enabled
      final bool notificationsEnabled = await areNotificationsEnabled();
      final bool mealTrackingEnabled = await isNotificationTypeEnabled(NotificationType.mealCalorieTracking);
      
      if (!notificationsEnabled || !mealTrackingEnabled) {
        debugPrint('Meal calorie tracking notifications disabled. Not sending notification.');
        return;
      }
      
      const NotificationDetails notificationDetails = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
        android: AndroidNotificationDetails(
          mealCalorieTrackingChannelId,
          'Meal Calorie Tracking',
          channelDescription: 'Notifications when food scan analysis is complete',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Food Analysis Complete',
        ),
      );
      
      // Use a unique ID for meal tracking notifications
      final int notificationId = mealCalorieTrackingId;
      
      // Get localized title and body
      final String title = await _getLocalizedString('notification_food_scan_complete_title');
      String body = await _getLocalizedString('notification_food_scan_complete_message');
      body = await _maybePrefixWithName(body);
      
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'food_scan_complete_${foodName.trim().replaceAll(' ', '_').toLowerCase()}',
      );
      
      // Track notification sent in Mixpanel
      MixpanelService.trackNotificationSent(
        'food_scan_complete',
        title: title,
        additionalProps: {
          'food_name': foodName.trim(),
          'calories': calories,
        },
      );
      
      debugPrint('Sent food scan complete notification for: ${foodName.trim()} (${calories.toInt()} calories)');
      
    } catch (e) {
      debugPrint('NotificationService: Error sending food scan complete notification: $e');
      // Don't rethrow - we don't want food scanning to fail due to notification issues
    }
  }
  
  // Send notification for unlocked achievement
  Future<void> sendAchievementUnlockedNotification({
    required String achievementName,
    required String achievementDescription,
  }) async {
    try {
      // Ensure notification service is initialized before showing notification
      await initialize();
      
      // Validate input parameters
      if (achievementName.trim().isEmpty) {
        debugPrint('NotificationService: Achievement name is empty, skipping notification');
        return;
      }
      
      if (achievementDescription.trim().isEmpty) {
        debugPrint('NotificationService: Achievement description is empty, skipping notification');
        return;
      }
      
      // First check if notifications and streak goals are enabled
      final bool notificationsEnabled = await areNotificationsEnabled();
      final bool streakGoalsEnabled = await isNotificationTypeEnabled(NotificationType.streakGoals);
      
      if (!notificationsEnabled || !streakGoalsEnabled) {
        debugPrint('Streak goals notifications disabled. Not sending achievement notification.');
        return;
      }
      
      const NotificationDetails notificationDetails = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
        android: AndroidNotificationDetails(
          streakGoalsChannelId,
          'Streak Updates',
          channelDescription: 'Updates about your streak progress and achievements',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Achievement Unlocked',
        ),
      );
      
      // Use a unique ID for achievement notifications
      final int notificationId = 200 + _random.nextInt(1000);
      
      // Get localized title with fallback
      final String title = await _getLocalizedString('notification_achievement_unlocked_generic_title');
      
      // Get localized body with placeholders
      final String bodyTemplate = await _getLocalizedString('notification_achievement_unlocked_generic_message');
      String body = bodyTemplate
          .replaceAll('{achievementName}', achievementName.trim())
          .replaceAll('{achievementDescription}', achievementDescription.trim());
      body = await _maybePrefixWithName(body);
      
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'achievement_unlocked_${achievementName.trim()}',
      );
      
      // Track notification sent in Mixpanel
      MixpanelService.trackNotificationSent(
        'achievement_unlocked',
        title: title,
        additionalProps: {
          'achievement_name': achievementName.trim(),
          'achievement_description': achievementDescription.trim(),
        },
      );
      
      debugPrint('Sent achievement notification for: ${achievementName.trim()}');
      
    } catch (e) {
      debugPrint('NotificationService: Error sending achievement notification: $e');
      // Don't rethrow - we don't want achievement unlock to fail due to notification issues
    }
  }
  
  // Schedule marketing offer notification (every 2 days for eligible users)
  Future<void> scheduleMarketingOfferNotification() async {
    // Check if notifications and marketing offers are enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    final bool marketingOffersEnabled = await isNotificationTypeEnabled(NotificationType.marketingOffers);
    
    if (!notificationsEnabled || !marketingOffersEnabled) {
      debugPrint('NotificationService: Marketing offers notifications disabled. Not scheduling notification.');
      return;
    }
    
    // Check if we should send notification
    final bool shouldSend = await _shouldSendMarketingOffer();
    if (!shouldSend) {
      debugPrint('NotificationService: Marketing offer notification sent recently. Not scheduling notification.');
      return;
    }
    
    // Select day-based random title and message
    final title = await _getLocalizedString(_marketingOfferTitleKeys[_getDayBasedRandomIndex(_marketingOfferTitleKeys)]);
    String body = await _getLocalizedString(_marketingOfferMessageKeys[_getDayBasedRandomIndex(_marketingOfferMessageKeys)]);
    body = await _maybePrefixWithName(body);
    
    // Create notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
      android: AndroidNotificationDetails(
        marketingOffersChannelId,
        'Special Offers',
        channelDescription: 'Limited time offers and exclusive deals',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Special Offer',
      ),
    );
    
    // Calculate notification time (use midday for cancelled trial and free users)
    final now = DateTime.now();
    DateTime scheduledDate = now.add(const Duration(minutes: 1));
    
    // Schedule the notification
    await _scheduleCapped(
      id: marketingOffersId,
      title: title,
      body: body,
      desiredTime: scheduledDate,
      details: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'INSERT_YOUR_GIFT_STEP_2_PLACEMENT_ID_HERE',
    );
    
    // Update last sent timestamp
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(lastMarketingNotificationKey, scheduledDate.millisecondsSinceEpoch);
    
    // Track notification scheduling in Mixpanel
    MixpanelService.trackNotificationScheduled(
      'marketing_offer',
      scheduledTime: scheduledDate,
      title: title,
    );
    
    debugPrint('NotificationService: Scheduled marketing offer notification for ${scheduledDate.toString()}');
  }
  
  // Schedule trial offer notification (every 1-2 days for non-subscribers only)
  Future<void> scheduleTrialOfferNotification() async {
    // Check if user is on trial - trial users get NO notifications at all
    final bool isOnTrial = await _isUserOnTrial();
    if (isOnTrial) {
      debugPrint('NotificationService (scheduleTrialOfferNotification): User is on trial. Skipping notification.');
      return;
    }
    
    // Check if notifications and trial offers are enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    final bool trialOffersEnabled = await isNotificationTypeEnabled(NotificationType.trialOffer);
    
    if (!notificationsEnabled || !trialOffersEnabled) {
      debugPrint('NotificationService: Trial offers notifications disabled. Not scheduling notification.');
      return;
    }
    
    // Check if user is eligible (non-subscribers only)
    final bool isEligible = await _isEligibleForTrialOffers();
    if (!isEligible) {
      debugPrint('NotificationService: User not eligible for trial offers (subscribers excluded). Not scheduling notification.');
      return;
    }
    
    // Check if we should send notification based on 1-2 day interval
    final bool shouldSend = await _shouldSendTrialOffer();
    if (!shouldSend) {
      debugPrint('NotificationService: Trial offer notification sent recently. Not scheduling notification.');
      return;
    }
    
    // Select day-based random title and message
    final title = await _getLocalizedString(_trialOfferTitleKeys[_getDayBasedRandomIndex(_trialOfferTitleKeys)]);
    String body = await _getLocalizedString(_trialOfferMessageKeys[_getDayBasedRandomIndex(_trialOfferMessageKeys)]);
    body = await _maybePrefixWithName(body);
    
    // Create notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
      android: AndroidNotificationDetails(
        trialOfferChannelId,
        'Trial Offers',
        channelDescription: 'Limited time trial offers for new users',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Free Trial',
      ),
    );
    
    // Calculate notification time (next available time slot - could be immediate or scheduled)
    final now = DateTime.now();
    DateTime scheduledDate = now.add(const Duration(minutes: 1)); // Send in 1 minute
    
    // Convert to TZ format
    final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    
    // Schedule the notification
    await _scheduleCapped(
      id: trialOfferId,
      title: title,
      body: body,
      desiredTime: scheduledDate,
      details: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'notification_push_trial',
    );
    
    // Update last sent timestamp
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(lastTrialNotificationKey, now.millisecondsSinceEpoch);
    
    // Track notification scheduling in Mixpanel
    MixpanelService.trackNotificationScheduled(
      'trial_offer',
      scheduledTime: scheduledDate,
      title: title,
    );
    
    debugPrint('NotificationService: Scheduled trial offer notification for ${scheduledDate.toString()}');
  }
  
  // Helper method to check if user is an active trial who cancelled
  Future<bool> _isCancelledTrialUser() async {
    try {
      // Use Purchases to get customer info
      final customerInfo = await Purchases.getCustomerInfo();
      
      // First check if user has any trial product
      bool hasTrialProduct = false;
      
      // Check if any active entitlement is from a trial product
      for (final entitlement in customerInfo.entitlements.active.values) {
        final productId = entitlement.productIdentifier;
        if (productId.toLowerCase().contains('trial')) {
          hasTrialProduct = true;
          break;
        }
      }
      
      // Also check active subscriptions for trial products
      if (!hasTrialProduct) {
        for (final productId in customerInfo.activeSubscriptions) {
          if (productId.toLowerCase().contains('trial')) {
            hasTrialProduct = true;
            break;
          }
        }
      }
      
      // If no trial product, they're not a cancelled trial user
      if (!hasTrialProduct) {
        return false;
      }
      
      // Check if they have active trial but cancelled it
      final activeEntitlements = customerInfo.entitlements.active;
      if (activeEntitlements.isNotEmpty) {
        final entitlement = activeEntitlements.values.first;
        final willRenew = entitlement.willRenew;
        final expirationDate = entitlement.expirationDate;
        
        // Check if trial is still active (not expired)
        bool trialStillActive = true;
        if (expirationDate != null) {
          try {
            final trialExpiration = DateTime.parse(expirationDate);
            final now = DateTime.now();
            trialStillActive = now.isBefore(trialExpiration);
          } catch (e) {
            debugPrint('NotificationService: Error parsing trial expiration date: $e');
          }
        }
        
        // They're a cancelled trial user if: trial is still active AND they cancelled (willRenew = false)
        if (trialStillActive && !willRenew) {
          debugPrint('NotificationService: User has active trial but cancelled (willRenew=false)');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('NotificationService: Error checking cancelled trial user status: $e');
      return false;
    }
  }
  
  // Check if user is eligible for marketing offers
  Future<bool> _isEligibleForMarketingOffers() async {
    try {
      // First check if user is an active trial who cancelled - they should get marketing offers
      final bool isCancelledTrialUser = await _isCancelledTrialUser();
      if (isCancelledTrialUser) {
        debugPrint('NotificationService: User is cancelled trial user, eligible for marketing offers');
        return true;
      }
      
      final bool isSubscribed = await isQualifiedSubscriber();
      
      if (!isSubscribed) {
        // Non-subscribers are eligible
        return true;
      }
      
      // Check subscription type for subscribers
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final UserRepository userRepository = UserRepository();
        final userData = await userRepository.getUserProfile(currentUser.uid);
        final subscriptionProductId = userData?['subscriptionProductId'] ?? '';
        
        // Check if it's monthly or weekly subscription
        final productIdLower = subscriptionProductId.toLowerCase();
        if (productIdLower.contains('monthly') || productIdLower.contains('weekly')) {
          return true;
        }
      }
      
      // Annual subscribers are not eligible
      return false;
    } catch (e) {
      debugPrint('Error checking marketing offer eligibility: $e');
      return false;
    }
  }
  
  // Check if we should send marketing offer based on 2-day interval
  Future<bool> _shouldSendMarketingOffer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSentTimestamp = prefs.getInt(lastMarketingNotificationKey) ?? 0;
      
      if (lastSentTimestamp == 0) {
        // Never sent before, can send
        return true;
      }
      
      final lastSentDate = DateTime.fromMillisecondsSinceEpoch(lastSentTimestamp);
      final daysSinceLastSent = DateTime.now().difference(lastSentDate).inDays;
      
      // Send if it's been 3 or more days
      return daysSinceLastSent >= 3;
    } catch (e) {
      debugPrint('Error checking marketing offer timing: $e');
      return false; // Don't send if we can't determine timing
    }
  }

  // Check if user is eligible for trial offers (non-subscribers only)
  Future<bool> _isEligibleForTrialOffers() async {
    try {
      final bool isSubscribed = await isQualifiedSubscriber();
      
      // Only non-subscribers are eligible for trial offers
      if (isSubscribed) {
        return false;
      }
      
      debugPrint('NotificationService: User is non-subscriber, eligible for trial offers');
      return true;
    } catch (e) {
      debugPrint('Error checking trial offer eligibility: $e');
      return false;
    }
  }
  
  // Check if we should send trial offer based on 1-2 day interval
  Future<bool> _shouldSendTrialOffer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSentTimestamp = prefs.getInt(lastTrialNotificationKey) ?? 0;
      
      if (lastSentTimestamp == 0) {
        // Never sent before, can send
        return true;
      }
      
      final lastSentDate = DateTime.fromMillisecondsSinceEpoch(lastSentTimestamp);
      final daysSinceLastSent = DateTime.now().difference(lastSentDate).inDays;
      
      // Send if it's been 1 or more days (more aggressive than marketing offers)
      return daysSinceLastSent >= 1;
    } catch (e) {
      debugPrint('Error checking trial offer timing: $e');
      return false; // Don't send if we can't determine timing
    }
  }
  
  // Check if user hasn't opened app for 2+ consecutive days
  Future<bool> _hasUserBeenInactiveForTwoDays() async {
    try {
      final AppOpenStreakService streakService = AppOpenStreakService();
      final streakData = streakService.currentStreak;
      
      if (streakData.lastOpenDate == null) {
        // No previous open date recorded, consider them inactive
        return true;
      }
      
      final now = DateTime.now();
      final lastOpen = streakData.lastOpenDate!;
      final daysSinceLastOpen = now.difference(lastOpen).inDays;
      
      debugPrint('NotificationService: Days since last app open: $daysSinceLastOpen');
      
      // Return true if user hasn't opened app for 2 or more days
      return daysSinceLastOpen >= 2;
    } catch (e) {
      debugPrint('NotificationService: Error checking app inactivity: $e');
      return false; // Don't send notification if we can't determine activity
    }
  }
  
  // Check if we should send time-sensitive notification (avoid spam)
  Future<bool> _shouldSendTimeSensitiveNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSentTimestamp = prefs.getInt(lastTimeSensitiveNotificationKey) ?? 0;
      
      if (lastSentTimestamp == 0) {
        // Never sent before, can send
        return true;
      }
      
      final lastSentDate = DateTime.fromMillisecondsSinceEpoch(lastSentTimestamp);
      final daysSinceLastSent = DateTime.now().difference(lastSentDate).inDays;
      
      // Send if it's been 2 or more days since last time-sensitive notification
      return daysSinceLastSent >= 2;
    } catch (e) {
      debugPrint('Error checking time-sensitive notification timing: $e');
      return false; // Don't send if we can't determine timing
    }
  }

  // Send notification for new chat message
  Future<void> sendChatNotification({
    required String senderName,
    required String messageText,
    String? senderUserId,
  }) async {
    // First check if notifications and chat notifications are enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    final bool chatNotificationsEnabled = await isNotificationTypeEnabled(NotificationType.chatNotifications);
    
    if (!notificationsEnabled || !chatNotificationsEnabled) {
      debugPrint('Chat notifications disabled. Not sending notification.');
      return;
    }
    
    // Only for paid subscribers and trial users (active or cancelled)
    final bool isSubscriber = await isQualifiedSubscriber();
    final bool isTrial = await _isUserOnTrial();
    final bool isCancelledTrial = await _isCancelledTrialUser();
    if (!(isSubscriber || isTrial || isCancelledTrial)) {
      debugPrint('Chat: free non-trial user - skip chat notification');
      return;
    }
    
    // Don't send notification if it's from the current user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && senderUserId == currentUser.uid) {
      debugPrint('Not sending notification for own message.');
      return;
    }
    
    // Create notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
      android: AndroidNotificationDetails(
        chatNotificationsChannelId,
        'Chat Notifications',
        channelDescription: 'Notifications about new chat messages',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'New Chat Message',
      ),
    );
    
    // Use a unique ID for chat notifications
    final int notificationId = 300 + _random.nextInt(1000);
    
    // Truncate message if too long
    String displayMessage = messageText.length > 100 
        ? '${messageText.substring(0, 100)}...' 
        : messageText;
    
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      (await _getLocalizedString('notification_chat_message_title_template'))
          .replaceAll('{senderName}', senderName),
      displayMessage,
      notificationDetails,
      payload: 'chat_message_$senderUserId',
    );
    
    // Track notification sent in Mixpanel
    MixpanelService.trackNotificationSent(
      'chat_message',
      title: 'New message from $senderName',
      additionalProps: {
        'sender_name': senderName,
        'message_length': messageText.length,
      },
    );
    
    debugPrint('Sent chat notification for message from: $senderName');
  }

  // Helper: free users who never had a trial
  Future<bool> _isFreeNonTrial() async {
    try {
      debugPrint('start _isFreeNonTrial');
      final bool isSub = await isQualifiedSubscriber();
      final bool isTrial = await _isUserOnTrial();
      final bool isCancelledTrial = await _isCancelledTrialUser();
      debugPrint('end try scope _isFreeNonTrial');
      return !isSub && !isTrial && !isCancelledTrial;
      debugPrint('2 end try scope _isFreeNonTrial');
    } catch (e) {
      debugPrint('NotificationService: error determining free non-trial: $e');
      return false;
    }
  }
  
  // Schedule time-sensitive notification for inactive users
  Future<void> scheduleTimeSensitiveNotification() async {
    // Check if user is on trial - trial users get NO notifications at all
    final bool isOnTrial = await _isUserOnTrial();
    if (isOnTrial) {
      debugPrint('NotificationService (scheduleTimeSensitiveNotification): User is on trial. Skipping notification.');
      return;
    }
    
    // Check if notifications and time-sensitive notifications are enabled
    final bool notificationsEnabled = await areNotificationsEnabled();
    final bool timeSensitiveEnabled = await isNotificationTypeEnabled(NotificationType.timeSensitive);
    
    if (!notificationsEnabled || !timeSensitiveEnabled) {
      debugPrint('NotificationService: Time-sensitive notifications disabled. Not scheduling notification.');
      return;
    }
    
    // Check if user is a qualified subscriber (only subscribers get time-sensitive notifications)
    final bool isSubscribed = await isQualifiedSubscriber();
    if (!isSubscribed) {
      debugPrint('NotificationService: User is not a qualified subscriber. Time-sensitive notifications are for subscribers only.');
      return;
    }
    
    // Check if user has been inactive for 2+ days
    final bool isInactive = await _hasUserBeenInactiveForTwoDays();
    if (!isInactive) {
      debugPrint('NotificationService: User has not been inactive for 2+ days. Not scheduling time-sensitive notification.');
      return;
    }
    
    // Check if we should send notification based on timing (avoid spam)
    final bool shouldSend = await _shouldSendTimeSensitiveNotification();
    if (!shouldSend) {
      debugPrint('NotificationService: Time-sensitive notification sent recently. Not scheduling notification.');
      return;
    }
    
    // Select day-based random title and message
    final title = await _getLocalizedString(_timeSensitiveTitleKeys[_getDayBasedRandomIndex(_timeSensitiveTitleKeys)]);
    final body = await _getLocalizedString(_timeSensitiveMessageKeys[_getDayBasedRandomIndex(_timeSensitiveMessageKeys)]);
    
    // Create notification details with time-sensitive interruption level for iOS
    const NotificationDetails notificationDetails = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
      android: AndroidNotificationDetails(
        timeSensitiveChannelId,
        'Time-Sensitive Reminders',
        channelDescription: 'Important reminders for inactive users',
        importance: Importance.max,
        priority: Priority.max,
        ticker: 'Come Back',
      ),
    );
    
    // Calculate notification time (send immediately when detected)
    final now = DateTime.now();
    DateTime scheduledDate = now.add(const Duration(seconds: 30)); // Send in 30 seconds
    
    // Convert to TZ format
    final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    
    // Schedule the notification
    await _scheduleCapped(
      id: timeSensitiveId,
      title: title,
      body: body,
      desiredTime: scheduledDate,
      details: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'time_sensitive_inactive',
    );
    
    // Update last sent timestamp
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(lastTimeSensitiveNotificationKey, now.millisecondsSinceEpoch);
    
    // Track notification scheduling in Mixpanel
    MixpanelService.trackNotificationScheduled(
      'time_sensitive_inactive',
      scheduledTime: scheduledDate,
      title: title,
      additionalProps: {
        'reason': 'user_inactive_2_days',
        'user_type': 'subscriber',
      },
    );
    
    debugPrint('NotificationService: Scheduled time-sensitive notification for inactive subscriber at ${scheduledDate.toString()}');
  }
  
  // Check and schedule time-sensitive notification if user is inactive
  Future<void> checkAndScheduleTimeSensitiveNotification() async {
    try {
      await scheduleTimeSensitiveNotification();
    } catch (e) {
      debugPrint('NotificationService: Error checking and scheduling time-sensitive notification: $e');
    }
  }
  
  // Get meal reminder time (returns TimeOfDay or null if not set)
  Future<TimeOfDay?> getMealReminderTime(NotificationType mealType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? timeKey;
      
      switch (mealType) {
        case NotificationType.breakfastReminder:
          return null; // removed
        case NotificationType.lunchReminder:
          timeKey = lunchReminderTimeKey;
          break;
        case NotificationType.dinnerReminder:
          timeKey = dinnerReminderTimeKey;
          break;
        default:
          return null;
      }
      
      final timeString = prefs.getString(timeKey);
      if (timeString != null) {
        final timeParts = timeString.split(':');
        if (timeParts.length == 2) {
          final hour = int.tryParse(timeParts[0]);
          final minute = int.tryParse(timeParts[1]);
          if (hour != null && minute != null) {
            return TimeOfDay(hour: hour, minute: minute);
          }
        }
      }
      
      // Return default times if not set
      switch (mealType) {
        case NotificationType.breakfastReminder:
          return null; // removed
        case NotificationType.lunchReminder:
          return const TimeOfDay(hour: 11, minute: 24);
        case NotificationType.dinnerReminder:
          return const TimeOfDay(hour: 18, minute: 41);
        default:
          return null;
      }
    } catch (e) {
      debugPrint('Error getting meal reminder time: $e');
      return null;
    }
  }
  
  // Set meal reminder time
  Future<void> setMealReminderTime(NotificationType mealType, TimeOfDay time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? timeKey;
      
      switch (mealType) {
        case NotificationType.breakfastReminder:
          return;
        case NotificationType.lunchReminder:
          timeKey = lunchReminderTimeKey;
          break;
        case NotificationType.dinnerReminder:
          timeKey = dinnerReminderTimeKey;
          break;
        default:
          return;
      }
      
      final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      await prefs.setString(timeKey, timeString);
      
      // Reschedule the specific meal reminder with new time
      await _scheduleMealReminder(mealType, time);
      
      debugPrint('Set meal reminder time for $mealType: $timeString');
    } catch (e) {
      debugPrint('Error setting meal reminder time: $e');
    }
  }
  
  // Schedule a specific meal reminder
  Future<void> _scheduleMealReminder(NotificationType mealType, TimeOfDay time) async {
    try {
      // Check if notifications and specific meal reminders are enabled
      final bool notificationsEnabled = await areNotificationsEnabled();
      final bool mealReminderEnabled = await isNotificationTypeEnabled(mealType);
      
      if (!notificationsEnabled || !mealReminderEnabled) {
        debugPrint('$mealType notifications disabled. Not scheduling notification.');
        return;
      }
      
      // Check if user is on trial - trial users get NO notifications at all
      final bool isOnTrial = await _isUserOnTrial();
      if (isOnTrial) {
        debugPrint('NotificationService (_scheduleMealReminder): User is on trial. Skipping $mealType notification.');
        return;
      }
      
      // Gate: Only active subscribers should receive lunch/dinner reminders
      // Excludes cancelled trial users and free (trial-expired) users who didn't renew
      final bool isSubscriber = await isQualifiedSubscriber();
      if (!isSubscriber) {
        debugPrint('NotificationService (_scheduleMealReminder): User is not a subscriber. Skipping $mealType notification.');
        return;
      }
      
      String titleKey;
      String bodyKey;
      String channelId;
      int notificationId;
      String payloadType;
      
      switch (mealType) {
        case NotificationType.breakfastReminder:
          return; // removed
        case NotificationType.lunchReminder:
          titleKey = 'notification_lunch_reminder_title';
          bodyKey = 'notification_lunch_reminder_message';
          channelId = lunchReminderChannelId;
          notificationId = lunchReminderId;
          payloadType = 'lunch_reminder';
          break;
        case NotificationType.dinnerReminder:
          titleKey = 'notification_dinner_reminder_title';
          bodyKey = 'notification_dinner_reminder_message';
          channelId = dinnerReminderChannelId;
          notificationId = dinnerReminderId;
          payloadType = 'dinner_reminder';
          break;
        default:
          return;
      }
      
      final title = await _getLocalizedString(titleKey);
      String body = await _getLocalizedString(bodyKey);
      body = await _maybePrefixWithName(body);
      
      // Create notification details
      NotificationDetails notificationDetails = NotificationDetails(
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
        android: AndroidNotificationDetails(
          channelId,
          mealType == NotificationType.lunchReminder
              ? 'Lunch Reminders'
              : 'Dinner Reminders',
          channelDescription: mealType == NotificationType.lunchReminder
              ? 'Reminders to track your lunch'
              : 'Reminders to track your dinner',
          importance: Importance.high,
          priority: Priority.high,
          ticker: mealType == NotificationType.lunchReminder
              ? 'Lunch Time'
              : 'Dinner Time',
        ),
      );
      
      // Calculate next notification time
      final now = DateTime.now();
      DateTime scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      
      // If the scheduled time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      
      // Convert to TZ format
      final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      
      // Cancel existing notification for this meal type first
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      
      // Schedule the notification
      await _scheduleCapped(
        id: notificationId,
        title: title,
        body: body,
        desiredTime: scheduledDate,
        details: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payloadType,
      );
      
      // Track notification scheduling in Mixpanel
      MixpanelService.trackNotificationScheduled(
        payloadType,
        scheduledTime: scheduledDate,
        title: title,
      );
      
      debugPrint('NotificationService: Scheduled $mealType notification for ${scheduledDate.toString()}');
    } catch (e) {
      debugPrint('NotificationService: Error scheduling $mealType reminder: $e');
    }
  }
  
  // Schedule all enabled meal reminders
  Future<void> scheduleAllMealReminders() async {
    try {
      // Breakfast removed
      
      // Schedule lunch reminder
      if (await isNotificationTypeEnabled(NotificationType.lunchReminder)) {
        final lunchTime = await getMealReminderTime(NotificationType.lunchReminder);
        if (lunchTime != null) {
          await _scheduleMealReminder(NotificationType.lunchReminder, lunchTime);
        }
      }
      
      // Schedule dinner reminder
      if (await isNotificationTypeEnabled(NotificationType.dinnerReminder)) {
        final dinnerTime = await getMealReminderTime(NotificationType.dinnerReminder);
        if (dinnerTime != null) {
          await _scheduleMealReminder(NotificationType.dinnerReminder, dinnerTime);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error scheduling all meal reminders: $e');
    }
  }

  // Get motivation reminder time (morning motivation UI-configurable)
  Future<TimeOfDay?> getMotivationReminderTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(motivationReminderTimeKey);
      if (v != null) {
        final parts = v.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
        }
      }
      return const TimeOfDay(hour: 8, minute: 42);
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 42);
    }
  }

  Future<void> setMotivationReminderTime(TimeOfDay t) async {
    final prefs = await SharedPreferences.getInstance();
    final s = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await prefs.setString(motivationReminderTimeKey, s);
    // Reschedule morning motivation using chosen time for subscribers
    final isSub = await isQualifiedSubscriber();
    final audience = isSub ? NotificationAudienceType.subscriber : NotificationAudienceType.nonSubscriber;
    await scheduleDailyMeditationReminder(hour: t.hour, minute: t.minute, audienceType: audience);
  }

  // Get pledge reminder time (checkup category) UI-configurable
  Future<TimeOfDay?> getPledgeReminderTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(pledgeReminderTimeKey);
      if (v != null) {
        final parts = v.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
        }
      }
      return const TimeOfDay(hour: 19, minute: 23);
    } catch (_) {
      return const TimeOfDay(hour: 19, minute: 23);
    }
  }

  Future<void> setPledgeReminderTime(TimeOfDay t) async {
    final prefs = await SharedPreferences.getInstance();
    final s = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await prefs.setString(pledgeReminderTimeKey, s);
    final isSub = await isQualifiedSubscriber();
    final audience = isSub ? NotificationAudienceType.subscriber : NotificationAudienceType.nonSubscriber;
    await scheduleCheckupReminder(hour: t.hour, minute: t.minute, audienceType: audience);
  }

  Future<String> _getNotificationDayWord(int days) async {
    if (days == 1) {
      return await _getLocalizedString('notification_day_singular');
    } else if (days >= 2 && days <= 4) {
      // Check if Czech locale
      final locale = await _getCurrentLocale();
      if (locale == 'cs') {
        return await _getLocalizedString('notification_day_few');
      }
    }
    return await _getLocalizedString('notification_day_plural');
  }

  // Single source of truth for app language preference
  Future<String> _getAppLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    // Prefer 'languageCode'; fall back to 'selected_language'; default to 'en'
    final code = prefs.getString('languageCode') ??
        prefs.getString('selected_language') ?? 'en';
    return code;
  }

  Future<String> _getCurrentLocale() async {
    return _getAppLanguageCode();
  }
} 