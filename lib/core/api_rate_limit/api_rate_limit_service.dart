import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

/// Service to manage API rate limiting
class ApiRateLimitService {
  static const String _apiRequestsCountKey = 'api_requests_count';
  static const String _apiRequestsDateKey = 'api_requests_date';
  static const int _maxRequestsPerDay = 20; // Daily limit per user

  /// Check if the user has exceeded their daily API request limit
  /// Returns true if the user can make more requests, false if limit reached
  static Future<bool> canMakeRequest() async {
    // Bypass limit for debug mode
    if (kDebugMode) {
      return true;
    }
    
    // Bypass limit for TestFlight and test environment users
    final bool isTestEnv = await MixpanelService.isTestEnvironment();
    if (isTestEnv) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
    final String? lastDate = prefs.getString(_apiRequestsDateKey);
    final int count = prefs.getInt(_apiRequestsCountKey) ?? 0;

    // Reset counter if it's a new day
    if (lastDate != today) {
      await prefs.setString(_apiRequestsDateKey, today);
      await prefs.setInt(_apiRequestsCountKey, 0);
      return true;
    }

    // Check if user has reached the limit
    return count < _maxRequestsPerDay;
  }

  /// Increment the API request counter
  /// Returns true if counter was successfully incremented, false if limit reached
  static Future<bool> incrementRequestCount() async {
    // First check if user can make a request
    final canMake = await canMakeRequest();
    if (!canMake) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().split('T')[0];
    final int currentCount = prefs.getInt(_apiRequestsCountKey) ?? 0;
    
    // Save the new count and date
    await prefs.setString(_apiRequestsDateKey, today);
    await prefs.setInt(_apiRequestsCountKey, currentCount + 1);
    
    return true;
  }

  /// Get the remaining number of API requests for today
  static Future<int> getRemainingRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String? lastDate = prefs.getString(_apiRequestsDateKey);
    
    // If it's a new day, reset the counter
    if (lastDate != today) {
      await prefs.setString(_apiRequestsDateKey, today);
      await prefs.setInt(_apiRequestsCountKey, 0);
      return _maxRequestsPerDay;
    }
    
    final int usedCount = prefs.getInt(_apiRequestsCountKey) ?? 0;
    return _maxRequestsPerDay - usedCount;
  }

  /// Get the current count of API requests for today
  static Future<int> getCurrentCount() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String? lastDate = prefs.getString(_apiRequestsDateKey);
    
    // If it's a new day, reset the counter
    if (lastDate != today) {
      await prefs.setString(_apiRequestsDateKey, today);
      await prefs.setInt(_apiRequestsCountKey, 0);
      return 0;
    }
    
    return prefs.getInt(_apiRequestsCountKey) ?? 0;
  }

  /// Reset the API request counter
  static Future<void> resetCounter() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString(_apiRequestsDateKey, today);
    await prefs.setInt(_apiRequestsCountKey, 0);
  }
} 