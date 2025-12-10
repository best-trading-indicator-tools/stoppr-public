import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../analytics/mixpanel_service.dart';

// Summary: Ensure the challenge day progresses for existing users.
// We now derive and persist `challenge_current_day` from the number of
// completed days in SharedPreferences. This fixes cases where the day did
// not advance due to older app versions storing an out-of-date value.

class ChallengeService {
  // Shared Preferences keys
  static const String _challengeStartedKey = 'challenge_started';
  static const String _challengeCurrentDayKey = 'challenge_current_day';
  static const String _challengeDayStatusKey = 'challenge_day_status';
  static const String _challengeStartDateKey = 'challenge_start_date';
  static const String _challengeTasksCompletedKey = 'challenge_tasks_completed';
  static const String _challengeTaskTypeKey = 'challenge_task_type';

  // Task types
  static const String taskTypeJournal = 'journal';
  static const String taskTypeBreathing = 'breathing';
  static const String taskTypePledge = 'pledge';
  static const String taskTypeMeditation = 'meditation';
  static const String taskTypePodcast = 'podcast';
  static const String taskTypeArticles = 'articles';
  static const String taskTypeFoodScan = 'food_scan';
  static const String taskTypeRateMyPlate = 'rate_my_plate';
  static const String taskTypeChatbot = 'chatbot';
  static const String taskTypeCommunityPost = 'community_post';
  static const String taskTypeSelfReflection = 'self_reflection';
  
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Random task distribution map
  static const List<String> allTaskTypes = [
    taskTypeJournal,
    taskTypeBreathing,
    taskTypePledge,
    taskTypeMeditation,
    taskTypePodcast,
    taskTypeArticles,
    taskTypeFoodScan,
    taskTypeRateMyPlate,
    taskTypeChatbot,
    taskTypeCommunityPost,
    taskTypeSelfReflection,
  ];

  // Challenge data model
  Future<Map<String, dynamic>> getChallengeData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final bool started = prefs.getBool(_challengeStartedKey) ?? false;
    int currentDay = prefs.getInt(_challengeCurrentDayKey) ?? 0;
    final List<String> dayStatusListJson = prefs.getStringList(_challengeDayStatusKey) ?? [];
    final int? startDateTimestamp = prefs.getInt(_challengeStartDateKey);
    final String? tasksCompletedJson = prefs.getString(_challengeTasksCompletedKey);
    
    // Parse day status list
    List<bool> dayStatusList = [];
    if (dayStatusListJson.isNotEmpty) {
      dayStatusList = dayStatusListJson.map((e) => e == 'true').toList();
    } else {
      dayStatusList = List.generate(28, (_) => false);
    }
    
    // Parse tasks completed record (must be before we use it below)
    Map<String, dynamic> tasksCompleted = {};
    if (tasksCompletedJson != null) {
      tasksCompleted = jsonDecode(tasksCompletedJson);
    }

    // Backward-compatible fix: if user has completed N days but
    // `challenge_current_day` is behind, advance and persist it.
    // ALSO: Check if it's a new calendar day since last completion
    // to advance to the next challenge day.
    if (started) {
      final int completedDays = dayStatusList.where((e) => e).length;
      
      // Check if current day's task is complete
      final bool currentDayComplete = currentDay > 0 && currentDay <= 28 
          ? dayStatusList[currentDay - 1] 
          : false;
      
      // If current day is complete, check if we should advance to next day
      if (currentDayComplete && currentDay < 28) {
        // Get last completion timestamp
        final lastCompletionTimestamp = tasksCompleted[currentDay.toString()] as int?;
        if (lastCompletionTimestamp != null) {
          final lastCompletionDate = DateTime.fromMillisecondsSinceEpoch(lastCompletionTimestamp);
          final now = DateTime.now();
          
          // Check if it's a new calendar day (compare dates, not time)
          final lastDate = DateTime(lastCompletionDate.year, lastCompletionDate.month, lastCompletionDate.day);
          final today = DateTime(now.year, now.month, now.day);
          
          // If at least one day has passed, advance to next day
          if (today.isAfter(lastDate)) {
            currentDay = currentDay + 1;
            await prefs.setInt(_challengeCurrentDayKey, currentDay);
          }
        }
      } else {
        // Fallback for older users who might have wrong current day
        final int derivedCurrentDay = completedDays >= 28 ? 28 : (completedDays + 1);
        if (derivedCurrentDay > currentDay) {
          currentDay = derivedCurrentDay;
          await prefs.setInt(_challengeCurrentDayKey, currentDay);
        }
      }
    }
    
    // Calculate start date
    DateTime? startDate;
    if (startDateTimestamp != null) {
      startDate = DateTime.fromMillisecondsSinceEpoch(startDateTimestamp);
    }
    
