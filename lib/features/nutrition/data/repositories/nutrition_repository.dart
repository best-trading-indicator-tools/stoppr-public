import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


import '../models/food_log.dart';
import '../models/daily_summary.dart';
import '../models/nutrition_goals.dart';
import '../models/nutrition_data.dart';
import '../models/weight_entry.dart';
import '../models/body_profile.dart';
import '../models/workout_log.dart';
import 'package:flutter/foundation.dart';

class NutritionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Prevent multiple simultaneous auth attempts
  static bool _isAuthenticating = false;

  // Ensure we have an authenticated user in debug to satisfy Firestore rules
  NutritionRepository() {
    // Don't create auth in constructor - let _ensureAuth handle it when needed
    if (_auth.currentUser != null) {
      debugPrint('🧪 NutritionRepository: Using existing auth: ${_auth.currentUser?.uid}');
    }
  }

  // Get current user ID - use debug user in development
  String? get _userId => _auth.currentUser?.uid;

  Future<void> _ensureAuth() async {
    if (_auth.currentUser == null && !_isAuthenticating) {
      try {
        _isAuthenticating = true;
        
        // Check again in case another instance already authenticated
        if (_auth.currentUser != null) {
          debugPrint('✅ NutritionRepository: Auth already established by another instance: ${_auth.currentUser?.uid}');
          return;
        }
        
        final credential = await _auth.signInAnonymously();
        debugPrint('✅ NutritionRepository: Anonymous auth successful: ${credential.user?.uid}');
        
        // Create minimal user document for promo users who skipped onboarding
        await _createMinimalUserDocument(credential.user!.uid);
      } catch (e) {
        debugPrint('❌ NutritionRepository: Anonymous auth failed: $e');
        throw Exception('Failed to authenticate user for nutrition features');
      } finally {
        _isAuthenticating = false;
      }
    } else if (_isAuthenticating) {
      // Wait for ongoing auth to complete
      debugPrint('⏳ NutritionRepository: Waiting for ongoing auth...');
      int retries = 0;
      while (_isAuthenticating && retries < 50) { // Max 5 seconds wait
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }
      if (_auth.currentUser == null) {
        throw Exception('Auth timeout - failed to establish authentication');
      }
    }
  }

  // Create minimal user document for promo users who skipped onboarding
  Future<void> _createMinimalUserDocument(String userId) async {
    try {
      // Check if user document already exists
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        // Create minimal user document
        await _firestore.collection('users').doc(userId).set({
          'isAnonymous': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'source': 'nutrition_auto_created', // Track how this user was created
          'hasCompletedOnboarding': false,
        }, SetOptions(merge: true));
        debugPrint('✅ NutritionRepository: Created minimal user document for: $userId');
      } else {
        debugPrint('✅ NutritionRepository: User document already exists for: $userId');
      }
    } catch (e) {
      debugPrint('❌ NutritionRepository: Failed to create user document: $e');
      // Don't throw - we can still proceed with nutrition features
    }
  }

  // Food Logs
  Future<String> addFoodLog(FoodLog foodLog) async {
    await _ensureAuth();
    if (_userId == null) throw Exception('User not authenticated');

    try {
      // Create food log with user ID  
      final updatedFoodLog = foodLog.copyWith(
        userId: _userId!,
        // Keep imageUrl as provided (local path for thumbnails)
      );

      // Add to Firestore
      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('food_logs')
          .add(_foodLogToJson(updatedFoodLog));

      // Update the food log with the generated ID
      final foodLogWithId = updatedFoodLog.copyWith(id: docRef.id);
      
      // Update daily summary
      await _updateDailySummary(foodLogWithId);

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding food log: $e');
      rethrow;
    }
  }

  /// Add food log with pre-generated ID (for image consistency)
  Future<void> addFoodLogWithId(FoodLog foodLog) async {
    await _ensureAuth();
    if (_userId == null) throw Exception('User not authenticated');
    if (foodLog.id == null) throw Exception('FoodLog ID is required');

    try {
      // Create food log with user ID
      final updatedFoodLog = foodLog.copyWith(
        userId: _userId!,
        // Keep imageUrl as provided
      );

      // Set document with specific ID
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('food_logs')
          .doc(foodLog.id!)
          .set(_foodLogToJson(updatedFoodLog));
      
      // Update daily summary
      await _updateDailySummary(updatedFoodLog);

    } catch (e) {
      debugPrint('Error adding food log with ID: $e');
      rethrow;
    }
  }

  // Get food logs for a specific date
  Stream<List<FoodLog>> getFoodLogsForDate(DateTime date) {
    // Ensure auth before attaching Firestore listeners so streams stay live
    return Stream.fromFuture(_ensureAuth()).asyncExpand((_) {
      final uid = _userId;
      if (uid == null) return Stream.value([]);

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      return _firestore
          .collection('users')
          .doc(uid)
          .collection('food_logs')
          .where('loggedAt', isGreaterThanOrEqualTo: startOfDay)
          .where('loggedAt', isLessThan: endOfDay)
          .orderBy('loggedAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => _foodLogFromFirestore(doc.data(), doc.id))
              .toList())
          .handleError((e, _) {
            if (e is FirebaseException && e.code == 'permission-denied') {
              // Swallow permission errors to avoid fatal FlutterError in release
              return <FoodLog>[];
            }
          });
    });
  }

  // Get recent food logs
  Stream<List<FoodLog>> getRecentFoodLogs({int limit = 10}) {
    return Stream.fromFuture(_ensureAuth()).asyncExpand((_) {
      final uid = _userId;
      if (uid == null) return Stream.value([]);
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('food_logs')
          .orderBy('loggedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => _foodLogFromFirestore(doc.data(), doc.id))
              .toList())
          .handleError((e, _) {
            if (e is FirebaseException && e.code == 'permission-denied') {
              return <FoodLog>[];
            }
          });
    });
  }

  // Update food log (for processing completion)
  Future<void> updateFoodLog(FoodLog foodLog) async {
    if (_userId == null) throw Exception('User not authenticated');
    if (foodLog.id == null || foodLog.id!.isEmpty) throw Exception('Food log ID is required');

    try {
      // Get the old food log first to update daily summary correctly
      final oldDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('food_logs')
          .doc(foodLog.id!)
          .get();

      if (oldDoc.exists) {
        final oldFoodLog = _foodLogFromFirestore(oldDoc.data()!, oldDoc.id);
        
        // Remove old values from daily summary
        await _updateDailySummary(oldFoodLog, isDelete: true);
        
        // Update the document
        final updatedFoodLog = foodLog.copyWith(
          userId: _userId!,
          // Keep imageUrl as provided (local path for thumbnails)
        );
        
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('food_logs')
            .doc(foodLog.id!)
            .update(_foodLogToJson(updatedFoodLog));
        
        // Add new values to daily summary
        await _updateDailySummary(updatedFoodLog);
      }
    } catch (e) {
      debugPrint('Error updating food log: $e');
      rethrow;
    }
  }

  // Serialize FoodLog avoiding nested Freezed object pitfalls
  Map<String, dynamic> _foodLogToJson(FoodLog log) {
    return {
      'userId': log.userId,
      'foodName': log.foodName,
      'mealType': _mealTypeToJson(log.mealType),
      'imageUrl': log.imageUrl,
      'nutritionData': _nutritionDataToJson(log.nutritionData),
      'loggedAt': Timestamp.fromDate(log.loggedAt),
      'notes': log.notes,
    }..removeWhere((key, value) => value == null);
  }

  // Manually serialize NutritionData to handle nested ServingInfo
  Map<String, dynamic> _nutritionDataToJson(NutritionData data) {
    return {
      'foodName': data.foodName,
      'calories': data.calories,
      'protein': data.protein,
      'carbs': data.carbs,
      'fat': data.fat,
      'sugar': data.sugar,
      'fiber': data.fiber,
      'sodium': data.sodium,
      'micronutrients': data.micronutrients.map((key, value) => 
        MapEntry(key, value.toJson())),
      'servingInfo': data.servingInfo?.toJson(),
    }..removeWhere((key, value) => value == null);
  }

  String _mealTypeToJson(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
    }
  }

  // Delete food log
  Future<void> deleteFoodLog(String logId) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      // Get the food log first to update daily summary
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('food_logs')
          .doc(logId)
          .get();

      if (doc.exists) {
        final foodLog = _foodLogFromFirestore(doc.data()!, doc.id);
        
        // Delete from Firestore
        await doc.reference.delete();

        // Update daily summary (subtract the deleted food)
        await _updateDailySummary(foodLog, isDelete: true);

        // No image deletion needed since we don't store images
      }
    } catch (e) {
      debugPrint('Error deleting food log: $e');
      rethrow;
    }
  }

  // Normalize Firestore numeric types (int -> double) to satisfy model decoding
  FoodLog _foodLogFromFirestore(Map<String, dynamic> data, String id) {
    final Map<String, dynamic> copy = {...data};
    copy['id'] = id;
    final nd = copy['nutritionData'];
    if (nd is Map<String, dynamic>) {
      double _asDouble(dynamic v) {
        if (v == null) return 0.0;
        if (v is double) return v;
        if (v is int) return v.toDouble();
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        return 0.0;
      }
      nd['calories'] = _asDouble(nd['calories']);
      nd['protein'] = _asDouble(nd['protein']);
      nd['carbs'] = _asDouble(nd['carbs']);
      nd['fat'] = _asDouble(nd['fat']);
      nd['sugar'] = _asDouble(nd['sugar']);
      nd['fiber'] = _asDouble(nd['fiber']);
      nd['sodium'] = _asDouble(nd['sodium']);
      if (nd['servingInfo'] is Map<String, dynamic>) {
        final si = nd['servingInfo'] as Map<String, dynamic>;
        si['amount'] = _asDouble(si['amount']);
        if (si['weight'] != null) si['weight'] = _asDouble(si['weight']);
      }
      if (nd['micronutrients'] is Map<String, dynamic>) {
        final m = nd['micronutrients'] as Map<String, dynamic>;
        m.forEach((k, v) {
          if (v is Map<String, dynamic>) {
            v['value'] = _asDouble(v['value']);
            v['unit'] = v['unit'] ?? '';
          }
        });
      }
    }
    return FoodLog.fromJson(copy);
  }

  // Daily Summary
  Future<void> _updateDailySummary(FoodLog foodLog, {bool isDelete = false}) async {
    try {
      final dateStr = _formatDateForId(foodLog.loggedAt);
      final summaryRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('daily_summaries')
          .doc(dateStr);



      // debugPrint('📊 DAILY SUMMARY UPDATE START');
      // debugPrint('   Date: $dateStr');
      // debugPrint('   Food: ${foodLog.foodName}');
      // debugPrint('   Calories: ${foodLog.nutritionData.calories}');
      // debugPrint('   Is Delete: $isDelete');

      await _firestore.runTransaction((transaction) async {
        final summaryDoc = await transaction.get(summaryRef);
        
        DailySummary summary;
        if (summaryDoc.exists) {
          try {
            summary = DailySummary.fromJson(summaryDoc.data()!);
            debugPrint('   Existing summary found - Current calories: ${summary.totalCalories}');
          } catch (e) {
            // Handle legacy docs that were created without required fields (e.g., debug water writes)
            double _asDouble(dynamic v) {
              if (v == null) return 0.0;
              if (v is double) return v;
              if (v is int) return v.toDouble();
              if (v is num) return v.toDouble();
              if (v is String) return double.tryParse(v) ?? 0.0;
              return 0.0;
            }
            final raw = summaryDoc.data()!;
            summary = DailySummary(
              date: dateStr,
              userId: _userId!,
              totalCalories: _asDouble(raw['totalCalories']),
              totalProtein: _asDouble(raw['totalProtein']),
              totalCarbs: _asDouble(raw['totalCarbs']),
              totalFat: _asDouble(raw['totalFat']),
              totalSugar: _asDouble(raw['totalSugar']),
              totalFiber: _asDouble(raw['totalFiber']),
              totalSodium: _asDouble(raw['totalSodium']),
              // Preserve existing totals if they existed; defaults to 0 otherwise
              updatedAt: DateTime.now(),
            );
            debugPrint('   Repaired legacy summary doc (missing required fields)');
          }
        } else {
          summary = DailySummary(
            date: dateStr,
            userId: _userId!,
            totalCalories: 0,
            totalProtein: 0,
            totalCarbs: 0,
            totalFat: 0,
            totalSugar: 0,
            totalFiber: 0,
            totalSodium: 0,
            updatedAt: DateTime.now(),
          );
          debugPrint('   Creating new summary');
        }

        // Update totals
        final multiplier = isDelete ? -1 : 1;
        final oldCalories = summary.totalCalories;
        final calorieChange = foodLog.nutritionData.calories * multiplier;
        final newCalories = oldCalories + calorieChange;
        
        debugPrint('   Calculation: $oldCalories + (${foodLog.nutritionData.calories} × $multiplier) = $newCalories');
        
        summary = summary.copyWith(
          totalCalories: (summary.totalCalories + (foodLog.nutritionData.calories * multiplier)).clamp(0.0, double.infinity),
          totalProtein: (summary.totalProtein + (foodLog.nutritionData.protein * multiplier)).clamp(0.0, double.infinity),
          totalCarbs: (summary.totalCarbs + (foodLog.nutritionData.carbs * multiplier)).clamp(0.0, double.infinity),
          totalFat: (summary.totalFat + (foodLog.nutritionData.fat * multiplier)).clamp(0.0, double.infinity),
          totalSugar: (summary.totalSugar + (foodLog.nutritionData.sugar * multiplier)).clamp(0.0, double.infinity),
          totalFiber: (summary.totalFiber + (foodLog.nutritionData.fiber * multiplier)).clamp(0.0, double.infinity),
          totalSodium: (summary.totalSodium + (foodLog.nutritionData.sodium * multiplier)).clamp(0.0, double.infinity),
          mealsLogged: (summary.mealsLogged + (isDelete ? -1 : 1)).clamp(0, 999),
          updatedAt: DateTime.now(),
        );

        // Calculate health score after updating totals
        summary = summary.copyWith(
          healthScore: _calculateHealthScore(summary),
        );

        transaction.set(summaryRef, summary.toJson(), SetOptions(merge: true));
        
        // debugPrint('📊 DAILY SUMMARY UPDATED SUCCESSFULLY');
        // debugPrint('   Final calories: ${summary.totalCalories}');
        // debugPrint('   Final protein: ${summary.totalProtein}g');
        // debugPrint('   Final carbs: ${summary.totalCarbs}g');
        // debugPrint('   Final fat: ${summary.totalFat}g');
      });
    } catch (e, stackTrace) {
      debugPrint('❌ DAILY SUMMARY UPDATE FAILED: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get daily summary
  Stream<DailySummary?> getDailySummary(DateTime date) {
    return Stream.fromFuture(_ensureAuth()).asyncExpand((_) {
      final uid = _userId;
      if (uid == null) return Stream.value(null);
      final dateStr = _formatDateForId(date);
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('daily_summaries')
          .doc(dateStr)
          .snapshots()
          .map((doc) => doc.exists ? _dailySummaryFromFirestore(doc.data()!) : null)
          .handleError((e, _) {
            if (e is FirebaseException && e.code == 'permission-denied') {
              return null;
            }
          });
    });
  }

  // Update water intake
  Future<void> updateWaterIntake(DateTime date, double waterMl) async {
    if (_userId == null) throw Exception('User not authenticated');

    final dateStr = _formatDateForId(date);
    final summaryRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('daily_summaries')
        .doc(dateStr);

    // Ensure the summary document exists with required fields on first write
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(summaryRef);

      if (snapshot.exists) {
        transaction.set(
          summaryRef,
          {
            'waterIntake': waterMl,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        final DailySummary seed = DailySummary(
          date: dateStr,
          userId: _userId!,
          totalCalories: 0,
          totalProtein: 0,
          totalCarbs: 0,
          totalFat: 0,
          totalSugar: 0,
          totalFiber: 0,
          totalSodium: 0,
          updatedAt: DateTime.now(),
        );

        final Map<String, dynamic> data = {
          ...seed.toJson(),
          'waterIntake': waterMl,
          // Preserve server time for consistency with other writes
          'updatedAt': FieldValue.serverTimestamp(),
        };

        transaction.set(summaryRef, data, SetOptions(merge: true));
      }
    });
  }

  // Nutrition Goals
  Future<void> saveNutritionGoals(NutritionGoals goals) async {
    if (_userId == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('nutrition_profile')
        .doc('daily_goals')
        .set(goals.toJson());
  }

  Stream<NutritionGoals?> getNutritionGoals() {
    if (_userId == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('nutrition_profile')
        .doc('daily_goals')
        .snapshots()
        .map((doc) => doc.exists ? NutritionGoals.fromJson(doc.data()!) : null)
        .handleError((e, _) {
          if (e is FirebaseException && e.code == 'permission-denied') {
            return null;
          }
        });
  }

  // ================= BODY METRICS & WEIGHT =================
  Future<void> saveBodyProfile({required double heightCm, required double goalWeightKg}) async {
    await _ensureAuth();
    if (_userId == null) throw Exception('User not authenticated');
    final profile = BodyProfile(
      heightCm: heightCm,
      goalWeightKg: goalWeightKg,
      updatedAt: DateTime.now(),
    );
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('body_metrics')
        .doc('profile')
        .set(profile.toJson(), SetOptions(merge: true));
  }

  /// Save only goal weight (preserves existing height)
  Future<void> saveGoalWeight(double goalWeightKg) async {
    await _ensureAuth();
    if (_userId == null) throw Exception('User not authenticated');
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('body_metrics')
        .doc('profile')
        .set({
      'goalWeightKg': goalWeightKg,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Save only height (preserves existing goal weight)
  Future<void> saveHeight(double heightCm) async {
    await _ensureAuth();
    if (_userId == null) throw Exception('User not authenticated');
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('body_metrics')
        .doc('profile')
        .set({
      'heightCm': heightCm,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<BodyProfile?> getBodyProfile() {
    if (_userId == null) return Stream.value(null);
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('body_metrics')
        .doc('profile')
        .snapshots()
        .map((d) => d.exists ? BodyProfile.fromJson(d.data()!) : null)
        .handleError((e, _) {
          if (e is FirebaseException && e.code == 'permission-denied') {
            return null;
          }
        });
  }

  Future<String> addWeightEntry(double weightKg, {DateTime? when, String source = 'manual'}) async {
    await _ensureAuth();
    if (_userId == null) throw Exception('User not authenticated');
    final entry = WeightEntry(
      weightKg: weightKg,
      loggedAt: when ?? DateTime.now(),
      source: source,
    );
    final ref = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('body_metrics')
        .doc('profile')
        .collection('weight_entries')
        .add(entry.toJson());
    return ref.id;
  }

  Stream<WeightEntry?> streamLatestWeight() {
    if (_userId == null) return Stream.value(null);
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('body_metrics')
        .doc('profile')
        .collection('weight_entries')
        .orderBy('loggedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((q) => q.docs.isNotEmpty
            ? WeightEntry.fromJson({
                ...q.docs.first.data(),
                'id': q.docs.first.id,
              })
            : null)
        .handleError((e, _) {
          if (e is FirebaseException && e.code == 'permission-denied') {
            return null;
          }
        });
  }

  Future<List<WeightEntry>> getWeightEntries(DateTime start, DateTime end) async {
    if (_userId == null) return [];
    final snap = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('body_metrics')
        .doc('profile')
        .collection('weight_entries')
        .where('loggedAt', isGreaterThanOrEqualTo: start)
        .where('loggedAt', isLessThanOrEqualTo: end)
        .orderBy('loggedAt')
        .get();
    return snap.docs
        .map((d) => WeightEntry.fromJson({
              ...d.data(),
              'id': d.id,
            }))
        .toList();
  }

  // ================= WORKOUT HABITS =================
  /// Stream the raw body profile doc for additional fields (e.g., workout habits)
  Stream<Map<String, dynamic>?> streamBodyProfileRaw() {
    if (_userId == null) return Stream.value(null);
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('body_metrics')
        .doc('profile')
        .snapshots()
        .map((d) => d.data())
        .handleError((e, _) {
          if (e is FirebaseException && e.code == 'permission-denied') {
            return null;
          }
        });
  }

  /// Save workout habits into body profile (merge)
  Future<void> saveWorkoutHabits({
    required double workoutsPerWeek,
    required int avgWorkoutMinutes,
    required String workoutStyle,
  }) async {
    await _ensureAuth();
    if (_userId == null) throw Exception('User not authenticated');
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('body_metrics')
        .doc('profile')
        .set({
      'workoutsPerWeek': workoutsPerWeek,
      'avgWorkoutMinutes': avgWorkoutMinutes,
      'workoutStyle': workoutStyle,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Range summaries for charts
  Future<List<DailySummary>> getDailySummariesInRange(DateTime start, DateTime end) async {
    if (_userId == null) return [];
    final startId = _formatDateForId(start);
    final endId = _formatDateForId(end);
    final col = _firestore
        .collection('users')
        .doc(_userId)
        .collection('daily_summaries');
    final snap = await col
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startId)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endId)
        .orderBy(FieldPath.documentId)
        .get();
    return snap.docs.map((d) => _dailySummaryFromFirestore(d.data())).toList();
  }

  // Helper methods
  String _formatDateForId(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  double _calculateHealthScore(DailySummary summary) {
    // Base score
    double score = 10.0;

    // Carbs penalty thresholds
    final carbs = summary.totalCarbs;

    // Movement/workout mitigation factor from body profile if present
    // Defaults to 1.0 (no mitigation). More movement reduces penalty up to 40%.
    double movementFactor = 1.0;
    // We cannot synchronously read profile here; rely on optional fields mirrored in summary later if added.
    // Keep pure function now; penalties scaled by conservative baseline (no extra reads here).

    if (carbs > 100) {
      score -= 4.0 * movementFactor; // terrible
    } else if (carbs > 50) {
      score -= 2.0 * movementFactor; // bad
    }

    // Penalize high sugar intake (>50g)
    if (summary.totalSugar > 50) {
      score -= (summary.totalSugar - 50) / 10;
    }

    // Sodium is not penalized by design

    // Reward fiber intake (>=25g)
    if (summary.totalFiber >= 25) {
      score += 1;
    }

    return score.clamp(0, 10);
  }

  // ================= WORKOUT LOGS =================
  
  // Add workout log
  Future<String> addWorkoutLog(WorkoutLog workoutLog) async {
    await _ensureAuth();
    if (_userId == null) throw Exception('User not authenticated');

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('workout_logs')
          .add(workoutLog.toJson());

      // Update daily summary with burned calories
      await _updateDailySummaryForWorkout(workoutLog);

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding workout log: $e');
      rethrow;
    }
  }

  // Get workout logs for a specific date
  Stream<List<WorkoutLog>> getWorkoutLogsForDate(DateTime date) {
    return Stream.fromFuture(_ensureAuth()).asyncExpand((_) {
      final uid = _userId;
      if (uid == null) return Stream.value([]);

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      return _firestore
          .collection('users')
          .doc(uid)
          .collection('workout_logs')
          .where('loggedAt', isGreaterThanOrEqualTo: startOfDay)
          .where('loggedAt', isLessThan: endOfDay)
          .orderBy('loggedAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => _workoutLogFromFirestore(doc.data(), doc.id))
              .toList())
          .handleError((e, _) {
            if (e is FirebaseException && e.code == 'permission-denied') {
              return <WorkoutLog>[];
            }
          });
    });
  }

  // Update workout log
  Future<void> updateWorkoutLog(String logId, WorkoutLog workoutLog) async {
    await _ensureAuth();
    if (_userId == null) throw Exception('User not authenticated');

    try {
      // Get the old workout log to calculate calorie difference
      final oldDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('workout_logs')
          .doc(logId)
          .get();
      
      if (!oldDoc.exists) {
        throw Exception('Workout log not found');
      }
      
      final oldWorkout = _workoutLogFromFirestore(oldDoc.data()!, oldDoc.id);
      
      // Update the workout log
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('workout_logs')
          .doc(logId)
          .update(workoutLog.toJson());
      
      // Update daily summary: remove old calories, then add new calories
      if (oldWorkout.caloriesBurned != workoutLog.caloriesBurned) {
        // Remove old workout calories
        await _updateDailySummaryForWorkout(oldWorkout, isDelete: true);
        // Add new workout calories
        await _updateDailySummaryForWorkout(workoutLog, isDelete: false);
      }
    } catch (e) {
      debugPrint('Error updating workout log: $e');
      rethrow;
    }
  }

  // Delete workout log
  Future<void> deleteWorkoutLog(String logId) async {
    if (_userId == null) throw Exception('User not authenticated');

    try {
      // Get the workout log first to update daily summary
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('workout_logs')
          .doc(logId)
          .get();

      if (doc.exists) {
        final workoutLog = _workoutLogFromFirestore(doc.data()!, doc.id);
        
        // Delete from Firestore
        await doc.reference.delete();

        // Update daily summary (remove the burned calories)
        await _updateDailySummaryForWorkout(workoutLog, isDelete: true);
      }
    } catch (e) {
      debugPrint('Error deleting workout log: $e');
      rethrow;
    }
  }

  // Update daily summary for workout (burned calories increase calories available)
  Future<void> _updateDailySummaryForWorkout(WorkoutLog workoutLog, {bool isDelete = false}) async {
    try {
      final dateStr = _formatDateForId(workoutLog.loggedAt);
      final summaryRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('daily_summaries')
          .doc(dateStr);

      await _firestore.runTransaction((transaction) async {
        final summaryDoc = await transaction.get(summaryRef);
        
        DailySummary summary;
        if (summaryDoc.exists) {
          summary = DailySummary.fromJson(summaryDoc.data()!);
        } else {
          summary = DailySummary(
            date: dateStr,
            userId: _userId!,
            totalCalories: 0,
            totalProtein: 0,
            totalCarbs: 0,
            totalFat: 0,
            totalSugar: 0,
            totalFiber: 0,
            totalSodium: 0,
            totalCaloriesBurned: 0,
            updatedAt: DateTime.now(),
          );
        }

        // Update burned calories - these increase available calories for consumption
        final multiplier = isDelete ? -1 : 1;
        summary = summary.copyWith(
          totalCaloriesBurned: (summary.totalCaloriesBurned + (workoutLog.caloriesBurned * multiplier)).clamp(0.0, double.infinity),
          updatedAt: DateTime.now(),
        );

        // Calculate health score after updating totals
        summary = summary.copyWith(
          healthScore: _calculateHealthScore(summary),
        );

        transaction.set(summaryRef, summary.toJson(), SetOptions(merge: true));
      });
    } catch (e, stackTrace) {
      debugPrint('❌ DAILY SUMMARY WORKOUT UPDATE FAILED: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Normalize WorkoutLog numeric types from Firestore
  WorkoutLog _workoutLogFromFirestore(Map<String, dynamic> data, String id) {
    final Map<String, dynamic> copy = {...data};
    copy['id'] = id;
    
    // Ensure numeric fields are proper types
    if (copy['duration'] is double) {
      copy['duration'] = (copy['duration'] as double).toInt();
    }
    if (copy['caloriesBurned'] is double) {
      copy['caloriesBurned'] = (copy['caloriesBurned'] as double).toInt();
    }
    
    return WorkoutLog.fromJson(copy);
  }

  // Normalize DailySummary numeric types
  DailySummary _dailySummaryFromFirestore(Map<String, dynamic> data) {
    double _asDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }
    final copy = {...data};
    copy['totalCalories'] = _asDouble(copy['totalCalories']);
    copy['totalProtein'] = _asDouble(copy['totalProtein']);
    copy['totalCarbs'] = _asDouble(copy['totalCarbs']);
    copy['totalFat'] = _asDouble(copy['totalFat']);
    copy['totalSugar'] = _asDouble(copy['totalSugar']);
    copy['totalFiber'] = _asDouble(copy['totalFiber']);
    copy['totalSodium'] = _asDouble(copy['totalSodium']);
    copy['waterIntake'] = _asDouble(copy['waterIntake']);
    copy['healthScore'] = _asDouble(copy['healthScore']);
    copy['totalCaloriesBurned'] = _asDouble(copy['totalCaloriesBurned']);
    return DailySummary.fromJson(copy);
  }
}
