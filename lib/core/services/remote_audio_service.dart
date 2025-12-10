import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Service to download and cache large audio files from Firebase Storage
/// to reduce APK size while maintaining functionality.
/// Uses authenticated Firebase Storage requests (works with anonymous auth).
class RemoteAudioService {
  static final _storage = FirebaseStorage.instance;

  /// Map of audio IDs to their remote filenames
  static const Map<String, String> _remoteAudioFiles = {
    'nsdr': 'NSDR.mp3',
    'podcast': 'podcast_sound_1.mp3',
  };

  /// Get the local path for a cached audio file
  static Future<String> _getCacheFilePath(String audioId) async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/audio_cache');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return '${cacheDir.path}/${_remoteAudioFiles[audioId]}';
  }

  /// Check if an audio file is already cached locally
  static Future<bool> isCached(String audioId) async {
    final filePath = await _getCacheFilePath(audioId);
    return File(filePath).exists();
  }

  /// Get the local path for an audio file, downloading it if necessary
  /// Returns null if download fails
  /// Uses Firebase Storage with authentication (works for anonymous users too)
  static Future<String?> getAudioPath(String audioId) async {
    try {
      final fileName = _remoteAudioFiles[audioId];
      if (fileName == null) {
        debugPrint('RemoteAudioService: Unknown audio ID: $audioId');
        return null;
      }

      final filePath = await _getCacheFilePath(audioId);
      final file = File(filePath);

      // Return cached file if it exists
      if (await file.exists()) {
        debugPrint('RemoteAudioService: Using cached $audioId from $filePath');
        return filePath;
      }

      // Download the file using Firebase Storage (authenticated)
      debugPrint('RemoteAudioService: Downloading $audioId from Firebase Storage...');
      final storageRef = _storage.ref('audio/$fileName');
      
      // Download directly to file
      await storageRef.writeToFile(file);
      
      final fileSize = await file.length();
      debugPrint(
        'RemoteAudioService: Downloaded $audioId ($fileSize bytes)',
      );
      return filePath;
    } catch (e, stackTrace) {
      debugPrint('RemoteAudioService: Error getting audio $audioId: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Preload an audio file in the background
  static Future<void> preloadAudio(String audioId) async {
    await getAudioPath(audioId);
  }

  /// Clear all cached audio files (for cleanup/debugging)
  static Future<void> clearCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audio_cache');

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('RemoteAudioService: Cache cleared');
      }
    } catch (e) {
      debugPrint('RemoteAudioService: Error clearing cache: $e');
    }
  }

  /// Get cache size in bytes
  static Future<int> getCacheSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audio_cache');

      if (!await cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('RemoteAudioService: Error getting cache size: $e');
      return 0;
    }
  }
}

