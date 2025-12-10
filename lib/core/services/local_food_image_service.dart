import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocalFoodImageService {
  static final LocalFoodImageService _instance = LocalFoodImageService._internal();
  factory LocalFoodImageService() => _instance;
  LocalFoodImageService._internal();

  static const String _imagesKey = 'food_images_by_date';
  static const int _maxDaysToKeepLocal = 7; // Keep local images for 7 days
  static const int _maxDaysToKeepCloud = 7; // Keep cloud images for 7 days (updated)
  static const int _thumbnailSize = 150;
  
  late final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cache for built thumbnail widgets to prevent unnecessary rebuilds
  final Map<String, Widget> _thumbnailCache = <String, Widget>{};
  final Map<String, Future<Widget>> _thumbnailFutures = <String, Future<Widget>>{};
  final List<String> _cacheOrder = <String>[]; // For LRU cache management
  static const int _maxCacheSize = 50; // Limit cache to 50 thumbnails

  /// Save a food image and return the local file path
  Future<String?> saveFoodImage(String foodLogId, Uint8List imageBytes) async {
    try {
      // 1. Save locally first (fast)
      final localPath = await _saveImageLocally(foodLogId, imageBytes);
      
      // 2. Upload to Firebase Storage in background (don't await)
      _uploadToFirebaseStorage(foodLogId, imageBytes).catchError((e) {
      });
      
      return localPath;
    } catch (e) {
      debugPrint('❌ Error saving food image: $e');
      return null;
    }
  }

  /// Save a food image locally only (for debug mode) without Firebase upload
  Future<String?> saveFoodImageLocalOnly(String foodLogId, Uint8List imageBytes) async {
    try {
      final localPath = await _saveImageLocally(foodLogId, imageBytes);
      debugPrint('📷 Image saved locally only: $localPath');
      return localPath;
    } catch (e) {
      debugPrint('❌ Error saving food image locally: $e');
      return null;
    }
  }


  /// Save image locally for fast access
  Future<String?> _saveImageLocally(String foodLogId, Uint8List imageBytes) async {
    try {
      // Get app support directory (more persistent across updates)
      final directory = await getApplicationSupportDirectory();
      final foodImagesDir = Directory('${directory.path}/food_images');
      
      // Create directory if it doesn't exist
      if (!await foodImagesDir.exists()) {
        await foodImagesDir.create(recursive: true);
      }

      // Compress image to thumbnail size
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;

      // Resize to thumbnail
      img.Image thumbnail = img.copyResize(originalImage, width: _thumbnailSize);
      final compressedBytes = img.encodeJpg(thumbnail, quality: 85);

      // Save to file
      final fileName = '$foodLogId.jpg';
      final file = File('${foodImagesDir.path}/$fileName');
      await file.writeAsBytes(compressedBytes);

      // Store path in SharedPreferences
      await _storeFoodImagePath(foodLogId, file.path);

      debugPrint('📷 Saved local image: ${file.path} (${compressedBytes.length} bytes)');
      return file.path;
    } catch (e) {
      debugPrint('❌ Error saving local image: $e');
      return null;
    }
  }

  /// Upload image to Firebase Storage (background operation)
  Future<void> _uploadToFirebaseStorage(String foodLogId, Uint8List imageBytes) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return;
      }
      
      // Use user-isolated path: food_images/{userId}/{foodLogId}.jpg
      final userId = user.uid;
      
      final ref = _storage.ref()
          .child('food_images')
          .child(userId)
          .child('$foodLogId.jpg');
      
      // Set metadata with custom deletion date (7 days from now)
      final deletionDate = DateTime.now().add(const Duration(days: _maxDaysToKeepCloud));
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'foodLogId': foodLogId,
          'uploadDate': DateTime.now().toIso8601String(),
          'deleteAfter': deletionDate.toIso8601String(),
          'isAnonymous': user.isAnonymous.toString(),
        },
      );
      
      await ref.putData(imageBytes, metadata);
    } catch (e) {
      // Don't rethrow - local image is still saved
    }
  }

  /// Get food image path for a food log ID
  Future<String?> getFoodImagePath(String foodLogId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagesJson = prefs.getString(_imagesKey) ?? '{}';
      final imagesMap = Map<String, dynamic>.from(jsonDecode(imagesJson));
      
      // Search through all dates for this food log ID
      for (final dateEntry in imagesMap.values) {
        if (dateEntry is Map<String, dynamic> && dateEntry.containsKey(foodLogId)) {
          final path = dateEntry[foodLogId] as String;
          // Check if file still exists
          if (await File(path).exists()) {
            return path;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting food image path: $e');
      return null;
    }
  }

  /// Store food image path organized by date
  Future<void> _storeFoodImagePath(String foodLogId, String imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _formatDate(DateTime.now());
      
      // Get existing images map
      final imagesJson = prefs.getString(_imagesKey) ?? '{}';
      final imagesMap = Map<String, dynamic>.from(jsonDecode(imagesJson));
      
      // Add to today's images
      if (!imagesMap.containsKey(today)) {
        imagesMap[today] = <String, String>{};
      }
      imagesMap[today][foodLogId] = imagePath;
      
      // Clean up old entries
      await _cleanupOldImages(imagesMap);
      
      // Save back to SharedPreferences
      await prefs.setString(_imagesKey, jsonEncode(imagesMap));
    } catch (e) {
      debugPrint('❌ Error storing food image path: $e');
    }
  }

  /// Clean up images older than maxDaysToKeep
  Future<void> _cleanupOldImages(Map<String, dynamic> imagesMap) async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: _maxDaysToKeepLocal));
      final datesToRemove = <String>[];
      
      for (final dateKey in imagesMap.keys) {
        final date = DateTime.tryParse(dateKey);
        if (date != null && date.isBefore(cutoffDate)) {
          datesToRemove.add(dateKey);
          
          // Delete actual files
          final dateImages = imagesMap[dateKey] as Map<String, dynamic>?;
          if (dateImages != null) {
            for (final imagePath in dateImages.values) {
              try {
                final file = File(imagePath as String);
                if (await file.exists()) {
                  await file.delete();
                  debugPrint('🗑️ Deleted old food image: $imagePath');
                }
              } catch (e) {
                debugPrint('⚠️ Could not delete old image file: $e');
              }
            }
          }
        }
      }
      
      // Remove old entries from map
      for (final dateKey in datesToRemove) {
        imagesMap.remove(dateKey);
      }
      
      if (datesToRemove.isNotEmpty) {
        debugPrint('🧹 Cleaned up ${datesToRemove.length} days of old food images');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up old images: $e');
    }
  }

  /// Format date for storage key
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Update image tracking from temporary ID to real Firestore ID
  Future<void> updateImageTrackingId(String tempId, String realId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagesJson = prefs.getString(_imagesKey) ?? '{}';
      final imagesMap = Map<String, dynamic>.from(jsonDecode(imagesJson));
      
      // Find and update the temp ID entry
      for (final dateKey in imagesMap.keys) {
        final dateImages = imagesMap[dateKey] as Map<String, dynamic>?;
        if (dateImages != null && dateImages.containsKey(tempId)) {
          final imagePath = dateImages[tempId];
          // Remove old temp ID entry
          dateImages.remove(tempId);
          // Add with real ID
          dateImages[realId] = imagePath;
          
          debugPrint('📷 Updated image tracking: $tempId -> $realId');
          break;
        }
      }
      
      // Save updated map
      await prefs.setString(_imagesKey, jsonEncode(imagesMap));
    } catch (e) {
      debugPrint('❌ Error updating image tracking ID: $e');
    }
  }

  /// Get thumbnail widget for a food log
  Widget buildThumbnail(String? imagePath, {double size = 80}) {
    if (imagePath == null || imagePath.isEmpty) {
      return _buildPlaceholderThumbnail(size);
    }

    // Check if this is a network URL (e.g., from recipes)
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // For recipe images from Edamam API, display directly from network
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // For local scanned food images, use existing logic
    // Extract foodLogId from imagePath for potential Firebase fallback
    final foodLogId = _extractFoodLogIdFromPath(imagePath);
    final cacheKey = '${foodLogId ?? imagePath}_$size';
    
    // Check if we already have a cached widget for this image
    if (_thumbnailCache.containsKey(cacheKey)) {
      // Move to end of cache order (LRU)
      _cacheOrder.remove(cacheKey);
      _cacheOrder.add(cacheKey);
      return _thumbnailCache[cacheKey]!;
    }
    
    // Check if we already have a future for this image to avoid duplicate requests
    if (!_thumbnailFutures.containsKey(cacheKey)) {
      _thumbnailFutures[cacheKey] = _buildThumbnailFromPath(imagePath, foodLogId, size);
    }
    
    return FutureBuilder<Widget>(
      key: ValueKey(cacheKey), // Stable key prevents unnecessary rebuilds
      future: _thumbnailFutures[cacheKey]!,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // Cache the built widget to prevent future rebuilds
          _addToCache(cacheKey, snapshot.data!);
          return snapshot.data!;
        }
        // Show loading placeholder while resolving
        return _buildLoadingThumbnail(size);
      },
    );
  }

  /// Build a full-size preview image widget with fallback logic (higher quality than thumbnails)
  Widget buildPreviewImage(String? imagePath, {double? width, double? height}) {
    if (imagePath == null || imagePath.isEmpty) {
      return _buildPlaceholderPreview(width, height);
    }

    // Check if this is a network URL (e.g., from recipes)
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // For recipe images from Edamam API, display directly from network
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // For local scanned food images, use existing logic
    // Extract foodLogId from imagePath for potential Firebase fallback
    final foodLogId = _extractFoodLogIdFromPath(imagePath);
    
    return FutureBuilder<Widget>(
      future: _buildPreviewFromPath(imagePath, foodLogId, width, height),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        // Show loading placeholder while resolving
        return _buildLoadingPreview(width, height);
      },
    );
  }

  /// Extract foodLogId from local path or use it directly
  String? _extractFoodLogIdFromPath(String imagePath) {
    try {
      // If imagePath is already a foodLogId (no slashes), return it directly
      if (!imagePath.contains('/')) {
        return imagePath;
      }
      
      // Otherwise extract from file path
      final fileName = imagePath.split('/').last;
      // Remove .jpg extension if present
      final nameWithoutExt = fileName.endsWith('.jpg') 
          ? fileName.substring(0, fileName.length - 4) 
          : fileName;
      
      // Return the ID (no more underscore logic needed)
      return nameWithoutExt;
    } catch (e) {
      debugPrint('Could not extract foodLogId from path: $imagePath');
    }
    return null;
  }

  /// Build thumbnail from local path or Firebase fallback
  Future<Widget> _buildThumbnailFromPath(String imagePath, String? foodLogId, double size) async {
    String? actualFilePath = imagePath;
    
    // If imagePath looks like a foodLogId (no slashes), get the actual file path
    if (!imagePath.contains('/') && foodLogId != null) {
      actualFilePath = await getFoodImagePath(foodLogId);
      debugPrint('📷 Resolved foodLogId $foodLogId to file path: $actualFilePath');
    }
    
    // First try local file if we have a valid path
    if (actualFilePath != null) {
      final file = File(actualFilePath);
      final fileExists = await file.exists();
      
      if (fileExists) {
        debugPrint('📷 Loading local thumbnail from: $actualFilePath');
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(file),
              fit: BoxFit.cover,
              onError: (error, stackTrace) {
                debugPrint('❌ Error loading local thumbnail: $error');
              },
            ),
          ),
        );
      } else {
        debugPrint('📷 Local file does not exist: $actualFilePath');
      }
    }

    // If local file doesn't exist and we have foodLogId, try Firebase
    if (foodLogId != null) {
      debugPrint('📷 Trying Firebase for foodLogId: $foodLogId');
      final firebaseWidget = await _buildThumbnailFromFirebase(foodLogId, size);
      if (firebaseWidget != null) {
        debugPrint('📷 Successfully loaded from Firebase: $foodLogId');
        return firebaseWidget;
      } else {
        debugPrint('📷 Firebase failed for foodLogId: $foodLogId');
      }
    }

    // Fallback to placeholder
    debugPrint('📷 Using placeholder for: $imagePath (foodLogId: $foodLogId)');
    return _buildPlaceholderThumbnail(size);
  }

  /// Try to load image from Firebase Storage
  Future<Widget?> _buildThumbnailFromFirebase(String foodLogId, double size) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }
      
      // Use user-isolated path
      final userId = user.uid;
      final ref = _storage.ref()
          .child('food_images')
          .child(userId)
          .child('$foodLogId.jpg');
      
      final imageBytes = await ref.getData();
      
      if (imageBytes != null) {
        // Optionally save back to local cache
        await _saveImageLocally(foodLogId, imageBytes);
        
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: MemoryImage(imageBytes),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Build preview from local path or Firebase fallback (higher quality)
  Future<Widget> _buildPreviewFromPath(String imagePath, String? foodLogId, double? width, double? height) async {
    String? actualFilePath = imagePath;
    
    // If imagePath looks like a foodLogId (no slashes), get the actual file path
    if (!imagePath.contains('/') && foodLogId != null) {
      actualFilePath = await getFoodImagePath(foodLogId);
      debugPrint('📷 Preview: Resolved foodLogId $foodLogId to file path: $actualFilePath');
    }
    
    // For preview images, use Firebase first for full quality (local files are thumbnail quality)
    if (foodLogId != null) {
      final firebaseWidget = await _buildPreviewFromFirebase(foodLogId, width, height);
      if (firebaseWidget != null) {
        return firebaseWidget;
      }
    }
    
    // Fallback to local file if Firebase fails
    if (actualFilePath != null) {
      final file = File(actualFilePath);
      final fileExists = await file.exists();
      
      if (fileExists) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(file),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    return _buildPlaceholderPreview(width, height);
  }

  /// Try to load preview image from Firebase Storage (higher quality)
  Future<Widget?> _buildPreviewFromFirebase(String foodLogId, double? width, double? height) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }
      
      // Use user-isolated path
      final userId = user.uid;
      final ref = _storage.ref()
          .child('food_images')
          .child(userId)
          .child('$foodLogId.jpg');
      
      final imageBytes = await ref.getData();
      
      if (imageBytes != null) {
        // Don't save back as thumbnail - keep full quality in memory
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: MemoryImage(imageBytes),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Build loading thumbnail
  Widget _buildLoadingThumbnail(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFAE6EC),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFed3272)),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderThumbnail(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFAE6EC),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          color: Color(0xFFed3272),
          size: 32,
        ),
      ),
    );
  }

  /// Build loading preview widget
  Widget _buildLoadingPreview(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF34C759).withValues(alpha: 0.05),
      ),
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF34C759)),
          ),
        ),
      ),
    );
  }

  /// Build placeholder preview widget  
  Widget _buildPlaceholderPreview(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF34C759).withValues(alpha: 0.1),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          color: Color(0xFF34C759),
          size: 48,
        ),
      ),
    );
  }

  /// Clean up all images for current user (called when subscription expires)
  Future<void> cleanupUserImages() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ No authenticated user for image cleanup');
        return;
      }
      
      debugPrint('🧹 Starting image cleanup for user: ${user.uid}');
      
      // 1. Clean up Firebase Storage images
      await _cleanupFirebaseStorageForUser(user.uid);
      
      // 2. Clean up local images
      await _cleanupLocalImagesForUser();
      
      // 3. Clear SharedPreferences tracking
      await _clearImageTracking();
      
      // 4. Clear all cached widgets
      clearAllCache();
      
      debugPrint('✅ Image cleanup completed for user: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error during user image cleanup: $e');
    }
  }

  /// Clean up Firebase Storage images for a specific user
  Future<void> _cleanupFirebaseStorageForUser(String userId) async {
    try {
      final userImagesRef = _storage.ref().child('food_images').child(userId);
      
      // List all files in user's directory
      final result = await userImagesRef.listAll();
      
      // Delete each file
      for (final item in result.items) {
        try {
          await item.delete();
          debugPrint('🗑️ Deleted Firebase image: ${item.name}');
        } catch (e) {
          debugPrint('⚠️ Failed to delete Firebase image ${item.name}: $e');
        }
      }
      
      debugPrint('🧹 Cleaned up ${result.items.length} Firebase images for user: $userId');
    } catch (e) {
      debugPrint('❌ Error cleaning up Firebase images: $e');
    }
  }

  /// Clean up local images for current user
  Future<void> _cleanupLocalImagesForUser() async {
    try {
      // Get app support directory
      final directory = await getApplicationSupportDirectory();
      final foodImagesDir = Directory('${directory.path}/food_images');
      
      if (await foodImagesDir.exists()) {
        // Delete all files in the food images directory
        final files = foodImagesDir.listSync();
        for (final file in files) {
          if (file is File) {
            try {
              await file.delete();
              debugPrint('🗑️ Deleted local image: ${file.path}');
            } catch (e) {
              debugPrint('⚠️ Failed to delete local image ${file.path}: $e');
            }
          }
        }
        debugPrint('🧹 Cleaned up ${files.length} local images');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up local images: $e');
    }
  }

  /// Clear image tracking from SharedPreferences
  Future<void> _clearImageTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_imagesKey);
      debugPrint('🧹 Cleared image tracking from SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error clearing image tracking: $e');
    }
  }

  /// Clean up expired images (called periodically or on app start)
  Future<void> cleanupExpiredImages() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ No authenticated user for expired image cleanup');
        return;
      }
      
      // Clean up Firebase images older than 7 days
      await _cleanupExpiredFirebaseImages(user.uid);
      
      // Clean up local images using existing logic
      final prefs = await SharedPreferences.getInstance();
      final imagesJson = prefs.getString(_imagesKey) ?? '{}';
      final imagesMap = Map<String, dynamic>.from(jsonDecode(imagesJson));
      await _cleanupOldImages(imagesMap);
      await prefs.setString(_imagesKey, jsonEncode(imagesMap));
      
    } catch (e) {
      debugPrint('❌ Error during expired image cleanup: $e');
    }
  }

  /// Clean up Firebase images older than 7 days for a user
  Future<void> _cleanupExpiredFirebaseImages(String userId) async {
    try {
      final userImagesRef = _storage.ref().child('food_images').child(userId);
      final result = await userImagesRef.listAll();
      
      final cutoffDate = DateTime.now().subtract(const Duration(days: _maxDaysToKeepCloud));
      int deletedCount = 0;
      
      for (final item in result.items) {
        try {
          final metadata = await item.getMetadata();
          final uploadDateStr = metadata.customMetadata?['uploadDate'];
          
          if (uploadDateStr != null) {
            final uploadDate = DateTime.parse(uploadDateStr);
            if (uploadDate.isBefore(cutoffDate)) {
              await item.delete();
              deletedCount++;
              debugPrint('🗑️ Deleted expired Firebase image: ${item.name} (uploaded: $uploadDate)');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error processing Firebase image ${item.name}: $e');
        }
      }
      
      if (deletedCount > 0) {
        debugPrint('🧹 Cleaned up $deletedCount expired Firebase images for user: $userId');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up expired Firebase images: $e');
    }
  }

  /// Delete image from both local storage and Firebase Storage for a specific food log ID
  Future<void> deleteImageFromStorage(String foodLogId) async {
    // 1. Delete from local storage
    await _deleteLocalImage(foodLogId);
    
    // 2. Delete from Firebase Storage
    await _deleteFirebaseImage(foodLogId);
    
    // 3. Remove from SharedPreferences tracking
    await _removeImageTracking(foodLogId);
    
    // 4. Clear cached widgets for this food log
    _clearCacheForFoodLog(foodLogId);
  }
  
  /// Clear cached thumbnail widgets for a specific food log ID
  void _clearCacheForFoodLog(String foodLogId) {
    try {
      final keysToRemove = <String>[];
      for (final key in _thumbnailCache.keys) {
        if (key.startsWith('${foodLogId}_')) {
          keysToRemove.add(key);
        }
      }
      
      for (final key in keysToRemove) {
        _thumbnailCache.remove(key);
        _thumbnailFutures.remove(key);
        _cacheOrder.remove(key);
      }
      
      if (keysToRemove.isNotEmpty) {
        debugPrint('🧹 Cleared ${keysToRemove.length} cached thumbnails for food log: $foodLogId');
      }
    } catch (e) {
      debugPrint('❌ Error clearing cache for food log $foodLogId: $e');
    }
  }
  
  /// Clear all cached thumbnails (called during cleanup)
  void clearAllCache() {
    _thumbnailCache.clear();
    _thumbnailFutures.clear();
    _cacheOrder.clear();
    debugPrint('🧹 Cleared all thumbnail cache');
  }
  
  /// Add widget to cache with LRU eviction
  void _addToCache(String cacheKey, Widget widget) {
    // If already cached, just update position
    if (_thumbnailCache.containsKey(cacheKey)) {
      _cacheOrder.remove(cacheKey);
      _cacheOrder.add(cacheKey);
      return;
    }
    
    // Check if we need to evict oldest entries
    while (_thumbnailCache.length >= _maxCacheSize) {
      if (_cacheOrder.isNotEmpty) {
        final oldestKey = _cacheOrder.removeAt(0);
        _thumbnailCache.remove(oldestKey);
        _thumbnailFutures.remove(oldestKey);
      } else {
        break;
      }
    }
    
    // Add new entry
    _thumbnailCache[cacheKey] = widget;
    _cacheOrder.add(cacheKey);
  }

  /// Delete local image file for a food log ID
  Future<void> _deleteLocalImage(String foodLogId) async {
    try {
      // Get the local path from SharedPreferences
      final localPath = await getFoodImagePath(foodLogId);
      
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ Deleted local image: $localPath');
        }
      } else {
        debugPrint('⚠️ No local image path found for food log: $foodLogId');
      }
    } catch (e) {
      debugPrint('❌ Error deleting local image for $foodLogId: $e');
      // Don't rethrow - continue with Firebase deletion
    }
  }

  /// Delete image from Firebase Storage for a food log ID
  Future<void> _deleteFirebaseImage(String foodLogId) async {
    // Ensure we have authentication before attempting deletion
    var user = _auth.currentUser;
    if (user == null) {
      try {
        await _auth.signInAnonymously();
        user = _auth.currentUser;
        if (user == null) {
          throw Exception('Failed to authenticate for Firebase Storage deletion');
        }
      } catch (authError) {
        throw Exception('Authentication failed: $authError');
      }
    }
    
    // Use user-isolated path
    final userId = user.uid;
    final ref = _storage.ref()
        .child('food_images')
        .child(userId)
        .child('$foodLogId.jpg');
    
    try {
      await ref.delete().timeout(const Duration(seconds: 30));
    } catch (e) {
      // If object doesn't exist, that's fine - it's already "deleted"
      if (e.toString().contains('object-not-found') || e.toString().contains('storage/object-not-found')) {
        return; // Success - object already doesn't exist
      }
      // Re-throw other errors
      rethrow;
    }
  }

  /// Remove image tracking from SharedPreferences for a food log ID
  Future<void> _removeImageTracking(String foodLogId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagesJson = prefs.getString(_imagesKey) ?? '{}';
      final imagesMap = Map<String, dynamic>.from(jsonDecode(imagesJson));
      
      // Search through all dates and remove the food log ID
      bool found = false;
      for (final dateKey in imagesMap.keys.toList()) {
        final dateImages = imagesMap[dateKey] as Map<String, dynamic>?;
        if (dateImages != null && dateImages.containsKey(foodLogId)) {
          dateImages.remove(foodLogId);
          found = true;
          
          // If this date entry is now empty, remove the entire date
          if (dateImages.isEmpty) {
            imagesMap.remove(dateKey);
          }
          
          break;
        }
      }
      
      if (found) {
        await prefs.setString(_imagesKey, jsonEncode(imagesMap));
        debugPrint('🗑️ Removed image tracking for food log: $foodLogId');
      } else {
        debugPrint('⚠️ No image tracking found for food log: $foodLogId');
      }
    } catch (e) {
      debugPrint('❌ Error removing image tracking for $foodLogId: $e');
      // Don't rethrow - this is cleanup
    }
  }
}
