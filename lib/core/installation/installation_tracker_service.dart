import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

/// Service to detect app redownloads (uninstall/reinstall)
/// 
/// Uses different detection strategies for iOS and Android:
/// - iOS: Keychain storage (survives uninstall)
/// - Android: Firebase data vs local storage comparison
class InstallationTrackerService {
  // Keychain key (survives iOS uninstall)
  static const _keychainInstallKey = 'permanent_install_uuid';
  
  // SharedPrefs key (cleared on uninstall)
  static const _localInstallKey = 'local_install_flag';
  
  // Version tracking to only trigger for new redownloads
  static const _trackedFromVersionKey = 'redownload_tracking_from_version';
  static const _currentTrackingVersion = '5.9.0';
  
  // Flag to show feedback form
  static const _showFeedbackFormKey = 'show_redownload_feedback';
  
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  
  /// Check if this is a redownload
  /// Returns true only for users who redownload after version 5.9.0
  Future<bool> isRedownload() async {
    try {
      if (Platform.isIOS) {
        return await _detectIOSRedownload();
      } else {
        return await _detectAndroidRedownload();
      }
    } catch (e) {
      debugPrint('Error detecting redownload: $e');
      return false;
    }
  }
  
  /// iOS detection using Keychain
  Future<bool> _detectIOSRedownload() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we've already initialized tracking in this version
    final trackedFromVersion = prefs.getString(_trackedFromVersionKey);
    
    // Check Keychain
    final keychainUuid = await _storage.read(key: _keychainInstallKey);
    // Check local storage
    final hasLocalFlag = prefs.getBool(_localInstallKey) ?? false;
    
    if (keychainUuid == null) {
      // First ever install (no Keychain UUID exists)
      final newUuid = const Uuid().v4();
      await _storage.write(key: _keychainInstallKey, value: newUuid);
      await prefs.setBool(_localInstallKey, true);
      await prefs.setString(_trackedFromVersionKey, _currentTrackingVersion);
      await _trackInstallation(newUuid, isRedownload: false);
      debugPrint('🆕 First install detected, UUID created: $newUuid');
      return false;
    }
    
    // If we haven't tracked from this version yet, mark it now
    if (trackedFromVersion == null) {
      await prefs.setString(_trackedFromVersionKey, _currentTrackingVersion);
      await prefs.setBool(_localInstallKey, true);
      debugPrint('📊 Existing user, starting tracking from version $_currentTrackingVersion');
      return false; // Don't show feedback for existing users
    }
    
    if (!hasLocalFlag) {
      // Keychain exists but local is empty = REDOWNLOAD
      await prefs.setBool(_localInstallKey, true);
      await _trackInstallation(keychainUuid, isRedownload: true);
      debugPrint('🔄 iOS Redownload detected! UUID: $keychainUuid');
      return true;
    }
    
    debugPrint('✅ Normal iOS app launch');
    return false;
  }
  
  /// Android detection using Firebase data comparison
  Future<bool> _detectAndroidRedownload() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final hasLocalFlag = prefs.getBool(_localInstallKey) ?? false;
    final trackedFromVersion = prefs.getString(_trackedFromVersionKey);
    
    if (user != null && !hasLocalFlag) {
      // User exists in Firebase but no local flag
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          // User has data in Firestore
          
          // Check if this user was already using the app before tracking started
          final userData = userDoc.data();
          final createdAt = userData?['createdAt'] as Timestamp?;
          
          if (trackedFromVersion == null) {
            // First time on this version - mark as tracked but don't show feedback
            await prefs.setString(_trackedFromVersionKey, _currentTrackingVersion);
            await prefs.setBool(_localInstallKey, true);
            debugPrint('📊 Existing Android user, starting tracking from version $_currentTrackingVersion');
            return false; // Don't show feedback for existing users
          }
          
          // This is a redownload
          await prefs.setBool(_localInstallKey, true);
          await _trackInstallation(user.uid, isRedownload: true);
          debugPrint('🔄 Android Redownload detected! User ID: ${user.uid}');
          return true;
        }
      } catch (e) {
        debugPrint('Error checking Firestore for redownload: $e');
      }
    }
    
    if (!hasLocalFlag) {
      // New install
      await prefs.setBool(_localInstallKey, true);
      await prefs.setString(_trackedFromVersionKey, _currentTrackingVersion);
      debugPrint('🆕 New Android install');
      return false;
    }
    
    debugPrint('✅ Normal Android app launch');
    return false;
  }
  
  /// Track installation in Firestore and Mixpanel
  Future<void> _trackInstallation(
    String installId, {
    required bool isRedownload,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown';
      
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      }
      
      // Update Firestore
      // CRITICAL: Cannot use FieldValue.serverTimestamp() inside arrayUnion()
      // This causes FIRInvalidArgumentException on iOS
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'installations': FieldValue.arrayUnion([
          {
            'installId': installId,
            'deviceId': deviceId,
            'installedAt': Timestamp.now(),
            'platform': Platform.operatingSystem,
            'isRedownload': isRedownload,
            'version': _currentTrackingVersion,
          }
        ])
      });
      
      // Track in Mixpanel
      MixpanelService.trackEvent(
        isRedownload ? 'App Redownloaded' : 'App First Install',
        properties: {
          'install_id': installId,
          'platform': Platform.operatingSystem,
          'device_id': deviceId,
          'version': _currentTrackingVersion,
        },
      );
      
      debugPrint('✅ Installation tracked: ${isRedownload ? "Redownload" : "New install"}');
    } catch (e) {
      debugPrint('Error tracking installation: $e');
    }
  }
  
  /// Check if feedback form should be shown
  Future<bool> shouldShowFeedbackForm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showFeedbackFormKey) ?? false;
  }
  
  /// Mark that redownload was detected and feedback form should be shown
  Future<void> markForFeedbackForm() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showFeedbackFormKey, true);
    debugPrint('📝 Marked for feedback form display');
  }
  
  /// Clear the feedback form flag
  Future<void> clearFeedbackFormFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_showFeedbackFormKey);
    debugPrint('✅ Cleared feedback form flag');
  }
}

