import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/user_repository.dart';
import 'package:intl/intl.dart';

class AppOpenStreakService {
  // Singleton pattern
  static final AppOpenStreakService _instance = AppOpenStreakService._internal();
  
  factory AppOpenStreakService() {
    return _instance;
  }
  
  AppOpenStreakService._internal();
  
  // Keys for shared preferences
  static const String _appOpenStreakCountKey = 'app_open_streak_count';
  static const String _lastAppOpenDateKey = 'last_app_open_date';
  static const String _appOpenStreakStartDateKey = 'app_open_streak_start_date';
  static const String _weeklyAppOpensKey = 'weekly_app_opens';
  
  // Firebase and User Repository instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();
  
  // Stream controller for streak updates
  final StreamController<AppOpenStreakData> _streakController = StreamController<AppOpenStreakData>.broadcast();
  
  // Stream of streak data that widgets can listen to
  Stream<AppOpenStreakData> get streakStream => _streakController.stream;
  
  // Current streak data
  AppOpenStreakData _currentStreak = const AppOpenStreakData(
    consecutiveDays: 0,
    lastOpenDate: null,
    streakStartDate: null,
    weeklyOpens: {},
  );
  
  // Get the current streak data without subscribing to updates
  AppOpenStreakData get currentStreak => _currentStreak;
  
  // Initialize the app open streak service
  Future<void> initialize() async {
    await _loadAppOpenStreak();
  }
  
  // Load app open streak data from shared preferences
  Future<void> _loadAppOpenStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final streakCount = prefs.getInt(_appOpenStreakCountKey) ?? 0;
    final lastOpenDateStr = prefs.getString(_lastAppOpenDateKey);
    final streakStartDateStr = prefs.getString(_appOpenStreakStartDateKey);
    final weeklyOpensStr = prefs.getString(_weeklyAppOpensKey);
    
    DateTime? lastOpenDate;
    DateTime? streakStartDate;
    Map<int, bool> weeklyOpens = {};
    
    if (lastOpenDateStr != null) {
      lastOpenDate = DateTime.tryParse(lastOpenDateStr);
    }
    
    if (streakStartDateStr != null) {
      streakStartDate = DateTime.tryParse(streakStartDateStr);
    }
    
    // Load weekly opens data
    if (weeklyOpensStr != null) {
      final List<String> opens = weeklyOpensStr.split(',');
      for (String openDate in opens) {
        final date = DateTime.tryParse(openDate);
        if (date != null && _isInCurrentWeek(date)) {
          weeklyOpens[date.weekday] = true;
        }
      }
    }
    
    _currentStreak = AppOpenStreakData(
      consecutiveDays: streakCount,
      lastOpenDate: lastOpenDate,
      streakStartDate: streakStartDate,
      weeklyOpens: weeklyOpens,
    );
    
