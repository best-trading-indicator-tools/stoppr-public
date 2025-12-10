import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide LogLevel;
import '../repositories/user_repository.dart';
import '../analytics/mixpanel_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stoppr/core/notifications/notification_service.dart';

/// A centralized service for managing and checking subscription status across the app.
/// 
/// This service provides a single source of truth for determining if a user is a paid
/// subscriber by checking both Superwall status and Firebase data.
class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();
  
  // The stream controller and listener have been removed to prevent a MissingPluginException
  // on app start. Subscription status is now handled exclusively by the
  // SuperwallDelegate's `subscriptionStatusDidChange` method in `main.dart`.
  
  /// Checks if the user is a paid subscriber based ONLY on Superwall and RevenueCat status.
  /// 
  /// This method prioritizes checks in the following order:
  /// 1. Superwall's subscription status (checks if it's ".active")
  /// 2. RevenueCat's `CustomerInfo` (checks `hasActiveEntitlementOrSubscription`)
  /// 
  /// Returns true if either check indicates an active paid subscription.
  /// Firebase data is NO LONGER consulted for granting access.
  Future<bool> isPaidSubscriber(String? userId) async {
    // --- ADDED: Allow debug/TestFlight builds ---
    if (kDebugMode) {
      debugPrint('SubscriptionService: Granting access for kDebugMode');
      return true;
    }
    try {
      final isTF = await MixpanelService.isTestFlight();
      if (isTF) {
        debugPrint('SubscriptionService: Granting access for TestFlight build');
        return true;
      }
    } catch (_) {}

    // --- ADDED: Special check for test/admin emails --- 
    final currentUser = _auth.currentUser;
    if (currentUser?.email == 'applereviews2025@gmail.com' || currentUser?.email == 'hello@stoppr.app') {
      debugPrint('SubscriptionService: Granting access for special test/admin email: ${currentUser?.email}');
      return true;
    }
    // --- END ADDED ---
    
    if (userId == null) {
      userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('SubscriptionService: No user ID provided and no user is logged in');
        return false;
      }
    }
    
    debugPrint('SubscriptionService: Checking if user $userId is a paid subscriber via Superwall/RevenueCat');
    
    // Check #1: Superwall status
    bool isActiveInSuperwall = false;
    try {
      final status = await Superwall.shared.getSubscriptionStatus();
      isActiveInSuperwall = status is SubscriptionStatusActive;
      
      if (isActiveInSuperwall) {
        debugPrint('SubscriptionService: User is active in Superwall');
        return true;
      }
    } catch (e) {
      debugPrint('SubscriptionService: Error checking Superwall status: $e');
      // Don't return false yet, proceed to RevenueCat check
    }
    
    // Check #2: RevenueCat status
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      // Check if either activeSubscriptions or active entitlements exist
      final bool hasActiveRcSubscription = 
          customerInfo.activeSubscriptions.isNotEmpty || 
          customerInfo.entitlements.active.isNotEmpty;
      
      if (hasActiveRcSubscription) {
        debugPrint('SubscriptionService: User has active subscription/entitlement in RevenueCat');
        return true;
      }
      
      // If we reach here, user is not active in Superwall or RevenueCat
      debugPrint('SubscriptionService: User is not a paid subscriber based on Superwall/RevenueCat checks');
      return false;
    } catch (e) {
      debugPrint('SubscriptionService: Error checking RevenueCat customer info: $e');
      // If both Superwall and RevenueCat checks fail or error out, assume not subscribed
      debugPrint('SubscriptionService: Returning false due to error in RevenueCat check');
      return false;
    }
  }
  
  /// Gets the detailed subscription information for a user.
  /// 
  /// Returns a [SubscriptionInfo] object containing:
  /// - The subscription type (free, paid_standard, paid_gift)
  /// - The product ID (if available)
  /// - Whether the user is a paid subscriber (ONLY based on Superwall/RevenueCat)
  Future<SubscriptionInfo> getSubscriptionInfo(String? userId) async {
    if (userId == null) {
      userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('SubscriptionService: No user ID provided and no user is logged in');
        return SubscriptionInfo(
          type: SubscriptionType.free,
          productId: null,
          isPaid: false,
        );
      }
    }
    
    // --- CRITICAL FIX: Only use Superwall/RevenueCat for access decisions ---
    // Check if user is actually paid according to payment systems (not Firebase)
    final bool isPaidUser = await isPaidSubscriber(userId);
    
    // Get product information from RevenueCat if available
    String? productId;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final activeSubscriptions = customerInfo.activeSubscriptions;
      
      if (activeSubscriptions.isNotEmpty) {
        productId = activeSubscriptions.first;
      }
    } catch (e) {
      debugPrint('SubscriptionService: Error getting RevenueCat customer info: $e');
    }
    
    // Determine subscription type based on actual payment status and product ID
    SubscriptionType type = SubscriptionType.free;
    
    if (isPaidUser) {
      // Check for lifetime purchase first
      if (productId != null && (productId.toLowerCase().contains('lifetime') ||
          productId == 'com.stoppr.lifetime' ||
          productId == 'com.stoppr.sugar.lifetime')) {
        type = SubscriptionType.paid_lifetime;
      // Check for gift subscription
      } else if (productId != null && productId.toLowerCase().contains('annual80off')) {
        type = SubscriptionType.paid_gift;
      } else {
        type = SubscriptionType.paid_standard;
      }
    }
    
    // Get product ID from Firebase only if not available from RevenueCat (for analytics)
    if (productId == null) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          productId = userDoc.data()!['subscriptionProductId'] as String?;
        }
      } catch (e) {
        debugPrint('SubscriptionService: Error getting Firebase product ID: $e');
      }
    }
    
    return SubscriptionInfo(
      type: type,
      productId: productId,
      isPaid: isPaidUser, // Only based on Superwall/RevenueCat
    );
  }
  
  /// Updates the local Firebase document with subscription information.
  /// This method is typically called by SuperwallPurchaseController but is
  /// provided here for convenience.
  Future<void> updateSubscriptionStatus(
    String userId, 
    SubscriptionType type, 
    {String? productId, DateTime? startDate, DateTime? expirationDate, DateTime? trialExpirationDate}
  ) async {
    try {
      await _userRepository.updateUserSubscriptionStatus(
        userId, 
        type, 
        productId: productId,
        startDate: startDate,
        expirationDate: expirationDate,
        trialExpirationDate: trialExpirationDate,
      );
      debugPrint('SubscriptionService: Updated subscription status for user $userId to $type, productId: $productId');
      if (startDate != null) {
        debugPrint('SubscriptionService: Subscription start date: ${startDate.toIso8601String()}');
      }
      if (trialExpirationDate != null) {
        debugPrint('SubscriptionService: Trial expiration date: ${trialExpirationDate.toIso8601String()}');
      }
      if (expirationDate != null) {
        debugPrint('SubscriptionService: Subscription expiration date: ${expirationDate.toIso8601String()}');
      }
    } catch (e) {
      debugPrint('SubscriptionService: Error updating subscription status: $e');
      throw e; // Rethrow for caller to handle
    }
  }
  
  /// Checks for unauthorized premium access by comparing Firebase data with actual subscription status
  /// This helps detect potential security breaches where users have Firebase premium data without payment
  Future<void> checkForUnauthorizedAccess(String? userId) async {
    if (userId == null) {
      userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('SubscriptionService: No user ID provided and no user is logged in');
        return;
      }
    }
    
    // Skip check for whitelisted test emails
    final currentUser = _auth.currentUser;
    if (currentUser?.email == 'applereviews2025@gmail.com' || currentUser?.email == 'hello@stoppr.app') {
      return;
    }
    
    try {
      // Check Superwall/RevenueCat status - actual subscription status
      bool hasRealSubscription = false;
      
      // Check #1: Superwall status
      try {
        final status = await Superwall.shared.getSubscriptionStatus();
        hasRealSubscription = status is SubscriptionStatusActive;
      } catch (e) {
        debugPrint('SubscriptionService: Error checking Superwall status: $e');
      }
      
      // Check #2: RevenueCat status if Superwall check failed
      if (!hasRealSubscription) {
        try {
          final customerInfo = await Purchases.getCustomerInfo();
          if (customerInfo.activeSubscriptions.isNotEmpty || 
              customerInfo.entitlements.active.isNotEmpty) {
            hasRealSubscription = true;
          }
        } catch (e) {
          debugPrint('SubscriptionService: Error checking RevenueCat status: $e');
        }
      }
      
      // Now check Firebase status
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists || userDoc.data() == null) {
        return; // No user document found
      }
      
      final data = userDoc.data()!;
      final subscriptionStatus = data['subscriptionStatus'] as String?;
      final subscriptionProductId = data['subscriptionProductId'] as String?;
      
      // Check if Firebase indicates premium but real payment systems don't
      bool hasPremiumInFirebase = 
          (subscriptionStatus == 'paid_standard' || 
           subscriptionStatus == 'paid_gift' ||
           subscriptionStatus == 'paid_lifetime' ||
           subscriptionStatus == 'free_apple_promo') ||
          (subscriptionProductId != null && subscriptionProductId.isNotEmpty);
      
      // ALERT: User has premium in Firebase but no real subscription
      if (hasPremiumInFirebase && !hasRealSubscription) {
        final deviceInfo = {
          'os': data['os'] as String? ?? 'unknown',
          'os_version': data['os_version'] as String? ?? 'unknown',
          'app_version': data['app_version'] as String? ?? 'unknown',
          'device_model': data['device_model'] as String? ?? 'unknown',
        };
        
        final Timestamp? signupDate = data['createdAt'] as Timestamp?;
        final String email = data['email'] as String? ?? 'unknown';
        final String displayName = data['displayName'] as String? ?? 'N/A';
        
        // Send alert via Mixpanel
        MixpanelService.trackEvent('Unauthorized Premium Access Detected', properties: {
          'user_id': userId,
          'email': email,
          'display_name': displayName,
          'subscription_status': subscriptionStatus ?? 'N/A',
          'subscription_product_id': subscriptionProductId ?? 'N/A',
          'signup_date': signupDate?.toDate().toIso8601String() ?? 'unknown',
          'detected_at': DateTime.now().toIso8601String(),
          'device_info': deviceInfo.toString(),
          'suspicious_access': true,
          'actionable_security_alert': true,
        });
        
        // Log to console for debugging
        debugPrint('🚨 SECURITY ALERT: Unauthorized premium access detected!');
        debugPrint('User ID: $userId, Email: $email');
        debugPrint('Firebase shows premium status, but no active subscription found in RevenueCat/Superwall');
        
        // Also record in a special Firestore collection for admin monitoring
        try {
          if (subscriptionProductId == 'apple_promo_code') {
            // User has an Apple promo code, log to 'influencers' collection
            await _firestore.collection('influencers').add({
              'user_id': userId,
              'email': email,
              'display_name': displayName,
              'subscription_product_id': subscriptionProductId,
              'firebase_subscription_status': subscriptionStatus, // It might be 'free' but product_id indicates promo
              'signup_date': signupDate,
              'promo_detected_at': FieldValue.serverTimestamp(),
              'device_info': deviceInfo,
              // Add any other relevant fields for influencers
            });
            debugPrint('User $userId logged to influencers collection due to apple_promo_code.');
          } else {
            // Original logic for other unauthorized access
            await _firestore.collection('security_alerts').add({
              'type': 'unauthorized_premium_access',
              'user_id': userId,
              'email': email,
              'display_name': displayName,
              'subscription_status': subscriptionStatus,
              'subscription_product_id': subscriptionProductId,
              'signup_date': signupDate,
              'detected_at': FieldValue.serverTimestamp(),
              'device_info': deviceInfo,
              'resolved': false,
            });
          }
        } catch (e) {
          debugPrint('Error recording security alert: $e');
        }
      }
    } catch (e) {
      debugPrint('SubscriptionService: Error checking for unauthorized access: $e');
    }
  }
  
  /// Check if user had a trial subscription but it expired (no active subscription now)
  Future<bool> hadExpiredTrial(String? userId) async {
    if (userId == null) {
      userId = _auth.currentUser?.uid;
      if (userId == null) return false;
    }
    
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      
      // Platform-specific trial product IDs
      final trialIds = Platform.isIOS 
        ? {'com.stoppr.app.annual.trial'} 
        : {'com.stoppr.sugar.app.annual.trial:com-stoppr-sugar-app-annual-trial'};
      
      // Check if they ever purchased a trial
      final hadTrial = customerInfo.allPurchasedProductIdentifiers.any((id) => trialIds.contains(id));
      
      // Check if no active subscription
      final noActiveSubscription = customerInfo.activeSubscriptions.isEmpty && customerInfo.entitlements.active.isEmpty;
      
      return hadTrial && noActiveSubscription;
    } catch (e) {
      debugPrint('SubscriptionService: Error checking expired trial status: $e');
      return false;
    }
  }
  
  void dispose() {
    // No-op. The stream controller has been removed.
  }
}

/// Container class for subscription information
class SubscriptionInfo {
  final SubscriptionType type;
  final String? productId;
  final bool isPaid;
  
  SubscriptionInfo({
    required this.type,
    this.productId,
    required this.isPaid,
  });
  
  @override
  String toString() => 'SubscriptionInfo(type: $type, productId: $productId, isPaid: $isPaid)';
} 