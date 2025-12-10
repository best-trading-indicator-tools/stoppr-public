import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {

  // --- Request Specific Permissions (Android Only) ---

  Future<bool> requestCameraPermission() async {
    if (Platform.isAndroid && await Permission.camera.isDenied) {
      final status = await Permission.camera.request();
      return status.isGranted;
    }
    // On iOS, permission is usually handled implicitly or via Info.plist
    // Return true if not Android or already granted/limited
    return Platform.isIOS || await Permission.camera.status.isGranted || await Permission.camera.status.isLimited;
  }

  Future<bool> requestMicrophonePermission() async {
    if (Platform.isAndroid && await Permission.microphone.isDenied) {
      final status = await Permission.microphone.request();
      return status.isGranted;
    }
    return Platform.isIOS || await Permission.microphone.status.isGranted || await Permission.microphone.status.isLimited;
  }

  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid && await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    // On iOS, use dedicated method in NotificationService
    return Platform.isIOS || await Permission.notification.status.isGranted;
  }

  Future<bool> requestLocationPermission() async {
    if (Platform.isAndroid && await Permission.locationWhenInUse.isDenied) {
      final status = await Permission.locationWhenInUse.request();
      return status.isGranted;
    }
    return Platform.isIOS || await Permission.locationWhenInUse.status.isGranted || await Permission.locationWhenInUse.status.isLimited;
  }

  Future<bool> requestPhotosPermission() async {
    Permission photosPermission;
    if (Platform.isAndroid) {
      photosPermission = Permission.photos;
      if (await photosPermission.isDenied) {
          final status = await photosPermission.request();
          return status.isGranted || status.isLimited;
      }
      return await photosPermission.status.isGranted || await photosPermission.status.isLimited;
    } else if (Platform.isIOS) {
      // On iOS, photos permission is usually handled implicitly
      photosPermission = Permission.photos;
      return await photosPermission.status.isGranted || await photosPermission.status.isLimited;
    } else {
      return false; // Unsupported platform
    }
  }

  // --- Check Status Methods (Keep these as they are useful on both platforms) ---
  
  Future<bool> isNotificationGranted() async {
    return await Permission.notification.isGranted;
  }

  Future<bool> isCameraGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted || status.isLimited;
  }

  Future<bool> isMicrophoneGranted() async {
    final status = await Permission.microphone.status;
    return status.isGranted || status.isLimited;
  }

  Future<bool> isLocationWhenInUseGranted() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted || status.isLimited;
  }

  Future<bool> isPhotosGranted() async {
    Permission photosPermission;
    if (Platform.isAndroid) {
        photosPermission = Permission.photos;
    } else if (Platform.isIOS) {
      photosPermission = Permission.photos;
    } else {
      return false; // Unsupported platform
    }
    final status = await photosPermission.status;
    return status.isGranted || status.isLimited;
  }
} 