    // Notify listeners of the loaded streak
    _streakController.add(_currentStreak);
  }
  
  // Helper method to check if a date is in the current week (Monday to Sunday)
  bool _isInCurrentWeek(DateTime date) {
    final now = DateTime.now();
    // Start of week is Monday (weekday 1)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOnly = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
    
    debugPrint('Checking if $dateOnly is in current week: $startOnly to $endOnly');
    return !dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly);
  }
  
  // Record app open and update streak
  Future<void> recordAppOpen() async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final prefs = await SharedPreferences.getInstance();
    
    final lastOpenDateStr = prefs.getString(_lastAppOpenDateKey);
    
    // If this is the first open today
    if (lastOpenDateStr == null || lastOpenDateStr != today) {
      DateTime? lastOpenDate;
      if (lastOpenDateStr != null) {
        lastOpenDate = DateTime.tryParse(lastOpenDateStr);
      }
      
      int newStreakCount = 1;
      DateTime? newStreakStartDate = now;
      
      if (lastOpenDate != null) {
        final daysDifference = now.difference(lastOpenDate).inDays;
        
        if (daysDifference == 1) {
          // Consecutive day - increment streak
          newStreakCount = (_currentStreak.consecutiveDays + 1);
          newStreakStartDate = _currentStreak.streakStartDate ?? now;
        } else if (daysDifference > 1) {
          // Streak broken - reset to 1
          newStreakCount = 1;
          newStreakStartDate = now;
        } else {
          // Same day - don't update
          return;
        }
      }
      
      // Update weekly opens
      final weeklyOpensStr = prefs.getString(_weeklyAppOpensKey) ?? '';
      List<String> weeklyOpensList = weeklyOpensStr.isEmpty ? [] : weeklyOpensStr.split(',');
      
      // Clean old dates (not in current week)
      weeklyOpensList = weeklyOpensList.where((dateStr) {
        final date = DateTime.tryParse(dateStr);
        return date != null && _isInCurrentWeek(date);
      }).toList();
      
      // Add today if not already there
      if (!weeklyOpensList.contains(now.toIso8601String().split('T')[0])) {
        weeklyOpensList.add(now.toIso8601String().split('T')[0]);
      }
      
      // Build weekly opens map
      Map<int, bool> weeklyOpens = {};
      for (String openDate in weeklyOpensList) {
        final date = DateTime.tryParse(openDate);
        if (date != null) {
          weeklyOpens[date.weekday] = true;
        }
      }
      
      // Save to SharedPreferences
      await prefs.setInt(_appOpenStreakCountKey, newStreakCount);
      await prefs.setString(_lastAppOpenDateKey, today);
      await prefs.setString(_appOpenStreakStartDateKey, newStreakStartDate?.toIso8601String() ?? now.toIso8601String());
      await prefs.setString(_weeklyAppOpensKey, weeklyOpensList.join(','));
      
      // Update current streak
      _currentStreak = AppOpenStreakData(
        consecutiveDays: newStreakCount,
        lastOpenDate: now,
        streakStartDate: newStreakStartDate ?? now,
        weeklyOpens: weeklyOpens,
      );
      
      // Notify listeners
      _streakController.add(_currentStreak);
      
      // Update Firestore
      await _updateStreakInFirestore();
      
      debugPrint('App open streak updated: $newStreakCount days');
      debugPrint('Weekly opens: ${weeklyOpens.keys.toList()}');
    }
  }
  
  // Update streak data in Firestore
  Future<void> _updateStreakInFirestore() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('User not logged in, skipping Firestore app open streak update.');
      return;
    }
    
    await _userRepository.updateAppOpenStreakData(
      user.uid,
      _currentStreak.consecutiveDays,
      _currentStreak.streakStartDate,
      _currentStreak.lastOpenDate,
    );
  }
  
  // Reset streak (if needed for testing or manual reset)
  Future<void> resetStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appOpenStreakCountKey);
    await prefs.remove(_lastAppOpenDateKey);
    await prefs.remove(_appOpenStreakStartDateKey);
    await prefs.remove(_weeklyAppOpensKey);
    
    _currentStreak = const AppOpenStreakData(
      consecutiveDays: 0,
      lastOpenDate: null,
      streakStartDate: null,
      weeklyOpens: {},
    );
    
    // Notify listeners
    _streakController.add(_currentStreak);
    
    // Update Firestore
    await _updateStreakInFirestore();
    
    debugPrint('App open streak reset');
  }
  
  // Dispose resources
  void dispose() {
    _streakController.close();
  }
}

// Immutable class to hold app open streak data
@immutable
class AppOpenStreakData {
  final int consecutiveDays;
  final DateTime? lastOpenDate;
  final DateTime? streakStartDate;
  final Map<int, bool> weeklyOpens; // Map of weekday (1-7) to whether app was opened
  
  const AppOpenStreakData({
    required this.consecutiveDays,
    required this.lastOpenDate,
    required this.streakStartDate,
    this.weeklyOpens = const {},
  });
  
  // Create a copy with updated values
  AppOpenStreakData copyWith({
    int? consecutiveDays,
    DateTime? lastOpenDate,
    DateTime? streakStartDate,
    Map<int, bool>? weeklyOpens,
  }) {
    return AppOpenStreakData(
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      lastOpenDate: lastOpenDate ?? this.lastOpenDate,
      streakStartDate: streakStartDate ?? this.streakStartDate,
      weeklyOpens: weeklyOpens ?? this.weeklyOpens,
    );
  }
} 