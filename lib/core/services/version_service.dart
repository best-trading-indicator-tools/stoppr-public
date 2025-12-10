import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A data class to hold the result of the version check.
class VersionCheckResult {
  final bool versionChanged;
  final String? currentBuildNumber;
  final String? changelogContent;

  const VersionCheckResult({
    required this.versionChanged,
    this.currentBuildNumber,
    this.changelogContent,
  });
}

class VersionService {
  static const MethodChannel _channel =
      MethodChannel('com.stoppr.app/environment');
  static const String _storedBuildKey = 'last_run_build_number';

  /// Checks if the app version (build number) has changed since the last run.
  ///
  /// If the version has changed, it returns a [VersionCheckResult] with
  /// `versionChanged` set to true, the `currentBuildNumber`, and the content
  /// of the corresponding changelog markdown file (if found).
  ///
  /// If the version hasn't changed, it returns `versionChanged` as false.
  Future<VersionCheckResult> checkVersion() async {
    try {
      final Map<dynamic, dynamic>? versionInfo = await _getVersionInfo();
      if (versionInfo == null || versionInfo['build'] == null) {
        debugPrint('Failed to get current build number from native channel.');
        return const VersionCheckResult(versionChanged: false);
      }

      final String currentBuild = versionInfo['build'] as String;
      debugPrint('Current build number: $currentBuild');

      final prefs = await SharedPreferences.getInstance();
      final String? storedBuild = prefs.getString(_storedBuildKey);
      debugPrint('Stored build number: $storedBuild');

      if (storedBuild == null || storedBuild != currentBuild) {
        debugPrint(
          'Version changed (or first run). Stored: $storedBuild, Current: $currentBuild',
        );
        // Update stored build number *before* attempting to load changelog
        await prefs.setString(_storedBuildKey, currentBuild);

        final changelog = await _loadChangelog(currentBuild);
        return VersionCheckResult(
          versionChanged: true,
          currentBuildNumber: currentBuild,
          changelogContent: changelog,
        );
      } else {
        debugPrint('Version has not changed.');
        return const VersionCheckResult(versionChanged: false);
      }
    } catch (e, stackTrace) {
      debugPrint('Error checking version: $e');
      return const VersionCheckResult(versionChanged: false);
    }
  }

  /// Calls the native method channel to get version and build number.
  Future<Map<dynamic, dynamic>?> _getVersionInfo() async {
    try {
      final versionInfo = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppVersion');
      return versionInfo;
    } on PlatformException catch (e) {
      debugPrint('Failed to get app version: ${e.message}');
      return null;
    }
  }

  /// Loads the changelog markdown content for the given build number.
  Future<String?> _loadChangelog(String buildNumber) async {
    // Remove dots from the build number to match file naming convention
    final formattedBuildNumber = buildNumber.replaceAll('.', '');
    final path = 'assets/changelog/$formattedBuildNumber.md';
    debugPrint('Attempting to load changelog from: $path');
    try {
      final content = await rootBundle.loadString(path);
      debugPrint('Changelog loaded successfully.');
      return content;
    } catch (e) {
      // It's okay if a changelog doesn't exist for a build
      debugPrint('Could not load changelog file: $path. Error: $e');
      return null;
    }
  }
} 