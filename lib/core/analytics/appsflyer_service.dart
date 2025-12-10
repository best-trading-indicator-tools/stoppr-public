import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:stoppr/core/streak/sharing_service.dart';
import 'dart:async'; // Pour Completer
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // Added import
import 'package:stoppr/core/config/env_config.dart'; // Added import

class PromoCodeData {
  final String promoCode;
  final String? mediaSource;

  PromoCodeData({required this.promoCode, this.mediaSource});
}

typedef PromoCodeHandler = void Function(PromoCodeData data);

class AppsFlyerService {
  AppsFlyerService._();
  static final AppsFlyerService _instance = AppsFlyerService._();
  factory AppsFlyerService() => _instance;

  late final AppsflyerSdk _afSdk;
  bool _initialized = false;
  // IMPORTANT: Le OneLink ID utilisé ici est l'ID du TEMPLATE OneLink que vous avez créé dans le dashboard AppsFlyer,
  // PAS l'URL courte complète. Par exemple, si votre URL courte est https://stoppr.onelink.me/LW4O/xxxx, alors LW4O est l'ID.
  static String? _oneLinkTemplateID; // Changed from const to allow runtime initialization

  final StreamController<PromoCodeData> _promoCodeStreamController =
      StreamController<PromoCodeData>.broadcast();

  Stream<PromoCodeData> get promoCodeStream => _promoCodeStreamController.stream;
  Future<void> init() async {
    if (_initialized) return;

    // Load OneLink Template ID from .env
    final String? localOneLinkTemplateID = EnvConfig.appsflyerOneLinkTemplate; // Assign to local final variable
    bool oneLinkTemplateIdIsMissing = false;

    if (localOneLinkTemplateID == null) {
      oneLinkTemplateIdIsMissing = true;
    } else {
      // Now, inside this block, localOneLinkTemplateID is promoted to non-nullable String
      if (localOneLinkTemplateID.isEmpty) {
        oneLinkTemplateIdIsMissing = true;
      }
    }
    _oneLinkTemplateID = localOneLinkTemplateID; // Assign back to the static field if needed later, or use localOneLinkTemplateID directly if only needed in init

    if (oneLinkTemplateIdIsMissing) {
      const String warningMessage =
          "[AppsFlyer] Warning: APPSFLYER_ONELINK_TEMPLATE not found or empty in .env. " +
          "This ID is typically configured natively (Info.plist/AndroidManifest.xml) for brandDomain " +
          "and may not be directly used by the Dart SDK's current generateInviteLink setup.";
      debugPrint(warningMessage);
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.log(warningMessage); // Logging as a non-fatal issue
      }
      // Assign a default or handle error if this ID were strictly necessary for a Dart-side operation
    }

