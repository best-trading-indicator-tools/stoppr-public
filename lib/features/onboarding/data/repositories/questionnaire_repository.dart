import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:stoppr/features/onboarding/domain/models/questionnaire_answers_model.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

class QuestionnaireRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Save questionnaire answers as a subcollection under the user document
  Future<void> saveQuestionnaireAnswers({
    required String userId,
    required Map<int, String> answers,
  }) async {
    try {
      // Verify user is authenticated before attempting write
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        // MIXPANEL_COST_CUT: Removed Firestore permission error - use Crashlytics
        debugPrint('⚠️ No authenticated user or user ID mismatch - skipping questionnaire save');
        return;
      }
      
      // Create a QuestionnaireAnswers model
      final questionnaireAnswers = QuestionnaireAnswers.create(answers: answers);
      
      // Save to Firestore subcollection 'questionnaire' with document ID 'onboarding'
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('onboarding')
          .doc('questionnaire')
          .set(questionnaireAnswers.toJson());
      
      debugPrint('✅ Successfully saved questionnaire answers for user: $userId');
          
    } catch (e) {
      debugPrint('❌ Error saving questionnaire answers: $e');
      if (e.toString().contains('permission-denied')) {
        // MIXPANEL_COST_CUT: Removed Firestore permission error - use Crashlytics
        debugPrint('⚠️ Permission denied - user may not be authenticated');
      }
      rethrow;
    }
  }
  
  // Save selected symptoms
  Future<void> saveSymptoms({
    required String userId,
    required Set<String> symptoms,
  }) async {
    try {
      // Verify user is authenticated before attempting write
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        // MIXPANEL_COST_CUT: Removed Firestore permission error - use Crashlytics
        debugPrint('⚠️ No authenticated user or user ID mismatch - skipping symptoms save');
        return;
      }
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('onboarding')
          .doc('symptoms')
          .set({
            'symptoms': symptoms.toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      debugPrint('✅ Successfully saved ${symptoms.length} symptoms for user: $userId');
    } catch (e) {
      debugPrint('❌ Error saving symptoms: $e');
      if (e.toString().contains('permission-denied')) {
        // MIXPANEL_COST_CUT: Removed Firestore permission error - use Crashlytics
        debugPrint('⚠️ Permission denied - user may not be authenticated');
      }
      rethrow;
    }
  }
  
  // Save selected goals
  Future<void> saveGoals({
    required String userId,
    required List<String> goals,
  }) async {
    try {
      // Verify user is authenticated before attempting write
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        // MIXPANEL_COST_CUT: Removed Firestore permission error - use Crashlytics
        debugPrint('⚠️ No authenticated user or user ID mismatch - skipping goals save');
        return;
      }
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('onboarding')
          .doc('goals')
          .set({
            'goals': goals,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      debugPrint('✅ Successfully saved ${goals.length} goals for user: $userId');
    } catch (e) {
      debugPrint('❌ Error saving goals: $e');
      if (e.toString().contains('permission-denied')) {
        // MIXPANEL_COST_CUT: Removed Firestore permission error - use Crashlytics
        debugPrint('⚠️ Permission denied - user may not be authenticated');
      }
      rethrow;
    }
  }
  
  // Retrieve questionnaire answers from subcollection
  Future<QuestionnaireAnswers?> getQuestionnaireAnswers(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('onboarding')
          .doc('questionnaire')
          .get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return QuestionnaireAnswers.fromJson(docSnapshot.data()!);
      }
      
      return null;
    } catch (e) {
      rethrow;
    }
  }
  
  // Retrieve saved symptoms
  Future<List<String>> getSymptoms(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('onboarding')
          .doc('symptoms')
          .get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        return List<String>.from(data['symptoms'] ?? []);
      }
      
      return [];
    } catch (e) {
      rethrow;
    }
  }
  
  // Retrieve saved goals
  Future<List<String>> getGoals(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('onboarding')
          .doc('goals')
          .get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        return List<String>.from(data['goals'] ?? []);
      }
      
      return [];
    } catch (e) {
      rethrow;
    }
  }
} 