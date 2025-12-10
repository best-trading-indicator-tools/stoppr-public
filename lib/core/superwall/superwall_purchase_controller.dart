import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide LogLevel, StoreProduct;
import 'package:purchases_flutter/models/store_product_wrapper.dart' as rc;
import 'package:stoppr/core/config/env_config.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:stoppr/core/subscription/subscription_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/core/services/local_food_image_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/diagnostics/crashlytics_filters.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Top-level helper class for localized pricing resolution
class _ResolvedPrice {
  final double price;
  final String currency;
  const _ResolvedPrice({required this.price, required this.currency});
}


class SuperwallPurchaseController extends PurchaseController {
  final UserRepository _userRepository = UserRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Track if the user previously had an active subscription during this app session
  bool _hadActiveSubscription = false;
  // In-memory flags to avoid duplicate/suppressed FB trial events per session
  final Set<String> _startTrialSentUsers = {};
  final Set<String> _startTrialDeferredUsers = {};
  final Set<String> _startTrialSuppressedUsers = {};
  final Set<String> _subscribeSentUsers = {};
  
  // MARK: Configure and sync subscription Status
  /// Makes sure that Superwall knows the customers subscription status by
  /// changing `Superwall.shared.subscriptionStatus`
  Future<void> configureAndSyncSubscriptionStatus() async {
    debugPrint('🔶 SuperwallPurchaseController: Starting configuration...');
    // Configure RevenueCat
    //await Purchases.setLogLevel(LogLevel.debug);
    
    // Get API keys from environment config - use RevenueCat keys, not Superwall keys
    final iosKey = EnvConfig.revenueCatIOSApiKey;
    final androidKey = EnvConfig.revenueCatAndroidApiKey;
    
    if (iosKey == null || androidKey == null) {
      debugPrint('🔴 SuperwallPurchaseController: RevenueCat API keys missing!');
      throw Exception('RevenueCat API keys are missing. Check your .env file.');
    }
    
    final configuration = Platform.isIOS
        ? PurchasesConfiguration(iosKey)
        : PurchasesConfiguration(androidKey);

    await Purchases.configure(configuration);
    debugPrint('🔶 SuperwallPurchaseController: RevenueCat configured successfully');

    // Listen for changes
    debugPrint('🔶 SuperwallPurchaseController: Adding customer info update listener');
    Purchases.addCustomerInfoUpdateListener((customerInfo) async {
      // --- ADDED: Ignore updates for Apple Reviewer --- 
      final currentUser = _auth.currentUser; // Get current Firebase user
      if (currentUser != null && (currentUser.email == 'applereviews2025@gmail.com' || currentUser.email == 'hello@stoppr.app')) {
        debugPrint('🔶 SuperwallPurchaseController: Ignoring CustomerInfo update listener for Apple Reviewer or Admin account.');
        return; // Do nothing for the reviewer email
      }
      // --- END ADDED ---

      // Gets called whenever new CustomerInfo is available
      debugPrint('🔶 SuperwallPurchaseController: CustomerInfo updated: activeSubscriptions=${customerInfo.activeSubscriptions}, entitlements=${customerInfo.entitlements.active.keys}');
      
      final entitlements = customerInfo.entitlements.active.keys
          .map((id) => Entitlement(id: id))
          .toSet();

      final hasActiveEntitlementOrSubscription = customerInfo
          .hasActiveEntitlementOrSubscription(); // Why? -> https://www.revenuecat.com/docs/entitlements#entitlements

      if (hasActiveEntitlementOrSubscription) {
        debugPrint('🟢 SuperwallPurchaseController: Setting subscription status to ACTIVE with entitlements: $entitlements');
        await Superwall.shared.setSubscriptionStatus(
            SubscriptionStatusActive(entitlements: entitlements));
            
        // Check for trial conversion before updating Firebase
        await _checkAndHandleTrialConversion(customerInfo);
        
        // Update Firebase with subscription status
        await _updateFirebaseSubscriptionStatus(customerInfo, true);

        // Mark that user currently has active subscription
        _hadActiveSubscription = true;
        
        // Update widget subscription status
        await StreakService().updateWidgetSubscriptionStatus(true);
        
        // Initialize streak if user doesn't have one yet
        await _initializeStreakIfNeeded();
        
        // Track Facebook subscription activation (only if not already tracked)
        await _trackFacebookSubscriptionActivation(customerInfo);
        
        // Track Firebase Analytics subscription activation
        await _trackFirebaseAnalyticsSubscriptionActivation(customerInfo);

        // --- NEW: Persist willRenew flag to Firestore ---
        try {
          bool willRenew = true; // default true
          final activeEntitlements = customerInfo.entitlements.active;
          if (activeEntitlements.isNotEmpty) {
            // Take first entitlement's willRenew value (all should match)
            willRenew = activeEntitlements.values.first.willRenew;
          }

          // Only log cancellation and set unsubscribedAt if not already set
          if (!willRenew) {
            final userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
            final alreadyCancelled = userDoc.data()?['unsubscribedAt'] != null;
            
            await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
              'subscriptionWillRenew': willRenew,
              if (!alreadyCancelled) 'unsubscribedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            if (!alreadyCancelled) {
              // User cancelled subscription
            }
          } else {
            await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
              'subscriptionWillRenew': willRenew,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        } catch (e) {
          debugPrint('🔴 SuperwallPurchaseController: Error syncing willRenew flag: $e');
        }
      } else {
        // Promo override: treat influencer/promo users as ACTIVE even without RC entitlements
        try {
          final bool hasPromoAccess = await _hasPromoAccess();
          if (hasPromoAccess) {
            debugPrint('🟢 SuperwallPurchaseController: Promo access detected. Forcing ACTIVE without RevenueCat entitlement.');
            await Superwall.shared.setSubscriptionStatus(SubscriptionStatusActive(entitlements: <Entitlement>{}));
            await StreakService().updateWidgetSubscriptionStatus(true);
            return; // Skip INACTIVE flow for promo users
          }
        } catch (e) {
          debugPrint('⚠️ SuperwallPurchaseController: Promo override check failed: $e');
        }
        debugPrint('🔴 SuperwallPurchaseController: Setting subscription status to INACTIVE');
        await Superwall.shared
            .setSubscriptionStatus(SubscriptionStatusInactive());
        // RC-first security check: if RC/Superwall shows INACTIVE but Firebase shows premium, log alert
        await _alertIfRevenueCatInactiveButFirebaseShowsPremium(customerInfo);
            
        // Re-identify and re-logIn to protect against silent appUserId drift before retries.
        try {
          final currentUser = _auth.currentUser;
          if (currentUser != null) {
            // Identify to Superwall
            await Superwall.shared.identify(currentUser.uid);
            // Attempt RevenueCat logIn with preserved original_app_user_id
            try {
              final prefs = await SharedPreferences.getInstance();
              final originalId = prefs.getString('original_app_user_id');
              if (originalId != null && originalId.isNotEmpty) {
                await Purchases.logIn(originalId);
                debugPrint('🔐 Re-logged into RevenueCat with preserved original_app_user_id.');
              }
            } catch (e) {
              debugPrint('⚠️ Re-login to RevenueCat failed (non-fatal): $e');
            }
          }
        } catch (e, st) {
          debugPrint('⚠️ SuperwallPurchaseController: Re-identify/logIn guard failed: $e');
          if (!kDebugMode) {
            FirebaseCrashlytics.instance.recordError(
              e,
              st,
              reason: 'Re-identify/Re-login guard failed before INACTIVE retries',
            );
          }
          // Also mirror to Mixpanel for visibility in behavior dashboards
          try {
            MixpanelService.trackEvent('Superwall Reidentify Guard Error', properties: {
              'reason': 'reidentify_relogin_failed',
              'error': e.toString(),
            });
          } catch (_) {}
        }

        // Double-check INACTIVE status before taking destructive actions.
        // Retry up to 2 times, 5s apart, using Superwall/RevenueCat as the source of truth.
        CustomerInfo latestCustomerInfo = customerInfo;
        try {
          for (int attempt = 0; attempt < 2; attempt++) {
            // Small delay only after the first immediate recheck
            if (attempt == 1) {
              await Future.delayed(const Duration(seconds: 5));
            }

            final refreshed = await Purchases.getCustomerInfo();
            if (refreshed.hasActiveEntitlementOrSubscription()) {
              // Subscription recovered during retry window → treat as ACTIVE and exit early
              final entitlements = refreshed.entitlements.active.keys
                  .map((id) => Entitlement(id: id))
                  .toSet();
              debugPrint('🟢 SuperwallPurchaseController: Active subscription detected on retry (attempt ${attempt + 1}). Skipping onboarding reset.');
              await Superwall.shared.setSubscriptionStatus(
                SubscriptionStatusActive(entitlements: entitlements),
              );
              await _updateFirebaseSubscriptionStatus(refreshed, true);
              _hadActiveSubscription = true;
              await StreakService().updateWidgetSubscriptionStatus(true);
              return; // Do not proceed with the INACTIVE flow
            }
            latestCustomerInfo = refreshed;
          }
        } catch (e, st) {
          debugPrint('⚠️ SuperwallPurchaseController: Retry check failed: $e');
          if (!kDebugMode) {
            FirebaseCrashlytics.instance.recordError(
              e,
              st,
              reason: 'Retrying CustomerInfo after INACTIVE failed',
            );
          }
          try {
            MixpanelService.trackEvent('Subscription Retry Error', properties: {
              'context': 'inactive_retries',
              'error': e.toString(),
            });
          } catch (_) {}
        }

        // After retries, still INACTIVE.
        // DEBUG/TESTFLIGHT BYPASS: do not clear onboarding or downgrade local state in debug/TestFlight
        bool isTf = false;
        try { isTf = await MixpanelService.isTestFlight(); } catch (_) {}
        if (kDebugMode || isTf) {
          debugPrint('🧪 Debug/TestFlight: Skipping onboarding clear and FREE downgrade on INACTIVE.');
          return;
        }

        // Only clear onboarding if there is NO purchase history.
        final bool hasAnyPurchaseHistory =
            latestCustomerInfo.allPurchasedProductIdentifiers.isNotEmpty;
        if (!hasAnyPurchaseHistory) {
          try {
            await OnboardingProgressService().clearOnboardingProgress();
            debugPrint('🟠 SuperwallPurchaseController: Cleared onboarding (confirmed inactive, no purchase history).');

            // Also reset onboardingCompleted flag in Firestore so dual verification respects the reset
            final currentUser = _auth.currentUser;
            if (currentUser != null) {
              await _firestore.collection('users').doc(currentUser.uid).set({
                'onboardingCompleted': false,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              debugPrint('🔒 SuperwallPurchaseController: onboardingCompleted=false persisted after confirmed inactivity.');
            }
          } catch (e) {
            debugPrint('🔴 SuperwallPurchaseController: Error clearing onboarding progress: $e');
          }
        } else {
          debugPrint('ℹ️ SuperwallPurchaseController: Skipping onboarding clear (purchase history present).');
        }

        // Update Firebase with free status (also mark willRenew false)
        await _updateFirebaseSubscriptionStatus(customerInfo, false);
        
        // Update widget subscription status
        await StreakService().updateWidgetSubscriptionStatus(false);

        // Clean up food images ONLY when subscription expires (not for users who were never subscribers)
        if (_hadActiveSubscription || customerInfo.allPurchasedProductIdentifiers.isNotEmpty) {
          try {
            await LocalFoodImageService().cleanupUserImages();
            debugPrint('🧹 SuperwallPurchaseController: Cleaned up food images for expired subscription');
          } catch (e) {
            debugPrint('🔴 SuperwallPurchaseController: Error cleaning up food images: $e');
          }
        }

        // Persist willRenew = false in Firestore
        try {
          final uid = _auth.currentUser?.uid;
          if (uid != null) {
            await _firestore.collection('users').doc(uid).set({
              'subscriptionWillRenew': false,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        } catch (e) {
          debugPrint('🔴 SuperwallPurchaseController: Error writing willRenew=false to Firestore: $e');
        }

        // Update flag
        _hadActiveSubscription = false;
      }
    });
    
    // Perform initial check of subscription status
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      debugPrint('🔶 SuperwallPurchaseController: Initial subscription status check: activeSubscriptions=${customerInfo.activeSubscriptions}, entitlements=${customerInfo.entitlements.active.keys}');
      
      final hasActiveEntitlementOrSubscription = customerInfo.hasActiveEntitlementOrSubscription();
      debugPrint('🔶 SuperwallPurchaseController: Initial active status: $hasActiveEntitlementOrSubscription');

      // Force set subscription status based on initial check
      if (hasActiveEntitlementOrSubscription) {
        final entitlements = customerInfo.entitlements.active.keys
            .map((id) => Entitlement(id: id))
            .toSet();
        debugPrint('🟢 SuperwallPurchaseController: Setting initial subscription status to ACTIVE');
        await Superwall.shared.setSubscriptionStatus(
            SubscriptionStatusActive(entitlements: entitlements));
            
        // Update Firebase with initial subscription status
        await _updateFirebaseSubscriptionStatus(customerInfo, true);
        
        // Update widget subscription status
        await StreakService().updateWidgetSubscriptionStatus(true);
      } else {
        // Promo override on initial check
        try {
          final bool hasPromoAccess = await _hasPromoAccess();
          if (hasPromoAccess) {
            debugPrint('🟢 SuperwallPurchaseController: Initial promo access detected. Forcing ACTIVE.');
            await Superwall.shared.setSubscriptionStatus(SubscriptionStatusActive(entitlements: <Entitlement>{}));
            await StreakService().updateWidgetSubscriptionStatus(true);
            return; // Do not run INACTIVE branch for promo users
          }
        } catch (e) {
          debugPrint('⚠️ SuperwallPurchaseController: Promo override (initial) check failed: $e');
        }
        debugPrint('🔴 SuperwallPurchaseController: Setting initial subscription status to INACTIVE');
        await Superwall.shared.setSubscriptionStatus(SubscriptionStatusInactive());
        
        // DEBUG/TESTFLIGHT BYPASS: do not clear onboarding / downgrade on initial inactive in debug/TestFlight
        bool isTf = false;
        try { isTf = await MixpanelService.isTestFlight(); } catch (_) {}
        if (kDebugMode || isTf) {
          debugPrint('🧪 Debug/TestFlight: Skipping initial FREE downgrade actions (listener will handle updates).');
          return;
        }

        // RC-first security check on initial load
        await _alertIfRevenueCatInactiveButFirebaseShowsPremium(customerInfo);

        // Update Firebase with initial free status
        await _updateFirebaseSubscriptionStatus(customerInfo, false);
        
        // Update widget subscription status
        await StreakService().updateWidgetSubscriptionStatus(false);
      }
    } catch (e) {
      debugPrint('🔴 SuperwallPurchaseController: Error getting initial customer info: $e');
    }
  }
  
  // Resolve localized price and currency from RevenueCat for a product id
  Future<_ResolvedPrice?> _resolveLocalizedPriceAndCurrency(String productId) async {
    try {
      final products = await PurchasesAdditions.getAllProducts([productId]);
      final rc.StoreProduct? product = products.firstOrNull;
      if (product == null) return null;
      return _ResolvedPrice(price: product.price, currency: product.currencyCode ?? 'USD');
    } catch (e) {
      debugPrint('⚠️ Failed to resolve localized price for $productId: $e');
      return null;
    }
  }

  // Infer the base subscription product id from a trial product id
  String _inferBasePlanProductId(String productId) {
    if (productId.contains(':')) {
      // Google Play trial id format "<base>:<trial>" → return base
      return productId.split(':').first;
    }
    return productId.replaceAll('.trial', '');
  }
  
  // Detect partner/influencer promo access granted outside RevenueCat
  Future<bool> _hasPromoAccess() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return false;
      final data = doc.data()!;
      final String? status = data['subscriptionStatus'] as String?;
      final String? productId = data['subscriptionProductId'] as String?;
      final String? partnerSource = data['partnerSource'] as String?;
      return status == 'free_apple_promo' ||
             status == 'free_android_promo' ||
             productId == 'apple_promo_code' ||
             productId == 'android_promo_code' ||
             partnerSource == 'apple_promo' ||
             partnerSource == 'android_promo';
    } catch (e) {
      debugPrint('⚠️ SuperwallPurchaseController: Error checking promo access: $e');
      return false;
    }
  }

  // _ResolvedPrice moved to top-level (Dart does not allow nested classes)

  /// Synchronize user properties from Firestore to RevenueCat
  Future<void> syncUserPropertiesFromFirestore(String userId) async {
    try {
      debugPrint('🔶 SuperwallPurchaseController: Syncing user properties from Firestore to RevenueCat for user: $userId');
      
      // Get user data from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists || userDoc.data() == null) {
        debugPrint('🔴 SuperwallPurchaseController: User document not found in Firestore: $userId');
        return;
      }
      
      final userData = userDoc.data()!;
      
      // Set attributes in RevenueCat
      final attributes = <String, String>{};
      
      // Map basic properties
      if (userData['gender'] != null) {
        attributes['gender'] = userData['gender'].toString();
      }
      
      if (userData['age'] != null) {
        attributes['age'] = userData['age'].toString();
      }
      
      if (userData['auth_provider_id'] != null) {
        attributes['auth_provider'] = userData['auth_provider_id'].toString();
      }
      
      if (userData['isAnonymous'] != null) {
        attributes['is_anonymous'] = userData['isAnonymous'].toString();
      }
      
      // Add OS and OS version to RevenueCat
      if (userData['os'] != null) {
        attributes['os'] = userData['os'].toString();
      } else {
        attributes['os'] = Platform.operatingSystem;
      }
      
      if (userData['os_version'] != null) {
        attributes['os_version'] = userData['os_version'].toString();
      } else {
        attributes['os_version'] = Platform.operatingSystemVersion;
      }
      // Add app_version to attributes
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final appVersion = packageInfo.version;
        attributes['app_version'] = appVersion;
      } catch (e) {
        // Optionally skip or set to unknown
      }
      
      // Handle Locale and Country (with fallback to device derivation)
      String? finalLocale = userData['locale'] as String?;
      String? finalCountry = userData['country'] as String?;
      bool updateFirestoreNeeded = false;
      
      if (finalLocale == null || finalLocale.isEmpty) {
        finalLocale = Platform.localeName;
        if (finalLocale.isNotEmpty) {
          attributes['locale'] = finalLocale;
          updateFirestoreNeeded = true; // Need to save derived locale
        }
      } else {
        attributes['locale'] = finalLocale;
      }
      
      if (finalCountry == null || finalCountry.isEmpty) {
        if (finalLocale.contains('_') || finalLocale.contains('-')) {
          final separator = finalLocale.contains('_') ? '_' : '-';
          final parts = finalLocale.split(separator);
          if (parts.length > 1 && parts[1].isNotEmpty) {
            finalCountry = parts[1];
            attributes['country'] = finalCountry;
            updateFirestoreNeeded = true; // Need to save derived country
          }
        }
      } else {
        attributes['country'] = finalCountry;
      }
      
      // Update Firestore with derived values if needed
      if (updateFirestoreNeeded) {
        Map<String, dynamic> firestoreUpdate = {
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (attributes.containsKey('locale')) {
          firestoreUpdate['locale'] = attributes['locale'];
        }
        if (attributes.containsKey('country')) {
          firestoreUpdate['country'] = attributes['country'];
        }
        _firestore.collection('users').doc(userId).update(firestoreUpdate)
          .catchError((e) => debugPrint('🔴 SuperwallPurchaseController: Error updating Firestore with derived locale/country: $e'));
      }
      
      // Handle dates properly
      final dateFields = {
        'createdAt': 'account_creation_date',
        'subscriptionStartDate': 'subscription_start_date',
        'subscriptionExpirationDate': 'subscription_expiration_date',
        'subscriptionUpdatedAt': 'subscription_updated_at',
      };
      
      dateFields.forEach((firestore, revenueCat) {
        if (userData[firestore] != null) {
          // Convert Timestamp to ISO string for better readability
          final timestamp = userData[firestore] as Timestamp;
          attributes[revenueCat] = timestamp.toDate().toIso8601String();
        }
      });
      
      // Add subscription details
      if (userData['subscriptionStatus'] != null) {
        attributes['subscription_status'] = userData['subscriptionStatus'].toString();
        
        // Calculate subscription active state
        final String status = userData['subscriptionStatus'] as String;
        final bool isSubscribed = status.contains('paid');
        attributes['is_subscribed'] = isSubscribed.toString();
      }
      
      if (userData['subscriptionProductId'] != null) {
        attributes['subscription_product_id'] = userData['subscriptionProductId'].toString();
      }
      
      // Set user attributes in RevenueCat
      await Purchases.setAttributes(attributes);
      debugPrint('🟢 SuperwallPurchaseController: Set ${attributes.length} attributes in RevenueCat: ${attributes.keys.join(", ")}');
      
      // Set email separately (has its own method)
      if (userData['email'] != null && userData['email'].toString().isNotEmpty) {
        final email = userData['email'].toString();
        await Purchases.setEmail(email);
        debugPrint('🟢 SuperwallPurchaseController: Set email in RevenueCat: $email');
      }
      
      // Set display name separately (has its own method)
      String? displayName;
      if (userData['firstName'] != null && userData['firstName'].toString().isNotEmpty) {
        displayName = userData['firstName'].toString();
      } else if (userData['displayName'] != null && userData['displayName'].toString().isNotEmpty) {
        displayName = userData['displayName'].toString();
      }
      
      if (displayName != null) {
        await Purchases.setDisplayName(displayName);
        debugPrint('🟢 SuperwallPurchaseController: Set display name in RevenueCat: $displayName');
      }
      
    } catch (e) {
      debugPrint('🔴 SuperwallPurchaseController: Error syncing user properties to RevenueCat: $e');
    }
  }
  
  // Helper method to update Firebase with subscription status
  Future<void> _updateFirebaseSubscriptionStatus(CustomerInfo customerInfo, bool isActive) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('🔶 SuperwallPurchaseController: Cannot update Firebase, no user logged in');
        return;
      }
      
