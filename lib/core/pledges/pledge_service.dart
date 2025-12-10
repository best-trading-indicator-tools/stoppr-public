import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../analytics/mixpanel_service.dart'; // Import MixpanelService

class PledgeService {
  // Singleton pattern
  static final PledgeService _instance = PledgeService._internal();
  
  factory PledgeService() {
    return _instance;
  }
  
  PledgeService._internal();
  
  // Keys for shared preferences
  static const String _pledgeTimestampKey = 'pledge_timestamp';
  static const String _pledgeCompletionTimestampKey = 'pledge_completion_timestamp';
  static const String _pendingCheckInKey = 'pending_pledge_check_in';
  static const String _lastCheckInTimestampKey = 'last_pledge_check_in_timestamp';
  
  // Keys for local pledge stats fallback
  static const String _localTotalPledgesKey = 'local_total_pledges';
  static const String _localSuccessfulPledgesKey = 'local_successful_pledges';
  static const String _localPledgeSuccessRateKey = 'local_pledge_success_rate';
  static const String _localLastCheckInTimestampKey = 'local_last_pledge_check_in_timestamp';
  
  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Starts a new pledge, saving locally and to Firebase.
  Future<void> startPledge(DateTime startTime, DateTime endTime) async {
    final prefs = await SharedPreferences.getInstance();
    final startTimestamp = startTime.millisecondsSinceEpoch;
    final endTimestamp = endTime.millisecondsSinceEpoch;
    final pledgeId = startTimestamp.toString(); // Use start timestamp as ID
    
    // 1. Save locally to SharedPreferences
    await prefs.setInt(_pledgeTimestampKey, startTimestamp);
    await prefs.setInt(_pledgeCompletionTimestampKey, endTimestamp);
    await prefs.setBool(_pendingCheckInKey, false); // Ensure pending flag is reset
    debugPrint('✅ Saved pledge timestamps locally.');
    
    // 2. Save to Firebase if user is logged in
    if (_auth.currentUser != null) {
      final uid = _auth.currentUser!.uid;
      final pledgeData = {
        'uid': uid,
        'pledgeId': pledgeId,
        'startTimestamp': startTimestamp,
        'startDate': Timestamp.fromDate(startTime),
        'endTimestamp': endTimestamp,
        'endDate': Timestamp.fromDate(endTime),
        'status': 'active', // Initial status
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('pledges')
            .doc(pledgeId)
            .set(pledgeData, SetOptions(merge: true));
        debugPrint('✅ Started pledge saved to Firebase: $pledgeId');
      } catch (e) {
        debugPrint('❌ Error saving started pledge to Firebase: $e');
        // Consider error handling: should we revert local save?
      }
    } else {
      debugPrint('⚠️ Not saving started pledge to Firebase: User not logged in');
    }
    
    // 3. Log Mixpanel Event
    MixpanelService.trackEvent('Pledge Started', properties: {
      'duration_hours': endTime.difference(startTime).inHours,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'pledge_id': pledgeId,
    });
  }
  
  // Check if there's a pending pledge that needs a check-in
  Future<bool> hasPendingCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check explicit pending check-in flag first
    if (prefs.getBool(_pendingCheckInKey) ?? false) {
      return true;
    }
    
    final completionTimestamp = prefs.getInt(_pledgeCompletionTimestampKey);
    final pledgeTimestamp = prefs.getInt(_pledgeTimestampKey);
    
