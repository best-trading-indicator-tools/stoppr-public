import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String? latestVersion;
  final String? currentVersion;
  final String? storeUrl;

  const AppUpdateInfo({
    required this.hasUpdate,
    this.latestVersion,
    this.currentVersion,
    this.storeUrl,
  });
}

class AppUpdateService {
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const String _dismissedVersionKey = 'dismissed_version';
  static const String _appStoreId = '6742406521'; // Your iOS App Store ID
  static const String _playStorePackage = 'com.stoppr.sugar.app'; // Your Android package name
  
  // Check for updates with caching to avoid excessive API calls
  Future<AppUpdateInfo> checkForUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      // Check if we've checked recently (within last 6 hours)
      final lastCheck = prefs.getString(_lastUpdateCheckKey);
      if (lastCheck != null) {
        final lastCheckTime = DateTime.parse(lastCheck);
        if (now.difference(lastCheckTime).inHours < 6) {
          debugPrint('App update check skipped - checked recently');
          return const AppUpdateInfo(hasUpdate: false);
        }
      }
      
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      String? latestVersion;
      String? storeUrl;
      
      if (Platform.isIOS) {
        final result = await _checkAppStoreVersion();
        latestVersion = result['version'];
        storeUrl = result['url'];
      } else if (Platform.isAndroid) {
        final result = await _checkPlayStoreVersion();
        latestVersion = result['version'];
        storeUrl = result['url'];
      }
      
      // Update last check time
      await prefs.setString(_lastUpdateCheckKey, now.toIso8601String());
      
      if (latestVersion != null) {
        final hasUpdate = _isVersionNewer(latestVersion, currentVersion);
        
        // Check if user has dismissed this version
        final dismissedVersion = prefs.getString(_dismissedVersionKey);
        if (dismissedVersion == latestVersion) {
          debugPrint('App update available but user dismissed this version: $latestVersion');
          return AppUpdateInfo(
            hasUpdate: false,
            latestVersion: latestVersion,
            currentVersion: currentVersion,
            storeUrl: storeUrl,
          );
        }
        
        debugPrint('App update check: current=$currentVersion, latest=$latestVersion, hasUpdate=$hasUpdate');
        
        return AppUpdateInfo(
          hasUpdate: hasUpdate,
          latestVersion: latestVersion,
          currentVersion: currentVersion,
          storeUrl: storeUrl,
        );
      }
      
      return const AppUpdateInfo(hasUpdate: false);
    } catch (e) {
      debugPrint('Error checking for app update: $e');
      return const AppUpdateInfo(hasUpdate: false);
    }
  }
  
  // Check App Store for latest version
  Future<Map<String, String?>> _checkAppStoreVersion() async {
    try {
      final url = 'https://itunes.apple.com/lookup?id=$_appStoreId';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(
          utf8.decode(
            response.bodyBytes,
            allowMalformed: true,
          ),
        );
        if (data['results'] != null && data['results'].isNotEmpty) {
          final appInfo = data['results'][0];
          return {
            'version': appInfo['version'],
            'url': appInfo['trackViewUrl'],
          };
        }
      }
    } catch (e) {
      debugPrint('Error checking App Store version: $e');
    }
    
    return {'version': null, 'url': null};
  }
  
  // Check Play Store for latest version
  Future<Map<String, String?>> _checkPlayStoreVersion() async {
    try {
      // Note: Google Play doesn't have a public API for version checking
      // This is a simplified approach - in production you might want to use
      // your own backend service or a third-party service
      final url = 'https://play.google.com/store/apps/details?id=$_playStorePackage';
      
      // For now, return the store URL for manual checking
      // You could implement web scraping or use a backend service here
      return {
        'version': null, // Would need backend service or web scraping
        'url': url,
      };
    } catch (e) {
      debugPrint('Error checking Play Store version: $e');
    }
    
    return {'version': null, 'url': null};
  }
  
  // Compare version strings (e.g., "2.0.1" vs "2.0.0")
  bool _isVersionNewer(String latestVersion, String currentVersion) {
    try {
      final latest = latestVersion.split('.').map(int.parse).toList();
      final current = currentVersion.split('.').map(int.parse).toList();
      
      // Pad shorter version with zeros
      while (latest.length < current.length) latest.add(0);
      while (current.length < latest.length) current.add(0);
      
      for (int i = 0; i < latest.length; i++) {
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }
      
      return false; // Versions are equal
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false;
    }
  }
  
  // Mark a version as dismissed by the user
  Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
    debugPrint('Dismissed app update version: $version');
  }
  
  // Clear dismissed version (for testing or when user wants to see updates again)
  Future<void> clearDismissedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedVersionKey);
  }
} 