      if (isActive) {
        // Get the actual product ID from active subscriptions
        final activeSubscriptions = customerInfo.activeSubscriptions;
        debugPrint('🔶 SuperwallPurchaseController: Active subscriptions: $activeSubscriptions');
        
        // Extract subscription dates
        DateTime? subscriptionStartDate;
        DateTime? subscriptionExpirationDate;
        
        // Try to get dates from entitlements
        final entitlements = customerInfo.entitlements.active;
        if (entitlements.isNotEmpty) {
          final entitlement = entitlements.values.first;
          // Get start date if available (purchase date)
          if (entitlement.latestPurchaseDate != null) {
            try {
              subscriptionStartDate = DateTime.parse(entitlement.latestPurchaseDate!);
            } catch (e) {
              debugPrint('❌ SuperwallPurchaseController: Failed to parse subscription start date: $e');
            }
          }
          // Get expiration date
          if (entitlement.expirationDate != null) {
            try {
              subscriptionExpirationDate = DateTime.parse(entitlement.expirationDate!);
            } catch (e) {
              debugPrint('❌ SuperwallPurchaseController: Failed to parse subscription expiration date: $e');
            }
          }
          
          debugPrint('📅 SuperwallPurchaseController: Subscription dates - Start: $subscriptionStartDate, Expiration: $subscriptionExpirationDate');
        }
        
        // If dates are not available from entitlements, try to get from transactions
        if (subscriptionStartDate == null) {
          subscriptionStartDate = customerInfo.getLatestTransactionPurchaseDate();
          debugPrint('📅 SuperwallPurchaseController: Using latest transaction date as start date: $subscriptionStartDate');
        }
        
        if (activeSubscriptions.isNotEmpty) {
          // CRITICAL FIX: For Android trials, check for trial product ID in allPurchasedProductIdentifiers
          // This is necessary because RevenueCat returns the base product ID in activeSubscriptions
          // but we need to save the original trial product ID for analytics/tracking purposes
          String productId = activeSubscriptions.first; // Default to active subscription
          
          // Check if user purchased a trial (Android format includes the full trial ID)
          final allPurchased = customerInfo.allPurchasedProductIdentifiers;
          const androidTrialId = 'com.stoppr.sugar.app.annual.trial:com-stoppr-sugar-app-annual-trial';
          const iosTrialId = 'com.stoppr.app.annual.trial';
          
          if (allPurchased.contains(androidTrialId)) {
            productId = androidTrialId;
            debugPrint('🔧 SuperwallPurchaseController: Android trial detected - using original trial product ID: $productId');
          } else if (allPurchased.contains(iosTrialId)) {
            productId = iosTrialId;
            debugPrint('🔧 SuperwallPurchaseController: iOS trial detected - using original trial product ID: $productId');
          }
          
          debugPrint('🔶 SuperwallPurchaseController: Final product ID to save: $productId');
          
          // Calculate expiration date if not available from RevenueCat but we have a start date
          if (subscriptionExpirationDate == null && subscriptionStartDate != null) {
            subscriptionExpirationDate = _calculateExpirationDate(productId, subscriptionStartDate);
          }
          
          // Use the subscription service to update Firebase with the correct type
          if (productId.toLowerCase().contains('annual80off')) {
            await _subscriptionService.updateSubscriptionStatus(
              user.uid,
              SubscriptionType.paid_gift,
              productId: productId,
              startDate: subscriptionStartDate,
              expirationDate: subscriptionExpirationDate
            );
            debugPrint('🟢 SuperwallPurchaseController: User has GIFT subscription ($productId), updating Firebase');
          } else if (productId.toLowerCase().contains('trial')) {
            // For trial subscriptions, calculate trial expiration date
            DateTime? trialExpirationDate;
            if (subscriptionStartDate != null) {
              trialExpirationDate = subscriptionStartDate.add(const Duration(days: 3));
            }
            
            await _subscriptionService.updateSubscriptionStatus(
              user.uid,
              SubscriptionType.paid_standard,
              productId: productId,
              startDate: subscriptionStartDate,
              expirationDate: subscriptionExpirationDate,
              trialExpirationDate: trialExpirationDate
            );
            debugPrint('🟢 SuperwallPurchaseController: User has TRIAL subscription ($productId), updating Firebase');
            if (trialExpirationDate != null) {
              debugPrint('📅 SuperwallPurchaseController: Trial expires: ${trialExpirationDate.toIso8601String()}');
            }
          } else if (productId.toLowerCase().contains('trial.paid')) {
            // For trial.paid, calculate 3-day expiration date
            DateTime? trialPaidExpirationDate;
            if (subscriptionStartDate != null) {
              trialPaidExpirationDate = subscriptionStartDate.add(const Duration(days: 3));
            } else {
              trialPaidExpirationDate = DateTime.now().add(const Duration(days: 3));
            }
            
            await _subscriptionService.updateSubscriptionStatus(
              user.uid,
              SubscriptionType.paid_standard,
              productId: productId,
              startDate: subscriptionStartDate,
              expirationDate: trialPaidExpirationDate
            );
            debugPrint('🟢 SuperwallPurchaseController: User has TRIAL PAID subscription ($productId), updating Firebase with 3-day expiration: ${trialPaidExpirationDate?.toIso8601String()}');
          } else if (productId.toLowerCase().contains('annual') || 
                    productId.toLowerCase().contains('monthly') ||
                    productId.toLowerCase().contains('33off')) {
            await _subscriptionService.updateSubscriptionStatus(
              user.uid,
              SubscriptionType.paid_standard,
              productId: productId,
              startDate: subscriptionStartDate,
              expirationDate: subscriptionExpirationDate
            );
            debugPrint('🟢 SuperwallPurchaseController: User has ANNUAL subscription ($productId), updating Firebase');
          } else {
            // Unknown product ID - still mark as paid_standard but log the actual ID
            await _subscriptionService.updateSubscriptionStatus(
              user.uid,
              SubscriptionType.paid_standard,
              productId: productId,
              startDate: subscriptionStartDate,
              expirationDate: subscriptionExpirationDate
            );
            debugPrint('🟢 SuperwallPurchaseController: User has UNKNOWN subscription type ($productId), marking as standard');
          }
        } else {
          // Has entitlements but no active subscriptions - use entitlement IDs
          final entitlements = customerInfo.entitlements.active;
          if (entitlements.isNotEmpty) {
            final entitlementId = entitlements.keys.first;
            debugPrint('🔶 SuperwallPurchaseController: Active entitlement ID: $entitlementId');
            
            // If we have an entitlement but no subscription, still mark as paid
            await _subscriptionService.updateSubscriptionStatus(
              user.uid,
              SubscriptionType.paid_standard,
              productId: 'entitlement:$entitlementId',
              startDate: subscriptionStartDate,
              expirationDate: subscriptionExpirationDate
            );
            debugPrint('🟢 SuperwallPurchaseController: User has active entitlement ($entitlementId), marking as standard');
          } else {
            // This should not happen, but handle it just in case
            await _subscriptionService.updateSubscriptionStatus(
              user.uid,
              SubscriptionType.paid_standard,
              productId: 'unknown_active',
              startDate: subscriptionStartDate,
              expirationDate: subscriptionExpirationDate
            );
            debugPrint('🟡 SuperwallPurchaseController: User has active status but no subscriptions or entitlements found');
          }
        }
      } else {
        // User has no active subscription - mark as free and clear expiration date
        // CRITICAL FIX: Don't preserve expiration dates - only RevenueCat/Superwall controls access
        await _subscriptionService.updateSubscriptionStatus(
          user.uid,
          SubscriptionType.free,
          productId: null,
        );
        debugPrint('🔴 SuperwallPurchaseController: User has FREE status, updating Firebase');
      }
    } catch (e) {
      debugPrint('🔴 SuperwallPurchaseController: Error updating Firebase subscription status: $e');
    }
  }

  // MARK: Security Alerts (RevenueCat-first)
  /// If RevenueCat/Superwall reports INACTIVE but Firebase user doc shows premium,
  /// create a security_alerts entry. Runs BEFORE we modify Firebase.
  Future<void> _alertIfRevenueCatInactiveButFirebaseShowsPremium(
      CustomerInfo customerInfo) async {
    try {
      // Only run when RC indicates no active entitlement/subscription
      final bool rcInactive = !customerInfo.hasActiveEntitlementOrSubscription();
      final uid = _auth.currentUser?.uid;
      if (!rcInactive || uid == null) return;

      // Read current Firebase user document (pre-update snapshot)
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists || userDoc.data() == null) return;

      final data = userDoc.data()!;
      final String? subscriptionStatus = data['subscriptionStatus'] as String?;
      final String? subscriptionProductId =
          data['subscriptionProductId'] as String?;

      final bool firebaseShowsPremium =
          (subscriptionStatus == 'paid_standard' ||
              subscriptionStatus == 'paid_gift' ||
              subscriptionStatus == 'free_apple_promo') ||
          (subscriptionProductId != null && subscriptionProductId.isNotEmpty);

      if (!firebaseShowsPremium) return; // No mismatch → no alert

      // Compose alert fields
      final deviceInfo = {
        'os': data['os'] as String? ?? 'unknown',
        'os_version': data['os_version'] as String? ?? 'unknown',
        'app_version': data['app_version'] as String? ?? 'unknown',
        'device_model': data['device_model'] as String? ?? 'unknown',
      };

      final Timestamp? signupDate = data['createdAt'] as Timestamp?;
      final String email = data['email'] as String? ?? 'unknown';
      final String displayName = data['displayName'] as String? ?? 'N/A';

      // Removed Mixpanel unauthorized access tracking

      debugPrint(
          '🚨 SECURITY ALERT: RC inactive but Firebase shows premium. Logging alert for $uid');

      // Write alert document (admin-only readable per rules)
      await _firestore.collection('security_alerts').add({
        'type': 'unauthorized_premium_access',
        'user_id': uid,
        'email': email,
        'display_name': displayName,
        'subscription_status': subscriptionStatus,
        'subscription_product_id': subscriptionProductId,
        'signup_date': signupDate,
        'detected_at': FieldValue.serverTimestamp(),
        'device_info': deviceInfo,
        'resolved': false,
      });
    } catch (e) {
      debugPrint('🔴 SuperwallPurchaseController: Error logging security alert: $e');
    }
  }
  
  // Helper to determine if subscription is a gift based on product/entitlement IDs
  bool _isGiftSubscription(CustomerInfo customerInfo) {
    // Check active subscriptions for the specific gift product ID
    for (final productId in customerInfo.activeSubscriptions) {
      if (productId.toLowerCase().contains('annual80off')) {
        return true;
      }
    }
    
    // Check entitlements
    for (final entitlementId in customerInfo.entitlements.active.keys) {
      if (entitlementId.toLowerCase().contains('annual80off')) {
        return true;
      }
    }
    
    return false;
  }

  // Helper to get product ID from CustomerInfo for tracking
  String _getProductIdFromCustomerInfo(CustomerInfo customerInfo) {
    // CRITICAL FIX: Check for trial product ID first
    final allPurchased = customerInfo.allPurchasedProductIdentifiers;
    const androidTrialId = 'com.stoppr.sugar.app.annual.trial:com-stoppr-sugar-app-annual-trial';
    const iosTrialId = 'com.stoppr.app.annual.trial';
    
    if (allPurchased.contains(androidTrialId)) {
      return androidTrialId;
    } else if (allPurchased.contains(iosTrialId)) {
      return iosTrialId;
    }
    
    // First try active subscriptions
    if (customerInfo.activeSubscriptions.isNotEmpty) {
      return customerInfo.activeSubscriptions.first;
    }
    
    // Then try active entitlements
    if (customerInfo.entitlements.active.isNotEmpty) {
      return customerInfo.entitlements.active.keys.first;
    }
    
    // If no active subscriptions or entitlements, check all purchased products
    if (customerInfo.allPurchasedProductIdentifiers.isNotEmpty) {
      return customerInfo.allPurchasedProductIdentifiers.first;
    }
    
    return 'unknown_product';
  }

  // MARK: Handle Purchases

  /// Makes a purchase from App Store with RevenueCat and returns its
  /// result. This gets called when someone tries to purchase a product on
  /// one of your paywalls from iOS.
  @override
  Future<PurchaseResult> purchaseFromAppStore(String productId) async {
    debugPrint('🔶 SuperwallPurchaseController: Attempting to purchase from App Store: $productId');
    // Find products matching productId from RevenueCat
    final products = await PurchasesAdditions.getAllProducts([productId]);
    debugPrint('🔶 SuperwallPurchaseController: Found ${products.length} products for ID: $productId');
    for (final product in products) {
      debugPrint('🔶 Product details:'
          '\n   - ID: ${product.identifier}'
          '\n   - Price: ${product.priceString}'
          '\n   - Description: ${product.description}'
          '\n   - Title: ${product.title}');
    }

    // Get first product for product ID (this will properly throw if empty)
    final storeProduct = products.firstOrNull;

    if (storeProduct == null) {
      final errorMsg = 'Failed to find store product for $productId';
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          errorMsg,
          StackTrace.current,
          reason: 'Purchase Error AppStore: ProductNotFound',
          information: ['productId: $productId'],
        );
      }
      debugPrint('🔴 SuperwallPurchaseController: $errorMsg');
      return PurchaseResult.failed(errorMsg);
    }

    debugPrint('🔶 SuperwallPurchaseController: Attempting to purchase product: ${storeProduct.identifier}');
    final purchaseResult = await _purchaseStoreProduct(storeProduct);
    debugPrint('🔶 SuperwallPurchaseController: Purchase result: $purchaseResult');
    return purchaseResult;
  }

  /// Makes a purchase from Google Play with RevenueCat and returns its
  /// result. This gets called when someone tries to purchase a product on
  /// one of your paywalls from Android.
  @override
  Future<PurchaseResult> purchaseFromGooglePlay(
      String productId, String? basePlanId, String? offerId) async {
    debugPrint('🔶 SuperwallPurchaseController: Attempting to purchase from Google Play: $productId, basePlanId: $basePlanId, offerId: $offerId');
    // Find products matching productId from RevenueCat
    List<rc.StoreProduct> products =
        await PurchasesAdditions.getAllProducts([productId]);
    debugPrint('🔶 SuperwallPurchaseController: Found ${products.length} products for ID: $productId');

    // Choose the product which matches the given base plan.
    // If no base plan set, select first product or fail.
    String storeProductId = "$productId:$basePlanId";
    debugPrint('🔶 SuperwallPurchaseController: Looking for product with ID: $storeProductId');

    // Try to find the first product where the googleProduct's basePlanId matches the given basePlanId.
    rc.StoreProduct? matchingProduct;

    // Loop through each product in the products list.
    for (final product in products) {
      // Check if the current product's basePlanId matches the given basePlanId.
      if (product.identifier == storeProductId) {
        // If a match is found, assign this product to matchingProduct.
        matchingProduct = product;
        // Break the loop as we found our matching product.
        break;
      }
    }

    // If a matching product is not found, then try to get the first product from the list.
    rc.StoreProduct? storeProduct =
        matchingProduct ?? (products.isNotEmpty ? products.first : null);

    // If no product is found (either matching or the first one), return a failed purchase result.
    if (storeProduct == null) {
      final errorMsg = "Product not found for ID: $productId, BasePlan: $basePlanId";
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          errorMsg,
          StackTrace.current,
          reason: 'Purchase Error GooglePlay: ProductNotFound',
          information: [
            'productId: $productId',
            'basePlanId: $basePlanId',
            'offerId: $offerId',
          ],
        );
      }
      debugPrint('🔴 SuperwallPurchaseController: $errorMsg');
      return PurchaseResult.failed("Product not found"); // Keep original short message for Superwall
    }

    switch (storeProduct.productCategory) {
      case ProductCategory.subscription:
        SubscriptionOption? subscriptionOption =
            await _fetchGooglePlaySubscriptionOption(
                storeProduct, basePlanId, offerId);
        if (subscriptionOption == null) {
          final errorMsg = "Valid subscription option not found for product: ${storeProduct.identifier}";
          if (!kDebugMode) {
            FirebaseCrashlytics.instance.recordError(
              errorMsg,
              StackTrace.current,
              reason: 'Purchase Error GooglePlay: SubscriptionOptionNotFound',
              information: [
                'productId: ${storeProduct.identifier}',
                'basePlanId: $basePlanId',
                'offerId: $offerId',
              ],
            );
          }
          debugPrint('🔴 SuperwallPurchaseController: $errorMsg');
          return PurchaseResult.failed(
              "Valid subscription option not found for product."); // Keep original message
        }
        final result = await _purchaseSubscriptionOption(subscriptionOption);
        debugPrint('🔶 SuperwallPurchaseController: Google Play Subscription Purchase Result: $result');
        return result;
      case ProductCategory.nonSubscription:
        final result = await _purchaseStoreProduct(storeProduct);
        debugPrint('🔶 SuperwallPurchaseController: Google Play Non-Subscription Purchase Result: $result');
        return result;
      case null:
        final errorMsg = "Unable to determine product category for: ${storeProduct.identifier}";
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordError(
            errorMsg,
            StackTrace.current,
            reason: 'Purchase Error GooglePlay: CategoryUnknown',
            information: ['productId: ${storeProduct.identifier}'],
          );
        }
        debugPrint('🔴 SuperwallPurchaseController: $errorMsg');
        return PurchaseResult.failed("Unable to determine product category");
    }
  }

  Future<SubscriptionOption?> _fetchGooglePlaySubscriptionOption(
    rc.StoreProduct storeProduct,
    String? basePlanId,
    String? offerId,
  ) async {
    final subscriptionOptions = storeProduct.subscriptionOptions;

    if (subscriptionOptions != null && subscriptionOptions.isNotEmpty) {
      // Concatenate base + offer ID
      final subscriptionOptionId =
          _buildSubscriptionOptionId(basePlanId, offerId);

      // Find first subscription option that matches the subscription option ID or use the default offer
      SubscriptionOption? subscriptionOption;

      // Search for the subscription option with the matching ID
      for (final option in subscriptionOptions) {
        if (option.id == subscriptionOptionId) {
          subscriptionOption = option;
          break;
        }
      }

      // If no matching subscription option is found, use the default option
      subscriptionOption ??= storeProduct.defaultOption;

      // Return the subscription option
      return subscriptionOption;
    }

    return null;
  }

  Future<PurchaseResult> _purchaseSubscriptionOption(
      SubscriptionOption subscriptionOption) async {
    // Define the async perform purchase function
    Future<CustomerInfo> performPurchase() async {
      // Attempt to purchase product
      CustomerInfo customerInfo =
          await Purchases.purchaseSubscriptionOption(subscriptionOption);
      return customerInfo;
    }

    PurchaseResult purchaseResult =
        await _handleSharedPurchase(performPurchase);
    return purchaseResult;
  }

  Future<PurchaseResult> _purchaseStoreProduct(
      rc.StoreProduct storeProduct) async {
    // Define the async perform purchase function
    Future<CustomerInfo> performPurchase() async {
      // Attempt to purchase product
      CustomerInfo customerInfo =
          await Purchases.purchaseStoreProduct(storeProduct);
      return customerInfo;
    }

    PurchaseResult purchaseResult =
        await _handleSharedPurchase(performPurchase);
    return purchaseResult;
  }

  // MARK: Shared purchase
  Future<PurchaseResult> _handleSharedPurchase(
      Future<CustomerInfo> Function() performPurchase) async {
    try {
      debugPrint('🔶 Starting purchase flow...');
      // Perform the purchase using the function provided
      CustomerInfo customerInfo = await performPurchase();
      
      // Removed Mixpanel purchase info tracking
      
      debugPrint('🔶 Purchase completed, checking subscription status...');

      // Handle the results
      if (customerInfo.hasActiveEntitlementOrSubscription()) {
        debugPrint('🟢 Purchase successful - active subscription found');
        
        // Track Facebook Purchase/Subscribe event
        await _trackFacebookPurchaseEvent(customerInfo);
        
        // Track Firebase Analytics Purchase event
        await _trackFirebaseAnalyticsPurchaseEvent(customerInfo);
        
        return PurchaseResult.purchased;
      } else {
        final errorMsg = "No active subscriptions found after purchase attempt.";
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordError(
            errorMsg,
            StackTrace.current,
            reason: 'Purchase Error: NoActiveSubscriptionPostPurchase',
            information: [
              'app_user_id: ${customerInfo.originalAppUserId}',
            ],
          );
        }
        debugPrint('🔴 Purchase completed but no active subscription found');
        return PurchaseResult.failed("No active subscriptions found."); // Keep original message
      }
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      
      // Centralized filter for purchase errors
      final shouldReportPurchaseError = CrashlyticsFilters
          .shouldReportPurchaseError(errorCode, isDebugMode: kDebugMode);
      if (shouldReportPurchaseError) {
        FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Purchase Error: PlatformException',
          information: [
            'errorCode: ${errorCode.toString()}',
            'billing_error_category: ${_categorizeBillingError(errorCode)}',
            'user_id: ${_auth.currentUser?.uid}',
            'user_email: ${_auth.currentUser?.email}',
          ],
        );
      }
      debugPrint('🔴 Purchase error: ${e.message}, code: $errorCode');
      
      if (errorCode == PurchasesErrorCode.paymentPendingError) {
        debugPrint('🟡 Payment is pending');
        return PurchaseResult.pending;
      } else if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('🟡 Purchase was cancelled by user');
        return PurchaseResult.cancelled;
      } else {
        debugPrint('🔴 Purchase failed with error: ${e.message}');
        return PurchaseResult.failed(
            e.message ?? "Purchase failed in SuperwallPurchaseController");
      }
    } catch (e) {
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Purchase Error: UnexpectedCatch',
        );
      }
      debugPrint('🔴 Unexpected error during purchase: $e');
      return PurchaseResult.failed("Unexpected error: $e");
    }
  }

  // MARK: Handle Restores

  /// Makes a restore with RevenueCat and returns `.restored`, unless an error is thrown.
  /// This gets called when someone tries to restore purchases on one of your paywalls.
  ///
  /// CHANGE: Suppress Crashlytics reporting for `invalidReceiptError` restores to
  /// avoid noisy, expected errors from iOS when receipts are invalid.
  @override
  Future<RestorationResult> restorePurchases() async {
    try {
      await Purchases.restorePurchases();
      return RestorationResult.restored;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      // Centralized filter for restore errors
      final shouldReportToCrashlytics = CrashlyticsFilters
          .shouldReportRestoreError(errorCode, isDebugMode: kDebugMode);
      if (shouldReportToCrashlytics) {
        FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Restore Purchase Error',
          information: [
            'errorCode: ${errorCode.toString()}',
            'restore_error_category: ${_categorizeRestoreError(errorCode)}',
            'user_id: ${_auth.currentUser?.uid}',
            'user_email: ${_auth.currentUser?.email}',
          ],
        );
      }
      debugPrint('🔴 Restore purchase error: ${e.message}, code: $errorCode');
      
      return RestorationResult.failed(
          e.message ?? "Restore failed in SuperwallPurchaseController");
    }
  }

  // Helper method to calculate expiration date based on product ID and start date
  DateTime? _calculateExpirationDate(String productId, DateTime? startDate) {
    if (startDate == null) {
      debugPrint('⚠️ Cannot calculate expiration date: No start date provided');
      return null;
    }
    
    // Default to 30 days if we can't determine subscription length
    Duration subscriptionDuration = const Duration(days: 30);
    
    // Determine subscription duration based on product ID
    if (productId.toLowerCase().contains('trial.paid')) {
      // Trial paid access - 3 days
      subscriptionDuration = const Duration(days: 3);
      debugPrint('📅 Calculated expiration for TRIAL PAID subscription: 3 days from start');
    } else if (productId.toLowerCase().contains('annual')) {
      // Annual subscription - 1 year
      subscriptionDuration = const Duration(days: 365);
      debugPrint('📅 Calculated expiration for ANNUAL subscription: 365 days from start');
    } else if (productId.toLowerCase().contains('monthly')) {
      // Monthly subscription - 1 month (approximated as 30 days)
      subscriptionDuration = const Duration(days: 30);
      debugPrint('📅 Calculated expiration for MONTHLY subscription: 30 days from start');
    } else if (productId.toLowerCase().contains('weekly')) {
      // Weekly subscription - 7 days
      subscriptionDuration = const Duration(days: 7);
      debugPrint('📅 Calculated expiration for WEEKLY subscription: 7 days from start');
    } else {
      debugPrint('⚠️ Unknown subscription type for product ID: $productId, using default 30 days');
    }
    
    // Calculate expiration date
    final expirationDate = startDate.add(subscriptionDuration);
    debugPrint('📅 Calculated expiration date: $expirationDate for start date: $startDate');
    return expirationDate;
  }
  
  /// Track Facebook Purchase/Subscribe event after successful purchase
  Future<void> _trackFacebookPurchaseEvent(CustomerInfo customerInfo) async {
    try {
      // Gate: skip Meta events for known male users
      if (!await _shouldSendMetaEvents()) {
        debugPrint('📘 Skipping FB event (male user gate).');
        return;
      }
      // Get the active subscription product ID
      final activeSubscriptions = customerInfo.activeSubscriptions;
      if (activeSubscriptions.isEmpty) {
        debugPrint('⚠️ No active subscriptions found for Facebook tracking');
        return;
      }
      
      final productId = activeSubscriptions.first;
      
      // Generate unique order ID for Facebook tracking
      final fbOrderId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Determine product details for Facebook tracking
      Map<String, dynamic> eventParameters = {
        'fb_content_type': 'product',
        'fb_content_id': productId,
        'fb_currency': 'USD',
        'fb_num_items': 1,
        'fb_order_id': fbOrderId, // Added order ID for deduplication
      };
      
      // Resolve localized price and currency via RevenueCat
      final resolved = await _resolveLocalizedPriceAndCurrency(productId);
      final bool isTrialPurchase =
          productId.toLowerCase().contains('trial');
      if (isTrialPurchase) {
        eventParameters['_valueToSum'] = 0.00;
        if (resolved != null) {
          eventParameters['fb_currency'] = resolved.currency;
        }
      } else if (resolved != null) {
        eventParameters['_valueToSum'] = resolved.price;
        eventParameters['fb_currency'] = resolved.currency;
      } else {
        // Fallback mapping when resolution fails
        if (productId.toLowerCase().contains('lifetime')) {
          eventParameters['_valueToSum'] = 79.99;
        } else if (productId.toLowerCase().contains('annual80off')) {
          eventParameters['_valueToSum'] = 19.99;
        } else if (productId.toLowerCase().contains('33off')) {
          eventParameters['_valueToSum'] = 33.33;
        } else if (productId.toLowerCase().contains('monthly')) {
          eventParameters['_valueToSum'] = 14.99;
        } else if (productId.toLowerCase().contains('weekly')) {
          eventParameters['_valueToSum'] = 2.99;
        } else {
          eventParameters['_valueToSum'] = 49.99;
        }
      }
      
      // For trials, defer reporting for 1 hour and suppress if cancelled within that window
      if (isTrialPurchase) {
        await _scheduleStartTrialCapiTask(customerInfo);
        return;
      }

      // Track purchase immediately for non-trial subscriptions
      final facebookAppEvents = FacebookAppEvents();
      await facebookAppEvents.logEvent(
        name: 'fb_mobile_purchase',
        parameters: eventParameters,
      );
      
      debugPrint('📘 Facebook fb_mobile_purchase event tracked successfully for product: $productId with order ID: $fbOrderId (Trial: $isTrialPurchase)');
      
      // Removed Mixpanel Facebook event tracking
    } catch (e) {
      debugPrint('❌ Error tracking Facebook purchase event: $e');
      
      // Removed Mixpanel Facebook failure tracking
    }
  }
  
  /// Track Facebook subscription activation (from listener, not purchase flow)
  Future<void> _trackFacebookSubscriptionActivation(CustomerInfo customerInfo) async {
    try {
      // Gate: skip Meta events for known male users
      if (!await _shouldSendMetaEvents()) {
        debugPrint('📘 Skipping FB activation event (male user gate).');
        return;
      }
      // Only track if user has active subscription and we haven't tracked this recently
      if (!customerInfo.hasActiveEntitlementOrSubscription()) {
        return;
      }
      
      final activeSubscriptions = customerInfo.activeSubscriptions;
      if (activeSubscriptions.isEmpty) {
        return;
      }
      
      final productId = activeSubscriptions.first;
      
      // Check if this is actually a trial subscription
      final allPurchased = customerInfo.allPurchasedProductIdentifiers;
      const androidTrialId = 'com.stoppr.sugar.app.annual.trial:com-stoppr-sugar-app-annual-trial';
      const iosTrialId = 'com.stoppr.app.annual.trial';
      
      bool isTrialSubscription = productId.toLowerCase().contains('trial') ||
                                 allPurchased.contains(androidTrialId) ||
                                 allPurchased.contains(iosTrialId);
      
      // Guard against duplicate Subscribe by in-memory marker
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final String flagKey = isTrialSubscription ? 'start_trial_sent' : 'subscribe_sent';
      if ((isTrialSubscription && _startTrialSentUsers.contains(uid)) ||
          (!isTrialSubscription && _subscribeSentUsers.contains(uid))) {
        return; // already sent for this user
      }

      if (isTrialSubscription) {
        // Schedule Meta CAPI StartTrial after 5 minutes via Cloud Functions
        await _scheduleStartTrialCapiTask(customerInfo);
        return;
      }

      // Track only once per user until reset for Subscribe (non-trial)
      final facebookAppEvents = FacebookAppEvents();
      await facebookAppEvents.logEvent(
        name: 'Subscribe',
        parameters: {
          'fb_content_type': 'product',
          'fb_content_id': productId,
          'fb_currency': 'USD',
        },
      );
      _subscribeSentUsers.add(uid);

      debugPrint('📘 Facebook Subscribe event tracked once for activation: $productId');
      
      // Removed Mixpanel Facebook subscription event tracking
    } catch (e) {
      debugPrint('❌ Error tracking Facebook subscription activation: $e');
      
      // Removed Mixpanel Facebook subscription failure tracking
    }
  }

  /// Defers sending Facebook StartTrial for 1 hour and suppresses it
  /// if the user cancels the trial within that window.
  Future<void> _scheduleDeferredStartTrialEvent(
    CustomerInfo customerInfo, {
    Map<String, dynamic>? eventParameters,
  }) async {
    try {
      // Gate: skip scheduling for known male users
      if (!await _shouldSendMetaEvents()) {
        debugPrint('📘 Skipping FB StartTrial scheduling (male user gate).');
        return;
      }
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final String productId = _getProductIdFromCustomerInfo(customerInfo);
      final bool isTrial = productId.toLowerCase().contains('trial');
      if (!isTrial) return;

      // Check in-memory flags
      if (_startTrialSentUsers.contains(uid) || _startTrialSuppressedUsers.contains(uid)) {
        return; // already handled previously
      }

      // Determine purchase start time
      DateTime now = DateTime.now();
      DateTime? startDate;
      final entitlements = customerInfo.entitlements.active;
      if (entitlements.isNotEmpty) {
        final entitlement = entitlements.values.first;
        if (entitlement.latestPurchaseDate != null) {
          try {
            startDate = DateTime.parse(entitlement.latestPurchaseDate!);
          } catch (_) {}
        }
      }
      startDate ??= customerInfo.getLatestTransactionPurchaseDate() ?? now;

      final DateTime triggerTime = startDate.add(const Duration(hours: 1));

      // Mark deferred in-memory
      _startTrialDeferredUsers.add(uid);

      // Wait until the trigger time (no background execution guarantee)
      final Duration wait = triggerTime.difference(DateTime.now());
      if (wait > Duration.zero) {
        await Future.delayed(wait);
      }

      // Recheck cancellation status within the first hour
      // Re-query RevenueCat state to check if willRenew became false within hour
      bool cancelledWithinHour = false;
      try {
        final refreshed = await Purchases.getCustomerInfo();
        final activeEntitlements = refreshed.entitlements.active;
        bool willRenew = true;
        if (activeEntitlements.isNotEmpty) {
          willRenew = activeEntitlements.values.first.willRenew;
        }
        if (!willRenew) {
          // Consider as cancelled
          cancelledWithinHour = true;
        }
      } catch (_) {}

      if (cancelledWithinHour) {
        _startTrialSuppressedUsers.add(uid);
        debugPrint('📘 Facebook StartTrial suppressed (cancelled within 1 hour).');
        return;
      }

      // Build parameters if not provided
      final Map<String, dynamic> params = eventParameters ?? {
        'fb_content_type': 'product',
        'fb_content_id': productId,
        'fb_currency': 'USD',
        '_valueToSum': 0.00,
      };

      // Re-check gate right before sending
      if (!await _shouldSendMetaEvents()) {
        _startTrialSuppressedUsers.add(uid);
        debugPrint('📘 StartTrial suppressed at send time (male user gate).');
        return;
      }

      final facebookAppEvents = FacebookAppEvents();
      await facebookAppEvents.logEvent(name: 'StartTrial', parameters: params);
      _startTrialSentUsers.add(uid);

      debugPrint('📘 Facebook StartTrial event sent after 1-hour validation.');
    } catch (e) {
      debugPrint('❌ Error in deferred StartTrial handling: $e');
    }
  }

  /// Schedule Meta CAPI StartTrial event via Cloud Functions (5 minutes delay on backend).
  Future<void> _scheduleStartTrialCapiTask(CustomerInfo customerInfo) async {
    try {
      if (!await _shouldSendMetaEvents()) {
        debugPrint('📘 Skipping CAPI schedule (male user gate).');
        return;
      }

      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final String productId = _getProductIdFromCustomerInfo(customerInfo);
      if (!productId.toLowerCase().contains('trial')) return;

      // Determine purchase start time
      DateTime now = DateTime.now();
      DateTime? startDate;
      final entitlements = customerInfo.entitlements.active;
      if (entitlements.isNotEmpty) {
        final entitlement = entitlements.values.first;
        if (entitlement.latestPurchaseDate != null) {
          try { startDate = DateTime.parse(entitlement.latestPurchaseDate!); } catch (_) {}
        }
      }
      startDate ??= customerInfo.getLatestTransactionPurchaseDate() ?? now;

      final callable = FirebaseFunctions.instance.httpsCallable('scheduleMetaStartTrial');
      await callable.call({
        'productId': productId,
        'startDateMs': startDate.millisecondsSinceEpoch,
      });
      debugPrint('📘 Scheduled Meta CAPI StartTrial via Cloud Task.');
    } catch (e) {
      debugPrint('❌ Error scheduling Meta CAPI StartTrial: $e');
    }
  }

  // Gate helper: returns true if Meta events should be sent
  Future<bool> _shouldSendMetaEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gender = prefs.getString('user_gender')?.toLowerCase().trim();
      if (gender == null || gender.isEmpty) return true; // unknown → allow
      if (gender == 'male' || gender == 'man' || gender == 'm') {
        return false; // skip for men
      }
      return true;
    } catch (_) {
      return true; // fail-open
    }
  }
  
  /// Track Firebase Analytics Purchase event after successful purchase
  Future<void> _trackFirebaseAnalyticsPurchaseEvent(CustomerInfo customerInfo) async {
    try {
      // Get the active subscription product ID
      final activeSubscriptions = customerInfo.activeSubscriptions;
      if (activeSubscriptions.isEmpty) {
        debugPrint('⚠️ No active subscriptions found for Firebase Analytics tracking');
        return;
      }
      
      final productId = activeSubscriptions.first;
      
      // Generate unique transaction ID
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Determine localized price via RevenueCat
      final resolved = await _resolveLocalizedPriceAndCurrency(productId);
      double price = resolved?.price ?? 49.99;
      String period = productId.toLowerCase().contains('monthly')
          ? 'Monthly'
          : productId.toLowerCase().contains('weekly')
              ? 'Weekly'
              : productId.toLowerCase().contains('lifetime')
                  ? 'Lifetime'
                  : 'Annual';
      String itemName = productId.toLowerCase().contains('trial')
          ? 'Trial Subscription'
          : 'Subscription';
      
      // Track Firebase Analytics Purchase event
      await FirebaseAnalytics.instance.logPurchase(
        currency: resolved?.currency ?? 'USD',
        value: price,
        transactionId: orderId,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: itemName,
            itemCategory: 'subscription',
            itemVariant: period,
          ),
        ],
      );
      
      debugPrint('📊 Firebase Analytics purchase event tracked successfully for product: $productId (Price: \$${price.toStringAsFixed(2)}, Period: $period)');
      
      // Removed Mixpanel Firebase Analytics purchase event tracking
    } catch (e) {
      debugPrint('❌ Error tracking Firebase Analytics purchase event: $e');
      
      // Removed Mixpanel Firebase Analytics purchase failure tracking
    }
  }
  
  /// Track Firebase Analytics subscription activation (from listener, not purchase flow)
  Future<void> _trackFirebaseAnalyticsSubscriptionActivation(CustomerInfo customerInfo) async {
    try {
      // Only track if user has active subscription and we haven't tracked this recently
      if (!customerInfo.hasActiveEntitlementOrSubscription()) {
        return;
      }
      
      final activeSubscriptions = customerInfo.activeSubscriptions;
      if (activeSubscriptions.isEmpty) {
        return;
      }
      
      final productId = activeSubscriptions.first;
      
      // Track subscription start/activation event with currency/price when available
      final resolved = await _resolveLocalizedPriceAndCurrency(productId);
      await FirebaseAnalytics.instance.logEvent(
        name: 'subscription_activated',
        parameters: {
          'product_id': productId,
          'subscription_source': 'listener_activation',
          if (resolved != null) 'currency': resolved.currency,
          if (resolved != null) 'price': resolved.price,
        },
      );
      
      debugPrint('📊 Firebase Analytics subscription_activated event tracked for: $productId');
      
      // Removed Mixpanel Firebase Analytics subscription activation tracking
    } catch (e) {
      debugPrint('❌ Error tracking Firebase Analytics subscription activation: $e');
      
      // Removed Mixpanel Firebase Analytics subscription activation failure tracking
    }
  }

  /// Checks if a trial subscription has converted to paid and updates Firestore accordingly
  Future<void> _checkAndHandleTrialConversion(CustomerInfo customerInfo) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get current user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists || userDoc.data() == null) return;

      final userData = userDoc.data()!;
      final bool isTrialActive = userData['isTrialActive'] ?? false;
      final bool trialConvertedToPaid = userData['trialConvertedToPaid'] ?? false;
      final Timestamp? trialExpirationTimestamp = userData['trialExpirationDate'] as Timestamp?;

      // Only check if trial is active and not yet converted
      if (!isTrialActive || trialConvertedToPaid || trialExpirationTimestamp == null) {
        return;
      }

      // Check if we have an active subscription that indicates trial conversion
      final activeSubscriptions = customerInfo.activeSubscriptions;
      bool hasTrialProduct = false;
      
      for (final productId in activeSubscriptions) {
        if (productId.toLowerCase().contains('trial')) {
          hasTrialProduct = true;
          break;
        }
      }

      if (hasTrialProduct) {
        final DateTime trialExpirationDate = trialExpirationTimestamp.toDate();
        final DateTime now = DateTime.now();

        // Check if trial has expired and should be converted
        if (now.isAfter(trialExpirationDate)) {
          debugPrint('⏰ SuperwallPurchaseController: Trial expired, converting to paid subscription for user ${user.uid}');
          
          // Update trial conversion status in Firestore
          await _firestore.collection('users').doc(user.uid).update({
            'isTrialActive': false,
            'trialConvertedToPaid': true,
            'trialToSubscriptionConversionDate': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Removed Mixpanel trial conversion tracking

          // Track trial conversion in all analytics platforms
          final productId = activeSubscriptions.first;
          await _trackTrialConversionAnalytics(user.uid, productId, trialExpirationDate);

          debugPrint('✅ SuperwallPurchaseController: Trial successfully converted to paid subscription for user ${user.uid}');
        }
      }
    } catch (e) {
      debugPrint('❌ SuperwallPurchaseController: Error checking trial conversion: $e');
    }
  }

  /// Track trial conversion in analytics (both Facebook and Firebase Analytics)
  Future<void> _trackTrialConversionAnalytics(String userId, String productId, DateTime trialExpirationDate) async {
    try {
      // Initialize localized price/currency for reuse across events
      double conversionPrice = 49.99;
      String conversionCurrency = 'USD';

      // Track Facebook standard purchase for trial conversion (for ROAS)
      try {
        final baseProductId = _inferBasePlanProductId(productId);
        final resolved = await _resolveLocalizedPriceAndCurrency(baseProductId);
        conversionPrice = resolved?.price ?? conversionPrice;
        conversionCurrency = resolved?.currency ?? conversionCurrency;
        final orderId = DateTime.now().millisecondsSinceEpoch.toString();

        final facebookAppEvents = FacebookAppEvents();
        await facebookAppEvents.logEvent(
          name: 'fb_mobile_purchase',
          parameters: {
            'fb_content_type': 'subscription',
            'fb_content_id': productId,
            'fb_currency': conversionCurrency,
            '_valueToSum': conversionPrice,
            'fb_order_id': orderId,
          },
        );
        debugPrint('📘 Facebook fb_mobile_purchase (trial conversion) tracked for: $productId');
      } catch (e) {
        debugPrint('❌ Error tracking Facebook purchase (trial conversion): $e');
      }

      // Track Firebase Analytics trial conversion event
      try {
        await FirebaseAnalytics.instance.logEvent(
          name: 'trial_converted_to_paid',
          parameters: {
            'product_id': productId,
            'trial_expiration_date': trialExpirationDate.toIso8601String(),
            'conversion_date': DateTime.now().toIso8601String(),
            'trial_duration_days': 3,
            'value': conversionPrice, // The value user will now pay
            'currency': conversionCurrency, // Include currency for complete tracking
          },
        );
        
        debugPrint('📊 Firebase Analytics trial_converted_to_paid event tracked for: $productId');
      } catch (e) {
        debugPrint('❌ Error tracking Firebase Analytics trial conversion: $e');
      }

      // Removed Mixpanel trial conversion analytics tracking
    } catch (e) {
      debugPrint('❌ Error tracking trial conversion analytics: $e');
      
      // Removed Mixpanel trial conversion failure tracking
    }
  }
  
  // Helper methods for billing error categorization and analysis
  
  /// Categorizes billing errors for better reporting and analysis
  String _categorizeBillingError(PurchasesErrorCode errorCode) {
    switch (errorCode) {
      case PurchasesErrorCode.purchaseInvalidError:
        return 'Payment Method Invalid';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchase Not Allowed';
      case PurchasesErrorCode.paymentPendingError:
        return 'Payment Pending (SCA/Approval Required)';
      case PurchasesErrorCode.storeProblemError:
        return 'Store Infrastructure Problem';
      case PurchasesErrorCode.networkError:
        return 'Network Connectivity Issue';
      case PurchasesErrorCode.insufficientPermissionsError:
        return 'Insufficient Permissions';
      case PurchasesErrorCode.invalidCredentialsError:
        return 'Invalid Store Credentials';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'Product Not Available';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'Product Already Owned';
      case PurchasesErrorCode.receiptAlreadyInUseError:
        return 'Receipt Already In Use';
      case PurchasesErrorCode.invalidReceiptError:
        return 'Invalid Receipt';
      case PurchasesErrorCode.missingReceiptFileError:
        return 'Missing Receipt File';
      case PurchasesErrorCode.ineligibleError:
        return 'User Ineligible for Offer';
      case PurchasesErrorCode.unknownBackendError:
        return 'Backend Service Error';
      case PurchasesErrorCode.unexpectedBackendResponseError:
        return 'Backend Response Error';
      case PurchasesErrorCode.purchaseCancelledError:
        return 'User Cancelled Purchase';
      default:
        return 'Unknown Error Type';
    }
  }
  
  /// Categorizes restore purchase errors for better reporting
  String _categorizeRestoreError(PurchasesErrorCode errorCode) {
    switch (errorCode) {
      case PurchasesErrorCode.invalidReceiptError:
        return 'Invalid Receipt During Restore';
      case PurchasesErrorCode.missingReceiptFileError:
        return 'No Receipt File Available';
      case PurchasesErrorCode.networkError:
        return 'Network Issue During Restore';
      case PurchasesErrorCode.storeProblemError:
        return 'Store Service Problem During Restore';
      case PurchasesErrorCode.invalidCredentialsError:
        return 'Invalid Store Credentials During Restore';
      default:
        return 'General Restore Error';
    }
  }
  
  /// Determines if the error occurred during a trial conversion attempt
  bool _isTrialConversionError(CustomerInfo? customerInfo) {
    if (customerInfo == null) return false;
    
    // Check if user has any trial product IDs in their purchase history
    final trialProductIds = [
      'com.stoppr.app.annual.trial', // iOS
      'com.stoppr.sugar.app.annual.trial:com-stoppr-sugar-app-annual-trial', // Android
    ];
    
    return customerInfo.allPurchasedProductIdentifiers
        .any((id) => trialProductIds.contains(id));
  }
  
  /// Initialize streak data for new subscribers if they don't have one yet
  /// Sets streak in BOTH SharedPreferences AND Firestore
  Future<void> _initializeStreakIfNeeded() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ Cannot initialize streak - no user logged in');
      return;
    }
    
    try {
      // Check if user already has a streak
      final streakStartDate = await _userRepository.getUserStreakStartDate(user.uid);
      
      if (streakStartDate == null) {
        // User doesn't have a streak - initialize it now
        final now = DateTime.now();
        debugPrint('🎉 Initializing NEW streak for subscriber: $now');
        
        // StreakService handles EVERYTHING: SharedPreferences, Firestore, and widget
        await StreakService().setCustomStreakStartDate(now);
        
        debugPrint('✅ Streak auto-started for new subscriber');
      } else {
        debugPrint('✅ User already has streak: $streakStartDate');
      }
    } catch (e, stack) {
      debugPrint('❌ Error initializing streak: $e');
      debugPrint('Stack trace: $stack');
    }
  }
}

