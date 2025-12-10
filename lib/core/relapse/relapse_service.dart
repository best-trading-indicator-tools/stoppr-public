import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class RelapseService {
  // Singleton pattern
  static final RelapseService _instance = RelapseService._internal();
  
  factory RelapseService() {
    return _instance;
  }
  
  RelapseService._internal();
  
  // Keys for shared preferences
  static const String _relapsesListKey = 'relapses_list';
  
  // Stream controller for relapse updates
  final StreamController<List<DateTime>> _relapseController = StreamController<List<DateTime>>.broadcast();
  
  // Stream of relapse data that widgets can listen to
  Stream<List<DateTime>> get relapseStream => _relapseController.stream;
  
  // Get all relapses
  Future<List<DateTime>> getAllRelapses() async {
    final relapses = await _loadRelapsesFromStorage();
    return relapses;
  }
  
  // Log a new relapse
  Future<void> logRelapse([DateTime? relapseTime]) async {
    final prefs = await SharedPreferences.getInstance();
    final relapseDateTime = relapseTime ?? DateTime.now();
    
    // Load existing relapses
    List<DateTime> relapses = await _loadRelapsesFromStorage();
    
    // Add the new relapse
    relapses.add(relapseDateTime);
    
    // Sort by most recent first
    relapses.sort((a, b) => b.compareTo(a));
    
    // Save the updated list
    await _saveRelapsesToStorage(relapses);
    
    // Notify listeners
    _relapseController.add(relapses);
    
    debugPrint('✅ Logged relapse at: ${relapseDateTime.toString()}');
  }
  
  // Get relapses for today
  Future<List<DateTime>> getTodayRelapses() async {
    final allRelapses = await _loadRelapsesFromStorage();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    return allRelapses.where((relapse) => 
      relapse.isAfter(startOfDay) && relapse.isBefore(endOfDay)
    ).toList();
  }
  
  // Get relapses for this week
  Future<List<DateTime>> getThisWeekRelapses() async {
    final allRelapses = await _loadRelapsesFromStorage();
    final now = DateTime.now();
    
    // Calculate first day of week (Sunday)
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final startOfWeek = DateTime(firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day);
    
    // Calculate last day of week (Saturday)
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    
    return allRelapses.where((relapse) => 
      relapse.isAfter(startOfWeek) && relapse.isBefore(endOfWeek)
    ).toList();
  }
  
  // Get relapses for this month
  Future<List<DateTime>> getThisMonthRelapses() async {
    final allRelapses = await _loadRelapsesFromStorage();
    final now = DateTime.now();
    
    // Calculate first and last day of month
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    
    return allRelapses.where((relapse) => 
      relapse.isAfter(startOfMonth) && relapse.isBefore(endOfMonth)
    ).toList();
  }
  
  // Get relapse counts by hour of day for the current time period
  Future<Map<int, int>> getRelapsesByHourOfDay(TimePeriod period) async {
    List<DateTime> relapses;
    
    switch (period) {
      case TimePeriod.today:
        relapses = await getTodayRelapses();
        break;
      case TimePeriod.week:
        relapses = await getThisWeekRelapses();
        break;
      case TimePeriod.month:
        relapses = await getThisMonthRelapses();
        break;
    }
    
    // Count relapses by hour
    final Map<int, int> hourCounts = {};
    
    // Initialize all hours to 0
    for (int i = 0; i < 24; i++) {
      hourCounts[i] = 0;
    }
    
    // Count relapses for each hour
    for (final relapse in relapses) {
      final hour = relapse.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }
    
    return hourCounts;
  }
  
  // Get relapse counts by day of week (0 = Monday, 6 = Sunday)
  Future<Map<int, int>> getRelapsesByDayOfWeek() async {
    final relapses = await getThisWeekRelapses();
    
    // Count relapses by day of week
    final Map<int, int> dayCounts = {};
    
    // Initialize all days to 0 (0 = Monday, 6 = Sunday)
    for (int i = 0; i < 7; i++) {
      dayCounts[i] = 0;
    }
    
    // Count relapses for each day
    for (final relapse in relapses) {
      // Convert from ISO weekday (1-7, Monday-Sunday) to 0-6 index
      final weekday = relapse.weekday - 1;
      dayCounts[weekday] = (dayCounts[weekday] ?? 0) + 1;
    }
    
    return dayCounts;
  }
  
  // Get relapse counts by month (0 = January, 11 = December)
  Future<Map<int, int>> getRelapsesByMonth() async {
    final now = DateTime.now();
    final allRelapses = await _loadRelapsesFromStorage();
    
    // Get relapses from the last 12 months
    final startOfPeriod = DateTime(now.year - 1, now.month, 1);
    final relapses = allRelapses.where((relapse) => 
      relapse.isAfter(startOfPeriod)
    ).toList();
    
    // Count relapses by month
    final Map<int, int> monthCounts = {};
    
    // Initialize all months to 0
    for (int i = 0; i < 12; i++) {
      monthCounts[i] = 0;
    }
    
    // Count relapses for each month
    for (final relapse in relapses) {
      final month = relapse.month - 1; // Convert 1-12 to 0-11
      monthCounts[month] = (monthCounts[month] ?? 0) + 1;
    }
    
    return monthCounts;
  }
  
  // Get chart data based on the selected time period
  Future<Map<int, int>> getChartDataForPeriod(TimePeriod period) async {
    switch (period) {
      case TimePeriod.today:
        return getRelapsesByHourOfDay(period);
      case TimePeriod.week:
        return getRelapsesByDayOfWeek();
      case TimePeriod.month:
        return getRelapsesByMonth();
    }
  }
  
  // Load relapses from shared preferences
  Future<List<DateTime>> _loadRelapsesFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final relapseStrings = prefs.getStringList(_relapsesListKey) ?? [];
    
    return relapseStrings.map((dateString) {
      return DateTime.parse(dateString);
    }).toList();
  }
  
  // Save relapses to shared preferences
  Future<void> _saveRelapsesToStorage(List<DateTime> relapses) async {
    final prefs = await SharedPreferences.getInstance();
    final relapseStrings = relapses.map((date) => date.toIso8601String()).toList();
    
    await prefs.setStringList(_relapsesListKey, relapseStrings);
  }
  
  // Clear all relapses (for testing or reset)
  Future<void> clearAllRelapses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_relapsesListKey);
    
    // Notify listeners
    _relapseController.add([]);
    
    debugPrint('✅ Cleared all relapses');
  }
  
  // Dispose resources
  void dispose() {
    _relapseController.close();
  }
}

// Enum for time periods
enum TimePeriod {
  today,
  week,
  month
} 