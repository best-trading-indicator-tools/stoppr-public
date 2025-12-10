import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/analytics/crashlytics_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Service that provides defensive measures for video player initialization,
/// specifically targeting Samsung device issues and iOS 18 platform view issues
class VideoPlayerDefensiveService {
  static bool? _isSamsungDevice;
  static bool? _isIOS18OrLater;
  
  /// Check if the current device is a Samsung device
  static Future<bool> get isSamsungDevice async {
    _isSamsungDevice ??= await _detectSamsungDevice();
    return _isSamsungDevice!;
  }
  
  /// Check if the current device is iOS 18 or later
  static Future<bool> get isIOS18OrLater async {
    _isIOS18OrLater ??= await _detectIOS18OrLater();
    return _isIOS18OrLater!;
  }
  
  /// Detect if this is a Samsung device using device_info_plus
  static Future<bool> _detectSamsungDevice() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      // Check brand, manufacturer, and model for Samsung identifiers
      final brand = androidInfo.brand.toLowerCase();
      final manufacturer = androidInfo.manufacturer.toLowerCase();
      final model = androidInfo.model.toLowerCase();
      
      return brand.contains('samsung') || 
             manufacturer.contains('samsung') || 
             model.contains('samsung') ||
             model.contains('sm-') || // Samsung model prefix
             model.contains('galaxy');
    } catch (e) {
      debugPrint('Error detecting Samsung device: $e');
      return false;
    }
  }
  
  /// Detect if this is iOS 18 or later using device_info_plus
  static Future<bool> _detectIOS18OrLater() async {
    if (!Platform.isIOS) return false;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      
      // Parse iOS version (e.g., "18.6.0" -> major version 18)
      final systemVersion = iosInfo.systemVersion;
      final versionParts = systemVersion.split('.');
      
      if (versionParts.isNotEmpty) {
        final majorVersion = int.tryParse(versionParts[0]) ?? 0;
        return majorVersion >= 18;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error detecting iOS version: $e');
      return false;
    }
  }
  
  
  /// Get platform-specific initialization delay
  /// Enhances existing delays with Samsung-specific and iOS 18 protection
  static Future<Duration> getInitializationDelay() async {
    if (Platform.isAndroid) {
      if (await isSamsungDevice) {
        // Samsung devices: Enhanced delay (existing 150ms + 100ms Samsung protection)
        return const Duration(milliseconds: 250);
      } else {
        // Other Android: Keep existing 150ms delay
        return const Duration(milliseconds: 150);
      }
    } else if (Platform.isIOS) {
      if (await isIOS18OrLater) {
        // iOS 18+: Increased delay for platform view initialization issues
        // Reduced to 150ms - main safety comes from post-init delay
        return const Duration(milliseconds: 150);
      } else {
        // iOS 17 and below: Keep existing 50ms delay
        return const Duration(milliseconds: 50);
      }
    } else {
      // Fallback: Default delay
      return const Duration(milliseconds: 50);
    }
  }
  
  /// Enhanced video controller initialization with Samsung-specific and iOS 18 error handling
  static Future<VideoPlayerController> initializeWithDefensiveMeasures({
    required String videoPath,
    bool isNetworkUrl = false,
    Map<String, String>? httpHeaders,
    VideoFormat? formatHint,
    required String context, // For tracking which screen is initializing
  }) async {
    final isSamsung = await isSamsungDevice;
    final isIOS18 = await isIOS18OrLater;
    final delay = await getInitializationDelay();
    
    // Apply the delay (preserves existing logic but enhances for Samsung)
    await Future.delayed(delay);
    
    late VideoPlayerController controller;
    
    try {
      // Create controller with existing logic preserved
      if (isNetworkUrl) {
        if (httpHeaders != null) {
          controller = VideoPlayerController.networkUrl(
            Uri.parse(videoPath),
            formatHint: formatHint ?? VideoFormat.hls,
            httpHeaders: httpHeaders,
          );
        } else {
          controller = VideoPlayerController.networkUrl(
            Uri.parse(videoPath),
            formatHint: formatHint ?? VideoFormat.hls,
          );
        }
      } else {
        controller = VideoPlayerController.asset(videoPath);
      }
      
      // Initialize controller with timeout protection (extended for iOS 18)
      final timeoutDuration = isIOS18 ? const Duration(seconds: 15) : const Duration(seconds: 10);
      await controller.initialize().timeout(
        timeoutDuration,
        onTimeout: () {
          throw TimeoutException('Video initialization timeout', timeoutDuration);
        },
      );

      // iOS 18+: Add a post-initialize delay to avoid platform view race
      // where the native view factory may not yet be ready, causing
      // "Could not find corresponding view type for playerId".
      // 250ms provides safety without excessive delay
      if (Platform.isIOS && isIOS18) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      
      debugPrint('✅ Video initialized successfully: $context on ${Platform.operatingSystem}${isSamsung ? ' (Samsung)' : ''}${isIOS18 ? ' (iOS 18+)' : ''}');
      
      // Track successful initialization
      MixpanelService.trackEvent('Video Player Init Success', properties: {
        'context': context,
        'platform': Platform.operatingSystem,
        'is_samsung': isSamsung,
        'is_ios18_or_later': isIOS18,
        'delay_ms': delay.inMilliseconds,
        'video_type': isNetworkUrl ? 'network' : 'asset',
      });
      
      return controller;
      
    } catch (e, stackTrace) {
      // Enhanced error tracking for Samsung devices and iOS 18
      final errorContext = {
        'context': context,
        'platform': Platform.operatingSystem,
        'is_samsung': isSamsung,
        'is_ios18_or_later': isIOS18,
        'delay_ms': delay.inMilliseconds,
        'video_type': isNetworkUrl ? 'network' : 'asset',
        'error': e.toString(),
      };
      
      debugPrint('❌ Video initialization failed: $context - $e');
      
      // Track the error
      // Removed Mixpanel video player init error tracking
      
      // Log to Crashlytics with enhanced context for Samsung devices and iOS 18
      if (isSamsung) {
        CrashlyticsService.setCustomKey('samsung_video_error', true);
        CrashlyticsService.setCustomKey('video_init_context', context);
      }
      
      if (isIOS18) {
        CrashlyticsService.setCustomKey('ios18_video_error', true);
        CrashlyticsService.setCustomKey('video_init_context', context);
        
        // Check for specific iOS 18 platform view errors
        if (e.toString().contains('Could not find corresponding view type') ||
            e.toString().contains('playerId') ||
            e.toString().contains('buildViewWithOptions')) {
          CrashlyticsService.setCustomKey('ios18_platform_view_error', true);
        }
      }
      
      final platformSuffix = isSamsung ? ' (Samsung)' : isIOS18 ? ' (iOS 18+)' : '';
      CrashlyticsService.logException(
        e, 
        stackTrace, 
        reason: 'Video Player Init Failed - $context$platformSuffix',
      );
      
      rethrow;
    }
  }
  
  /// Enhanced video listener with Samsung-specific error handling
  static VoidCallback createDefensiveVideoListener({
    required VideoPlayerController controller,
    required String context,
    VoidCallback? onError,
    VoidCallback? onPositionUpdate,
  }) {
    return () {
      try {
        if (!controller.value.isInitialized) return;
        
        // Check for video errors with Samsung-specific tracking
        if (controller.value.hasError) {
          final errorDescription = controller.value.errorDescription ?? 'Unknown playback error';
          
          debugPrint('🔴 Video playback error: $context - $errorDescription');
          
          // For playback errors, we need to check Samsung status asynchronously
          // but we can't await in a VoidCallback, so we'll track without Samsung context
          // and handle Samsung-specific logging separately
          if (!kDebugMode) {
            FirebaseCrashlytics.instance.recordError(
              errorDescription,
              StackTrace.current,
              reason: 'Video Player Playback Error',
              information: [
                'context: $context',
                'platform: ${Platform.operatingSystem}',
              ],
            );
          }
          
          // Handle Samsung-specific error logging asynchronously
          _handleSamsungPlaybackError(context, errorDescription);
          
          onError?.call();
          return;
        }
        
        // Call position update callback if provided
        onPositionUpdate?.call();
        
      } catch (e, stackTrace) {
        debugPrint('🔴 Video listener error: $context - $e');
        
        // Don't propagate listener errors to avoid cascade failures
        // But log them for debugging
        CrashlyticsService.logException(
          e,
          stackTrace,
          reason: 'Video Listener Error - $context',
        );
      }
    };
  }
  
  /// Handle Samsung-specific playback error logging asynchronously
  static Future<void> _handleSamsungPlaybackError(String context, String errorDescription) async {
    try {
      final isSamsung = await isSamsungDevice;
      
      if (isSamsung) {
        CrashlyticsService.setCustomKey('samsung_playback_error', true);
        CrashlyticsService.setCustomKey('playback_error_context', context);
        
        CrashlyticsService.logException(
          Exception('Video playback error: $errorDescription'),
          StackTrace.current,
          reason: 'Video Playback Error - $context (Samsung)',
        );
      }
    } catch (e) {
      debugPrint('Error handling Samsung playback error: $e');
    }
  }
} 