    if (completionTimestamp != null && pledgeTimestamp != null) {
      // If completion time has passed
      if (now >= completionTimestamp) {
        // Check if this specific pledge has already been checked in locally (using old feeling key method as fallback)
        final pledgeEndDate = DateTime.fromMillisecondsSinceEpoch(completionTimestamp);
        final endDateString = DateFormat('yyyy-MM-dd').format(pledgeEndDate);
        final pledgeFeelingKey = 'pledge_feeling_$endDateString';
        final hasLocalCheckInData = prefs.containsKey(pledgeFeelingKey);

        // Also check Firebase status if user is logged in
        bool needsCheckIn = true; // Assume check-in is needed unless proven otherwise
        String pledgeId = pledgeTimestamp.toString();

        if (_auth.currentUser != null) {
          final uid = _auth.currentUser!.uid;
          try {
            final pledgeDoc = await _firestore
                .collection('users')
                .doc(uid)
                .collection('pledges')
                .doc(pledgeId)
                .get();

            if (pledgeDoc.exists) {
              final data = pledgeDoc.data();
              final status = data?['status'] as String?;
              // If status is already finished or checked_in, no *new* check-in is needed
              if (status == 'finished' || status == 'checked_in') {
                 needsCheckIn = false;
                 // If status is finished but not checked_in, mark pending locally
                 if (status == 'finished' && !(prefs.getBool(_pendingCheckInKey) ?? false)) {
                    await prefs.setBool(_pendingCheckInKey, true);
                    debugPrint('ℹ️ Pledge $pledgeId already finished, marking check-in pending locally.');
                    return true; // Return true to trigger UI
                 }
              } else if (status == 'active') {
                // Pledge finished now, update status and log event
                await pledgeDoc.reference.update({
                  'status': 'finished',
                  'actualEndTime': FieldValue.serverTimestamp(), // Record actual finish time
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                MixpanelService.trackEvent('Pledge Finished', properties: {
                  'pledge_id': pledgeId,
                  'scheduled_end_time': pledgeEndDate.toIso8601String(),
                });
                debugPrint('✅ Marked pledge $pledgeId as finished in Firebase and logged event.');
                needsCheckIn = true; // Set to true as it just finished
              }
            } else {
               // Pledge doc doesn't exist in Firebase, rely on local check-in data
               needsCheckIn = !hasLocalCheckInData;
               debugPrint('⚠️ Pledge $pledgeId not found in Firebase, relying on local check-in data.');
            }
          } catch (e) {
             debugPrint('❌ Error checking Firebase pledge status: $e. Relying on local check-in data.');
             needsCheckIn = !hasLocalCheckInData; // Fallback to local check on error
          }
        } else {
           // User not logged in, rely purely on local data
           needsCheckIn = !hasLocalCheckInData;
        }

        // If a check-in is needed (either just finished or previously finished but not checked in)
        if (needsCheckIn) {
          await prefs.setBool(_pendingCheckInKey, true);
          debugPrint('ℹ️ Pledge $pledgeId needs check-in, marking pending locally.');
          return true;
        } else {
           // Check-in not needed (already checked in or status indicates otherwise)
           // Clear any potentially stale local flags
           await prefs.setBool(_pendingCheckInKey, false);
           // Maybe remove completion timestamp too? No, keep it for history if needed.
           debugPrint('ℹ️ Pledge $pledgeId does not require check-in.');
        }
      }
    }
    
    // Default to false if no conditions met
    return false;
  }
  
  // Save the check-in results for a completed pledge
  Future<void> savePledgeCheckIn({
    required bool wasSuccessful,
    required String feeling,
    String? notes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pledgeTimestamp = prefs.getInt(_pledgeTimestampKey);
    final completionTimestamp = prefs.getInt(_pledgeCompletionTimestampKey); // Still needed for local keys/fallback
    
    if (pledgeTimestamp == null || completionTimestamp == null) {
      debugPrint('⚠️ Cannot save check-in without pledge timestamps');
      return;
    }
    
    final pledgeId = pledgeTimestamp.toString();
    final pledgeEndDate = DateTime.fromMillisecondsSinceEpoch(completionTimestamp);
    final endDateString = DateFormat('yyyy-MM-dd').format(pledgeEndDate);
    
    // 1. Save locally to SharedPreferences (as backup/offline support)
    await _saveCheckInToSharedPreferences(
      wasSuccessful: wasSuccessful,
      feeling: feeling,
      notes: notes,
      endDateString: endDateString,
    );
    
    // 2. Save to Firebase if user is logged in (update existing document)
    if (_auth.currentUser != null) {
      // Pass necessary details for potential creation
      final pledgeStartDate = DateTime.fromMillisecondsSinceEpoch(pledgeTimestamp);
      await _updateFirebasePledgeCheckIn(
        pledgeId: pledgeId,
        uid: _auth.currentUser!.uid, // Pass UID
        startTimestamp: pledgeTimestamp, // Pass Start Timestamp
        startDate: pledgeStartDate, // Pass Start Date
        endTimestamp: completionTimestamp, // Pass End Timestamp
        endDate: pledgeEndDate, // Pass End Date
        wasSuccessful: wasSuccessful,
        feeling: feeling,
        notes: notes,
      );
      
      // Update aggregate stats in the user document
      final uid = _auth.currentUser!.uid;
      await _updateUserPledgeStats(uid, wasSuccessful);
      
    } else {
       debugPrint('⚠️ Not saving check-in to Firebase: User not logged in.');
    }
    
    // 3. Log Mixpanel Event
    MixpanelService.trackEvent('Pledge CheckIn Completed', properties: {
      'pledge_id': pledgeId,
      'wasSuccessful': wasSuccessful,
      'feeling': feeling,
      'has_notes': notes != null && notes.isNotEmpty,
    });
    
    // 4. Clean up local state
    await prefs.setBool(_pendingCheckInKey, false);
    await prefs.setInt(_lastCheckInTimestampKey, DateTime.now().millisecondsSinceEpoch);
    // Clear the main pledge timestamps now that it's fully checked-in
    await prefs.remove(_pledgeTimestampKey);
    await prefs.remove(_pledgeCompletionTimestampKey);
    debugPrint('✅ Cleared local pledge timestamps after check-in.');
  }
  
  // Save pledge check-in to SharedPreferences (Reduced scope - just for local history/fallback)
  Future<void> _saveCheckInToSharedPreferences({
    required bool wasSuccessful,
    required String feeling,
    String? notes,
    required String endDateString,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save completed status
    final pledgeCompletedKey = 'pledge_completed_$endDateString';
    await prefs.setBool(pledgeCompletedKey, wasSuccessful);
    
    // Save feeling
    final pledgeFeelingKey = 'pledge_feeling_$endDateString';
    await prefs.setString(pledgeFeelingKey, feeling);
    
    // Save notes if provided
    if (notes != null && notes.isNotEmpty) {
      final pledgeNotesKey = 'pledge_notes_$endDateString';
      await prefs.setString(pledgeNotesKey, notes);
    }
    
    debugPrint('✅ Saved pledge check-in backup to SharedPreferences: $endDateString');
  }
  
  // Update pledge check-in details in Firebase (or create if missing)
  Future<void> _updateFirebasePledgeCheckIn({
    required String pledgeId,
    required String uid, // Added
    required int startTimestamp, // Added
    required DateTime startDate, // Added
    required int endTimestamp, // Added
    required DateTime endDate, // Added
    required bool wasSuccessful,
    required String feeling,
    String? notes,
  }) async {
    // No need for logged-in check here, already done before calling
    
    try {
      // Prepare the data map - include all fields for creation case
      final checkInData = {
        'uid': uid,
        'pledgeId': pledgeId,
        'startTimestamp': startTimestamp,
        'startDate': Timestamp.fromDate(startDate),
        'endTimestamp': endTimestamp,
        'endDate': Timestamp.fromDate(endDate),
        'wasSuccessful': wasSuccessful,
        'feeling': feeling,
        'notes': notes,
        'status': 'checked_in', // Final status after check-in
        'checkInTimestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Add createdAt only if we are effectively creating it (tricky without read)
        // Set with merge handles this reasonably well. If doc exists, createdAt isn't overwritten.
        // If doc doesn't exist, createdAt will be missing initially but can be added if needed.
      };
      
      // Use set with merge: creates if missing, updates if exists
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('pledges')
          .doc(pledgeId)
          .set(checkInData, SetOptions(merge: true));
          
      debugPrint('✅ Upserted pledge check-in in Firebase: $pledgeId (Created or Updated)');
    } catch (e) {
      debugPrint('❌ Error upserting pledge check-in in Firebase: $e');
      // If upsert fails, local SharedPreferences copy still exists
    }
  }
  
  // Save pledge check-in to Firebase (DEPRECATED - Use _updateFirebasePledgeCheckIn)
  // Future<void> _saveToFirebase({ ... }) { ... } // Keep old method commented or remove if confident

  // Update user's pledge statistics in their document and locally
  Future<void> _updateUserPledgeStats(String uid, bool wasSuccessful) async {
    int newTotalPledges = 0;
    int newSuccessfulPledges = 0;
    double successRate = 0.0;
    final nowTimestamp = DateTime.now().millisecondsSinceEpoch; // For local save
    
    // Attempt Firestore update first
    try {
      final userRef = _firestore.collection('users').doc(uid);

      // Use a transaction to ensure atomic read/write for stats
      await _firestore.runTransaction((transaction) async {
         final userDoc = await transaction.get(userRef);

         int currentTotalPledges = 0;
         int currentSuccessfulPledges = 0;
         
         if (userDoc.exists) {
           final userData = userDoc.data() ?? {};
           currentTotalPledges = (userData['totalPledges'] as int?) ?? 0;
           currentSuccessfulPledges = (userData['successfulPledges'] as int?) ?? 0;
         } else {
           debugPrint('⚠️ User document not found during pledge stats update transaction. Will create if needed.');
           // Initialize stats if document doesn't exist
         }

         // Calculate new stats
         newTotalPledges = currentTotalPledges + 1;
         newSuccessfulPledges = wasSuccessful ? currentSuccessfulPledges + 1 : currentSuccessfulPledges;
         successRate = newTotalPledges > 0 ? (newSuccessfulPledges.toDouble() / newTotalPledges.toDouble()) * 100 : 0.0;

         // Prepare updates for Firestore
         final Map<String, dynamic> updates = {
           'totalPledges': newTotalPledges,
           'successfulPledges': newSuccessfulPledges, // Make sure to include this
           'pledgeSuccessRate': successRate,
           'lastPledgeCheckInDate': FieldValue.serverTimestamp(),
           'updatedAt': FieldValue.serverTimestamp(),
         };
         
         // Add necessary fields if creating the document
         if (!userDoc.exists) {
           updates['uid'] = uid;
           updates['createdAt'] = FieldValue.serverTimestamp(); // Add creation timestamp
           // Add other default fields if necessary for a new user doc during stats update
           transaction.set(userRef, updates, SetOptions(merge: true));
           debugPrint('📈 Created user document and set initial pledge stats via transaction.');
         } else {
           // Perform the update within the transaction
           transaction.update(userRef, updates);
           debugPrint('📈 Updated user pledge stats via transaction: Total=$newTotalPledges, Successful=$newSuccessfulPledges');
         }
      }); // End of transaction
      debugPrint('✅ Firestore pledge stats update successful.');
    } catch (e) {
      debugPrint('❌ Error updating user pledge stats in Firestore: $e');
      // Firestore update failed, but we will still attempt to update local stats
      // We need to calculate the stats based on the *local* values if Firestore failed
      final prefs = await SharedPreferences.getInstance();
      final localTotal = prefs.getInt(_localTotalPledgesKey) ?? 0;
      final localSuccessful = prefs.getInt(_localSuccessfulPledgesKey) ?? 0;
      
      newTotalPledges = localTotal + 1;
      newSuccessfulPledges = wasSuccessful ? localSuccessful + 1 : localSuccessful;
      successRate = newTotalPledges > 0 ? (newSuccessfulPledges.toDouble() / newTotalPledges.toDouble()) * 100 : 0.0;
      debugPrint('📉 Firestore failed, calculated stats based on local fallback: Total=$newTotalPledges, Successful=$newSuccessfulPledges');
    }
    
    // Always update SharedPreferences as a fallback/local source
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_localTotalPledgesKey, newTotalPledges);
      await prefs.setInt(_localSuccessfulPledgesKey, newSuccessfulPledges);
      await prefs.setDouble(_localPledgeSuccessRateKey, successRate);
      await prefs.setInt(_localLastCheckInTimestampKey, nowTimestamp); // Save timestamp as ms
      debugPrint('✅ Saved/Updated pledge stats fallback in SharedPreferences.');
    } catch (e) {
      debugPrint('❌ Error updating pledge stats fallback in SharedPreferences: $e');
    }
  }
  
  // Get pledge history from both sources
  Future<List<Map<String, dynamic>>> getPledgeHistory({int limit = 30}) async {
    final List<Map<String, dynamic>> pledges = [];
    
    // Try to get from Firebase first
    final firebasePledges = await _getFirebasePledgeHistory(limit);
    if (firebasePledges.isNotEmpty) {
      pledges.addAll(firebasePledges);
    } else {
      // Fallback to SharedPreferences if Firebase fails or returns empty
      final localPledges = await _getLocalPledgeHistory(limit);
      pledges.addAll(localPledges);
    }
    
    return pledges;
  }
  
  // Get pledge history from Firebase
  Future<List<Map<String, dynamic>>> _getFirebasePledgeHistory(int limit) async {
    final List<Map<String, dynamic>> pledges = [];
    
    // Only get from Firebase if user is logged in
    if (_auth.currentUser == null) {
      return pledges;
    }
    
    try {
      final uid = _auth.currentUser!.uid;
      
      // Query the user's pledges subcollection
      // Order by start timestamp now, as that's the unique ID and represents creation order better
      final querySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('pledges')
          .orderBy('startTimestamp', descending: true) // Order by start time
          .limit(limit)
          .get();
      
      // Convert each document to a map
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        // Add Firestore Timestamps directly or convert if needed by UI
         pledges.add({
           ...data,
           // Ensure dates are converted if UI expects DateTime
           'startDate': (data['startDate'] as Timestamp?)?.toDate(),
           'endDate': (data['endDate'] as Timestamp?)?.toDate(),
           'checkInTimestamp': (data['checkInTimestamp'] as Timestamp?)?.toDate(),
           'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
           'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate(),
           'actualEndTime': (data['actualEndTime'] as Timestamp?)?.toDate(),
         });
      }
      
      debugPrint('✅ Fetched ${pledges.length} pledges from Firebase.');
      return pledges;
    } catch (e) {
      debugPrint('❌ Error getting Firebase pledge history: $e');
      return [];
    }
  }
  
