import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:stoppr/features/accountability/data/models/accountability_partner.dart';
import 'package:stoppr/features/accountability/data/models/partnership.dart';

/// Repository for managing accountability partnerships in Firestore
/// Handles all CRUD operations for partnerships, pool entries, and partner data
class AccountabilityRepository {
  AccountabilityRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _currentUserId => _auth.currentUser?.uid;

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _partnershipsCollection =>
      _firestore.collection('accountability_partnerships');
  CollectionReference get _poolCollection =>
      _firestore.collection('accountability_pool');

  /// Get current user's accountability partner data from their user document
  Future<AccountabilityPartner?> getMyPartnerData() async {
    if (_currentUserId == null) return null;

    try {
      final doc = await _usersCollection.doc(_currentUserId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('accountabilityPartner')) {
        return null;
      }

      return AccountabilityPartner.fromJson(
        data['accountabilityPartner'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Error getting partner data: $e');
      return null;
    }
  }

  /// Stream of current user's accountability partner data
  Stream<AccountabilityPartner?> watchMyPartnerData() {
    if (_currentUserId == null) {
      return Stream.value(null);
    }

    return _usersCollection.doc(_currentUserId).snapshots().map((doc) {
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('accountabilityPartner')) {
        return null;
      }

      return AccountabilityPartner.fromJson(
        data['accountabilityPartner'] as Map<String, dynamic>,
      );
    });
  }

  /// Update current user's accountability partner data
  Future<void> updateMyPartnerData(AccountabilityPartner partner) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    await _usersCollection.doc(_currentUserId).set({
      'accountabilityPartner': partner.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get a specific partnership by ID
  Future<Partnership?> getPartnership(String partnershipId) async {
    try {
      final doc = await _partnershipsCollection.doc(partnershipId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return Partnership.fromJson({
        'id': doc.id,
        ...data,
      });
    } catch (e) {
      debugPrint('Error getting partnership: $e');
      return null;
    }
  }

  /// Stream of partnerships where current user is involved
  Stream<List<Partnership>> watchMyPartnerships() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _partnershipsCollection
        .where(
          Filter.or(
            Filter('user1Id', isEqualTo: _currentUserId),
            Filter('user2Id', isEqualTo: _currentUserId),
          ),
        )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Partnership.fromJson({
          'id': doc.id,
          ...data,
        });
      }).toList();
    });
  }

  /// Get all pending partnership requests for current user
  Future<List<Partnership>> getPendingRequests() async {
    if (_currentUserId == null) return [];

    try {
      final query = await _partnershipsCollection
          .where('status', isEqualTo: 'pending')
          .where(
            Filter.or(
              Filter('user1Id', isEqualTo: _currentUserId),
              Filter('user2Id', isEqualTo: _currentUserId),
            ),
          )
          .get();

      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Partnership.fromJson({
          'id': doc.id,
          ...data,
        });
      }).toList();
    } catch (e) {
      debugPrint('Error getting pending requests: $e');
      return [];
    }
  }

  /// Get outgoing pending partnership requests (sent by current user)
  /// Used to prevent duplicate requests to the same user
  Future<List<Partnership>> getOutgoingPendingRequests() async {
    if (_currentUserId == null) return [];

    try {
      final query = await _partnershipsCollection
          .where('status', isEqualTo: 'pending')
          .where('initiatedBy', isEqualTo: _currentUserId)
          .get();

      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Partnership.fromJson({
          'id': doc.id,
          ...data,
        });
      }).toList();
    } catch (e) {
      debugPrint('Error getting outgoing pending requests: $e');
      return [];
    }
  }

  /// Create a new partnership request
  Future<Partnership> createPartnership({
    required String partnerId,
    required String partnerName,
    required String myName,
    required String inviteMethod,
  }) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final now = DateTime.now();
    final partnershipData = {
      'user1Id': _currentUserId,
      'user2Id': partnerId,
      'user1Name': myName,
      'user2Name': partnerName,
      'status': 'pending',
      'initiatedBy': _currentUserId,
      'inviteMethod': inviteMethod,
      'createdAt': Timestamp.fromDate(now),
      'acceptedAt': null,
      'endedAt': null,
      'endedBy': null,
      'endReason': null,
    };

    final docRef = await _partnershipsCollection.add(partnershipData);

    // Notify recipient (best-effort, ignore errors in repository layer)
    try {
      // Write a simple marker under recipient for UI polling if needed
      await _usersCollection.doc(partnerId).set({
        'accountabilityRequestFrom': myName,
        'accountabilityRequestAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    return Partnership.fromJson({
      'id': docRef.id,
      ...partnershipData,
    });
  }

  /// Accept a partnership request
  Future<void> acceptPartnership(String partnershipId) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    await _partnershipsCollection.doc(partnershipId).update({
      'status': 'active',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Decline a partnership request
  Future<void> declinePartnership(String partnershipId) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    await _partnershipsCollection.doc(partnershipId).update({
      'status': 'declined',
    });
  }

  /// End an active partnership (unpair)
  Future<void> endPartnership(
    String partnershipId, {
    required String endReason,
  }) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    await _partnershipsCollection.doc(partnershipId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'endedBy': _currentUserId,
      'endReason': endReason,
    });
  }

  /// Add current user to the accountability pool for random matching
  Future<void> joinPool({
    required String firstName,
    required int currentStreak,
    required bool isSubscribed,
  }) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final now = DateTime.now();
    final poolData = {
      'userId': _currentUserId,
      'firstName': firstName,
      'currentStreak': currentStreak,
      'lookingForPartner': true,
      'addedToPoolAt': Timestamp.fromDate(now),
      'isSubscribed': isSubscribed,
      'lastActive': Timestamp.fromDate(now),
      'preferences': {
        'streakRange': 'any',
      },
    };

    await _poolCollection.doc(_currentUserId).set(poolData);
  }

  /// Remove current user from the accountability pool
  Future<void> leavePool() async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    await _poolCollection.doc(_currentUserId).delete();
  }

  /// Check if current user is in the pool
  Future<bool> isInPool() async {
    if (_currentUserId == null) return false;

    try {
      final doc = await _poolCollection.doc(_currentUserId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking pool status: $e');
      return false;
    }
  }

  /// Get list of users in the pool (for displaying available partners)
  /// Fetches live streak data from users collection for accurate display
  Future<List<PoolEntry>> getPoolUsers({int limit = 20}) async {
    try {
      final querySnapshot = await _poolCollection
          .where('lookingForPartner', isEqualTo: true)
          .where('isSubscribed', isEqualTo: true)
          .limit(limit)
          .get();

      final poolEntries = <PoolEntry>[];
      
      for (final doc in querySnapshot.docs) {
        try {
          final poolData = doc.data() as Map<String, dynamic>;
          final userId = doc.id;
          
          // Fetch live user data from users collection
          int currentStreak = poolData['currentStreak'] ?? 0;
          bool isCurrentlySubscribed = false;
          bool isFreshData = false; // Default to false if data can't be fetched
          
          try {
            final userDoc = await _usersCollection.doc(userId).get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>?;
              if (userData != null) {
                // Use live streak data
                currentStreak = userData['currentStreakDays'] ?? currentStreak;
                
                // CRITICAL: Check if subscription data is fresh (synced with RevenueCat in last 7 days)
                final subscriptionUpdatedAt = userData['subscriptionUpdatedAt'] as Timestamp?;
                final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
                final isFreshData = subscriptionUpdatedAt != null && 
                    subscriptionUpdatedAt.toDate().isAfter(sevenDaysAgo);
                
                // Use RevenueCat-synced Firestore data as source of truth (ALWAYS check, even in debug)
                final subscriptionStatus = userData['subscriptionStatus'] as String?;
                final subscriptionExpirationTimestamp = userData['subscriptionExpirationDate'] as Timestamp?;
                final isTrialActive = (userData['isTrialActive'] as bool?) ?? false;
                final trialExpirationTimestamp = userData['trialExpirationDate'] as Timestamp?;
                final subscriptionProductId = userData['subscriptionProductId'] as String?;
                
                // Check if subscription is one of the valid paid types
                final bool hasPaidStatus = subscriptionStatus == 'paid_standard' || 
                                           subscriptionStatus == 'paid_gift' || 
                                           subscriptionStatus == 'paid_lifetime' ||
                                           subscriptionStatus == 'free_apple_promo' ||
                                           subscriptionStatus == 'free_android_promo';
                
                // Check if trial period is still valid (even if canceled, as long as not expired)
                bool hasActiveTrial = false;
                if (trialExpirationTimestamp != null) {
                  final trialExpirationDate = trialExpirationTimestamp.toDate();
                  // User has access if trial hasn't expired, regardless of cancellation status
                  hasActiveTrial = DateTime.now().isBefore(trialExpirationDate);
                }
                
                // Check if paid subscription hasn't expired
                bool subscriptionNotExpired = true;
                if (hasPaidStatus && subscriptionStatus != 'paid_lifetime') {
                  if (subscriptionExpirationTimestamp != null) {
                    final expirationDate = subscriptionExpirationTimestamp.toDate();
                    subscriptionNotExpired = DateTime.now().isBefore(expirationDate);
                  } else {
                    // LENIENT: If no expiration date but has paid status AND product ID, assume active
                    // This handles cases where Firestore sync is incomplete but RevenueCat shows active
                    subscriptionNotExpired = subscriptionProductId != null && subscriptionProductId.isNotEmpty;
                  }
                }
                
                // User must have: (paid status AND not expired) OR active unexpired trial
                isCurrentlySubscribed = (hasPaidStatus && subscriptionNotExpired) || hasActiveTrial;
              }
            }
          } catch (e) {
            debugPrint('Error fetching live data for user $userId: $e');
            // Fall back to pool data on error
          }
          
          // Only include users with active subscriptions (or all users in debug)
          if (!isCurrentlySubscribed) continue;
          
          // CRITICAL: Skip users whose subscription data is stale (not synced with RevenueCat in 7 days)
          if (!isFreshData) continue;
          
          // Include ALL users, even with streak 0 - they need accountability partners the most!
          
          final entry = PoolEntry.fromJson({
            ...poolData,
            'userId': userId,
            'currentStreak': currentStreak, // Use live streak
          });
          
          poolEntries.add(entry);
        } catch (e) {
          debugPrint('Error parsing pool entry: $e');
        }
      }

      // Sort by streak (lowest first - prioritize users who need help)
      poolEntries.sort((a, b) => a.currentStreak.compareTo(b.currentStreak));

      return poolEntries;
    } catch (e) {
      debugPrint('Error getting pool users: $e');
      return [];
    }
  }

  /// Fallback: fetch available users directly from `users` collection when pool
  /// is sparsely populated (debug/TestFlight, early rollout, etc.). This only
  /// returns non-sample users and excludes the current user.
  /// 
  /// PRIORITIZES USERS WITH LOWEST STREAKS (including 0) - they need the most support!
  Future<List<PoolEntry>> getFallbackAvailableUsers({int limit = 30}) async {
    try {
      // Query for paying subscribers FIRST by subscription status
      // This ensures we only fetch users with active subscriptions
      final paidStatuses = [
        'paid_standard',
        'paid_gift',
        'paid_lifetime',
        'free_apple_promo',
        'free_android_promo',
      ];
      
      final entries = <PoolEntry>[];
      int totalDocumentsChecked = 0;
      
      // CRITICAL: Only fetch users who synced with RevenueCat recently (last 7 days)
      // This ensures Firestore data is fresh and matches RevenueCat's source of truth
      final sevenDaysAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 7)),
      );
      
      // Query each subscription status separately (Firestore limitation with 'in' operator)
      for (final subscriptionStatus in paidStatuses) {
        final snapshot = await _usersCollection
            .where('subscriptionStatus', isEqualTo: subscriptionStatus)
            .where('subscriptionUpdatedAt', isGreaterThan: sevenDaysAgo)
            .get();
        
        totalDocumentsChecked += snapshot.docs.length;

        for (final doc in snapshot.docs) {
          final userId = doc.id;
          if (userId == _currentUserId) continue;

          final data = (doc.data() as Map<String, dynamic>?) ?? {};

          final firstName = (data['firstName'] as String?)?.trim();
          if (firstName == null || firstName.isEmpty) continue;

          // Filter out sample/test/debug users
          final isSample = (data['sample'] as bool?) ?? false;
          final isDebugUser = (data['debugUser'] as bool?) ?? false;
          final isTestUser = (data['is_test_user'] as bool?) ?? false;
          final isFakeUser = (data['fakeUser'] as bool?) ?? false;
          if (isSample || isDebugUser || isTestUser || isFakeUser) continue;

          // Double-check subscription is still active (expiration dates)
          final subscriptionExpirationTimestamp = data['subscriptionExpirationDate'] as Timestamp?;
          final trialExpirationTimestamp = data['trialExpirationDate'] as Timestamp?;
          final subscriptionProductId = data['subscriptionProductId'] as String?;
          
          // Check if trial period is still valid
          bool hasActiveTrial = false;
          if (trialExpirationTimestamp != null) {
            final trialExpirationDate = trialExpirationTimestamp.toDate();
            hasActiveTrial = DateTime.now().isBefore(trialExpirationDate);
          }
          
          // Check if paid subscription hasn't expired
          bool subscriptionNotExpired = true;
          if (subscriptionStatus != 'paid_lifetime' && subscriptionStatus != 'free_apple_promo' && subscriptionStatus != 'free_android_promo') {
            if (subscriptionExpirationTimestamp != null) {
              final expirationDate = subscriptionExpirationTimestamp.toDate();
              subscriptionNotExpired = DateTime.now().isBefore(expirationDate);
            } else {
              // LENIENT: If no expiration date but has product ID, assume active
              subscriptionNotExpired = subscriptionProductId != null && subscriptionProductId.isNotEmpty;
            }
          }
          
          // Skip if subscription expired
          if (!subscriptionNotExpired && !hasActiveTrial) {
            continue;
          }

          // Skip if already paired
          final partnerData = data['accountabilityPartner'] as Map<String, dynamic>?;
          final partnerStatus = partnerData != null ? (partnerData['status'] as String?) : null;
          if (partnerStatus == 'paired' || partnerStatus == 'active') continue;

          // Use currentStreakDays field
          final currentStreak = (data['currentStreakDays'] as int?) ?? 0;

          try {
            entries.add(
              PoolEntry.fromJson({
                'userId': userId,
                'firstName': firstName,
                'currentStreak': currentStreak,
                'lookingForPartner': true,
                'isSubscribed': true,
                'addedToPoolAt': Timestamp.now(),
                'lastActive': data['lastActive'] ?? Timestamp.now(),
              }),
            );
          } catch (e) {
            debugPrint('Error building fallback PoolEntry for $userId: $e');
          }
        }
      }

      // Sort by streak (lowest first - prioritize users who need help)
      entries.sort((a, b) => a.currentStreak.compareTo(b.currentStreak));

      // Return up to 'limit' entries (but we processed ALL to find the best matches)
      return entries.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting fallback users: $e');
      return [];
    }
  }

  /// Get partner's user data (first name and current streak)
  Future<Map<String, dynamic>?> getPartnerUserData(String partnerId) async {
    try {
      final doc = await _usersCollection.doc(partnerId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      return {
        'firstName': data['firstName'] as String?,
        'currentStreak': data['currentStreakDays'] as int? ?? 0,
        'lastActive': data['lastActive'],
      };
    } catch (e) {
      debugPrint('Error getting partner user data: $e');
      return null;
    }
  }

  /// DEBUG ONLY: Create a fake pool entry for testing
  Future<void> createDebugPoolEntry({
    required String firstName,
    required int currentStreak,
  }) async {
    if (!kDebugMode) return;

    final fakeUserId = 'debug_${firstName.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
    
    final poolData = {
      'userId': fakeUserId,
      'firstName': firstName,
      'currentStreak': currentStreak,
      'lookingForPartner': true,
      'isSubscribed': true,
      'addedToPoolAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    };

    await _poolCollection.doc(fakeUserId).set(poolData);
  }

  /// Get all partnerships for a user (for admin/debugging)
  Future<List<Partnership>> getAllPartnershipsForUser(String userId) async {
    try {
      final query = await _partnershipsCollection
          .where(
            Filter.or(
              Filter('user1Id', isEqualTo: userId),
              Filter('user2Id', isEqualTo: userId),
            ),
          )
          .get();

      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Partnership.fromJson({
          'id': doc.id,
          ...data,
        });
      }).toList();
    } catch (e) {
      debugPrint('Error getting all partnerships: $e');
      return [];
    }
  }

  /// Check if user has an active partnership
  Future<bool> hasActivePartnership() async {
    if (_currentUserId == null) return false;

    try {
      final query = await _partnershipsCollection
          .where('status', isEqualTo: 'active')
          .where(
            Filter.or(
              Filter('user1Id', isEqualTo: _currentUserId),
              Filter('user2Id', isEqualTo: _currentUserId),
            ),
          )
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking active partnership: $e');
      return false;
    }
  }

  /// Get active partnership for current user
  Future<Partnership?> getActivePartnership() async {
    if (_currentUserId == null) return null;

    try {
      final query = await _partnershipsCollection
          .where('status', isEqualTo: 'active')
          .where(
            Filter.or(
              Filter('user1Id', isEqualTo: _currentUserId),
              Filter('user2Id', isEqualTo: _currentUserId),
            ),
          )
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      return Partnership.fromJson({
        'id': doc.id,
        ...data,
      });
    } catch (e) {
      debugPrint('Error getting active partnership: $e');
      return null;
    }
  }
}
