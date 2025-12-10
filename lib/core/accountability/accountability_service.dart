import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stoppr/features/accountability/data/models/accountability_partner.dart';
import 'package:stoppr/features/accountability/data/models/partnership.dart';
import 'package:stoppr/features/accountability/data/repositories/accountability_repository.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/core/analytics/crashlytics_service.dart';
import 'package:stoppr/core/subscription/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service for managing accountability partnerships
/// Provides high-level business logic for finding partners, accepting requests, and managing partnerships
class AccountabilityService {
  AccountabilityService._internal();
  static final AccountabilityService instance = AccountabilityService._internal();

  final AccountabilityRepository _repository = AccountabilityRepository();
  final StreakService _streakService = StreakService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  StreamSubscription<AccountabilityPartner?>? _partnerSubscription;
  final StreamController<AccountabilityPartner?> _partnerStreamController =
      StreamController<AccountabilityPartner?>.broadcast();

  AccountabilityPartner? _currentPartner;

  /// Stream of current accountability partner data
  Stream<AccountabilityPartner?> get partnerStream => _partnerStreamController.stream;

  /// Current accountability partner (cached)
  AccountabilityPartner? get currentPartner => _currentPartner;

  /// Initialize service and start listening to partner changes
  Future<void> initialize() async {
    debugPrint('AccountabilityService: Initializing...');

    // Listen to partner data changes
    _partnerSubscription?.cancel();
    _partnerSubscription = _repository.watchMyPartnerData().listen((partner) {
      _currentPartner = partner;
      _partnerStreamController.add(partner);
      debugPrint('AccountabilityService: Partner updated: ${partner?.partnerId ?? "no partner"}');
    });
  }

  /// Dispose service and clean up resources
  void dispose() {
    _partnerSubscription?.cancel();
    _partnerStreamController.close();
  }

  /// Get current user's first name from SharedPreferences
  Future<String> _getMyFirstName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('user_first_name');
      if (firstName != null && firstName.isNotEmpty) {
        return firstName;
      }