  // Get pledge history from SharedPreferences
  Future<List<Map<String, dynamic>>> _getLocalPledgeHistory(int limit) async {
    final List<Map<String, dynamic>> pledges = [];
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // Get all keys and filter for pledge-related ones
      final keys = prefs.getKeys();
      final completedKeys = keys.where((key) => key.startsWith('pledge_completed_')).toList();
      
      // Sort by date (descending)
      completedKeys.sort((a, b) => b.compareTo(a));
      
      // Limit the number of entries
      final limitedKeys = completedKeys.take(limit).toList();
      
      // Process each key
      for (final key in limitedKeys) {
        final dateString = key.replaceFirst('pledge_completed_', '');
        
        // Extract the completed status
        final wasSuccessful = prefs.getBool(key) ?? false;
        
        // Try to get feeling and notes
        final feelingKey = 'pledge_feeling_$dateString';
        final notesKey = 'pledge_notes_$dateString';
        
        final feeling = prefs.getString(feelingKey) ?? 'Unknown';
        final notes = prefs.getString(notesKey);
        
        // Parse the date
        DateTime? date;
        try {
          final parts = dateString.split('-');
          if (parts.length == 3) {
            date = DateTime(
              int.parse(parts[0]), 
              int.parse(parts[1]), 
              int.parse(parts[2]),
            );
          }
        } catch (e) {
          debugPrint('❌ Error parsing date: $dateString');
        }
        
        // Add to the list
        pledges.add({
          'endDate': date,
          'wasSuccessful': wasSuccessful,
          'feeling': feeling,
          'notes': notes,
        });
      }
      
      return pledges;
    } catch (e) {
      debugPrint('❌ Error getting local pledge history: $e');
      return [];
    }
  }
} 