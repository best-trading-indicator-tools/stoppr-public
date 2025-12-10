import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/core/auth/models/app_user.dart';
import 'package:stoppr/features/onboarding/presentation/screens/congratulations/congratulations_screen_1.dart';

/// Centralized post-purchase handler for all paywalls
/// 
/// This utility handles the complete post-purchase flow:
/// 1. Resolves the purchased product ID from RevenueCat
/// 2. Updates Firestore subscription status
/// 3. Initializes streak
/// 4. Navigates to CongratulationsScreen1
class PostPurchaseHandler {
  static final UserRepository _userRepository = UserRepository();
  static final StreakService _streakService = StreakService();

  /// Handle post-purchase logic for all paywalls
  /// 
  /// [context] - BuildContext for navigation
  /// [defaultProductId] - Optional fallback product ID if RevenueCat query fails
  static Future<void> handlePostPurchase(
    BuildContext context, {
    String? defaultProductId,
  }) async {
    try {
      debugPrint('🎉 PostPurchaseHandler: Starting post-purchase flow');

      // Step 1: Resolve purchased product ID from RevenueCat
      final purchasedProductId = await _resolvePurchasedProductId(
        defaultProductId: defaultProductId,
      );
      debugPrint('✅ PostPurchaseHandler: Resolved product ID: $purchasedProductId');

      // Step 2: Update Firestore subscription status
      await _updateFirebaseSubscription(purchasedProductId);
      debugPrint('✅ PostPurchaseHandler: Updated Firestore subscription');

      // Step 3: Initialize streak
      await _initializeStreak();
      debugPrint('✅ PostPurchaseHandler: Initialized streak');

      // Step 4: Navigate to CongratulationsScreen1
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const CongratulationsScreen1(),
          ),
          (route) => false,
        );
        debugPrint('✅ PostPurchaseHandler: Navigated to CongratulationsScreen1');
      }
    } catch (e, stack) {
      debugPrint('❌ PostPurchaseHandler: Error in post-purchase flow: $e');
      debugPrint('Stack trace: $stack');
      // Still attempt navigation even if updates fail
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const CongratulationsScreen1(),
          ),
          (route) => false,
        );
      }
    }
  }

  /// Resolve the purchased product ID from RevenueCat
  static Future<String> _resolvePurchasedProductId({
    String? defaultProductId,
  }) async {
    // Default fallback product IDs by platform
    String fallbackProductId = defaultProductId ??
        (Platform.isIOS
            ? 'com.stoppr.app.annual'
            : 'com.stoppr.sugar.app.annual:com-stoppr-sugar-app-annual');

    try {
      final customerInfo = await Purchases.getCustomerInfo();

      // Define expected product IDs by platform
      final String monthlyId = Platform.isIOS
          ? 'com.stoppr.app.monthly'
          : 'com.stoppr.sugar.app.monthly:com-stoppr-app-sugar-monthly';
      final String annualId = Platform.isIOS
          ? 'com.stoppr.app.annual'
          : 'com.stoppr.sugar.app.annual:com-stoppr-sugar-app-annual';
      final String annualTrialId = Platform.isIOS
          ? 'com.stoppr.app.annual.trial'
          : 'com.stoppr.sugar.app.annual.trial:com-stoppr-sugar-app-annual-trial';
      final String annual80offId = Platform.isIOS
          ? 'com.stoppr.app.annual80OFF'
          : 'com.stoppr.sugar.app.annual80off:annual80off';
      final String weeklyId = Platform.isIOS
          ? ''
          : 'com.stoppr.sugar.app.weekly:com-stoppr-sugar-app-weekly';
      final String weeklyCheapId = Platform.isIOS
          ? 'com.stoppr.weekly_cheap.app'
          : 'com.stoppr.sugar.app.weekly_cheap:com-stoppr-sugar-app-weekly-cheap';
      final String monthlyCheapId = Platform.isIOS
          ? 'com.stoppr.monthly_cheap.app'
          : 'com.stoppr.sugar.app.monthly_cheap:com-stoppr-app-sugar-monthly-cheap';
      final String annualCheapId = Platform.isIOS
          ? 'com.stoppr.annual_cheap.app'
          : 'com.stoppr.sugar.app.annual_cheap:com-stoppr-sugar-app-annual-cheap';
      final String annualExp1Id = Platform.isIOS
          ? 'com.stoppr.app.annual.exp1'
          : 'com.stoppr.sugar.app.annual.exp1:com-stoppr-sugar-app-annual-exp1';
      final String annualExp2Id = Platform.isIOS
          ? 'com.stoppr.app.annual.exp2'
          : 'com.stoppr.sugar.app.annual.exp2:com-stoppr-sugar-app-annual-exp2';

      // Check active subscriptions in priority order
      if (customerInfo.activeSubscriptions.contains(annual80offId)) {
        return annual80offId;
      } else if (customerInfo.activeSubscriptions.contains(annualTrialId)) {
        return annualTrialId;
      } else if (customerInfo.activeSubscriptions.contains(annualExp2Id)) {
        return annualExp2Id;
      } else if (customerInfo.activeSubscriptions.contains(annualExp1Id)) {
        return annualExp1Id;
      } else if (customerInfo.activeSubscriptions.contains(annualCheapId)) {
        return annualCheapId;
      } else if (customerInfo.activeSubscriptions.contains(annualId)) {
        return annualId;
      } else if (customerInfo.activeSubscriptions.contains(monthlyCheapId)) {
        return monthlyCheapId;
      } else if (customerInfo.activeSubscriptions.contains(monthlyId)) {
        return monthlyId;
      } else if (customerInfo.activeSubscriptions.contains(weeklyCheapId)) {
        return weeklyCheapId;
      } else if (weeklyId.isNotEmpty &&
          customerInfo.activeSubscriptions.contains(weeklyId)) {
        return weeklyId;
      }

      debugPrint(
          '⚠️ PostPurchaseHandler: No matching product found in active subscriptions, using fallback');
      return fallbackProductId;
    } catch (e) {
      debugPrint(
          '❌ PostPurchaseHandler: Error fetching CustomerInfo from RevenueCat: $e');
      return fallbackProductId;
    }
  }

  /// Update Firestore with subscription data
  static Future<void> _updateFirebaseSubscription(String productId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        debugPrint('❌ PostPurchaseHandler: No user ID found');
        return;
      }

      final now = DateTime.now();

      // Determine subscription type and expiration based on product ID
      SubscriptionType subscriptionType;
      DateTime expirationDate;

      // Get base product ID (remove platform prefix if present)
      String baseProductId = productId;
      if (productId.contains(':')) {
        baseProductId = productId.split(':')[0];
      }

      // Determine subscription details based on product type
      if (baseProductId.toLowerCase().contains('lifetime')) {
        subscriptionType = SubscriptionType.paid_lifetime;
        expirationDate = now; // Not used for lifetime
      } else if (baseProductId.toLowerCase().contains('annual80off') ||
          baseProductId.toLowerCase().contains('80off')) {
        subscriptionType = SubscriptionType.paid_gift;
        expirationDate = DateTime(
          now.year + 1,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
      } else if (baseProductId.toLowerCase().contains('33off')) {
        subscriptionType = SubscriptionType.paid_standard;
        expirationDate = DateTime(
          now.year + 1,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
      } else if (baseProductId.toLowerCase().contains('.exp1') ||
          baseProductId.toLowerCase().contains('.exp2')) {
        // Expensive annual subscriptions
        subscriptionType = SubscriptionType.paid_standard;
        expirationDate = DateTime(
          now.year + 1,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
      } else if (baseProductId.toLowerCase().contains('cheap')) {
        // Youth subscriptions (age < 24)
        subscriptionType = SubscriptionType.paid_standard_cheap;
        if (baseProductId.toLowerCase().contains('annual')) {
          expirationDate = DateTime(
            now.year + 1,
            now.month,
            now.day,
            now.hour,
            now.minute,
            now.second,
          );
        } else if (baseProductId.toLowerCase().contains('monthly')) {
          expirationDate = DateTime(
            now.year,
            now.month + 1,
            now.day,
            now.hour,
            now.minute,
            now.second,
          );
        } else if (baseProductId.toLowerCase().contains('weekly')) {
          expirationDate = now.add(const Duration(days: 7));
        } else {
          // Default cheap to annual
          expirationDate = DateTime(
            now.year + 1,
            now.month,
            now.day,
            now.hour,
            now.minute,
            now.second,
          );
        }
      } else if (baseProductId.toLowerCase().contains('trial')) {
        subscriptionType = SubscriptionType.paid_standard;
        // Trial: subscription starts in 3 days, expires in 1 year + 3 days
        final trialExpirationDate = now.add(const Duration(days: 3));
        expirationDate = now.add(const Duration(days: 365 + 3));
        
        // Update with trial info
        await _userRepository.updateUserSubscriptionStatus(
          uid,
          subscriptionType,
          productId: productId,
          startDate: trialExpirationDate, // Subscription starts after trial
          expirationDate: expirationDate,
          trialExpirationDate: trialExpirationDate,
        );
        return;
      } else if (baseProductId.toLowerCase().contains('annual')) {
        subscriptionType = SubscriptionType.paid_standard;
        expirationDate = DateTime(
          now.year + 1,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
      } else if (baseProductId.toLowerCase().contains('monthly')) {
        subscriptionType = SubscriptionType.paid_standard;
        expirationDate = DateTime(
          now.year,
          now.month + 1,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
      } else if (baseProductId.toLowerCase().contains('weekly')) {
        subscriptionType = SubscriptionType.paid_standard;
        expirationDate = now.add(const Duration(days: 7));
      } else {
        // Default to standard annual
        subscriptionType = SubscriptionType.paid_standard;
        expirationDate = DateTime(
          now.year + 1,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
      }

      await _userRepository.updateUserSubscriptionStatus(
        uid,
        subscriptionType,
        productId: productId,
        startDate: now,
        expirationDate: expirationDate,
      );
    } catch (e, stack) {
      debugPrint('❌ PostPurchaseHandler: Error updating Firebase: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  /// Initialize streak for the user
  static Future<void> _initializeStreak() async {
    try {
      final now = DateTime.now();
      await _streakService.setCustomStreakStartDate(now);
      debugPrint('✅ PostPurchaseHandler: Streak initialized at $now');
    } catch (e) {
      debugPrint('❌ PostPurchaseHandler: Error initializing streak: $e');
      rethrow;
    }
  }
}

