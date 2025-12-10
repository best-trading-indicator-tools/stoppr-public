import 'package:cloud_functions/cloud_functions.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../analytics/appsflyer_service.dart';

/// Service for generating and verifying share tokens for the shared streak widget.
class SharingService {
  SharingService._();
  static final SharingService instance = SharingService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Generates a share token and returns the universal link.
  Future<String?> generateShareLink({int ttlMinutes = 60}) async {
    // developer.log('[SharingService] Attempting to generate share link...', name: 'stoppr.sharing');
    debugPrint('PRINT: [SharingService] Attempting to generate share link...');

    // Ensure user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('PRINT: [SharingService] No user authenticated – signing in anonymously...');
      try {
        await FirebaseAuth.instance.signInAnonymously();
        debugPrint('PRINT: [SharingService] Anonymous sign-in succeeded');
      } catch (e) {
        debugPrint('PRINT: [SharingService] Anonymous sign-in FAILED: $e');
        return null;
      }
    }

    try {
      // 1. Generate the short server-side token (already implemented)
      final callable = _functions.httpsCallable('generateShareToken');
      final result = await callable.call({'ttlMinutes': ttlMinutes});
      final serverData = result.data as Map?;
      final serverToken = serverData?['token'] as String?;

      if (serverToken == null) {
        debugPrint('PRINT: [SharingService] Failed to get serverToken from generateShareToken');
        return null;
      }
      debugPrint('PRINT: [SharingService] Successfully got serverToken: $serverToken');

      // 2. Build AppsFlyer OneLink URL using the serverToken
      final appsFlyerLink = await AppsFlyerService().buildShareLink(serverToken);

      if (appsFlyerLink != null) {
        debugPrint('PRINT: [SharingService] Successfully generated AppsFlyer link: $appsFlyerLink');
      } else {
        debugPrint('PRINT: [SharingService] Failed to generate AppsFlyer link. Server token was: $serverToken');
      }
      return appsFlyerLink; // This will be the OneLink URL

    } catch (e, s) {
      // developer.log('[SharingService] Error generating share link', name: 'stoppr.sharing', error: e, stackTrace: s);
      debugPrint('PRINT: [SharingService] Error in generateShareLink (either server token or AppsFlyer link generation). Error: $e. Stacktrace: $s');
      return null;
    }
  }

  /// Verifies token and returns a map with initiatorId & name.
  Future<Map<String, dynamic>?> verifyToken(String token) async {
    // developer.log('[SharingService] Attempting to verify token: $token', name: 'stoppr.sharing');
    debugPrint('PRINT: [SharingService] Attempting to verify token: $token');
    try {
      final result = await _functions
          .httpsCallable('verifyShareToken')
          .call({'token': token});
      final data = Map<String, dynamic>.from(result.data as Map);
      // developer.log('[SharingService] Successfully verified token. Data: $data', name: 'stoppr.sharing');
      debugPrint('PRINT: [SharingService] Successfully verified token. Data: $data');
      return data;
    } catch (e, s) {
      // developer.log('[SharingService] Error verifying token $token', name: 'stoppr.sharing', error: e, stackTrace: s);
      debugPrint('PRINT: [SharingService] Error verifying token $token. Error: $e. Stacktrace: $s');
      return null;
    }
  }

  /// Respond to share request.
  Future<bool> respondToRequest(String token, bool accept) async {
    // developer.log('[SharingService] Attempting to respond to request. Token: $token, Accept: $accept', name: 'stoppr.sharing');
    debugPrint('PRINT: [SharingService] Attempting to respond to request. Token: $token, Accept: $accept');
    try {
      await _functions
          .httpsCallable('respondToShareRequest')
          .call({'token': token, 'accept': accept});
      // developer.log('[SharingService] Successfully responded to request. Token: $token, Accept: $accept', name: 'stoppr.sharing');
      debugPrint('PRINT: [SharingService] Successfully responded to request. Token: $token, Accept: $accept');
      return true;
    } catch (e, s) {
      // developer.log('[SharingService] Error responding to request. Token: $token, Accept: $accept', name: 'stoppr.sharing', error: e, stackTrace: s);
      debugPrint('PRINT: [SharingService] Error responding to request. Token: $token, Accept: $accept. Error: $e. Stacktrace: $s');
      return false;
    }
  }

  /// Generates an accountability partner invite link using AppsFlyer
  Future<String?> generateAccountabilityInviteLink() async {
    debugPrint('PRINT: [SharingService] Generating accountability invite link...');

    // Ensure user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('PRINT: [SharingService] No user authenticated for accountability invite');
      try {
        await FirebaseAuth.instance.signInAnonymously();
        debugPrint('PRINT: [SharingService] Anonymous sign-in succeeded');
      } catch (e) {
        debugPrint('PRINT: [SharingService] Anonymous sign-in FAILED: $e');
        return null;
      }
    }

    try {
      // Generate token (reuse existing token generation)
      final callable = _functions.httpsCallable('generateShareToken');
      final result = await callable.call({
        'ttlMinutes': 43200, // 30 days for accountability invites
        'inviteType': 'accountability', // Mark as accountability invite
      });
      final serverData = result.data as Map?;
      final serverToken = serverData?['token'] as String?;

      if (serverToken == null) {
        debugPrint('PRINT: [SharingService] Failed to get token for accountability invite');
        return null;
      }

      debugPrint('PRINT: [SharingService] Got token for accountability invite: $serverToken');

      // Build AppsFlyer link with accountability-specific parameters
      final appsFlyerLink = await AppsFlyerService().buildAccountabilityInviteLink(
        serverToken,
        referrerUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
      );

      if (appsFlyerLink != null) {
        debugPrint('PRINT: [SharingService] Successfully generated accountability invite link: $appsFlyerLink');
      } else {
        debugPrint('PRINT: [SharingService] Failed to generate accountability invite link');
      }

      return appsFlyerLink;
    } catch (e, s) {
      debugPrint('PRINT: [SharingService] Error generating accountability invite link: $e. Stacktrace: $s');
      return null;
    }
  }

  static void forwardDeepLink(Uri uri) {
    // expose to AppsFlyerService callback
    _externalDeepLinkHandler?.call(uri);
  }
  static Function(Uri)? _externalDeepLinkHandler;
  static void registerExternalHandler(Function(Uri) handler){_externalDeepLinkHandler=handler;}
} 