// MARK: Helpers

String _buildSubscriptionOptionId(String? basePlanId, String? offerId) {
  String result = '';

  if (basePlanId != null) {
    result += basePlanId;
  }

  if (offerId != null) {
    if (basePlanId != null) {
      result += ':';
    }
    result += offerId;
  }

  return result;
}

extension CustomerInfoAdditions on CustomerInfo {
  bool hasActiveEntitlementOrSubscription() {
    return (activeSubscriptions.isNotEmpty || entitlements.active.isNotEmpty);
  }

  DateTime? getLatestTransactionPurchaseDate() {
    Map<String, String?> allPurchaseDates = this.allPurchaseDates;

    // Return null if there are no purchase dates
    if (allPurchaseDates.entries.isEmpty) {
      return null;
    }

    // Initialise the latestDate with the earliest possible date
    DateTime latestDate = DateTime.fromMillisecondsSinceEpoch(0);

    // Iterate over each entry in the map
    allPurchaseDates.forEach((key, value) {
      // Check if the value is not null
      if (value != null) {
        try {
          // Parse the date from the string value
          DateTime date = DateTime.parse(value);
          // Update the latestDate if the current date is after the latestDate
          if (date.isAfter(latestDate)) {
            latestDate = date;
          }
        } catch (e) {
          debugPrint('❌ Failed to parse purchase date: $e for key: $key, value: $value');
        }
      }
    });

    // Only return the date if it's after 1970 (not the default initialized value)
    return latestDate.isAfter(DateTime.fromMillisecondsSinceEpoch(1000)) ? latestDate : null;
  }
}

extension PurchasesAdditions on Purchases {
  static Future<List<rc.StoreProduct>> getAllProducts(List<String> productIdentifiers) async {
    // Only query for subscription products since we know our products are subscriptions
    return await Purchases.getProducts(
      productIdentifiers,
      productCategory: ProductCategory.subscription
    );
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
} 