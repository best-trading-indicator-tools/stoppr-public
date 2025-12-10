import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/models/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../analytics/mixpanel_service.dart';
import '../superwall/superwall_purchase_controller.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../models/leaderboard_entry.dart'; // Import the new model
import 'package:package_info_plus/package_info_plus.dart';

// Add enum for subscription types
enum SubscriptionType {
  free,
  free_apple_promo,
  paid_standard,
  paid_standard_cheap, // Discounted subscription for users < 24 years old
  paid_gift,
  paid_lifetime // One-time lifetime purchase (not a subscription)
}


class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';
  final String _postsCollection = 'community_posts';
  bool _currentUserEligibility = true; // helper to expose eligibility in result
  
  Future<void> saveUserProfile(AppUser user) async {
    try {
      // Verify authentication before proceeding
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        MixpanelService.trackEvent('Firestore Permission Error', properties: {
          'error_type': 'authentication_missing',
          'operation': 'save_user_profile',
          'requested_user_id': user.uid,
        });
        debugPrint('⚠️ No authenticated user - skipping profile save');
        return;
      }
      
      // Verify the UID matches
      if (currentUser.uid != user.uid) {
        MixpanelService.trackEvent('Firestore Permission Error', properties: {
          'error_type': 'user_id_mismatch',
          'operation': 'save_user_profile',
          'current_user_id': currentUser.uid,
          'requested_user_id': user.uid,
        });
        debugPrint('⚠️ User ID mismatch - current: ${currentUser.uid}, requested: ${user.uid}');
        return;
      }
      
      // Extract first name from displayName if available
      String? firstName;
      if (user.displayName != null) {
        firstName = user.displayName!.split(' ').first;
      }
      
      // Check if user has email - if they do, they're not anonymous
      bool isAnonymous = user.email.isEmpty;
      
      // Convert provider ID to simpler auth_provider_id
      String? authProviderId;
      if (user.providerId != null) {
        if (user.providerId!.contains('google')) {
          authProviderId = 'google';
        } else if (user.providerId!.contains('apple')) {
          authProviderId = 'apple';
        } else if (user.providerId!.contains('password')) {
          authProviderId = 'email+pwd';
        } else {
          authProviderId = user.providerId; // Fallback to original
        }
      }
      
      // Check if user doc exists and if createdAt is already set
      final docRef = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await docRef.get();
      final bool documentExists = docSnapshot.exists;
      final userDocData = documentExists ? docSnapshot.data() : null;
      
      // Create user data map
      final userData = {
        'uid': user.uid,
        'email': user.email,
        'firstName': firstName,
        'displayName': user.displayName,
        'providerId': user.providerId,
        'auth_provider_id': authProviderId, // Add new field with simplified provider ID
        'isAnonymous': isAnonymous, // Set properly based on email presence
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Only set createdAt if doc does not exist or field is missing
      if (!documentExists || userDocData?['createdAt'] == null) {
        userData['createdAt'] = FieldValue.serverTimestamp();
      }
      
      // Add created during payment flag if true
      if (user.createdDuringPayment) {
        userData['createdDuringPayment'] = true;
        userData['paymentCreationTime'] = FieldValue.serverTimestamp();
      }
      
      // Save to Firestore
      await docRef.set(userData, SetOptions(merge: true));
      
      // Log for debugging
      debugPrint('✅ Saved user profile with auth_provider_id: $authProviderId, createdDuringPayment: ${user.createdDuringPayment}');
    } catch (e) {
      debugPrint('❌ Error saving user profile: $e');
      if (e.toString().contains('permission-denied')) {
        MixpanelService.trackEvent('Firestore Permission Error', properties: {
          'error_type': 'permission_denied',
          'operation': 'save_user_profile',
          'user_id': user.uid,
          'error_message': e.toString(),
        });
        debugPrint('⚠️ Permission denied - user may not be authenticated properly');
      }
      rethrow;
    }
  }
  
  // New method to update user profile with questionnaire data
  Future<void> updateUserProfile(String uid, {
    String? firstName, 
    String? age, 
    String? gender, 
    String? email, 
    String? authProviderId,
    String? locale,
    String? country
  }) async {
    String? oldFirstName; // Store old first name

    try {
      // Verify authentication before proceeding
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ No authenticated user - skipping profile update');
        return;
      }
      
      // Verify the UID matches
      if (currentUser.uid != uid) {
        debugPrint('⚠️ User ID mismatch - current: ${currentUser.uid}, requested: $uid');
        return;
      }
      
      debugPrint('Repo: updateUserProfile started for UID: $uid with firstName: $firstName'); // Log entry
      // Get current user data first to check existing values
      final docRef = _firestore.collection('users').doc(uid); // Use docRef for efficiency
      print('Repo: Getting document snapshot...'); // Log before get
      final docSnapshot = await docRef.get();
      print('Repo: Document snapshot received. Exists: ${docSnapshot.exists}'); // Log after get
      final bool documentExists = docSnapshot.exists;
      final userData = documentExists ? docSnapshot.data() : null;
      print('Repo: User data fetched: ${userData?.toString() ?? "null"}'); // Log fetched data
      final bool hasManuallyEnteredFirstName = firstName != null && firstName.isNotEmpty;
      print('Repo: hasManuallyEnteredFirstName: $hasManuallyEnteredFirstName'); // Log check result

      if (documentExists && userData != null) {
        print('Repo: Attempting to get oldFirstName...'); // Log before cast
        oldFirstName = userData['firstName'] as String?;
        print('Repo: oldFirstName retrieved: "$oldFirstName"'); // Log after cast
      }

      // Create update data map with only provided values
      print('Repo: Creating updateData map...'); // Log before map creation
      final Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // If document doesn't exist, add required fields for new document
      if (!documentExists) {
        updateData['uid'] = uid;
        
        // Check if email was provided - if so, user is not anonymous
        final bool isAnonymous = email == null || email.isEmpty;
        updateData['isAnonymous'] = isAnonymous;
        
        // Add email if provided
        if (email != null && email.isNotEmpty) {
          updateData['email'] = email;
        }
        
        // Add auth provider ID if provided
        if (authProviderId != null && authProviderId.isNotEmpty) {
          updateData['auth_provider_id'] = authProviderId;
        }
        
        // Only set createdAt if doc does not exist or field is missing
        if (userData == null || userData['createdAt'] == null) {
          updateData['createdAt'] = FieldValue.serverTimestamp();
        }
        
        // Add TTL field (expiresAt) for anonymous users - 90 days from now
        // Only add expiration for anonymous users
        if (isAnonymous) {
          final DateTime expirationDate = DateTime.now().add(const Duration(days: 90));
          updateData['expiresAt'] = Timestamp.fromDate(expirationDate);
          print('🆕 Creating new user profile for anonymous user: $uid with 90-day TTL');
        } else {
          print('🆕 Creating new user profile for email user: $uid');
        }
      } else {
        // If document exists, check if it already has email and update isAnonymous if needed
        final existingEmail = userData?['email'];
        final bool currentlyAnonymous = userData?['isAnonymous'] ?? true;
        
        if (currentlyAnonymous && email != null && email.isNotEmpty) {
          updateData['isAnonymous'] = false;
          updateData['email'] = email;
          print('✅ Converting anonymous user to email user: $uid');
          
          // Remove expiration date if it exists
          updateData['expiresAt'] = FieldValue.delete();
        }
        
        // Update auth provider ID if provided
        if (authProviderId != null && authProviderId.isNotEmpty) {
          updateData['auth_provider_id'] = authProviderId;
        }
      }
      
      // Only add fields that are provided and valid
      if (hasManuallyEnteredFirstName) {
        updateData['firstName'] = firstName;
        print('✅ Adding firstName to profile: $firstName'); // Existing log
      }
      
      if (age != null) updateData['age'] = age;
      if (gender != null) updateData['gender'] = gender;
      
      // Handle locale and country derivation
      String? finalLocale = locale;
      String? finalCountry = country;
      String? osName;
      String? osVersion;

      // If locale is not explicitly provided, get it from the device
      if (finalLocale == null || finalLocale.isEmpty) {
        try {
          finalLocale = Platform.localeName;
          print('✅ Using device locale: $finalLocale');
        } catch (e, s) {
          print('❌ Error getting device locale: $e');
          FirebaseCrashlytics.instance.recordError(
            e,
            s,
            reason: 'Failed to get Platform.localeName',
            information: ['User ID: $uid']
          );
          finalLocale = ''; // Assign empty string to avoid issues later
        }
      }
      
      // If country is not explicitly provided, try to derive it from the locale
      if (finalCountry == null || finalCountry.isEmpty) {
        // Ensure finalLocale is not null/empty before trying to split
        if (finalLocale != null && finalLocale.isNotEmpty && (finalLocale.contains('_') || finalLocale.contains('-'))) {
            final separator = finalLocale.contains('_') ? '_' : '-';
            final parts = finalLocale.split(separator);
            if (parts.length > 1 && parts[1].isNotEmpty) {
              finalCountry = parts[1];
              print('✅ Derived country from locale: $finalCountry');
            }
        }
      }
      
      // Add locale and country to updateData if they have values
      if (finalLocale != null && finalLocale.isNotEmpty) {
        updateData['locale'] = finalLocale;
      }
      if (finalCountry != null && finalCountry.isNotEmpty) {
        updateData['country'] = finalCountry;
      }
      
      // Get OS and OS version from Platform
       try {
         osName = Platform.operatingSystem;
         osVersion = Platform.operatingSystemVersion;
         print('✅ Adding OS information to profile: $osName $osVersion');
         updateData['os'] = osName;
         updateData['os_version'] = osVersion;
       } catch (e, s) {
         print('❌ Error getting OS information: $e');
         FirebaseCrashlytics.instance.recordError(
           e,
           s,
           reason: 'Failed to get Platform.operatingSystem or operatingSystemVersion',
           information: ['User ID: $uid']
         );
         // Optionally set default values or leave them out of updateData
         // updateData['os'] = 'unknown';
         // updateData['os_version'] = 'unknown';
       }
      
      // Get app version using package_info_plus
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final appVersion = packageInfo.version;
        print('✅ Adding app version to profile: $appVersion');
        updateData['app_version'] = appVersion;
      } catch (e, s) {
        print('❌ Error getting app version: $e');
        FirebaseCrashlytics.instance.recordError(
          e,
          s,
          reason: 'Failed to get app version using package_info_plus',
          information: ['User ID: $uid']
        );
        // Optionally set default value or leave out
        // updateData['app_version'] = 'unknown';
      }
      
      // Don't update if there's nothing to update other than timestamp
      if (updateData.length <= 1 && documentExists) {
        print('ℹ️ No profile data to update for user $uid (only timestamp)');
        // Even if only timestamp changes, we might still need to proceed if firstName logic changes,
        // But for now, let's keep this check. Revisit if needed.
         return; // Skip update if only timestamp is present for existing user
      }
      
      // Use set() with merge for new documents, update() for existing ones
      bool updateSuccessful = false;
      try {
        if (documentExists) {
          // Update the existing Firestore document
          await docRef.update(updateData); // Use docRef
          print('✅ Existing user profile updated with data: $updateData');
          updateSuccessful = true;
        } else {
          // Create a new document with set()
          await docRef.set(updateData, SetOptions(merge: true)); // Use docRef
          print('✅ New user profile created with data: $updateData');
          updateSuccessful = true; // Assume success if no error

          // Also check if we need to create the onboarding subcollection
          // Create an empty document in the onboarding subcollection to ensure it exists
          await docRef // Use docRef
              .collection('onboarding')
              .doc('init')
              .set({
                'createdAt': FieldValue.serverTimestamp(),
                'initialized': true
              }, SetOptions(merge: true));
          print('✅ Initialized onboarding subcollection for user $uid');
        }
      } catch (e, s) {
        print('❌ Error performing Firestore set/update operation: $e');
        
        // Handle Firebase unavailable errors with retry logic
        if (e.toString().contains('cloud_firestore/unavailable') || 
            e.toString().contains('unavailable')) {
          print('⚠️ Firebase unavailable, attempting retry...');
          
          // Simple retry logic - wait and try once more
          await Future.delayed(const Duration(seconds: 2));
          try {
            if (documentExists) {
              await docRef.update(updateData);
            } else {
              await docRef.set(updateData, SetOptions(merge: true));
            }
            print('✅ Retry successful after Firebase unavailable error');
            updateSuccessful = true;
            return; // Exit early on successful retry
          } catch (retryError) {
            print('❌ Retry failed: $retryError');
            // Continue with normal error handling below
          }
        }
        
        FirebaseCrashlytics.instance.recordError(
            e,
            s,
            reason: 'Firestore update/set failed in updateUserProfile',
            information: ['User ID: $uid', 'Document Existed: $documentExists', 'Update Data: ${updateData.toString()}']
        );
        // updateSuccessful remains false
      }
      
      // --- Add the call to update comments ---
      if (updateSuccessful && updateData.containsKey('firstName')) {
         final newFirstName = updateData['firstName'] as String?;
         // Check if name actually changed and is not null/empty
         if (newFirstName != null && newFirstName.isNotEmpty && newFirstName != oldFirstName) {
            print('ℹ️ First name changed from "$oldFirstName" to "$newFirstName". Triggering comment update.');
            // Asynchronously update comments - don't wait for it to finish
            _updateCommentsAuthorName(uid, newFirstName).catchError((e) {
                print("❌ Error during background comment update: $e");
                 // TODO: Log this error to Crashlytics or your monitoring service
            });
         } else {
            print('ℹ️ First name update detected, but value ("$newFirstName") is same as old ("$oldFirstName") or invalid. Skipping comment update.');
         }
      }
      // --- End of added logic ---

      print('Repo: Finished preparing base updateData: $updateData'); // Log after base map setup
      
      // Sync updated data to analytics and subscription services
      if (updateSuccessful) {
        // Don't wait for these operations to complete as they are non-critical
        _syncUserDataToAnalytics(uid).catchError((e, s) {
          print('❌ Error syncing user data to analytics services: $e');
          // Optionally log this sync error to Crashlytics as well, but maybe with lower priority
           FirebaseCrashlytics.instance.recordError(
             e,
             s,
             reason: 'Error during background _syncUserDataToAnalytics',
             information: ['User ID: $uid'],
             fatal: false // Mark as non-fatal
           );
        });
      }

    } catch (e, s) { // Also catch stack trace
      debugPrint('❌ Error updating user profile: $e');
      debugPrint('❌ Stacktrace: $s'); // Print stack trace
      
      // Handle specific Firebase errors
      if (e.toString().contains('permission-denied')) {
        debugPrint('⚠️ Permission denied - user may not be authenticated properly');
      } else if (e.toString().contains('cloud_firestore/unavailable') || 
                 e.toString().contains('unavailable')) {
        debugPrint('⚠️ Firebase service temporarily unavailable - this is a transient error');
        // Don't crash the app for transient Firebase issues
        return;
      }
      
      FirebaseCrashlytics.instance.recordError( // <-- Log top-level errors too
        e,
        s,
        reason: 'Unhandled error in updateUserProfile top-level try-catch',
        information: ['User ID: $uid', 'First Name Input: $firstName']
      );
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('❌ Error getting user profile: $e');
      rethrow;
    }
  }
  
  // Method to handle user conversion from anonymous to permanent
  Future<void> convertAnonymousUser(String uid) async {
    try {
      // Remove the TTL field when user converts to a permanent account
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'isAnonymous': false,
            'expiresAt': FieldValue.delete(), // Remove the expiration
            'updatedAt': FieldValue.serverTimestamp(),
          });
      print('✅ Converted anonymous user to permanent: $uid');
    } catch (e) {
      print('❌ Error converting anonymous user: $e');
      rethrow;
    }
  }
  
  // Method to refresh TTL for anonymous users
  Future<void> refreshAnonymousUserTTL(String uid) async {
    try {
      // Get current user data to check if they're anonymous
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      if (!docSnapshot.exists) return;
      
      final userData = docSnapshot.data();
      final bool isAnonymous = userData?['isAnonymous'] == true;
      
      // Only refresh TTL for anonymous users
      if (isAnonymous) {
        final DateTime expirationDate = DateTime.now().add(const Duration(days: 90));
        await _firestore
            .collection('users')
            .doc(uid)
            .update({
              'expiresAt': Timestamp.fromDate(expirationDate),
              'updatedAt': FieldValue.serverTimestamp(),
            });
        print('✅ Refreshed TTL for anonymous user: $uid');
      }
    } catch (e) {
      print('❌ Error refreshing anonymous user TTL: $e');
      // Don't rethrow as this is a non-critical operation
    }
  }
  
  // Method to update user subscription status
  Future<void> updateUserSubscriptionStatus(String uid, SubscriptionType subscriptionType, {String? productId, DateTime? startDate, DateTime? expirationDate, DateTime? trialExpirationDate}) async {
    try {
      final String subscriptionTypeStr = subscriptionType.toString().split('.').last;
      
      // Create update data map
      final Map<String, dynamic> updateData = {
        'subscriptionStatus': subscriptionTypeStr,
        'updatedAt': FieldValue.serverTimestamp(),
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      };
      
      // Add product ID if provided (for better tracking)
      if (productId != null && productId.isNotEmpty) {
        updateData['subscriptionProductId'] = productId;
      }
      
      // Add subscription start date if available
      if (startDate != null) {
        updateData['subscriptionStartDate'] = Timestamp.fromDate(startDate);
      }

      // Add trial expiration date if provided (for trial subscriptions)
      if (trialExpirationDate != null) {
        updateData['trialExpirationDate'] = Timestamp.fromDate(trialExpirationDate);
        updateData['isTrialActive'] = true; // Mark trial as active
        updateData['trialConvertedToPaid'] = false; // Not yet converted
        print('✅ Trial expiration date set: ${trialExpirationDate.toIso8601String()}');
      }

      // Add subscription expiration date ONLY if the type is NOT free/lifetime
      // and the date is actually provided.
      // Lifetime purchases don't have expiration dates
      if (subscriptionType != SubscriptionType.free && 
          subscriptionType != SubscriptionType.paid_lifetime && 
          expirationDate != null) {
        updateData['subscriptionExpirationDate'] = Timestamp.fromDate(expirationDate);
      } else if (subscriptionType == SubscriptionType.free) {
        // Explicitly do NOT update expirationDate when setting status to free,
        // preserving any potentially valid future date.
        // We could optionally set it to null here if that's the desired behavior
        // when a user *becomes* free, but for the current issue, just omitting
        // the update is safer.
        // updateData['subscriptionExpirationDate'] = null; // Optional: Uncomment to clear date when becoming free
        print('ℹ️ Subscription status is free, preserving existing expiration date in Firestore.');
      } else if (subscriptionType == SubscriptionType.paid_lifetime) {
        // Lifetime purchases don't need expiration dates
        print('ℹ️ Lifetime purchase - no expiration date needed.');
      }
      
      await _firestore
          .collection('users')
          .doc(uid)
          .set(updateData, SetOptions(merge: true)); // Use set with merge to create or update
      
      print('✅ Updated user subscription status to $subscriptionTypeStr${productId != null ? ' with product ID: $productId' : ''}');
      if (startDate != null) {
        print('✅ Subscription start date: ${startDate.toIso8601String()}');
      }
      if (trialExpirationDate != null) {
        print('✅ Trial expiration date: ${trialExpirationDate.toIso8601String()}');
      }
      if (expirationDate != null) {
        print('✅ Subscription expiration date: ${expirationDate.toIso8601String()}');
      }
    } catch (e) {
      print('❌ Error updating user subscription status: $e');
      rethrow;
    }
  }
  
  // Method to delete user data from Firestore
  Future<void> deleteUserData(String uid) async {
    try {
      final batch = _firestore.batch();
      
      // 1. Delete the main user document
      final userRef = _firestore.collection('users').doc(uid);
      batch.delete(userRef);
      
      // 2. Delete onboarding subcollection
      final onboardingDocs = await userRef.collection('onboarding').get();
      for (final doc in onboardingDocs.docs) {
        batch.delete(doc.reference);
      }
      
      // 3. Delete pledges subcollection
      final pledgeDocs = await userRef.collection('pledges').get();
      for (final doc in pledgeDocs.docs) {
        batch.delete(doc.reference);
      }
      
      // 4. Delete any other user-specific subcollections
      // Add more subcollections here as they are added to the app
      
      // Commit all deletions in a single batch
      await batch.commit();
      
      print('✅ Deleted all user data for user: $uid');
    } catch (e) {
      print('❌ Error deleting user data: $e');
      rethrow;
    }
  }
  
  // Method to get the user's current subscription status
  Future<SubscriptionType> getUserSubscriptionStatus(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final userData = doc.data();
      
      if (userData == null || !userData.containsKey('subscriptionStatus')) {
        return SubscriptionType.free; // Default to free if not set
      }
      
      final String subscriptionStr = userData['subscriptionStatus'] as String;
      
      switch (subscriptionStr) {
        case 'paid_standard':
          return SubscriptionType.paid_standard;
        case 'paid_gift':
          return SubscriptionType.paid_gift;
        case 'paid_lifetime':
          return SubscriptionType.paid_lifetime;
        default:
          return SubscriptionType.free;
      }
    } catch (e) {
      print('❌ Error getting subscription status: $e');
      return SubscriptionType.free; // Default to free on error
    }
  }
  
  // Method to refresh user data from Firestore (without any caching)
  Future<Map<String, dynamic>?> refreshUserData(String uid) async {
    try {
      // Force a fresh fetch from Firestore without relying on cache
      final doc = await _firestore.collection('users').doc(uid).get(GetOptions(source: Source.server));
      print('✅ Refreshed user data from server for user: $uid');
      return doc.data();
    } catch (e) {
      print('❌ Error refreshing user data: $e');
      rethrow;
    }
  }
  
  // Method to save referral code for a user
  Future<void> saveReferralCode(String uid, String referralCode) async {
    try {
      if (referralCode.isEmpty) {
        print('ℹ️ No referral code to save for user: $uid');
        return;
      }
      
      // Create the data map
      final Map<String, dynamic> updateData = {
        'referralCode': referralCode,
        'referralCodeAddedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Use set with merge option to handle cases where the document might not exist yet
      await _firestore
          .collection('users')
          .doc(uid)
          .set(updateData, SetOptions(merge: true));
      
      print('✅ Saved referral code for user: $uid - Code: $referralCode');
    } catch (e) {
      print('❌ Error saving referral code: $e');
      rethrow;
    }
  }
  
  // For testing: Set subscription status
  Future<void> setSubscriptionStatus(String uid, String status) async {
    try {
      // Valid statuses: 'free', 'paid_standard', 'paid_gift', 'paid_lifetime'
      if (!['free', 'paid_standard', 'paid_gift', 'paid_lifetime'].contains(status)) {
        throw ArgumentError('Invalid subscription status: $status. Must be free, paid_standard, paid_gift, or paid_lifetime');
      }
      
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'subscriptionStatus': status,
            'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      print('✅ Updated subscription status to $status for user $uid');
    } catch (e) {
      print('❌ Error updating subscription status: $e');
      rethrow;
    }
  }
  
  // Method to update just the auth provider information
  Future<void> updateAuthProvider(String uid, String providerId) async {
    try {
      // Convert provider ID to simpler auth_provider_id
      String authProviderId;
      if (providerId.contains('google')) {
        authProviderId = 'google';
      } else if (providerId.contains('apple')) {
        authProviderId = 'apple';
      } else if (providerId.contains('password')) {
        authProviderId = 'email+pwd';
      } else {
        authProviderId = providerId; // Fallback to original
      }
      
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
            'providerId': providerId,
            'auth_provider_id': authProviderId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
      print('✅ Updated auth provider to: $authProviderId');
    } catch (e) {
      print('❌ Error updating auth provider: $e');
      rethrow;
    }
  }

  /// Updates the authorName in all comments made by a specific user.
  /// Assumes comments are stored in a root 'comments' collection.
  Future<void> _updateCommentsAuthorName(String userId, String newFirstName) async {
    // It's crucial that newFirstName is the validated, non-empty name here.
    if (newFirstName.isEmpty) {
        print('⚠️ Attempted to update comments with an empty first name for user $userId. Aborting.');
        return; // Safety check
    }

    print('ℹ️ Starting background update of authorName to "$newFirstName" for user $userId comments.');
    // IMPORTANT: Adjust this collection path if comments are nested (e.g., under posts)
    final commentsRef = _firestore.collection('comments');
    final query = commentsRef.where('authorId', isEqualTo: userId);
    final int batchLimit = 499; // Firestore batch limit is 500 operations per commit

    try {
        QuerySnapshot snapshot = await query.limit(batchLimit).get();
        int totalUpdatedCount = 0;
        int processedDocs = 0;

        while (snapshot.docs.isNotEmpty) {
            WriteBatch batch = _firestore.batch(); // Start a new batch for this set of documents
            int currentBatchUpdateCount = 0;
            processedDocs += snapshot.docs.length;

            for (final doc in snapshot.docs) {
                final currentData = doc.data() as Map<String, dynamic>?; // Cast data
                final currentName = currentData?['authorName'] as String?;

                // Update only if name is different from the new name
                if (currentName != newFirstName) {
                    batch.update(doc.reference, {'authorName': newFirstName});
                    currentBatchUpdateCount++;
                }
            }

            if (currentBatchUpdateCount > 0) {
                print(' Committing batch to update authorName for $currentBatchUpdateCount comments (User: $userId)...');
                await batch.commit();
                totalUpdatedCount += currentBatchUpdateCount;
                print(' Batch committed successfully.');
            } else {
                 print('ℹ️ No authorName updates needed in this batch of ${snapshot.docs.length} comments (User: $userId).');
            }

            // Check if we processed less than the limit, meaning we are done
            if (snapshot.docs.length < batchLimit) {
                 print(' Finished processing comments. Less than batch limit received.');
                 break;
            }

            // Get the last document to continue the query for the next batch
            final lastVisible = snapshot.docs.last;
            print(' Fetching next batch of comments after doc ID: ${lastVisible.id} (User: $userId)...');
            snapshot = await query.startAfterDocument(lastVisible).limit(batchLimit).get();
        }

        if (totalUpdatedCount > 0) {
             print('✅ Successfully updated authorName for $totalUpdatedCount comments for user $userId. Total docs processed: $processedDocs.');
        } else if (processedDocs > 0) {
             print('ℹ️ Processed $processedDocs comments for user $userId, but no authorName updates were required.');
        } else {
             print('ℹ️ No comments found for user $userId needing an authorName update.');
        }

    } catch (e) {
        print('❌ FATAL Error during batch update of authorName in comments for user $userId: $e');
        // Log this critical error (e.g., Crashlytics)
    }
  }
  
  /// Updates the authorName in all comments made by a specific user in the community posts structure.
  /// Works with comments that are subcollections under posts.
  Future<void> updateCommunityCommentsAuthorName(String userId, String newFirstName) async {
    if (newFirstName.isEmpty) {
        print('⚠️ Attempted to update community comments with an empty first name for user $userId. Aborting.');
        return; // Safety check
    }

    print('ℹ️ Starting update of authorName to "$newFirstName" for user $userId in community comments.');
    
    // In the community structure, comments are subcollections under posts
    final String postsCollectionName = 'community_posts';
    final String commentsSubCollectionName = 'comments';
    final int batchLimit = 499; // Firestore batch limit is 500 operations per commit
    int totalUpdatedCount = 0;
    int totalPostsWithComments = 0;

    try {
        // First, get all posts
        final postsSnapshot = await _firestore.collection(postsCollectionName).get();
        print('📂 Found ${postsSnapshot.docs.length} posts to check for comments by user $userId');
        
        // For each post, check for comments by this user
        for (final postDoc in postsSnapshot.docs) {
            final postId = postDoc.id;
            final commentsQuery = _firestore
                .collection(postsCollectionName)
                .doc(postId)
                .collection(commentsSubCollectionName)
                .where('authorId', isEqualTo: userId);
                
            final commentsSnapshot = await commentsQuery.get();
            
            if (commentsSnapshot.docs.isNotEmpty) {
                totalPostsWithComments++;
                print('📑 Found ${commentsSnapshot.docs.length} comments by user $userId in post $postId');
                
                // Use a batch to update all comments in this post
                final batch = _firestore.batch();
                int currentBatchCount = 0;
                
                for (final commentDoc in commentsSnapshot.docs) {
                    final currentData = commentDoc.data() as Map<String, dynamic>?;
                    final currentName = currentData?['authorName'] as String?;
                    
                    // Update only if name is different
                    if (currentName != newFirstName) {
                        batch.update(commentDoc.reference, {'authorName': newFirstName});
                        currentBatchCount++;
                    }
                }
                
                // Commit the batch if there are updates
                if (currentBatchCount > 0) {
                    await batch.commit();
                    totalUpdatedCount += currentBatchCount;
                    print('✅ Updated $currentBatchCount comments in post $postId');
                }
            }
        }
        
        print('🎉 Finished updating comments. Updated $totalUpdatedCount comments across $totalPostsWithComments posts.');
        
    } catch (e) {
        print('❌ Error updating community comments: $e');
    }
    
    return;
  }

  /// Checks if user has an active trial and converts it to paid subscription if trial has expired.
  /// This should be called periodically (e.g., on app open) to handle trial conversions.
  Future<bool> checkAndConvertExpiredTrial(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return false;
      }
      
      final userData = doc.data()!;
      final bool isTrialActive = userData['isTrialActive'] ?? false;
      final bool trialConvertedToPaid = userData['trialConvertedToPaid'] ?? false;
      final Timestamp? trialExpirationTimestamp = userData['trialExpirationDate'] as Timestamp?;
      
      // Only check if trial is active and not yet converted
      if (!isTrialActive || trialConvertedToPaid || trialExpirationTimestamp == null) {
        return false;
      }
      
      final DateTime trialExpirationDate = trialExpirationTimestamp.toDate();
      final DateTime now = DateTime.now();
      
      // Check if trial has expired
      if (now.isAfter(trialExpirationDate)) {
        print('⏰ Trial expired for user $uid. Converting to paid subscription...');
        
        // Update trial status
        await _firestore.collection('users').doc(uid).update({
          'isTrialActive': false,
          'trialConvertedToPaid': true,
          'trialToSubscriptionConversionDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Track conversion in Mixpanel
        try {
          MixpanelService.trackEvent('Trial Converted to Paid Subscription', properties: {
            'user_id': uid,
            'trial_expiration_date': trialExpirationDate.toIso8601String(),
            'conversion_date': now.toIso8601String(),
            'trial_duration_days': 3,
          });
        } catch (e) {
          print('❌ Error tracking trial conversion: $e');
        }
        
        print('✅ Trial successfully converted to paid subscription for user $uid');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error checking and converting expired trial: $e');
      return false;
    }
  }

  // Helper method to sync user data to analytics and subscription services
  Future<void> _syncUserDataToAnalytics(String userId) async {
    try {
      // Get the current Firebase user to verify they're still logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        print("⚠️ User is no longer logged in or UID doesn't match, skipping analytics sync");
        return;
      }
      
      // Sync to Mixpanel
      await MixpanelService.syncUserPropertiesFromFirestore(userId);
      print('✅ Synced user data to Mixpanel for user: $userId');
      
      // Sync to RevenueCat
      final purchaseController = SuperwallPurchaseController();
      await purchaseController.syncUserPropertiesFromFirestore(userId);
      print('✅ Synced user data to RevenueCat for user: $userId');
      
    } catch (e) {
      print('❌ Error in _syncUserDataToAnalytics: $e');
      // Don't rethrow as this is a background operation
    }
  }

  /// Updates the streak start timestamp and calculated current streak days for a user.
  Future<void> updateUserStreakData(String uid, DateTime? streakStartDate) async {
    try {
      final Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (streakStartDate != null) {
        final now = DateTime.now();
        // Ensure start date is not in the future for calculation
        final validStartDate = streakStartDate.isAfter(now) ? now : streakStartDate;
        final streakDuration = now.difference(validStartDate);
        final currentStreakDays = streakDuration.inDays;

        updateData['streak_start_timestamp'] = Timestamp.fromDate(validStartDate);
        updateData['currentStreakDays'] = currentStreakDays;
        print('✅ Updating streak data for user $uid: Start=$validStartDate, Days=$currentStreakDays');
      } else {
        // If start date is null, clear the streak fields
        updateData['streak_start_timestamp'] = null;
        updateData['currentStreakDays'] = 0;
        print('✅ Clearing streak data for user $uid');
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .set(updateData, SetOptions(merge: true)); // Use set with merge to handle potential new user case

    } catch (e, s) {
      print('❌ Error updating user streak data: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        s,
        reason: 'Failed to update user streak data in Firestore',
        information: ['User ID: $uid', 'Streak Start Date: ${streakStartDate?.toIso8601String()}']
      );
      // Decide if rethrowing is necessary based on usage context
      // rethrow;
    }
  }

  /// Updates the app open streak data for a user.
  Future<void> updateAppOpenStreakData(String uid, int consecutiveDays, DateTime? streakStartDate, DateTime? lastOpenDate) async {
    try {
      final Map<String, dynamic> updateData = {
        'appOpenStreakDays': consecutiveDays,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (streakStartDate != null) {
        updateData['appOpenStreakStartDate'] = Timestamp.fromDate(streakStartDate);
      }

      if (lastOpenDate != null) {
        updateData['appOpenLastDate'] = Timestamp.fromDate(lastOpenDate);
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .set(updateData, SetOptions(merge: true));

      print('✅ Updated app open streak data for user $uid: Days=$consecutiveDays');

    } catch (e, s) {
      print('❌ Error updating app open streak data: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        s,
        reason: 'Failed to update app open streak data in Firestore',
        information: ['User ID: $uid', 'Consecutive Days: $consecutiveDays']
      );
    }
  }

  /// Gets the user's streak start timestamp from Firestore
  Future<DateTime?> getUserStreakStartDate(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        debugPrint('No user document found for streak data: $uid');
        return null;
      }
      
      final userData = doc.data();
      if (userData == null) {
        return null;
      }
      
      // Check for streak_start_timestamp field
      final streakTimestamp = userData['streak_start_timestamp'] as Timestamp?;
      if (streakTimestamp != null) {
        final streakDate = streakTimestamp.toDate();
        debugPrint('✅ Found streak start date in Firestore: $streakDate for user $uid');
        return streakDate;
      }
      
      debugPrint('No streak_start_timestamp found in Firestore for user $uid');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user streak from Firestore: $e');
      return null;
    }
  }

  /// Fetches leaderboard data including top entries and current user's info.
  /// Assumes current user doc has 'leaderboardRank' and 'currentStreakDays' fields.
  Future<Map<String, dynamic>> getLeaderboardData(String? currentUserId) async { // Allow null userId
    const int limit = 10; // Number of entries to fetch from each source

    try {
      // --- Fetch Top Users (Always fetch these) ---
      // Avoid composite index requirement by not mixing equality filter with orderBy.
      // We'll filter out fake/debug users client-side (debugUser == true) and over-fetch.
      final usersQuery = _firestore
          .collection(_usersCollection)
          .orderBy('currentStreakDays', descending: true)
          .limit(limit * 5);
      final usersSnapshot = await usersQuery.get();
      final List<Map<String, dynamic>> topUsers = [];
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        // Skip obviously fake users
        final isDebugUser = (data['debugUser'] == true) ||
            (data['is_test_user'] == true) ||
            (data['fakeUser'] == true);
        if (isDebugUser) continue;

        // Include all users regardless of subscription status; only skip obvious debug/fake users

        final name = (data['firstName'] as String?) ??
            (data['displayName'] as String?) ??
            'User';
        final streak = (data['currentStreakDays'] ?? 0) as int;
        topUsers.add({'id': doc.id, 'name': name, 'streak': streak});
        if (topUsers.length >= limit) break; // stop once we have enough
      }

      // --- Fetch Current User Info (Only if logged in) ---
      int currentUserRank = 0; // Default rank
      int currentUserStreak = 0; // Default streak
      if (currentUserId != null) { // Check if userId is provided
        final currentUserDoc = await _firestore.collection(_usersCollection).doc(currentUserId).get();
        if (currentUserDoc.exists) {
          final data = currentUserDoc.data();
          // Ensure data is not null before trying to access fields
          if (data != null) {
            // Eligibility: exclude free or expired subscriptions
            final String subscriptionStatus = (data['subscriptionStatus'] as String?) ?? 'free';
            final Timestamp? subExpTs = data['subscriptionExpirationDate'] as Timestamp?;
            final bool isTrialActive = data['isTrialActive'] == true;
            final bool trialConvertedToPaid = data['trialConvertedToPaid'] == true;
            final Timestamp? trialExpTs = data['trialExpirationDate'] as Timestamp?;
            final DateTime now = DateTime.now();
            bool isExpired = false;
            if (subExpTs != null && now.isAfter(subExpTs.toDate())) {
              isExpired = true;
            }
            if (isTrialActive && trialExpTs != null) {
              final DateTime trialExp = trialExpTs.toDate();
              if (now.isAfter(trialExp) && !trialConvertedToPaid) {
                isExpired = true;
              }
            }
            final bool isFree = subscriptionStatus == 'free';

            currentUserRank = (data['leaderboardRank'] ?? 0) as int;
            currentUserStreak = (data['currentStreakDays'] ?? 0) as int;

            // If rank is 0 (or not properly set), calculate it even for 0-day streaks.
            if (currentUserRank <= 0) {
              try {
                print('ℹ️ User $currentUserId has streak $currentUserStreak but rank is $currentUserRank. Calculating rank...');
                final countQuery = _firestore
                    .collection(_usersCollection)
                    .where('currentStreakDays', isGreaterThan: currentUserStreak);
                
                final aggregateSnapshot = await countQuery.count().get();
                // aggregateSnapshot.count can be null if the query fails or for other reasons.
                currentUserRank = (aggregateSnapshot.count ?? 0) + 1;
                print('✅ Calculated rank for $currentUserId: $currentUserRank');

                // Optional: Consider writing this calculated rank back to Firestore for persistence.
                // await _firestore.collection(_usersCollection).doc(currentUserId).set({'leaderboardRank': currentUserRank, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                // print('✅ Updated Firestore with calculated rank for $currentUserId: $currentUserRank');

              } catch (e, s) {
                print('⚠️ Error calculating rank for user $currentUserId: $e');
                // Log to Crashlytics or your preferred error reporting service
                FirebaseCrashlytics.instance.recordError(
                  e,
                  s,
                  reason: 'Failed to calculate leaderboard rank for current user',
                  information: ['User ID: $currentUserId', 'User Streak: $currentUserStreak'],
                );
                // If calculation fails, currentUserRank remains what it was (e.g., 0)
              }
            }
            // Attach eligibility to result map via local variable capture below
            final bool currentEligible = !(isExpired || isFree);
            // stash in closure state via a temp map we'll merge later
            _currentUserEligibility = currentEligible;
          } else {
            // Handle case where currentUserDoc exists but data() is null (should be rare)
            print('⚠️ currentUserDoc exists for $currentUserId but data is null.');
          }
        } else {
          // Handle case where currentUserDoc doesn't exist
           print('ℹ️ No user document found for $currentUserId. Rank and streak will be 0.');
        }
      }

      // --- Merge and Sort Top Entries --- (users only)
      final combinedEntries = [...topUsers];
      combinedEntries.sort((a, b) => (b['streak'] as int).compareTo(a['streak'] as int));

      // --- Create LeaderboardEntry Objects & Assign Medals ---
      final List<LeaderboardEntry> leaderboardEntries = [];
      final displayedEntries = combinedEntries.take(limit).toList(); // Take top N based on limit

      for (int i = 0; i < displayedEntries.length; i++) {
        final entry = displayedEntries[i];
        String? medal;
        if (i == 0) medal = '🥇'; // Gold
        if (i == 1) medal = '🥈'; // Silver
        if (i == 2) medal = '🥉'; // Bronze

        leaderboardEntries.add(LeaderboardEntry(
          userId: entry['id'] as String,
          rank: i + 1,
          name: entry['name'] as String,
          streakDays: entry['streak'] as int,
          medalEmoji: medal,
        ));
      }

      print('✅ Fetched Leaderboard Data: ${leaderboardEntries.length} top entries, User Rank: $currentUserRank, User Streak: $currentUserStreak (User ID: $currentUserId)');

      return {
        'topEntries': leaderboardEntries,
        'currentUserInfo': {
          'rank': currentUserRank,
          'streak': currentUserStreak,
          'eligible': _currentUserEligibility,
        },
      };
    } catch (e, s) {
      print('❌ Error fetching leaderboard data: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        s,
        reason: 'Failed to fetch leaderboard data',
        information: ['User ID: ${currentUserId ?? "Not logged in"}'], // Include user ID info
      );
      // Return empty/default data on error
      return {
        'topEntries': <LeaderboardEntry>[],
        'currentUserInfo': {
          'rank': 0,
          'streak': 0,
        },
      };
    }
  }
} 