    final devKey = EnvConfig.appsflyerDevKey; // Use EnvConfig
    if (devKey == null || devKey.isEmpty) {
      const String errorMessage = '[AppsFlyer] Error: Missing APPSFLYER_DEV_KEY in .env file. Cannot initialize.';
      debugPrint(errorMessage);
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          Exception(errorMessage),
          StackTrace.current,
          reason: 'AppsFlyer Init Failed',
          fatal: false, // Not fatal to the app's core, but fatal to AppsFlyer init
        );
      }
      return;
    }
    // APPSFLYER_APP_ID in .env must be the numeric App Store ID, e.g. "6742406521"
    final appIdFromEnv = EnvConfig.appsflyerAppId;
    debugPrint('[AppsFlyer] APPSFLYER_APP_ID from .env: "$appIdFromEnv"');
    if (appIdFromEnv == null) {
      const String errorMessage = '[AppsFlyer] Error: Missing APPSFLYER_APP_ID in .env file. Cannot initialize.';
      debugPrint(errorMessage);
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          Exception(errorMessage),
          StackTrace.current,
          reason: 'AppsFlyer Init Failed',
          fatal: false,
        );
      }
      return;
    }
    final appId = appIdFromEnv;
    // No need for the following redundant checks as they are covered above
    // if (devKey.isEmpty) { ... }
    // if (appId.isEmpty) { ... }

    final options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: appId, // For iOS only
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 60,
    );
    _afSdk = AppsflyerSdk(options);

    try {
      await _afSdk.initSdk(
        registerConversionDataCallback: true,
        registerOnDeepLinkingCallback: true,
        registerOnAppOpenAttributionCallback: true,
      );
      debugPrint("[AppsFlyer] SDK Successfully Initialized.");

      _afSdk.onDeepLinking((DeepLinkResult deepLinkResult) { // Explicit type
        debugPrint("[AppsFlyer] onDeepLinking received: Status: ${deepLinkResult.status}, Error: ${deepLinkResult.error}");
        
        // Check status using enum values from the AppsFlyer SDK
        if (deepLinkResult.status == Status.FOUND) { 
          DeepLink? deepLinkData = deepLinkResult.deepLink;
          if (deepLinkData != null) {
            debugPrint("[AppsFlyer] DeepLink Data: ${deepLinkData.toString()}");
            debugPrint("[AppsFlyer] DeepLinkValue: ${deepLinkData.deepLinkValue}");
            debugPrint("[AppsFlyer] ClickEvent for deep link: ${deepLinkData.clickEvent}");

            String? token;
            // Try to extract token from 'clickEvent' (preferred)
            if (deepLinkData.clickEvent?.containsKey('token') ?? false) {
              token = deepLinkData.clickEvent!['token'] as String?;
              debugPrint("[AppsFlyer] Token extracted from clickEvent: $token");
            }
            
            // Fallback: Try to extract from 'deepLinkValue' if it's a URL formatted by us
            if ((token == null || token.isEmpty) && deepLinkData.deepLinkValue != null) {
                debugPrint("[AppsFlyer] Token not found in clickEvent, fallback to deepLinkValue: ${deepLinkData.deepLinkValue}");
                try {
                    final uri = Uri.parse(deepLinkData.deepLinkValue!);
                    if (uri.queryParameters.containsKey('token')) {
                        token = uri.queryParameters['token'];
                        debugPrint("[AppsFlyer] Token extrait des queryParameters de deepLinkValue: $token");
                    } else if (uri.pathSegments.isNotEmpty && uri.pathSegments.length > 1 && uri.pathSegments.first == 'share') {
                        // If deep_link_value was our complete URL like https://stoppr.app/share/TOKEN
                        token = uri.pathSegments[1];
                         debugPrint("[AppsFlyer] Token extracted from deepLinkValue path: $token");
                    }
                } catch(e) {
                    debugPrint("[AppsFlyer] Error parsing deepLinkValue for token: $e");
                }
            }

            if (token != null && token.isNotEmpty) {
              final syntheticUri = Uri.parse("https://stoppr.app/share/$token"); // To match your existing handler
              SharingService.forwardDeepLink(syntheticUri);
            } else {
              debugPrint("[AppsFlyer] Token not found in deep link.");
            }
          } else {
            debugPrint("[AppsFlyer] DeepLink Data is null.");
          }
        } else if (deepLinkResult.status == Status.NOT_FOUND) {
          debugPrint("[AppsFlyer] Deep link not found.");
        } else { // ERROR
          debugPrint("[AppsFlyer] Deep Link Error: ${deepLinkResult.error}.");
        }
      });

      // Listener for install conversion data (first launch)
      _afSdk.onInstallConversionData((dynamic installData) { // Explicit type
        debugPrint("[AppsFlyer] onInstallConversionData received: $installData");
        if (installData is Map && installData['status'] == 'success') {
          final Map<dynamic, dynamic> conversionData =
              installData['payload'] as Map<dynamic, dynamic>;
          _handleAttributionData(conversionData, 'Install Conversion');
        } else {
          debugPrint("[AppsFlyer] onInstallConversionData: Status not 'success' or invalid payload.");
        }
      });

      // Listener for app open attribution (subsequent opens via deep link)
      _afSdk.onAppOpenAttribution((dynamic attributionData) { // Explicit type
        debugPrint("[AppsFlyer] onAppOpenAttribution received: $attributionData");
        if (attributionData is Map && attributionData['status'] == 'success') {
          final Map<dynamic, dynamic> payload =
              attributionData['payload'] as Map<dynamic, dynamic>;
          _handleAttributionData(payload, 'App Open Attribution');
        } else {
          debugPrint("[AppsFlyer] onAppOpenAttribution: Status not 'success' or invalid payload.");
        }
      });

      _initialized = true;
    } catch (e, s) { // Added stack trace parameter s
      final String errorMessage = "[AppsFlyer] SDK initialization error: $e";
      debugPrint(errorMessage);
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          e,
          s,
          reason: 'AppsFlyer SDK Init Exception',
          fatal: false, // SDK init failure might not be fatal to the whole app
        );
      }
    }
  }

  void _handleAttributionData(Map<dynamic, dynamic> data, String source) {
    debugPrint("[AppsFlyer] _handleAttributionData ($source): $data");
    String? promoCode;
    String? mediaSource = data['media_source'] as String?;

    // Prefer 'af_sub1' or 'deep_link_sub1' for promo code
    if (data.containsKey('af_sub1') && data['af_sub1'] != null && (data['af_sub1'] as String).isNotEmpty) {
      promoCode = data['af_sub1'] as String?;
      debugPrint("[AppsFlyer] ($source) Promo code found in 'af_sub1': $promoCode");
    } else if (data.containsKey('deep_link_sub1')  && data['deep_link_sub1'] != null && (data['deep_link_sub1'] as String).isNotEmpty) {
      promoCode = data['deep_link_sub1'] as String?;
      debugPrint("[AppsFlyer] ($source) Promo code found in 'deep_link_sub1': $promoCode");
    } else if (data.containsKey('promo_code') && data['promo_code'] != null && (data['promo_code'] as String).isNotEmpty) {
      promoCode = data['promo_code'] as String?;
      debugPrint("[AppsFlyer] ($source) Promo code found in 'promo_code' (fallback): $promoCode");
    }

    if (promoCode != null && promoCode.isNotEmpty) {
      debugPrint("[AppsFlyer] ($source) Promo code '$promoCode' (media source: '$mediaSource') will be sent to stream.");
      _promoCodeStreamController.add(PromoCodeData(promoCode: promoCode, mediaSource: mediaSource));
    } else {
      debugPrint("[AppsFlyer] ($source) No relevant promo code found in attribution data.");
    }
  }

  Future<String?> buildShareLink(String userToken) async {
    if (!_initialized) {
      const String warningMessage = "[AppsFlyer] SDK not initialized before buildShareLink. Attempting to initialize now...";
      debugPrint(warningMessage);
      // Log this attempt, as it might indicate an issue if init() wasn't called earlier
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.log("$warningMessage - Called from buildShareLink");
      }
      await init(); // Attempt to initialize
      if (!_initialized) {
        const String errorMessage = "[AppsFlyer] SDK initialization failed after attempt from buildShareLink. Cannot build share link.";
        debugPrint(errorMessage);
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMessage),
            StackTrace.current,
            reason: 'AppsFlyer buildShareLink Failed - SDK Not Initialized',
            fatal: false,
          );
        }
        return null;
      }
    }

    final completer = Completer<String?>();

    // Custom parameters to be embedded in the link
    Map<String, String> customParams = {
        "token": userToken,
    };

    // Build parameters using the AppsFlyerInviteLinkParams model (required by generateInviteLink API)
    final params = AppsFlyerInviteLinkParams(
      channel: "user_share",
      campaign: "share_streak_widget",
      customerID: userToken,
      referrerName: "StopprAppFriend",
      customParams: customParams,
      // baseDeepLink can be set to ensure the token is present in deep link value
      baseDeepLink: "https://stoppr.app/share/$userToken",
      // brandDomain relies on manifest/Info.plist configuration (LW4O), so no need to specify template ID here
    );

    debugPrint("[AppsFlyer] Génération du OneLink avec params: ${params.toString()}");

    // Call generateInviteLink with the required 3 positional arguments
    _afSdk.generateInviteLink(
      params,
      (dynamic linkResult) { // Changed 'link' to 'linkResult' for clarity and added type
        debugPrint("[AppsFlyer] Raw OneLink Result (succès): $linkResult");
        if (linkResult is Map &&
            linkResult['status'] == 'success' &&
            linkResult['payload'] is Map &&
            (linkResult['payload'] as Map).containsKey('userInviteURL') &&
            (linkResult['payload'] as Map)['userInviteURL'] is String) {
          String actualLink = (linkResult['payload'] as Map)['userInviteURL'] as String;
          debugPrint("[AppsFlyer] Extracted OneLink URL: $actualLink");
          completer.complete(actualLink);
        } else {
          debugPrint("[AppsFlyer] OneLink result structure inattendu, échec, ou userInviteURL manquante/invalide: $linkResult");
          completer.complete(null);
        }
      },
      (error) {
        debugPrint('[AppsFlyer] Erreur de génération du OneLink: $error');
        completer.complete(null);
      },
    );
    return completer.future;
  }

  /// Build accountability partner invite link using AppsFlyer OneLink
  Future<String?> buildAccountabilityInviteLink(
    String userToken, {
    required String referrerUserId,
  }) async {
    if (!_initialized) {
      const String warningMessage = "[AppsFlyer] SDK not initialized before buildAccountabilityInviteLink. Attempting to initialize now...";
      debugPrint(warningMessage);
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.log("$warningMessage - Called from buildAccountabilityInviteLink");
      }
      await init();
      if (!_initialized) {
        const String errorMessage = "[AppsFlyer] SDK initialization failed. Cannot build accountability invite link.";
        debugPrint(errorMessage);
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordError(
            Exception(errorMessage),
            StackTrace.current,
            reason: 'AppsFlyer buildAccountabilityInviteLink Failed - SDK Not Initialized',
            fatal: false,
          );
        }
        return null;
      }
    }

    final completer = Completer<String?>();

    // Custom parameters for accountability invite
    Map<String, String> customParams = {
      "token": userToken,
      "invite_type": "accountability",
      "referrer_user_id": referrerUserId,
    };

    final params = AppsFlyerInviteLinkParams(
      channel: "accountability_invite",
      campaign: "accountability_partner",
      customerID: userToken,
      referrerName: "AccountabilityPartner",
      customParams: customParams,
      baseDeepLink: "https://stoppr.app/accountability/$userToken",
    );

    debugPrint("[AppsFlyer] Generating accountability invite OneLink with params: ${params.toString()}");

    _afSdk.generateInviteLink(
      params,
      (dynamic linkResult) {
        debugPrint("[AppsFlyer] Accountability invite OneLink result: $linkResult");
        if (linkResult is Map &&
            linkResult['status'] == 'success' &&
            linkResult['payload'] is Map &&
            (linkResult['payload'] as Map).containsKey('userInviteURL') &&
            (linkResult['payload'] as Map)['userInviteURL'] is String) {
          String actualLink = (linkResult['payload'] as Map)['userInviteURL'] as String;
          debugPrint("[AppsFlyer] Extracted accountability invite URL: $actualLink");
          completer.complete(actualLink);
        } else {
          debugPrint("[AppsFlyer] Accountability invite OneLink result structure unexpected: $linkResult");
          completer.complete(null);
        }
      },
      (error) {
        debugPrint('[AppsFlyer] Error generating accountability invite OneLink: $error');
        completer.complete(null);
      },
    );

    return completer.future;
  }
} 