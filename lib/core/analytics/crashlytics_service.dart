import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service for handling Firebase Crashlytics error reporting
class CrashlyticsService {
  // Singleton instance
  static final CrashlyticsService _instance = CrashlyticsService._internal();
  factory CrashlyticsService() => _instance;
  
  // Private constructor
  CrashlyticsService._internal();
  
  /// Log a non-fatal exception to Crashlytics
  static void logException(dynamic exception, StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    if (kDebugMode) {
      // In debug mode, just print to console
      debugPrint('Exception: $exception');
      if (reason != null) debugPrint('Reason: $reason');
      if (stack != null) debugPrint('Stack trace: $stack');
      return;
    }
    
    try {
      FirebaseCrashlytics.instance.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('Failed to log exception to Crashlytics: $e');
    }
  }
  
  /// Log a custom key-value pair to Crashlytics
  static void setCustomKey(String key, dynamic value) {
    if (kDebugMode) {
      // In debug mode, just print to console
      debugPrint('Crashlytics custom key: $key = $value');
      return;
    }
    
    try {
      if (value is String) {
        FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else if (value is bool) {
        FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else if (value is int) {
        FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else if (value is double) {
        FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else {
        FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
      }
    } catch (e) {
      debugPrint('Failed to set custom key in Crashlytics: $e');
    }
  }
  
  /// Log a message to Crashlytics
  static void log(String message) {
    if (kDebugMode) {
      // In debug mode, just print to console
      debugPrint('Crashlytics log: $message');
      return;
    }
    
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      debugPrint('Failed to log message to Crashlytics: $e');
    }
  }
  
  /// Set user identifier in Crashlytics
  static void setUserIdentifier(String userId) {
    if (kDebugMode) {
      // In debug mode, just print to console
      debugPrint('Crashlytics user ID: $userId');
      return;
    }
    
    try {
      FirebaseCrashlytics.instance.setUserIdentifier(userId);
    } catch (e) {
      debugPrint('Failed to set user identifier in Crashlytics: $e');
    }
  }
  
  /// Force a test crash (only for testing Crashlytics)
  static void crash() {
    FirebaseCrashlytics.instance.crash();
  }
} 