    return {
      'started': started,
      'currentDay': currentDay,
      'dayStatusList': dayStatusList,
      'startDate': startDate,
      'tasksCompleted': tasksCompleted,
    };
  }
  
  // Start or restart the challenge
  Future<void> startChallenge() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Initialize challenge data
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final dayStatusList = List.generate(28, (_) => false);
    final Map<String, dynamic> tasksCompleted = {};
    
    // Distribute tasks randomly across 28 days
    final Map<String, String> taskTypes = _generateRandomTaskDistribution();
    
    // Save challenge data to SharedPreferences
    await prefs.setBool(_challengeStartedKey, true);
    await prefs.setInt(_challengeCurrentDayKey, 1);
    await prefs.setStringList(_challengeDayStatusKey, dayStatusList.map((e) => e.toString()).toList());
    await prefs.setInt(_challengeStartDateKey, timestamp);
    await prefs.setString(_challengeTasksCompletedKey, jsonEncode(tasksCompleted));
    await prefs.setString(_challengeTaskTypeKey, jsonEncode(taskTypes));
    
    // Save to Firebase
    await _saveStartChallengeToFirebase(timestamp);
    
    // Log Mixpanel Event
    MixpanelService.trackEvent('Challenge Started', properties: {
      'start_timestamp': timestamp,
    });
  }
  
  // Save challenge start to Firebase
  Future<void> _saveStartChallengeToFirebase(int startTimestamp) async {
    // Only save to Firebase if the user is logged in
    if (_auth.currentUser == null) {
      debugPrint('⚠️ Not saving challenge start to Firebase: User not logged in');
      return;
    }
    
    final uid = _auth.currentUser!.uid;
    final challengeId = startTimestamp.toString();
    
    try {
      // Prepare the challenge data
      final challengeData = {
        'uid': uid,
        'challengeId': challengeId,
        'startTimestamp': startTimestamp,
        'startDate': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(startTimestamp)),
        'currentDay': 1,
        'status': 'in_progress',
        'completedTasks': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Save to the user's challenges collection
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('challenges')
          .doc(challengeId)
          .set(challengeData, SetOptions(merge: true));
      
      // Update user document with challenge info
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'currentChallengeId': challengeId,
            'currentChallengeStartDate': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(startTimestamp)),
            'currentChallengeDay': 1,
            'hasActiveChallenge': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      debugPrint('✅ Saved challenge start to Firebase: $challengeId');
    } catch (e) {
      debugPrint('❌ Error saving challenge start to Firebase: $e');
    }
  }
  
  // Mark a task as complete for the current day
  Future<void> completeTask(int day) async {
    if (day <= 0 || day > 28) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Get current day status list
    final List<String> dayStatusListJson = prefs.getStringList(_challengeDayStatusKey) ?? [];
    List<bool> dayStatusList = [];
    
    if (dayStatusListJson.isNotEmpty) {
      dayStatusList = dayStatusListJson.map((e) => e == 'true').toList();
    } else {
      dayStatusList = List.generate(28, (_) => false);
    }
    
    // Update day status
    dayStatusList[day - 1] = true;
    
    // Get tasks completed record
    String? tasksCompletedJson = prefs.getString(_challengeTasksCompletedKey);
    Map<String, dynamic> tasksCompleted = {};
    
    if (tasksCompletedJson != null) {
      tasksCompleted = jsonDecode(tasksCompletedJson);
    }
    
    // Get challenge start timestamp
    final startTimestamp = prefs.getInt(_challengeStartDateKey);
    
    // Record completion timestamp
    final now = DateTime.now();
    final completionTimestamp = now.millisecondsSinceEpoch;
    tasksCompleted[day.toString()] = completionTimestamp;
    
    // Get task type for this day
    final taskType = await getTaskTypeForDay(day);
    
    // Save updated data to SharedPreferences
    await prefs.setStringList(_challengeDayStatusKey, dayStatusList.map((e) => e.toString()).toList());
    await prefs.setString(_challengeTasksCompletedKey, jsonEncode(tasksCompleted));
    // Note: We no longer advance the day here. The day will only advance
    // when the user returns on a new calendar day (checked in getChallengeData).
    
    // Save completion to Firebase
    if (startTimestamp != null) {
      await _saveTaskCompletionToFirebase(
        day: day,
        startTimestamp: startTimestamp,
        completionTimestamp: completionTimestamp,
        taskType: taskType,
      );
    }
    
    // Log Mixpanel Event
    MixpanelService.trackEvent('Challenge Task Completed', properties: {
      'day': day,
      'task_type': taskType,
      'challenge_start_timestamp': startTimestamp,
    });
    
    // Check if challenge is complete (all 28 days)
    if (day == 28) {
      await _markChallengeCompleteInFirebase(startTimestamp);
    }
  }
  
  // Save task completion to Firebase
  Future<void> _saveTaskCompletionToFirebase({
    required int day,
    required int startTimestamp,
    required int completionTimestamp,
    required String taskType,
  }) async {
    // Only save to Firebase if the user is logged in
    if (_auth.currentUser == null) {
      debugPrint('⚠️ Not saving task completion to Firebase: User not logged in');
      return;
    }
    
    final uid = _auth.currentUser!.uid;
    final challengeId = startTimestamp.toString();
    final taskId = '$challengeId-day$day';
    
    try {
      // Prepare the task completion data
      final taskData = {
        'uid': uid,
        'challengeId': challengeId,
        'taskId': taskId,
        'day': day,
        'taskType': taskType,
        'completionTimestamp': completionTimestamp,
        'completionDate': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(completionTimestamp)),
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Save to the user's challenge tasks subcollection
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('challenges')
          .doc(challengeId)
          .collection('tasks')
          .doc(taskId)
          .set(taskData, SetOptions(merge: true));
      
      // Update the challenge document with the completed task
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('challenges')
          .doc(challengeId)
          .update({
            'currentDay': day,
            'lastCompletedDay': day,
            'lastCompletedDate': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(completionTimestamp)),
            'completedTasks': FieldValue.arrayUnion([day]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // Update user document with current challenge day
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'currentChallengeDay': day,
            'lastChallengeActivity': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(completionTimestamp)),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      debugPrint('✅ Saved task completion to Firebase: Day $day, Type: $taskType');
    } catch (e) {
      debugPrint('❌ Error saving task completion to Firebase: $e');
    }
  }
  
  // Mark challenge as complete in Firebase
  Future<void> _markChallengeCompleteInFirebase(int? startTimestamp) async {
    if (startTimestamp == null) return;
    
    // Only update Firebase if the user is logged in
    if (_auth.currentUser == null) {
      debugPrint('⚠️ Not updating challenge completion in Firebase: User not logged in');
      return;
    }
    
    final uid = _auth.currentUser!.uid;
    final challengeId = startTimestamp.toString();
    
    try {
      // Update the challenge document
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('challenges')
          .doc(challengeId)
          .update({
            'status': 'completed',
            'completionDate': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // Update user document
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'hasActiveChallenge': false,
            'completedChallenges': FieldValue.increment(1),
            'lastCompletedChallengeDate': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      debugPrint('✅ Marked challenge as complete in Firebase: $challengeId');
      
      // Log Mixpanel Event
      MixpanelService.trackEvent('Challenge Completed', properties: {
         'challenge_id': challengeId,
         'start_timestamp': startTimestamp,
      });
      
    } catch (e) {
      debugPrint('❌ Error marking challenge as complete in Firebase: $e');
    }
  }
  
  // Reset challenge to day 1
  Future<void> resetChallenge() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get previous challenge data for Firebase
    final previousStartTimestamp = prefs.getInt(_challengeStartDateKey);
    
    // Reset to day 1
    final now = DateTime.now();
    final newTimestamp = now.millisecondsSinceEpoch;
    final dayStatusList = List.generate(28, (_) => false);
    final Map<String, dynamic> tasksCompleted = {};
    
    // Distribute tasks randomly across 28 days
    final Map<String, String> taskTypes = _generateRandomTaskDistribution();
    
    // Save reset data to SharedPreferences
    await prefs.setBool(_challengeStartedKey, true);
    await prefs.setInt(_challengeCurrentDayKey, 1);
    await prefs.setStringList(_challengeDayStatusKey, dayStatusList.map((e) => e.toString()).toList());
    await prefs.setInt(_challengeStartDateKey, newTimestamp);
    await prefs.setString(_challengeTasksCompletedKey, jsonEncode(tasksCompleted));
    await prefs.setString(_challengeTaskTypeKey, jsonEncode(taskTypes));
    
    // Update Firebase with reset information
    if (previousStartTimestamp != null) {
      await _markChallengeResetInFirebase(previousStartTimestamp, newTimestamp);
    } else {
      await _saveStartChallengeToFirebase(newTimestamp);
    }
    
    // Log Mixpanel Event
    MixpanelService.trackEvent('Challenge Reset', properties: {
       'previous_challenge_start_timestamp': previousStartTimestamp,
       'new_challenge_start_timestamp': newTimestamp,
       'reset_at_day': prefs.getInt(_challengeCurrentDayKey) ?? 1,
    });
  }
  
  // Mark challenge as reset in Firebase and start a new one
  Future<void> _markChallengeResetInFirebase(int previousTimestamp, int newTimestamp) async {
    // Only update Firebase if the user is logged in
    if (_auth.currentUser == null) {
      debugPrint('⚠️ Not updating challenge reset in Firebase: User not logged in');
      return;
    }
    
    final uid = _auth.currentUser!.uid;
    final previousChallengeId = previousTimestamp.toString();
    final newChallengeId = newTimestamp.toString();
    
    try {
      // Update the previous challenge document
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('challenges')
          .doc(previousChallengeId)
          .update({
            'status': 'reset',
            'resetDate': FieldValue.serverTimestamp(),
            'resetTimestamp': newTimestamp,
            'newChallengeId': newChallengeId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // Create a new challenge document
      final challengeData = {
        'uid': uid,
        'challengeId': newChallengeId,
        'startTimestamp': newTimestamp,
        'startDate': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(newTimestamp)),
        'currentDay': 1,
        'status': 'in_progress',
        'completedTasks': [],
        'previousChallengeId': previousChallengeId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('challenges')
          .doc(newChallengeId)
          .set(challengeData, SetOptions(merge: true));
      
      // Update user document
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'currentChallengeId': newChallengeId,
            'currentChallengeStartDate': Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(newTimestamp)),
            'currentChallengeDay': 1,
            'hasActiveChallenge': true,
            'resetChallenges': FieldValue.increment(1),
            'lastChallengeResetDate': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      debugPrint('✅ Marked challenge as reset and created new challenge in Firebase');
    } catch (e) {
      debugPrint('❌ Error resetting challenge in Firebase: $e');
    }
  }
  
  // Get the task type for a specific day (journal or breathing)
  Future<String> getTaskTypeForDay(int day) async {
    if (day <= 0 || day > 28) return taskTypeJournal; // Default to journal
    
    final prefs = await SharedPreferences.getInstance();
    final String? taskTypesJson = prefs.getString(_challengeTaskTypeKey);
    
    if (taskTypesJson != null) {
      final Map<String, dynamic> taskTypes = jsonDecode(taskTypesJson);
      return taskTypes[day.toString()] ?? taskTypeJournal;
    }
    
    // Default to alternating pattern if not stored
    return day % 2 == 0 ? taskTypeBreathing : taskTypeJournal;
  }
  
  // Get task description KEY based on task type
  String getTaskDescription(String taskType) {
    switch (taskType) {
      case taskTypeJournal:
        return 'challengeTask_journal';
      case taskTypeBreathing:
        return 'challengeTask_breathing';
      case taskTypePledge:
        return 'challengeTask_pledge';
      case taskTypeMeditation:
        return 'challengeTask_meditation';
      case taskTypePodcast:
        return 'challengeTask_podcast';
      case taskTypeArticles:
        return 'challengeTask_articles';
      case taskTypeFoodScan:
        return 'challengeTask_foodScan';
      case taskTypeRateMyPlate:
        return 'challengeTask_rateMyPlate';
      case taskTypeChatbot:
        return 'challengeTask_chatbot';
      case taskTypeCommunityPost:
        return 'challengeTask_communityPost';
      case taskTypeSelfReflection:
        return 'challengeTask_selfReflection';
      default:
        return 'challengeTask_journal'; // Default to a journal task key
    }
  }
  
  // Get the next daily task description KEY
  Future<String> getDailyTaskDescription(int day) async {
    if (day <= 0 || day > 28) return 'challengeTask_journal'; // Default key
    
    final taskType = await getTaskTypeForDay(day);
    return getTaskDescription(taskType); // This now returns a key
  }
  
  // Generate a random distribution of tasks for the 28-day challenge
  Map<String, String> _generateRandomTaskDistribution() {
    final Map<String, String> taskTypes = {};
    final List<String> availableTasks = List.from(allTaskTypes);
    final int numTaskTypes = availableTasks.length;
    final int daysPerTaskAverage = 28 ~/ numTaskTypes;
    
    // Count how many times each task should appear
    final Map<String, int> taskCounts = {};
    for (String taskType in availableTasks) {
      taskCounts[taskType] = daysPerTaskAverage;
    }
    
    // Distribute any remaining days (if 28 is not divisible by the number of task types)
    int remainingDays = 28 - (daysPerTaskAverage * numTaskTypes);
    final List<String> taskPool = List.from(availableTasks);
    taskPool.shuffle(); // Randomize which tasks get an extra day
    
    for (int i = 0; i < remainingDays; i++) {
      String extraTaskType = taskPool[i % taskPool.length];
      taskCounts[extraTaskType] = (taskCounts[extraTaskType] ?? 0) + 1;
    }
    
    // Create a list with the right number of each task type
    List<String> taskDistribution = [];
    taskCounts.forEach((taskType, count) {
      for (int i = 0; i < count; i++) {
        taskDistribution.add(taskType);
      }
    });
    
    // Shuffle the task distribution
    taskDistribution.shuffle();
    
    // Assign tasks to days
    for (int i = 1; i <= 28; i++) {
      taskTypes[i.toString()] = taskDistribution[i - 1];
    }
    
    return taskTypes;
  }
} 