      // Fallback to Firebase Auth display name
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.displayName != null) {
        return currentUser!.displayName!.split(' ')[0];
      }

      return 'User';
    } catch (e) {
      debugPrint('Error getting first name: $e');
      return 'User';
    }
  }

  /// Check if user is subscribed (for pool eligibility)
  /// Uses RevenueCat via SubscriptionService as source of truth
  Future<bool> _isSubscribed() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final isPaid = await _subscriptionService.isPaidSubscriber(userId);
      debugPrint('AccountabilityService: Subscription check via RevenueCat: $isPaid');
      return isPaid;
    } catch (e) {
      debugPrint('AccountabilityService: Error checking subscription via RevenueCat: $e');
      return false;
    }
  }

  /// Join the accountability pool to find a random partner
  /// Returns true if successfully joined pool
  Future<bool> joinPool() async {
    try {
      debugPrint('AccountabilityService: Joining pool...');

      // Check if already in pool
      final isInPool = await _repository.isInPool();
      if (isInPool) {
        debugPrint('AccountabilityService: Already in pool');
        return true;
      }

      // Check if already has active partnership
      final hasActive = await _repository.hasActivePartnership();
      if (hasActive) {
        debugPrint('AccountabilityService: Already has active partnership');
        throw Exception('You already have an accountability partner');
      }

      // Check subscription status
      final isSubscribed = await _isSubscribed();
      if (!isSubscribed) {
        debugPrint('AccountabilityService: Not subscribed');
        throw Exception('Active subscription required to join pool');
      }

      final firstName = await _getMyFirstName();
      final currentStreak = _streakService.currentStreak.days;

      await _repository.joinPool(
        firstName: firstName,
        currentStreak: currentStreak,
        isSubscribed: isSubscribed,
      );

      debugPrint('AccountabilityService: Successfully joined pool');
      return true;
    } catch (e, stackTrace) {
      debugPrint('AccountabilityService: Error joining pool: $e');
      // Only log critical Firestore errors, not business logic errors
      if (e.toString().contains('firestore') || 
          e.toString().contains('permission') ||
          e.toString().contains('unavailable')) {
        CrashlyticsService.logException(
          e,
          stackTrace,
          reason: '[Accountability] CRITICAL: Failed to join pool',
        );
      }
      rethrow;
    }
  }

  /// Leave the accountability pool
  Future<void> leavePool() async {
    try {
      await _repository.leavePool();
      debugPrint('AccountabilityService: Left pool');
    } catch (e) {
      debugPrint('AccountabilityService: Error leaving pool: $e');
      rethrow;
    }
  }

  /// Check if currently in the pool
  Future<bool> isInPool() async {
    return await _repository.isInPool();
  }

  /// Send a partnership request to a specific user (for invite flow)
  /// Returns the created partnership
  Future<Partnership> sendPartnerRequest({
    required String partnerId,
    required String partnerName,
    required String inviteMethod,
  }) async {
    try {
      debugPrint('AccountabilityService: Sending partner request to $partnerId');

      // Check if already has active partnership
      final hasActive = await _repository.hasActivePartnership();
      if (hasActive) {
        throw Exception('You already have an accountability partner');
      }

      final myName = await _getMyFirstName();

      final partnership = await _repository.createPartnership(
        partnerId: partnerId,
        partnerName: partnerName,
        myName: myName,
        inviteMethod: inviteMethod,
      );

      debugPrint('AccountabilityService: Partnership request sent: ${partnership.id}');
      return partnership;
    } catch (e) {
      debugPrint('AccountabilityService: Error sending partner request: $e');
      rethrow;
    }
  }

  /// Accept a pending partnership request
  /// 
  /// Note: Only updates the partnership document to 'active'.
  /// The Cloud Function `onPartnershipUpdated` automatically:
  /// - Ends any existing active partnerships for both users
  /// - Updates accountabilityPartner field for BOTH users with current streak data
  /// - Sends notifications to both users
  Future<void> acceptPartnerRequest(String partnershipId) async {
    try {
      debugPrint('AccountabilityService: Accepting partnership $partnershipId');

      // Get partnership details
      final partnership = await _repository.getPartnership(partnershipId);
      if (partnership == null) {
        throw Exception('Partnership not found');
      }

      // Check if already has active partnership
      final hasActive = await _repository.hasActivePartnership();
      if (hasActive) {
        throw Exception('You already have an accountability partner');
      }

      // Accept partnership - Cloud Function handles user document updates
      await _repository.acceptPartnership(partnershipId);

      debugPrint('AccountabilityService: Partnership accepted. Cloud Function will update user documents and send notifications.');
    } catch (e, stackTrace) {
      debugPrint('AccountabilityService: Error accepting partnership: $e');
      // Log critical partnership acceptance failures
      CrashlyticsService.logException(
        e,
        stackTrace,
        reason: '[Accountability] CRITICAL: Failed to accept partnership',
      );
      CrashlyticsService.setCustomKey('failed_partnership_id', partnershipId);
      rethrow;
    }
  }

  /// Decline a pending partnership request
  Future<void> declinePartnerRequest(String partnershipId) async {
    try {
      debugPrint('AccountabilityService: Declining partnership $partnershipId');
      await _repository.declinePartnership(partnershipId);
      debugPrint('AccountabilityService: Partnership declined');
    } catch (e) {
      debugPrint('AccountabilityService: Error declining partnership: $e');
      rethrow;
    }
  }

  /// Unpair from current accountability partner
  /// 
  /// Note: Only updates the partnership document to 'ended'.
  /// The Cloud Function `onPartnershipUpdated` automatically:
  /// - Removes accountabilityPartner field from BOTH users
  /// - Sends notification to the other partner
  Future<void> unpair({String endReason = 'manual'}) async {
    try {
      debugPrint('AccountabilityService: Unpairing (reason: $endReason)');

      // Get active partnership
      final partnership = await _repository.getActivePartnership();
      if (partnership == null) {
        debugPrint('AccountabilityService: No active partnership to unpair');
        return;
      }

      // End partnership - Cloud Function handles user document cleanup
      await _repository.endPartnership(
        partnership.id,
        endReason: endReason,
      );

      debugPrint('AccountabilityService: Partnership ended. Cloud Function will clean up user documents.');
    } catch (e, stackTrace) {
      debugPrint('AccountabilityService: Error unpairing: $e');
      // Log critical unpair failures
      CrashlyticsService.logException(
        e,
        stackTrace,
        reason: '[Accountability] CRITICAL: Failed to unpair partner',
      );
      CrashlyticsService.setCustomKey('unpair_reason', endReason);
      rethrow;
    }
  }

  /// Get all pending partnership requests for current user
  Future<List<Partnership>> getPendingRequests() async {
    try {
      final requests = await _repository.getPendingRequests();
      
      // Filter to only show requests sent TO current user (not BY current user)
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      return requests.where((req) => req.initiatedBy != currentUserId).toList();
    } catch (e) {
      debugPrint('AccountabilityService: Error getting pending requests: $e');
      return [];
    }
  }

  /// Get active partnership details
  Future<Partnership?> getActivePartnership() async {
    return await _repository.getActivePartnership();
  }

  /// Sync partner's current streak (called periodically or on-demand)
  Future<void> syncPartnerStreak() async {
    try {
      if (_currentPartner?.partnerId == null) {
        debugPrint('AccountabilityService: No partner to sync');
        return;
      }

      final partnerData = await _repository.getPartnerUserData(
        _currentPartner!.partnerId!,
      );

      if (partnerData == null) {
        debugPrint('AccountabilityService: Partner data not found');
        return;
      }

      final partnerStreak = partnerData['currentStreak'] as int? ?? 0;

      // Update if streak changed
      if (_currentPartner!.partnerStreak != partnerStreak) {
        await _repository.updateMyPartnerData(
          _currentPartner!.copyWith(
            partnerStreak: partnerStreak,
            lastSyncedAt: DateTime.now(),
          ),
        );
        debugPrint('AccountabilityService: Partner streak synced: $partnerStreak');
      }
    } catch (e) {
      debugPrint('AccountabilityService: Error syncing partner streak: $e');
    }
  }

  /// Check if user has an active partner
  bool get hasActivePartner {
    return _currentPartner?.status == 'paired' && 
           _currentPartner?.partnerId != null;
  }

  /// Check if user has pending requests
  Future<bool> hasPendingRequests() async {
    final requests = await getPendingRequests();
    return requests.isNotEmpty;
  }

  /// DEBUG ONLY: Create fake pool users for testing
  /// Call this once in debug mode to populate the pool
  Future<void> createDebugPoolUsers() async {
    if (!kDebugMode) {
      debugPrint('createDebugPoolUsers() only works in debug mode');
      return;
    }

    debugPrint('Creating debug pool users...');
    
    final fakeUsers = [
      {'firstName': 'Sarah', 'streak': 45},
      {'firstName': 'Mike', 'streak': 23},
      {'firstName': 'Emma', 'streak': 78},
      {'firstName': 'Alex', 'streak': 12},
      {'firstName': 'Lisa', 'streak': 56},
    ];

    for (var user in fakeUsers) {
      try {
        await _repository.createDebugPoolEntry(
          firstName: user['firstName'] as String,
          currentStreak: user['streak'] as int,
        );
        debugPrint('Created debug user: ${user['firstName']} (${user['streak']} days)');
      } catch (e) {
        debugPrint('Error creating debug user ${user['firstName']}: $e');
      }
    }

    debugPrint('✅ Debug pool users created!');
  }
}


