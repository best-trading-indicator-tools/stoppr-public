import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:app_links/app_links.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide LogLevel;
import 'firebase_options.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/cubit/auth_cubit.dart';
import 'core/config/env_config.dart';
import 'core/services/version_service.dart';
import 'core/superwall/superwall_purchase_controller.dart';
import 'core/subscription/subscription_service.dart';
import 'core/analytics/mixpanel_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/chat/crisp_service.dart';
import 'core/quick_actions/quick_actions_service.dart';
import 'core/pmf_survey/pmf_survey_manager.dart';
import 'core/installation/installation_tracker_service.dart';
import 'features/onboarding/presentation/screens/onboarding_page.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/features/onboarding/presentation/screens/questionnaire_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/profile_info_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/symptoms_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_sugar_painpoints_page_view.dart';
import 'package:stoppr/features/onboarding/presentation/screens/benefits_page_view.dart';
import 'package:stoppr/features/onboarding/presentation/screens/referral_code_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/choose_goals_onboarding.dart';
import 'package:stoppr/features/onboarding/presentation/screens/stoppr_science_backed_plan.dart';
import 'package:stoppr/features/onboarding/presentation/screens/weeks_progression_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/letter_from_future_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/read_the_vow_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/pre_paywall.dart';
import 'package:stoppr/features/onboarding/presentation/screens/analysis_result_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/give_us_ratings_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/benefits_impact_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_screen4.dart';
import 'package:stoppr/features/onboarding/presentation/screens/welcome_video_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/congratulations_payment_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/congratulations/congratulations_screen_1.dart';
import 'features/app/presentation/screens/home_screen.dart';
import 'features/app/presentation/screens/pledge_screen.dart';
import 'features/app/presentation/screens/meditation_screen.dart';
import 'features/app/presentation/screens/panic_button/what_happening_screen.dart';
import 'features/app/presentation/screens/main_scaffold.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/navigation/page_transitions.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:camera/camera.dart';
import 'package:flutter/rendering.dart'; // Add import for rendering library
import 'package:stoppr/permissions/permission_service.dart'; // Import the permission service
import 'package:stoppr/features/community/data/repositories/community_repository.dart'; // Import CommunityRepository
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'core/auth/models/app_user.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Added import
import 'package:stoppr/core/localization/app_localizations.dart'; // Added import
import 'package:stoppr/core/analytics/superwall_utils.dart'; // Added import
// Android
// import 'package:superwallkit_flutter/src/public/RedemptionResult.dart' if (dart.library.io) 'package:stoppr/core/superwall/redemption_result_stub.dart';
// iOS
import 'package:superwallkit_flutter/src/public/RedemptionResult.dart';

import 'package:stoppr/core/streak/sharing_service.dart';
import 'package:stoppr/core/subscription/post_purchase_handler.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/features/streak/presentation/accept_invite_page.dart';
import 'package:stoppr/core/analytics/appsflyer_service.dart';
import 'package:stoppr/core/analytics/screenshot_tracker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stoppr/features/onboarding/presentation/screens/current_6_blocks_rating_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/potential_rating_screen.dart';

// Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

List<CameraDescription> cameras = [];

// --- NEW: Top-level background message handler ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, like Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
  // No UI interaction here, but you could potentially store the payload 
  // if needed for later processing when the app opens.
  // For triggering Superwall, we only need to handle the tap action when the app is opened.
}
// --- END NEW ---

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint('Starting app initialization');
  
  // Disable all debug painting flags
  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintPointersEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugRepaintRainbowEnabled = false;
  
  // Load environment variables from file system (development only)
  // NOTE: .env is NOT bundled as an asset - it's loaded from file system
  // For production builds, use build-time environment variables or secure config
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
    // In production, environment variables should be provided via build-time config
  }
  
  // Early RevenueCat configuration to prevent fatal errors
  try {
    final iosKey = EnvConfig.revenueCatIOSApiKey;
    final androidKey = EnvConfig.revenueCatAndroidApiKey;
    
    if (iosKey != null && androidKey != null) {
      final configuration = Platform.isIOS
          ? PurchasesConfiguration(iosKey)
          : PurchasesConfiguration(androidKey);
      
      await Purchases.configure(configuration);
      debugPrint('Early RevenueCat configuration completed successfully');
      // Mark RevenueCat as ready for NotificationService trial checks
      NotificationService.setRevenueCatReady(true);
    } else {
      debugPrint('Warning: RevenueCat API keys missing in .env file');
    }
  } catch (e) {
    debugPrint('Error during early RevenueCat configuration: $e');
    // Ensure we mark it not ready on error
    NotificationService.setRevenueCatReady(false);
    // Continue app initialization even if RevenueCat fails to configure
  }
  
  // Initialize OpenAI API
  OpenAI.apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  
  // Initialize available cameras
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error initializing cameras: $e');
  }
  
  // Initialize Firebase with the DefaultFirebaseOptions
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
    
    // Initialize Firebase Crashlytics
    if (!kDebugMode) {
      // Pass all uncaught errors to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      
      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      
      // Enable automatic data collection
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      
      debugPrint('Firebase Crashlytics initialized successfully');
    } else {
      // In debug mode, print errors to console instead of sending to Crashlytics
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('Flutter error: ${details.exception}');
      };
      
      // Disable automatic data collection in debug mode
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      
      debugPrint('Firebase Crashlytics disabled in debug mode');
    }
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
  }

  // Boot-time reschedule: recompute and schedule today's notifications
  try {
    // Scheduling moved to occur after NotificationService.initialize()
    debugPrint('Boot-time: Superwall marked ready; scheduling deferred until NotificationService.initialize completes');
  } catch (e) {
    debugPrint('Boot-time reschedule error: $e');
  }
  
  // Initialize the notification service
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    debugPrint('Notification service initialized successfully');
    
    // Check for app updates and schedule notifications if available
    try {
      debugPrint('before checkAndScheduleAppUpdateNotification');
      await notificationService.checkAndScheduleAppUpdateNotification();
      debugPrint('App update check completed successfully');
    } catch (e) {
      debugPrint('Failed to check for app updates: $e');
    }

    // Boot-time reschedule AFTER initialization
    try {
      await NotificationService().updateNotificationsBasedOnSubscription();
      debugPrint('Boot-time reschedule: updateNotificationsBasedOnSubscription executed after initialize');
    } catch (e) {
      debugPrint('Boot-time reschedule (post-init) error: $e');
    }
  } catch (e) {
    debugPrint('Failed to initialize notification service: $e');
  }
  
  // Initialize Crisp chat service
  try {
    final crispService = CrispService();
    crispService.initialize();
    debugPrint('Crisp service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize Crisp service: $e');
  }
  
  // Initialize Quick Actions service (app icon actions)
  try {
    final quickActionsService = QuickActionsService();
    quickActionsService.initialize();
    debugPrint('Quick Actions service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize Quick Actions service: $e');
  }
  
  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();
  //SharedPreferences.getInstance().then((p) => p.clear());
  
  // Initialize AuthService (singleton)
  final authService = AuthService();
  debugPrint('AuthService initialized');
  
  // Initialize Mixpanel
  await MixpanelService.initMixpanel();
  
  // Initialize PMF Survey Manager
  final pmfSurveyManager = PMFSurveyManager();
  await pmfSurveyManager.trackAppOpen();
  debugPrint('PMF Survey Manager initialized');
  
  // Check for redownload (must be done early, after Firebase Auth is available)
  try {
    final installationTracker = InstallationTrackerService();
    final isRedownload = await installationTracker.isRedownload();
    if (isRedownload) {
      debugPrint('🔄 Redownload detected - marking for feedback form');
      await installationTracker.markForFeedbackForm();
    }
  } catch (e) {
    debugPrint('Error checking for redownload: $e');
    // Continue app initialization even if redownload check fails
  }
  
  // Re-apply Meta advertiser tracking flag from previous ATT choice (iOS only)
  try {
    if (Platform.isIOS) {
      final bool enabled = prefs.getBool('fb_advertiser_tracking_enabled') ?? false;
      final facebookAppEvents = FacebookAppEvents();
      await facebookAppEvents.setAdvertiserTracking(enabled: enabled);
      debugPrint('Re-applied Facebook advertiser tracking flag: $enabled');
    }
  } catch (e) {
    debugPrint('Error re-applying advertiser tracking flag: $e');
  }

  // Check TestFlight or Google Play Internal status
  final isTestEnvironment = await MixpanelService.isTestEnvironment();
  _logTestEnvironmentStatus(isTestEnvironment);

  // Check for app version changes
  await _checkAppVersionAndShowChangelog();
  
  // --- NEW: Setup Firebase Messaging ---
  try {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    // Request permissions (iOS) - REMOVING THIS SECTION
    // if (Platform.isIOS) {
    //   await FirebaseMessaging.instance.requestPermission(
    //     alert: true,
    //     badge: true,
    //     sound: true,
    //   );
    // }
    // Get FCM token and save to Firestore for accountability notifications
    final fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint("FCM Token: $fcmToken");
    
    // Save token to Firestore if user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && fcmToken != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ FCM token saved to Firestore for user: ${currentUser.uid}');
    }
    
    // Listen for token refresh (tokens can expire/change)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ FCM token refreshed and saved: $newToken');
      }
    });

    // Handle foreground messages (optional, usually just a notification shown by OS)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message received:');
      debugPrint('Message data: ${message.data}');
      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification!.title}');
      }
    });

    // Handle notification tap when app is in background/terminated
    // NOTE: Moved listener setup to _MyAppState.initState
    // RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    // if (initialMessage != null) {
    //   _handleMessageOpened(initialMessage); // Error: _handleMessageOpened is instance method
    // }
    // Listener for when app is opened from background state
    // FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened); // Error: _handleMessageOpened is instance method

    debugPrint('Firebase Messaging initialized successfully');
  } catch (e) {
      debugPrint('Failed to initialize Firebase Messaging: $e');
      // Network/temporary error - not sent to Crashlytics
  }
  // --- END NEW ---
  
  // Initialize AppsFlyerService AFTER Firebase
  await AppsFlyerService().init();

  // Setup deep link forwarding from SharingService to _processDeepLink
  SharingService.registerExternalHandler((uri) {
    debugPrint("[main] Forwarded deep link from AppsFlyer via SharingService: $uri");
    // Ensure you have a way to access _processDeepLink or equivalent logic here
    // This might require passing navigatorKey or having a global deep link processor.
    // For simplicity, assuming _processDeepLink can be made accessible or refactored.
    // If _processDeepLink is in _MyAppState, you might need a more robust solution
    // like a global StreamController for deep links, or a static method in _MyAppState.
    final appState = navigatorKey.currentContext?.findAncestorStateOfType<_MyAppState>();
    appState?._processDeepLink(uri);
  });
  
  // EARLY Superwall init for Android only
  if (Platform.isAndroid) {
    final androidApiKey = EnvConfig.superwallAndroidApiKey;
    if (androidApiKey != null) {
      final logging = Logging();
      logging.level = LogLevel.debug;
      logging.scopes = {LogScope.all};
      final options = SuperwallOptions();
      options.paywalls.shouldPreload = true;
      options.logging = logging;
      Superwall.configure(
        androidApiKey,
        options: options,
      );
      // Mark Superwall ready for Android
      NotificationService.setSuperwallReady(true);
      Superwall.shared.setDelegate(navigatorKey.currentState?.context.findAncestorStateOfType<_MyAppState>() ?? navigatorKey.currentContext?.findAncestorStateOfType<_MyAppState>());
    }
  }
  
  // Determine initial locale synchronously before runApp
  Locale initialLocale = const Locale('en');
  try {
    final savedCode = prefs.getString('languageCode');
    const supported = ['en', 'es', 'de', 'zh', 'ru', 'fr', 'sk', 'cs', 'pl', 'it'];
    if (savedCode != null && savedCode.isNotEmpty && supported.contains(savedCode)) {
      initialLocale = Locale(savedCode);
    } else {
      final systemCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      initialLocale = supported.contains(systemCode) ? Locale(systemCode) : const Locale('en');
      // Persist chosen initial for next time if nothing saved yet
      if (savedCode == null || savedCode.isEmpty) {
        await prefs.setString('languageCode', initialLocale.languageCode);
      }
    }
  } catch (_) {
    initialLocale = const Locale('en');
  }

  // Run the app
  runApp(MyApp(
    prefs: prefs,
    authService: authService,
    initialLocale: initialLocale,
  ));
}


// Check app version and show changelog if needed
Future<void> _checkAppVersionAndShowChangelog() async {
  try {
    debugPrint('Checking for app version changes');
    final versionService = VersionService();
    final result = await versionService.checkVersion();
    
    if (result.versionChanged && result.changelogContent != null) {
      debugPrint('Version change detected, ready to show changelog');
      
      // Prepare the changelog dialog to show after app is built
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Wait a short moment to let any initial UI elements settle
        await Future.delayed(const Duration(milliseconds: 800));
        
        // Ensure there's a valid context to show the dialog in
        final context = WidgetsBinding.instance.renderViewElement?.findRenderObject()?.paintBounds != null
            ? WidgetsBinding.instance.renderViewElement
            : null;
            
        if (context != null) {
          // Get shared preferences to check UI states
          final prefs = await SharedPreferences.getInstance();
          final hasPendingCheckIn = prefs.getBool('pending_pledge_check_in') ?? false;
          final isFirstLaunchOfDay = await _isFirstLaunchOfDay();
          
          // Only show changelog if no other important UI elements are active
          if (!hasPendingCheckIn && !isFirstLaunchOfDay) {
            _showChangelogDialog(
              Navigator.of(context as BuildContext), 
              result.changelogContent!
            );
            debugPrint('Changelog dialog displayed');
          } else {
            // Save changelog content to show later when appropriate
            await prefs.setString('pending_changelog', result.changelogContent!);
            debugPrint('Changelog saved for later display');
          }
        } else {
          debugPrint('No valid context to display changelog dialog');
        }
      });
    } else {
      debugPrint('No version change detected or no changelog content available');
    }
  } catch (e) {
    debugPrint('Error checking app version: $e');
  }
}

// Helper function to check if this is first launch of day
Future<bool> _isFirstLaunchOfDay() async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final prefs = await SharedPreferences.getInstance();
  final lastLaunchStr = prefs.getString('last_launch_date');
  
  if (lastLaunchStr == null) {
    prefs.setString('last_launch_date', today.toIso8601String());
    return true;
  }
  
  final lastLaunch = DateTime.parse(lastLaunchStr);
  final lastLaunchDay = DateTime(lastLaunch.year, lastLaunch.month, lastLaunch.day);
  
  if (today != lastLaunchDay) {
    prefs.setString('last_launch_date', today.toIso8601String());
    return true;
  }
  
  return false;
}

// Show the changelog dialog
void _showChangelogDialog(NavigatorState navigator, String markdownContent) {
  try {
    showGeneralDialog(
      context: navigator.context,
      barrierDismissible: true,
      barrierLabel: 'Changelog',
      pageBuilder: (context, _, __) {
        return Center(
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 500.0,
                maxHeight: 600.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'What\'s New',
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Markdown(
                        data: markdownContent,
                        selectable: true,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(AppLocalizations.of(context)!.translate('common_gotIt')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
    );
  } catch (e) {
    debugPrint('Error showing changelog dialog: $e');
  }
}

// Function to log test environment status information
void _logTestEnvironmentStatus(bool isTestEnvironment) {
  try {
    final String environment = Platform.isIOS 
        ? (isTestEnvironment ? 'TestFlight' : 'iOS Production')
        : (isTestEnvironment ? 'Google Play Internal' : 'Android Production');
    
    // Log test environment status to Mixpanel
    final Map<String, dynamic> properties = {
      'timestamp': DateTime.now().toIso8601String(),
      'platform': defaultTargetPlatform.toString(),
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
    };
    
    // Log a specific environment detection event to Mixpanel
    MixpanelService.trackEvent(
      isTestEnvironment ? 'App Test Environment Detected' : 'App Production Environment Detected', 
      properties: properties
    );
    
    // Print detailed logs
    debugPrint('🔍 Environment Detection Results:');
    debugPrint('---------------------------------------');
    debugPrint('✅ Environment: $environment');
    debugPrint('📲 Platform: $defaultTargetPlatform');
    debugPrint('📱 OS: ${Platform.operatingSystem}');
    debugPrint('📱 OS Version: ${Platform.operatingSystemVersion}');
    debugPrint('---------------------------------------');
    
    // Add to Crashlytics as well for easier debugging
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.setCustomKey('environment', environment);
      FirebaseCrashlytics.instance.setCustomKey('is_test_environment', isTestEnvironment);
    }
    
    // IMPORTANT: Make sure Mixpanel's global property for the environment is set correctly
    // This affects ALL future events
    if (isTestEnvironment) {
      // Override any previous environment setting with Test Environment
      MixpanelService.instance?.registerSuperProperties({
        'Environment': environment,
        'Is Test Environment': true
      });
      debugPrint('🧪 IMPORTANT: Set Mixpanel global property "Environment" = "$environment"');
    } else {
      // Only set Production if we're sure it's not a test environment
      MixpanelService.instance?.registerSuperProperties({
        'Environment': environment,
        'Is Test Environment': false
      });
      debugPrint('📱 IMPORTANT: Set Mixpanel global property "Environment" = "$environment"');
    }
    
    // Send an additional distinct event based on environment
    MixpanelService.trackEvent('App Running In Environment', properties: {
      'timestamp': DateTime.now().toIso8601String(),
      'environment': environment, // Add environment explicitly to properties
    });
    debugPrint('✅ CONFIRMED: Running in $environment environment');
  } catch (e) {
    debugPrint('❌ Error logging environment status: $e');
    // Environment logging error - not critical, not sent to Crashlytics
  }
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;
  final AuthService authService;
  final Locale initialLocale;
  
  const MyApp({
    super.key, 
    required this.prefs,
    required this.authService,
    required this.initialLocale,
  });

  // Global reference to app state (similar to navigatorKey pattern)
  static _MyAppState? _appState;

  // Add static method to change locale HERE
  static void setLocale(BuildContext context, Locale newLocale) {
    if (_appState != null) {
      _appState!._setLocale(newLocale);
      debugPrint('✅ Locale change using global app state reference');
    } else {
      // Fallback to context search for edge cases
      _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
      if (state != null) {
        state._setLocale(newLocale);
        debugPrint('✅ Locale change using context fallback');
      } else {
        debugPrint('❌ Could not find MyAppState - both global reference and context search failed');
        // Log this production-specific issue to Crashlytics
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordError(
            'Locale change failed: No app state available',
            StackTrace.current,
            reason: 'Locale Change Failed',
            information: [
              'attempted_language: ${newLocale.languageCode}',
              'global_state_null: ${_appState == null}',
              'context_search_failed: true',
            ],
          );
        }
      }
    }
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver implements SuperwallDelegate {
  final logging = Logging();
  bool _isLoading = true;
  Widget? _startScreen;
  Locale _currentLocale = const Locale('en');
  final OnboardingProgressService _progressService = OnboardingProgressService();
  final UserRepository _userRepository = UserRepository();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final QuickActionsService _quickActionsService = QuickActionsService();
  // Force MaterialApp rebuild on hot reload
  Key _materialAppKey = UniqueKey();
  // Screenshot tracking
  final ScreenRouteObserver _screenRouteObserver = ScreenRouteObserver();
  ScreenshotTracker? _screenshotTracker;
  
  // Flag to detect hot reload vs hot restart
  bool _isHotReload = false;
  
  // Store the last navigation state to preserve it during hot reload
  String? _lastNavigationState;
  

  // Flag to track if quick actions were already initialized
  bool _isQuickActionsInitialized = false;
  // Flag to prevent duplicate home widget deep link processing during startup
  bool _hasProcessedHomeWidgetDeepLink = false;
  // StreamSubscription<SubscriptionStatus>? _subscription; // No longer needed - using delegate instead
  // --- START NEW ---
  StreamSubscription<PromoCodeData>? _promoCodeSubscription;
  // --- END NEW ---
  // Add a flag to prevent infinite loops with Apple reviewer account
  bool _isAppleReviewerBeingProcessed = false;
  // Add a timestamp to track when the Apple reviewer account was last processed
  DateTime? _lastAppleReviewerProcessTime;
  // Key for storing Apple reviewer processed flag in SharedPreferences
  static const String _appleReviewerProcessedKey = 'apple_reviewer_processed';
  // Flag to track if IAP products have been loaded successfully
  bool _iapProductsLoaded = false;
  int _iapProductLoadAttempts = 0; // Track number of attempts

  @override
  void initState() {
    const useRevenueCat = true;
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
    
    // Set global app state reference for reliable locale changes
    MyApp._appState = this;
    
    // Set initial locale from constructor
    _currentLocale = widget.initialLocale;
    
    // Initialize the app logic
    _initializeAppLogic(useRevenueCat);
    // Initialize screenshot tracker after app logic completes in init
    _screenshotTracker = ScreenshotTracker(routeObserver: _screenRouteObserver);
    _screenshotTracker!.start();
  }
  
  @override
  void reassemble() {
    super.reassemble();
    // Hot reload fix: Re-establish global reference
    MyApp._appState = this;
    debugPrint('🔥 Hot reload: Re-established global app state reference');
    
    // Mark that we're in a hot reload
    _isHotReload = true;
    
    // Only reload localization cache, don't rebuild the entire MaterialApp
    if (mounted && kDebugMode) {
      // Clear localization cache so new translations load
      AppLocalizations.evictAllFromCache();
      debugPrint('🔥 Hot reload: Cleared localization cache only (preserving navigation state)');
      
      // Just trigger a setState to refresh the UI with new localizations
      // without changing the MaterialApp key
      setState(() {
        // This will refresh the current screen with new localizations
        // without resetting navigation state
      });
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
    // Stop screenshot tracker
    _screenshotTracker?.stop();
    // _subscription?.cancel(); // No longer needed - using delegate instead
    // --- START NEW ---
    _promoCodeSubscription?.cancel();
    // --- END NEW ---
    
    // Clear global app state reference
    MyApp._appState = null;
    
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    //debugPrint('🔄 App lifecycle state changed to: $state');
    
    // When app comes to foreground and IAP products haven't been loaded, try again
    if (state == AppLifecycleState.resumed && !_iapProductsLoaded) {
      debugPrint('🛍️ App resumed and IAP products not loaded, attempting to load...');
      _loadInAppPurchaseProducts();
    }
    
    // Handle quick actions when app resumes
    if (state == AppLifecycleState.resumed) {
      // Check pending local-notification payloads
      _processPendingNotificationPayload();
      
      // Check if Don't Delete Me quick action is pending
      if (_quickActionsService.isDontDeleteMePending) {
        debugPrint('🎁 Don\'t Delete Me quick action pending, showing paywall immediately');
        // Delay slightly to ensure the app is fully resumed
        Future.delayed(const Duration(milliseconds: 100), () {
          _showDontDeleteMePaywall();
        });
      }
    }
  }

  // NEW: Consolidated initialization logic
  Future<void> _initializeAppLogic(bool useRevenueCat) async {
    // Load saved locale FIRST before any other initialization
    await _loadLocale(); // Load locale asynchronously
    
    // Essential initializations after locale is loaded
    await configureSuperwall(useRevenueCat);
    
    // Now that Superwall is configured, process any pending local-notification payloads
    await _processPendingNotificationPayload();
    _loadInAppPurchaseProducts();
    _setupFirebaseMessagingListeners();
    // --- START NEW ---
    _setupPromoCodeListener();
    // --- END NEW ---
    
    // Add security check for unauthorized premium access
    await _checkForUnauthorizedSubscriptionAccess();

    // Initialize AppLinks to check for initial link
    final appLinks = AppLinks();
    Uri? initialUri;
    bool handledInitialLink = false;

    try {
      initialUri = await appLinks.getInitialLink();
      
      if (initialUri != null && initialUri.scheme == 'stoppr' && initialUri.host == 'home') {
        // If launched via home widget link, store it but don't bypass welcome video
        MixpanelService.trackEvent('Initial Deep Link Received', properties: {
           'uri': initialUri.toString(),
           'type': 'widget_home_tap',
           'handled_early': false,
        });
        
        // Mark that we've processed this home widget deep link
        _hasProcessedHomeWidgetDeepLink = true;
        
        // Store the deep link to process after welcome video
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pending_home_navigation', true);
        await prefs.setString('pending_widget_deeplink', 'home');
        
        // Reset the flag after a delay to allow future home widget taps
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            _hasProcessedHomeWidgetDeepLink = false;
          }
        });
        
        // Don't set handledInitialLink = true, so welcome video shows
        handledInitialLink = false;
      } else if (initialUri != null && initialUri.scheme == 'stoppr' &&
                 (initialUri.host == 'pledge' || initialUri.host == 'panic' || initialUri.host == 'meditation')) {
        MixpanelService.trackEvent('Initial Deep Link Received', properties: {
          'uri': initialUri.toString(),
          'type': 'widget_feature_tap',
          'feature': initialUri.host,
          'handled_early': false,
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_widget_deeplink', initialUri.host);

        // Keep welcome video; do not mark handled
        handledInitialLink = false;
      } else if (initialUri != null) {
         // Track other initial links if needed
         MixpanelService.trackEvent('Initial Deep Link Received', properties: {
           'uri': initialUri.toString(),
           'type': 'other',
           'handled_early': false,
         });
      }
    } catch (e) {
      debugPrint('Error getting initial deep link during init: $e');
      // Deep link parsing/network error - not sent to Crashlytics
      // Continue with normal flow even if initial link check fails
    }

    // Setup the listener for subsequent links AFTER checking the initial one
    _handleIncomingLinks(appLinks); // Pass the initialized instance

      // Always proceed with onboarding check to show welcome video
      try {
        await _checkOnboardingProgress();
      } catch (e) {
        debugPrint('Error in _checkOnboardingProgress: $e');
        // Ensure loading state is cleared even on error
        if (mounted) {
          setState(() {
            _startScreen = WelcomeVideoScreen(
              nextScreen: const OnboardingPage(),
            );
            _isLoading = false;
          });
        }
      }
  }
  
  // NEW: Method to setup Firebase Messaging listeners
  Future<void> _setupFirebaseMessagingListeners() async {
    try {
      // Handle notification tap when app is in background/terminated
      // Initial message check (app opened from terminated state)
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null && mounted) { // Check mounted before calling instance method
        _handleMessageOpened(initialMessage);
      }
      
      // Listener for when app is opened from background state
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (mounted) { // Check mounted before calling instance method
           _handleMessageOpened(message);
        }
      });
      
      debugPrint('Firebase Messaging listeners setup successfully in _MyAppState');
    } catch (e) {
       debugPrint('Error setting up Firebase Messaging listeners in _MyAppState: $e');
       // Network/setup error - not sent to Crashlytics
    }
  }
  
  // Add new method to load in-app purchase products at startup
  Future<void> _loadInAppPurchaseProducts() async {
    debugPrint('🛍️ Loading in-app purchase products at app startup...');
    _iapProductLoadAttempts++;
    // --- START MODIFICATION ---
    // Allow IAP loading in debug mode for testing paywalls
    if (kDebugMode) {
      debugPrint('🛍️ Loading IAP products in debug mode for paywall testing.');
    }
    // --- END MODIFICATION ---
    
    // Check if app is in background - if so, skip IAP loading
    final appLifecycleState = WidgetsBinding.instance.lifecycleState;
    if (appLifecycleState != null && 
        (appLifecycleState == AppLifecycleState.paused || 
         appLifecycleState == AppLifecycleState.detached)) {
      debugPrint('🛍️ App is in background, skipping IAP product loading');

      return;
    }
    
    // Loading IAP products at startup
    
    try {
      // Check if store is available
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        debugPrint('🛍️ Store not available');
        // Store not available
        // Don't record as error in Crashlytics - this is expected in some environments
        return;
      }

      // Android Product IDs
      // com.stoppr.sugar.app.annual80off:annual80off
      // com.stoppr.sugar.app.annual:com-stoppr-sugar-app-annual
      // com.stoppr.sugar.app.monthly:com-stoppr-app-sugar-monthly
      // com.stoppr.sugar.app.weekly:com-stoppr-sugar-app-weekly
      
      // Define your product IDs based on the platform
      final Set<String> productIds;
      if (Platform.isIOS) {
        productIds = {
          'com.stoppr.app.monthly',
          'com.stoppr.app.annual',
          'com.stoppr.app.annual.trial',
          'com.stoppr.app.annual80OFF',
          'com.stoppr.app.trial.paid', // Trial paid access for iOS
          'com.stoppr.lifetime', // Lifetime one-time purchase for iOS
          'com.stoppr.weekly_cheap.app', // Youth weekly subscription
          'com.stoppr.monthly_cheap.app', // Youth monthly subscription
          'com.stoppr.annual_cheap.app', // Youth annual subscription
          'com.stoppr.app.annual.exp1', // Annual Expensive 1
          'com.stoppr.app.annual.exp2', // Annual Expensive 2
        };
      } else { // Assuming Android or other platforms
        productIds = {
          'com.stoppr.sugar.app.monthly:com-stoppr-app-sugar-monthly',
          'com.stoppr.sugar.app.annual:com-stoppr-sugar-app-annual',
          'com.stoppr.sugar.app.annual.trial:com-stoppr-sugar-app-annual-trial',
          'com.stoppr.sugar.app.annual80off:annual80off',
          'com.stoppr.sugar.app.weekly:com-stoppr-sugar-app-weekly', // Ensure weekly for Android
          'com.stoppr.sugar.lifetime', // Lifetime one-time purchase for Android
          'com.stoppr.sugar.app.weekly_cheap:com-stoppr-sugar-app-weekly-cheap', // Youth weekly subscription
          'com.stoppr.sugar.app.monthly_cheap:com-stoppr-app-sugar-monthly-cheap', // Youth monthly subscription
          'com.stoppr.sugar.app.annual_cheap:com-stoppr-sugar-app-annual-cheap', // Youth annual subscription
          'com.stoppr.sugar.app.annual.exp1:com-stoppr-sugar-app-annual-exp1', // Annual Expensive 1
          'com.stoppr.sugar.app.annual.exp2:com-stoppr-sugar-app-annual-exp2', // Annual Expensive 2
        };
      }
      
      
      // Querying product IDs
      
      // Add timeout to prevent hanging in background
      final ProductDetailsResponse response = await InAppPurchase.instance
          .queryProductDetails(productIds)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('🛍️ Product query timed out');
              // Return empty response on timeout
              return ProductDetailsResponse(
                productDetails: [],
                notFoundIDs: productIds.toList(),
                error: IAPError(
                  source: 'timeout',
                  code: 'timeout',
                  message: 'Product query timed out',
                ),
              );
            },
          );
          
      debugPrint('🛍️ Products loaded: ${response.productDetails.length}');
      
      // Products loaded
      debugPrint('🛍️ Products loaded: ${response.productDetails.length}, not found: ${response.notFoundIDs.length}');
      
      // Only set Crashlytics keys if not in debug mode
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.setCustomKey('iap_products_loaded_count', response.productDetails.length);
        FirebaseCrashlytics.instance.setCustomKey('iap_products_missing_count', response.notFoundIDs.length);
      }
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('🛍️ Products not found: \\${response.notFoundIDs}');
        debugPrint('⚠️ Products not found warning for platform: ${Platform.isIOS ? 'iOS' : 'Android'}');
        // Only retry once if products are not found
        if (response.productDetails.isEmpty && _iapProductLoadAttempts < 2) {
          debugPrint('🛍️ No products found, scheduling a single retry in 30 seconds');
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) {
              _retryLoadingIAPProducts();
            }
          });
        }
      }
      
      // Log each product found (helps verify during review)
      final List<Map<String, dynamic>> foundProducts = [];
      for (final product in response.productDetails) {
        debugPrint('🛍️ Found product: ${product.id} - ${product.title} - ${product.price}');
        foundProducts.add({
          'id': product.id,
          'title': product.title,
          'price': product.price,
          'price_string': product.price,
          'description': product.description,
        });
      }
      
      // Mark IAP products as successfully loaded if found
      if (foundProducts.isNotEmpty) {
        _iapProductsLoaded = true;
      }
    } catch (e) {
      debugPrint('🛍️ Error loading products: $e');
      // IAP store/network error - not sent to Crashlytics
      // Only retry once on error
      if (_iapProductLoadAttempts < 2) {
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted) {
            _retryLoadingIAPProducts();
          }
        });
      }
    }
  }
  
  // Add retry method for loading IAP products
  Future<void> _retryLoadingIAPProducts() async {
    debugPrint('🛍️ Retrying IAP product loading...');
    if (_iapProductsLoaded) {
      debugPrint('🛍️ IAP products already loaded, skipping retry');
      return;
    }
    if (_iapProductLoadAttempts >= 2) {
      debugPrint('🛍️ Max IAP product load attempts reached, not retrying again');
      return;
    }
    if (kDebugMode) {
      debugPrint('🛍️ Retrying IAP product loading in debug mode for paywall testing.');
    }
    final appLifecycleState = WidgetsBinding.instance.lifecycleState;
    if (appLifecycleState == AppLifecycleState.resumed) {
      await _loadInAppPurchaseProducts();
    } else {
      debugPrint('🛍️ App not in foreground, skipping retry');
    }
  }
  
  // Helper method to check if Apple reviewer account can be processed
  // Only allows processing once every 30 seconds
  bool _canProcessAppleReviewer() {
    if (_isAppleReviewerBeingProcessed) {
      logging.info('🍎 Apple reviewer account is already being processed');
      return false;
    }
    
    if (_lastAppleReviewerProcessTime != null) {
      final timeSinceLastProcess = DateTime.now().difference(_lastAppleReviewerProcessTime!);
      if (timeSinceLastProcess.inSeconds < 30) {
        logging.info('🍎 Apple reviewer account was processed too recently (${timeSinceLastProcess.inSeconds}s ago)');
        return false;
      }
    }
    
    return true;
  }
  
  // Helper method to check if Apple reviewer account has already been processed
  Future<bool> _hasAppleReviewerBeenProcessed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final processed = prefs.getBool('${_appleReviewerProcessedKey}_$userId') ?? false;
    
    if (processed) {
      logging.info('🍎 Apple reviewer account has already been processed before');
    }
    
    return processed;
  }
  
  // Helper method to mark Apple reviewer account as processed
  Future<void> _markAppleReviewerAsProcessed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_appleReviewerProcessedKey}_$userId', true);
    logging.info('🍎 Apple reviewer account marked as processed');
  }
  
  void listenForPurchases() {
    // IMPORTANT: We do not directly subscribe to Superwall.shared.subscriptionStatus.listen()
    // because it can cause a MissingPluginException if the native stream handler is not ready.
    // Instead, we rely on the SuperwallDelegate's subscriptionStatusDidChange() method
    // which is called by the native SDK when the subscription status changes.
    // This is the official, safe way to monitor subscription status changes.
    
    logging.info('Subscription monitoring is handled via SuperwallDelegate.subscriptionStatusDidChange()');
    
    /* The following code is commented out to prevent MissingPluginException:
    _subscription = Superwall.shared.subscriptionStatus.listen((status) async {
      final String statusString = status.toString(); // New way
      logging.info('subscriptionStatusDidChange listener: $statusString');
      
      // Update Firebase with subscription status
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check if subscription is active based on status description
        final isSubscribed = statusString.toLowerCase() == ".active";
        
        // Default to free subscription
        SubscriptionType subscriptionType = SubscriptionType.free;
        String? productId;
        
        if (isSubscribed) {
          // Try to get product details from RevenueCat for better tracking
          try {
            final customerInfo = await Purchases.getCustomerInfo().timeout(
              const Duration(seconds: 3),
            );
            final activeSubscriptions = customerInfo.activeSubscriptions;
            
            if (activeSubscriptions.isNotEmpty) {
              productId = activeSubscriptions.first; // Use first active subscription
              logging.info('Found active product ID: $productId');
              
              // Get base product ID if it's in the new format (platformID:baseID)
              String baseProductId = productId ?? '';
              if (baseProductId.contains(':')) {
                baseProductId = baseProductId.split(':')[0];
                logging.info('Using base product ID for type detection: $baseProductId');
              }
              
              // Determine the subscription type based on the product ID
              if (baseProductId.toLowerCase().contains('annual80off') || 
                  baseProductId.toLowerCase() == 'sugar.app.annual80off') {
                subscriptionType = SubscriptionType.paid_gift;
                logging.info('Identified as GIFT subscription based on product ID');
              } else if (baseProductId.toLowerCase().contains('annual') || 
                        baseProductId.toLowerCase().contains('monthly')) {
                subscriptionType = SubscriptionType.paid_standard;
                logging.info('Identified as STANDARD subscription based on product ID');
              } else if (baseProductId.toLowerCase().contains('weekly')) {
                subscriptionType = SubscriptionType.paid_standard;
                logging.info('Identified as STANDARD (Weekly) subscription based on product ID');
              } else {
                // Unknown product ID but still active - default to standard
                subscriptionType = SubscriptionType.paid_standard;
                logging.info('Using default STANDARD status for unknown product ID: $productId');
              }
            } else {
              // Active in Superwall but no product found in RevenueCat
              subscriptionType = SubscriptionType.paid_standard;
              productId = 'superwall_active';
              logging.info('No specific product found, using default STANDARD status');
            }
          } catch (e) {
            logging.error('Error getting product details from RevenueCat: $e');
            subscriptionType = SubscriptionType.paid_standard; // Fallback value
            productId = 'superwall_active_fallback';
          }
        }
        
        // Update Firebase using the subscription service
        await _subscriptionService.updateSubscriptionStatus(
          user.uid, 
          subscriptionType,
          productId: productId
        );
        
        logging.info('Updated Firebase: User has subscription status: $subscriptionType, productId: $productId');
        
        // Set up notifications based on subscription status
        try {
          final notificationService = NotificationService();
          await notificationService.updateNotificationsBasedOnSubscription(isSubscribed: isSubscribed);
          logging.info('Updated notifications based on subscription status');
        } catch (e) {
          logging.error('Failed to update notifications: $e');
        }
      }
    });
    */
  }



  // Method for handling deep links - Modified to accept AppLinks instance
  void _handleIncomingLinks(AppLinks appLinks) {
    // final appLinks = AppLinks(); // Remove: Instance is now passed in
    appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        // logging.info('Received deep link: $uri');
        MixpanelService.trackEvent('Deep Link Received', properties: {
          'uri': uri.toString(),
        });
        _processDeepLink(uri); // Use a helper method
      }
    }, onError: (Object err) {
      // logging.error('Error receiving incoming link: $err');
      // URL parsing/malformed deep link error - not sent to Crashlytics
    });
    
    // Also handle initial URI if the app was started with a deep link
    _handleInitialUri(appLinks);
  }
  
  // Handle initial URI if the app was started with a deep link
  Future<void> _handleInitialUri(AppLinks appLinks) async {
    try {
      // Get the initial link that opened the app
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        // logging.info('Initial deep link: $initialUri');
        MixpanelService.trackEvent('Initial Deep Link Received', properties: {
          'uri': initialUri.toString(),
        });
        // Process the same way as stream links, but wait for navigator
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _processDeepLink(initialUri);
        });
      }
    } catch (e) {
      // logging.error('Error getting initial deep link: $e');
      // URL parsing/network error - not sent to Crashlytics
    }
  }
  
  // Helper method to process both initial and streamed deep links
  void _processDeepLink(Uri uri) {
    // Prevent processing the same home widget deep link twice during startup
    if (uri.scheme == 'stoppr' && uri.host == 'home' && _hasProcessedHomeWidgetDeepLink) {
      return;
    }
    
    // Check if the navigator is available
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      // // logging.info('Navigator not yet available for deep link: $uri'); // Removed this line
      // Log this scenario to Crashlytics
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          'Deep link received but navigator unavailable',
          StackTrace.current,
          reason: 'Deep Link Navigator Unavailable',
          information: ['uri: ${uri.toString()}'],
        );
      }
      // Optionally, queue the link to be processed later
      return;
    }
    
    // Handle payment success deep link
    if (uri.scheme == 'https' && uri.host == 'stoppr.app' && uri.path == '/payment/success') { // More specific check
      // logging.info('Payment success deep link detected');
      MixpanelService.trackEvent('Deep Link Processed', properties: {
        'type': 'payment_success',
        'uri': uri.toString(),
      });
      
      // Refresh user's subscription status
      _refreshSubscriptionStatus();
      
      // Navigate to appropriate screen
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const CongratulationsScreen1(),
          settings: const RouteSettings(name: '/payment_success'),
        ),
        (route) => false, // Remove all previous routes
      );
    } 
    // Handle widget tap deep link
    else if (uri.scheme == 'stoppr' && uri.host == 'home') {
      // logging.info('Home screen deep link detected from widget');
      MixpanelService.trackEvent('Home Widget Tapped', properties: {
        'source': 'Home Screen Widget',
        'uri': uri.toString(),
      });
      // Navigate to MainScaffold, ensuring the home tab (index 0) is selected
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MainScaffold(initialIndex: 0),
          settings: const RouteSettings(name: '/home_from_widget'), // Unique name
        ),
         (route) => route.settings.name == '/home' || route.settings.name == '/', // Keep only root home route
      );
    }
    // Handle pledge widget tap deep link
    else if (uri.scheme == 'stoppr' && uri.host == 'pledge') {
      MixpanelService.trackEvent('Daily Pledge Widget Tapped', properties: {
        'source': 'Home Screen Widget',
        'uri': uri.toString(),
      });
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const PledgeScreen(),
          settings: const RouteSettings(name: '/pledge_from_widget'),
        ),
        (route) => false,
      );
    }
    // Handle panic widget deep link
    else if (uri.scheme == 'stoppr' && uri.host == 'panic') {
      MixpanelService.trackEvent('Panic Button Widget Tapped', properties: {
        'source': 'Home Screen Widget',
        'uri': uri.toString(),
      });
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const WhatHappeningScreen(),
          settings: const RouteSettings(name: '/panic_from_widget'),
        ),
        (route) => false,
      );
    }
    // Handle quick meditation widget deep link
    else if (uri.scheme == 'stoppr' && uri.host == 'meditation') {
      MixpanelService.trackEvent('Quick Meditation Widget Tapped', properties: {
        'source': 'Home Screen Widget',
        'uri': uri.toString(),
      });
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MeditationScreen(),
          settings: const RouteSettings(name: '/meditation_from_widget'),
        ),
        (route) => false,
      );
    }
    // (removed) winback lifetime deep link handler
    // We don't use deep links with Superwall
    else if (uri.scheme == 'https' && uri.host == 'stoppr.app' && uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'share') {
      final token = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
      if (token != null) {
        // Verify token via SharingService
        SharingService.instance.verifyToken(token).then((data) {
          if (data != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (ctx) => AcceptInvitePage(
                  token: token,
                  initiatorName: data['initiatorName'] ?? '',
                ),
                settings: const RouteSettings(name: '/accept_invite'),
              ),
            );
          }
        });
      }
    }
    // The promo_code logic previously here is now handled by AppsFlyerService listeners
  }
  
  // --- START NEW: Helper method to apply promo from deep link ---
  Future<void> _applyPromoFromDeepLink(String mediaSource, String promoCode) async {
    try {
      var user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint("🪰 AppsFlyer OneLink: No current user. Creating anonymous user for promo: $promoCode.");
        try {
          final userCredential = await FirebaseAuth.instance.signInAnonymously();
          user = userCredential.user;
          debugPrint("🪰 AppsFlyer OneLink: Anonymous user created: ${user?.uid}");
        } catch (e) {
          debugPrint("🪰 AppsFlyer OneLink: Error creating anonymous user for promo $promoCode: $e");
          if (!kDebugMode) {
            FirebaseCrashlytics.instance.recordError(
              e,
              StackTrace.current,
              reason: 'AppsFlyer Promo Error: Anonymous user creation failed',
              information: ['promo_code: $promoCode'],
            );
          }
          return;
        }
      }

      if (user != null) {
        debugPrint("🪰 AppsFlyer OneLink: Applying promo $promoCode for user: ${user.uid}");
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'isAnonymous': user.isAnonymous,
          'referralCode': promoCode, // Use parameter
          'partnerUser': true,
          'lastAppliedPromoSource': mediaSource, // Store the actual media source from AppsFlyer
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint("🪰 AppsFlyer OneLink: Firestore updated for promo $promoCode.");

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_partner_user', true);
        debugPrint("🪰 AppsFlyer OneLink: SharedPreferences updated for promo $promoCode.");

        MixpanelService.instance?.identify(user.uid);
        MixpanelService.instance?.getPeople().set('Promo Code', promoCode); // Use parameter
        MixpanelService.instance?.getPeople().set('Partner', true);
        MixpanelService.instance?.getPeople().set('Last Promo Media Source', mediaSource);
        MixpanelService.trackEvent('AppsFlyer Promo Applied', properties: { // Generic event name
          'promo_code': promoCode, // Use parameter
          'user_id': user.uid,
          'media_source': mediaSource,
        });
        debugPrint("🪰 AppsFlyer OneLink: Mixpanel tracked for promo $promoCode.");
        
        // Optional: Refresh user data locally if your app relies on a local user model
        // context.read<AuthCubit>().refreshUserData(); 
        
        // You might want to show a non-intrusive confirmation if the app is already active
        // For example, using a simple debugPrint or a subtle toast if context allows.
        // For now, it applies silently.
         debugPrint("🪰 AppsFlyer OneLink: Promo $promoCode successfully applied for user ${user.uid}.");

      } else {
         debugPrint("🪰 AppsFlyer OneLink: User is still null after attempting anonymous sign-in. Cannot apply promo $promoCode.");
         if (!kDebugMode) {
            FirebaseCrashlytics.instance.recordError(
              'User is null after anonymous sign-in attempt',
              StackTrace.current,
              reason: 'AppsFlyer Promo Error: User null after anon signin',
              information: ['promo_code: $promoCode'],
            );
          }
      }
    } catch (e) {
      debugPrint("🪰 AppsFlyer OneLink: Error applying promo $promoCode from deep link: $e");
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'AppsFlyer Promo Error: Exception in apply logic',
          information: ['promo_code: $promoCode'],
        );
      }
    }
  }
  // --- END NEW ---
  
  // Refresh subscription status from Firebase
  Future<void> _refreshSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Force a refresh of user data from Firestore
        await _userRepository.refreshUserData(user.uid);
        
        // Check subscription status (guarded by readiness)
        SubscriptionStatus? status;
        if (NotificationService.isSuperwallReady) {
          status = await Superwall.shared.getSubscriptionStatus();
        } else {
          logging.info('Superwall not ready; skipping immediate status refresh');
        }
        final bool isSubscribed = status is SubscriptionStatusActive;
        logging.info('Subscription status refreshed - isPaid: $isSubscribed (Status: ${status ?? 'null'})');
        
        // Update notifications based on subscription status
        try {
          final notificationService = NotificationService();
          await notificationService.updateNotificationsBasedOnSubscription(isSubscribed: isSubscribed);
          logging.info('Updated notifications based on subscription status');
        } catch (e) {
          logging.error('Failed to update notifications: $e');
        }
      } catch (e) {
        logging.error('Error refreshing subscription status: $e');
      }
    }
  }

  // Configure Superwall
  Future<void> configureSuperwall(bool useRevenueCat) async {
    try {
      // Reset Superwall's cache to ensure fresh state
      // await Superwall.shared.reset();
      
      // Create the SuperwallPurchaseController
      final purchaseController = SuperwallPurchaseController();

      // Get Superwall API Keys from environment config
      final iosApiKey = EnvConfig.superwallIOSApiKey;
      final androidApiKey = EnvConfig.superwallAndroidApiKey;
      
      if (iosApiKey == null || androidApiKey == null) {
        debugPrint('Error: Superwall API keys are missing in .env file');
        return;
      }
      
      final apiKey = Platform.isIOS ? iosApiKey : androidApiKey;

      // Configure logging
      final logging = Logging();
      logging.level = LogLevel.debug;
      logging.scopes = {LogScope.all};

      // Set Superwall options
      final options = SuperwallOptions();
      options.paywalls.shouldPreload = true;
      options.logging = logging;

      // --- ANDROID: Do NOT call Superwall.configure here ---
      if (Platform.isAndroid) {
        debugPrint('Superwall.configure already called in main() for Android. Skipping duplicate call.');
        return;
      }
      // --- END ANDROID ---

      // iOS (or other platforms): configure immediately
      debugPrint('About to configure Superwall...');
      Superwall.configure(
        apiKey,
        purchaseController: useRevenueCat ? purchaseController : null,
        options: options, 
        completion: () {
          debugPrint('🔍 SUPERWALL CONFIGURATION COMPLETE - INSPECTING BRIDGE ID');
          // listenForPurchases(); // No longer needed - using delegate instead
          logging.info('Executing Superwall configure completion block');
          // Mark Superwall ready on iOS (configure path)
          NotificationService.setSuperwallReady(true);
        }
      );
      
      
      Superwall.shared.setDelegate(this);
      
      // Configure RevenueCat and sync subscription status
      if (useRevenueCat) {
        await purchaseController.configureAndSyncSubscriptionStatus();
      }
    } catch (e) {
      // Handle any errors during configuration
      logging.error('Failed to configure Superwall:', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with RepositoryProvider for CommunityRepository
    return RepositoryProvider(
      create: (context) => CommunityRepository(),
      child: BlocProvider(
        create: (context) => AuthCubit(
          authService: widget.authService,
          subscriptionService: _subscriptionService,
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light, // iOS: black status bar items
            statusBarIconBrightness: Brightness.dark, // Android: black status bar items
            statusBarColor: Colors.transparent, // Android: transparent background
          ),
          child: MaterialApp(
            key: _materialAppKey, // Force rebuild on hot reload
            navigatorKey: navigatorKey, // Assign the global key here
            title: 'Stoppr',
            debugShowCheckedModeBanner: false,
            locale: _currentLocale, // Use the _currentLocale state
            // Localization settings
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''), // English, no country code
              Locale('es', ''), // Spanish, no country code
              Locale('de', ''), // German, no country code
              Locale('zh', ''), // Chinese, no country code
              Locale('ru', ''), // Russian, no country code
              Locale('fr', ''), // French, no country code
              Locale('sk', ''), // Slovak, no country code
              Locale('cs', ''), // Czech, no country code
              Locale('pl', ''), // Polish, no country code
              Locale('it', ''), // Italian, no country code
            ],
            // We will set the locale dynamically later based on user preference
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarBrightness: Brightness.light,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarColor: Colors.transparent,
                ),
              ),
              pageTransitionsTheme: PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: const FadeTransitionBuilder(),
                  TargetPlatform.iOS: const FadeTransitionBuilder(),
                  TargetPlatform.macOS: const FadeTransitionBuilder(),
                },
              ),
            ),
            navigatorObservers: <NavigatorObserver>[
              _screenRouteObserver,
            ],
            routes: {
              '/home': (context) => const MainScaffold(initialIndex: 0)
            },
            // Instead of using AppStartPage, we'll directly use the loading screen or start screen
            home: Builder(
              builder: (BuildContext context) {
                // Set up quick actions callbacks once we have a context
                _setupQuickActions(context);
                
                return _isLoading 
                    ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                    : _startScreen ?? WelcomeVideoScreen(
                        nextScreen: const OnboardingPage(),
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
  
  // Setup quick actions callbacks
  void _setupQuickActions(BuildContext context) {
    // Initialize quick actions only once
    if (!_isQuickActionsInitialized) {
      // Initialize quick actions
      _quickActionsService.initialize();
      
      // Set up direct action handlers that don't require context
      _quickActionsService.setupDirectActionHandlers();
      
      _isQuickActionsInitialized = true;
      debugPrint('Quick actions initialized once');
    }
    
    // We need to run this after the first frame is rendered to have a valid context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Save this context for quick actions
        _quickActionsService.setLastValidContext(context);
        
        // Process any initial action that might have launched the app
        _quickActionsService.processInitialAction(context);
      }
    });
  }
  
  // SuperwallDelegate methods
  @override
  void didDismissPaywall(PaywallInfo paywallInfo) async {
    logging.info('didDismissPaywall: $paywallInfo');
    
    // Paywall dismissed
    debugPrint('📊 Paywall dismissed');
  }

  @override
  void didPresentPaywall(PaywallInfo paywallInfo) async {
    logging.info('didPresentPaywall: $paywallInfo');
    
    // Paywall presented
    debugPrint('📊 Paywall presented');
  }

  @override
  void handleCustomPaywallAction(String name) {
    logging.info('handleCustomPaywallAction: $name');
  }

  @override
  void handleLog(String level, String scope, String? message,
      Map<dynamic, dynamic>? info, String? error) {
    // logging.info("handleLog: $level, $scope, $message, $info, $error");
  }

  @override
  Future<void> handleSuperwallEvent(SuperwallEventInfo eventInfo) async {
    //debugPrint('handleSuperwallEvent: ${eventInfo.event.type}');
    
    switch (eventInfo.event.type) {
      case EventType.appOpen:
        logging.info('appOpen event');
        break;
      case EventType.deviceAttributes:
        logging.info('deviceAttributes event');
        break;
      case EventType.paywallOpen:
        final paywallInfo = eventInfo.event.paywallInfo;
        logging.info('paywallOpen event: $paywallInfo');
        
        if (paywallInfo != null) {
          final String? identifier = await paywallInfo.identifier; // If name became nullable, identifier might have too
          logging.info('paywallInfo.identifier: ${identifier ?? "N/A"}');
          
          final productIds = await paywallInfo.productIds;
          logging.info('paywallInfo.productIds: $productIds');
        }
        break;
      case EventType.transactionComplete:
        // Handle successful purchase
        final paywallInfo = eventInfo.event.paywallInfo;
        if (paywallInfo != null) {
          final String? identifier = await paywallInfo.identifier; // If name became nullable, identifier might have too
          final String? paywallName = await paywallInfo.name;
          debugPrint('🎉 Purchase completed for paywall: ${identifier ?? "N/A"}');
          
          // Purchase completed
          debugPrint('🎉 Paywall conversion completed');
          
          // Store that this is the first time subscribing (for showing congratulations)
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('first_time_subscribed', true);
          
          // Safety check: only navigate if the widget is still mounted AND context is valid
          if (mounted && context != null) {
            try {
              // Use a safer navigation approach
              final navigator = Navigator.maybeOf(context);
              if (navigator != null) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const CongratulationsScreen1(),
                    settings: const RouteSettings(name: '/congratulations'),
                  ),
                  (route) => false, // Remove all previous routes
                );
              } else {
                logging.info('Navigator not available for navigation after transaction');
              }
            } catch (e) {
              logging.error('Error navigating after transaction: $e');
            }
          } else {
            logging.info('Widget not mounted or context invalid, skipping navigation after transaction');
          }
        }
        break;
      case EventType.transactionAbandon:
        debugPrint('❌ Purchase abandoned');
        
        // Purchase abandoned
        debugPrint('❌ Paywall conversion abandoned');
        break;
      default:
        break;
    }
  }

  @override
  void paywallWillOpenDeepLink(Uri url) {
    logging.info('paywallWillOpenDeepLink: $url');
  }

  @override
  void paywallWillOpenURL(Uri url) {
    logging.info('paywallWillOpenURL: $url');
  }

  @override
  void subscriptionStatusDidChange(SubscriptionStatus newValue) async {
    final String newStatusString = newValue.toString(); // New way for logging
    logging.info('subscriptionStatusDidChange: $newStatusString');
    
    // Update Firebase subscription status via subscription service
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final bool isActive = newValue is SubscriptionStatusActive; // New way
      
      try {
        if (isActive) {
          // Get customer info from RevenueCat
          try {
            final customerInfo = await Purchases.getCustomerInfo().timeout(
              const Duration(seconds: 3),
            );
            final activeSubscriptions = customerInfo.activeSubscriptions;
            
            // Extract subscription dates
            DateTime? subscriptionStartDate;
            DateTime? subscriptionExpirationDate;
            
            // Try to get dates from entitlements
            final entitlements = customerInfo.entitlements.active;
            if (entitlements.isNotEmpty) {
              final entitlement = entitlements.values.first;
              // Get start date if available (purchase date)
              if (entitlement.latestPurchaseDate != null) {
                try {
                  subscriptionStartDate = DateTime.parse(entitlement.latestPurchaseDate!);
                } catch (e) {
                  logging.error('Failed to parse subscription start date: $e');
                }
              }
              // Get expiration date
              if (entitlement.expirationDate != null) {
                try {
                  subscriptionExpirationDate = DateTime.parse(entitlement.expirationDate!);
                } catch (e) {
                  logging.error('Failed to parse subscription expiration date: $e');
                }
              }
              
              logging.info('📅 Subscription dates - Start: $subscriptionStartDate, Expiration: $subscriptionExpirationDate');
            }
            
            if (activeSubscriptions.isNotEmpty) {
              // CRITICAL FIX: For Android trials, check for trial product ID in allPurchasedProductIdentifiers
              // This is necessary because RevenueCat returns the base product ID in activeSubscriptions
              // but we need to save the original trial product ID for analytics/tracking purposes
              String productId = activeSubscriptions.first; // Default to active subscription
              
              // Check if user purchased a trial (Android format includes the full trial ID)
              final allPurchased = customerInfo.allPurchasedProductIdentifiers;
              const androidTrialId = 'com.stoppr.sugar.app.annual.trial:com-stoppr-sugar-app-annual-trial';
              const iosTrialId = 'com.stoppr.app.annual.trial';
              
              if (allPurchased.contains(androidTrialId)) {
                productId = androidTrialId;
                logging.info('🔧 Android trial detected - using original trial product ID: $productId');
              } else if (allPurchased.contains(iosTrialId)) {
                productId = iosTrialId;
                logging.info('🔧 iOS trial detected - using original trial product ID: $productId');
              }
              
              logging.info('Final product ID to save to Firestore: $productId');
              
              // Get base product ID if it's in the new format (platformID:baseID)
              String baseProductId = productId;
              if (productId.contains(':')) {
                baseProductId = productId.split(':')[0];
                logging.info('Using base product ID for subscription type determination: $baseProductId');
              }
              
              // Calculate expiration date if not available but we have start date
              if (subscriptionExpirationDate == null && subscriptionStartDate != null) {
                // Determine duration based on product ID
                Duration subscriptionDuration = const Duration(days: 30); // Default to 30 days
                
                if (baseProductId.toLowerCase().contains('annual')) {
                  subscriptionDuration = const Duration(days: 365); // Annual = 1 year
                } else if (baseProductId.toLowerCase().contains('monthly')) {
                  subscriptionDuration = const Duration(days: 30); // Monthly = 30 days
                } else if (baseProductId.toLowerCase().contains('weekly')) {
                  subscriptionDuration = const Duration(days: 7); // Weekly = 7 days
                }
                
                // Calculate and use expiration date
                subscriptionExpirationDate = subscriptionStartDate.add(subscriptionDuration);
                logging.info('📅 Calculated expiration date: $subscriptionExpirationDate based on start date');
              }
              
              // Use the subscription service to update Firebase
              // Determine subscription type based on product ID
              if (baseProductId.toLowerCase().contains('lifetime') || 
                  baseProductId == 'com.stoppr.lifetime' ||
                  baseProductId == 'com.stoppr.sugar.lifetime') {
                // Lifetime purchase - no expiration date needed
                await _subscriptionService.updateSubscriptionStatus(
                  user.uid, 
                  SubscriptionType.paid_lifetime,
                  productId: productId,
                  startDate: subscriptionStartDate,
                  expirationDate: null // No expiration for lifetime purchases
                );
                logging.info('Delegate: Updated Firebase with LIFETIME purchase ($productId)');
              } else if (baseProductId.toLowerCase().contains('annual80off') || 
                  baseProductId.toLowerCase() == 'sugar.app.annual80off') {
                await _subscriptionService.updateSubscriptionStatus(
                  user.uid, 
                  SubscriptionType.paid_gift,
                  productId: productId,
                  startDate: subscriptionStartDate,
                  expirationDate: subscriptionExpirationDate
                );
                logging.info('Delegate: Updated Firebase with GIFT subscription ($productId)');
              } else if (baseProductId.toLowerCase().contains('.exp1') || 
                  baseProductId.toLowerCase().contains('.exp2')) {
                await _subscriptionService.updateSubscriptionStatus(
                  user.uid, 
                  SubscriptionType.paid_standard,
                  productId: productId,
                  startDate: subscriptionStartDate,
                  expirationDate: subscriptionExpirationDate
                );
                logging.info('Delegate: Updated Firebase with EXPENSIVE ANNUAL subscription ($productId)');
              } else if (baseProductId.toLowerCase().contains('trial')) {
                // For trial subscriptions: trial starts now, subscription starts in 3 days
                final DateTime trialStartDate = subscriptionStartDate ?? DateTime.now();
                final DateTime trialExpirationDate = trialStartDate.add(const Duration(days: 3));
                final DateTime actualSubscriptionStartDate = trialExpirationDate; // Subscription starts when trial ends
                final DateTime actualSubscriptionExpirationDate = trialStartDate.add(const Duration(days: 365 + 3)); // 1 year + 3 trial days
                
                await _subscriptionService.updateSubscriptionStatus(
                  user.uid, 
                  SubscriptionType.paid_standard,
                  productId: productId,
                  startDate: actualSubscriptionStartDate, // Subscription starts in 3 days
                  expirationDate: actualSubscriptionExpirationDate,
                  trialExpirationDate: trialExpirationDate
                );
                logging.info('Delegate: Updated Firebase with TRIAL subscription ($productId)');
                logging.info('Trial period: ${trialStartDate.toIso8601String()} to ${trialExpirationDate.toIso8601String()}');
                logging.info('Paid subscription starts: ${actualSubscriptionStartDate.toIso8601String()}, expires: ${actualSubscriptionExpirationDate.toIso8601String()}');
              } else if (baseProductId.toLowerCase().contains('cheap')) {
                // Youth subscriptions (age < 24)
                await _subscriptionService.updateSubscriptionStatus(
                  user.uid, 
                  SubscriptionType.paid_standard_cheap,
                  productId: productId,
                  startDate: subscriptionStartDate,
                  expirationDate: subscriptionExpirationDate
                );
                logging.info('Delegate: Updated Firebase with YOUTH CHEAP subscription ($productId)');
              } else if (baseProductId.toLowerCase().contains('annual')) {
                await _subscriptionService.updateSubscriptionStatus(
                  user.uid, 
                  SubscriptionType.paid_standard,
                  productId: productId,
                  startDate: subscriptionStartDate,
                  expirationDate: subscriptionExpirationDate
                );
                logging.info('Delegate: Updated Firebase with ANNUAL subscription ($productId)');
              } else if (baseProductId.toLowerCase().contains('monthly')) {
                await _subscriptionService.updateSubscriptionStatus(
                  user.uid, 
                  SubscriptionType.paid_standard,
                  productId: productId,
                  startDate: subscriptionStartDate,
                  expirationDate: subscriptionExpirationDate
                );
                logging.info('Delegate: Updated Firebase with MONTHLY subscription ($productId)');
              } else if (baseProductId.toLowerCase().contains('weekly')) {
                await _subscriptionService.updateSubscriptionStatus(
                  user.uid, 
                  SubscriptionType.paid_standard,
                  productId: productId,
                  startDate: subscriptionStartDate,
                  expirationDate: subscriptionExpirationDate
                );
                logging.info('Delegate: Updated Firebase with WEEKLY subscription ($productId)');
              } else if (baseProductId.toLowerCase().contains('33off')) {
                await _subscriptionService.updateSubscriptionStatus(
                  user.uid, 
                  SubscriptionType.paid_standard,
                  productId: productId,
                  startDate: subscriptionStartDate,
                  expirationDate: subscriptionExpirationDate
                );
                logging.info('Delegate: Updated Firebase with 33% OFF subscription ($productId)');
              } else {
                // Unknown product ID - still mark as paid_standard but log the actual ID
                await _subscriptionService.updateSubscriptionStatus(
                  user.uid, 
                  SubscriptionType.paid_standard,
                  productId: productId,
                  startDate: subscriptionStartDate,
                  expirationDate: subscriptionExpirationDate
                );
                logging.info('Delegate: Updated Firebase with UNKNOWN subscription type ($productId), marking as standard');
              }
            } else {
              // Active but no subscriptions found
              await _subscriptionService.updateSubscriptionStatus(
                user.uid, 
                SubscriptionType.paid_standard,
                productId: 'delegate_active'
              );
              logging.info('Delegate: User is ACTIVE but no subscription found in RevenueCat');
            }
          } catch (rcError) {
            // RevenueCat query failed, use fallback
            logging.error('Delegate: Error getting subscription from RevenueCat: $rcError');
            await _subscriptionService.updateSubscriptionStatus(
              user.uid, 
              SubscriptionType.paid_standard,
              productId: 'delegate_active_fallback'
            );
            logging.info('Delegate: Updated Firebase with ACTIVE subscription (fallback)');
          }
          
          // Update notifications for subscribers
          try {
            final notificationService = NotificationService();
            await notificationService.updateNotificationsBasedOnSubscription(isSubscribed: true);
            logging.info('Updated notifications for SUBSCRIBED user in delegate');
          } catch (e) {
            logging.error('Failed to update notifications in delegate: $e');
          }
        } else {
          // SECURITY FIX: Don't preserve Firebase dates - RevenueCat is the source of truth
          // Mark user as free immediately when RevenueCat says they're inactive
          await _subscriptionService.updateSubscriptionStatus(
            user.uid, 
            SubscriptionType.free,
            productId: null
          );
          
          // Update notifications for non-subscribers
          try {
            final notificationService = NotificationService();
            await notificationService.updateNotificationsBasedOnSubscription(isSubscribed: false);
            logging.info('Updated notifications for NON-SUBSCRIBED user in delegate');
          } catch (e) {
            logging.error('Failed to update notifications in delegate: $e');
          }
        }
      } catch (e) {
        logging.error('Failed to update subscription status in delegate: $e');
      }
    }
  }

  @override
  void willDismissPaywall(PaywallInfo paywallInfo) {
    logging.info('willDismissPaywall: $paywallInfo');
  }

  @override
  void willPresentPaywall(PaywallInfo paywallInfo) {
    printSubscriptionStatus();
    logging.info('willPresentPaywall: $paywallInfo');
  }

  @override
  void handleSuperwallDeepLink(Uri fullURL, List<String> pathComponents, Map<String, String> queryParameters) {
    logging.info('handleSuperwallDeepLink: $fullURL, pathComponents: $pathComponents, queryParameters: $queryParameters');
    // Handle Superwall deep links here if needed
    // This method is required by SuperwallDelegate in version 2.3.4+
  }

  Future<void> printSubscriptionStatus() async {
    final status = await Superwall.shared.getSubscriptionStatus();
    // final description = await status.description; // Old way
    final String statusString = status.toString(); // New way for logging
    logging.info('Status: $statusString');
  }

  Future<void> _checkOnboardingProgress() async {
    debugPrint('🔄 Checking onboarding progress...');
    
    try {
      // CRITICAL FIX: Check if user previously completed onboarding BEFORE checking auth state
      // This prevents the race condition where Firebase Auth hasn't restored the session yet
      final hasCompletedOnboardingBefore = await _progressService.isOnboardingCompleted();
      
      User? currentUser;
      
      if (hasCompletedOnboardingBefore) {
        debugPrint('📱 User has completed onboarding before, waiting for Firebase Auth restoration...');
        
        // Track that we detected and prevented the race condition
        // Firebase Auth race condition prevented
        
        // Wait for Firebase Auth to restore the session
        final completer = Completer<User?>();
        final subscription = FirebaseAuth.instance.authStateChanges().listen((user) {
          if (!completer.isCompleted) {
            completer.complete(user);
          }
        });
        
        // Wait up to 3 seconds for auth state to be resolved
        currentUser = await completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('⏰ Firebase Auth restoration timed out, checking current user');
            return FirebaseAuth.instance.currentUser;
          },
        );
        subscription.cancel();
        
        if (currentUser == null) {
          // This is unusual - user completed onboarding but no auth session found
          debugPrint('⚠️ Warning: User completed onboarding but no auth session found');
          // Final check - maybe auth is now available
          currentUser = FirebaseAuth.instance.currentUser;
          
          if (currentUser == null) {
            // Track the edge case where auth truly failed to restore
            // Firebase Auth failed to restore
          }
        } else {
          debugPrint('✅ Firebase Auth successfully restored session for user: ${currentUser.uid}');
          // Firebase Auth session restored
        }
      } else {
        debugPrint('🆕 New user or onboarding not completed, checking current auth state');
        currentUser = FirebaseAuth.instance.currentUser;
      }
      
      Widget targetScreen;
      
      // First check if user is already logged in
      if (currentUser != null) {
        logging.info('Found authenticated user: ${currentUser.uid}');
        
        // Set Superwall user attributes for existing users
        await _setSuperwallAttributesForCurrentUser(currentUser.uid);
                
        // Implement dual verification to check if onboarding is actually completed
        // 1. Check Firestore (server-side persistence)
        // 2. Check SharedPreferences (local device persistence)
        bool hasCompletedOnboarding = false;
        bool firestoreStatus = false;
        bool sharedPrefsStatus = false;
        
        // First check Firestore (this persists across app reinstalls)
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
              
          if (userDoc.exists && userDoc.data() != null) {
            firestoreStatus = userDoc.data()!['onboardingCompleted'] ?? false;
            hasCompletedOnboarding = firestoreStatus;
            logging.info('Firestore onboarding status check: $firestoreStatus');
          }
          
          // Track Firestore check
          /*MixpanelService.trackEvent('Onboarding Dual Verification Check Performed', properties: {
            'source': 'Firestore',
            'onboarding_completed': firestoreStatus,
            'document_exists': userDoc.exists,
            'user_id': currentUser.uid,
          });*/
          
        } catch (e) {
          logging.error('Error checking Firestore onboarding status: $e');
          
          // Firestore network/permission error - not sent to Crashlytics
        }
        
        // If not confirmed from Firestore, also check local SharedPreferences as backup
        if (!hasCompletedOnboarding) {
          sharedPrefsStatus = await _progressService.isOnboardingCompleted();
          hasCompletedOnboarding = sharedPrefsStatus;
          logging.info('SharedPreferences onboarding status check: $sharedPrefsStatus');
          
        }
        
        
        // If onboarding is not completed, send to onboarding flow regardless of auth state
        if (!hasCompletedOnboarding) {
          // ADDED: Check subscription status first for non-onboarded users
          final isPaidSubscriber = await _subscriptionService.isPaidSubscriber(currentUser.uid).timeout(
            const Duration(seconds: 3),
            onTimeout: () => false, // Default to free on timeout
          );
          bool hasValidExpiration = false; // Assuming already defined or add if needed

          // SECURITY FIX: Only use RevenueCat/Superwall for access decisions
          // Firebase dates are for analytics only, not gating

          if (isPaidSubscriber) {
            logging.info('User is authenticated, onboarding not confirmed, BUT IS PAID. Navigating to MainScaffold.');
            // Navigation to main app after payment
            targetScreen = const MainScaffold();
            // Mark onboarding as complete now
            await _progressService.markOnboardingComplete(currentUser.uid);
          } else {
            logging.info('User is authenticated, onboarding not confirmed, NOT PAID. Resuming onboarding.');
            // Navigation to onboarding resume
            // Resume from the last saved onboarding screen
            final lastSavedScreenEnum = await _progressService.getCurrentScreen();
            targetScreen = await _getTargetScreenFromProgress(lastSavedScreenEnum);
          }
        } else {
          // Now check subscription status since we know onboarding is complete
          final isPaidSubscriber = await _subscriptionService.isPaidSubscriber(currentUser.uid).timeout(
            const Duration(seconds: 3),
            onTimeout: () => false, // Default to free on timeout
          );
          
          // SECURITY FIX: Only use RevenueCat/Superwall for access decisions
          // Firebase dates are for analytics only, not gating
          if (isPaidSubscriber) {
            // Track subscription status
            // Subscription status check performed
          }
          
          // CRITICAL: Check if user had expired trial and force to gated paywall
          final hadExpiredTrial = await _subscriptionService.hadExpiredTrial(currentUser.uid).timeout(
            const Duration(seconds: 3),
            onTimeout: () => false, // Default to no expired trial on timeout
          );
          
          if (hadExpiredTrial && !isPaidSubscriber) {
            logging.info('User had expired trial - forcing to gated paywall');
            // Navigation to expired trial paywall
            targetScreen = const PrePaywallScreen();
          } else if (isPaidSubscriber) {
            logging.info('User is a paid subscriber or has valid expiration');
            
            // Check if this is the first time opening the app after subscribing
            final prefs = await SharedPreferences.getInstance();
            final isFirstTimeSubscribed = prefs.getBool('first_time_subscribed') ?? false;
            
            // Track first time check
            /*MixpanelService.trackEvent('Subscription First Time Check Performed', properties: {
              'is_first_time': isFirstTimeSubscribed,
              'user_id': currentUser.uid,
            });*/
            
            if (isFirstTimeSubscribed) {
              // First time after subscribing - show congratulations screen
              logging.info('First time after subscribing - showing congratulations screen');
              // Clear the flag so we don't show it again
              await prefs.setBool('first_time_subscribed', false);
              
              // Track navigation decision
              // Navigation to congratulations screen
              
              targetScreen = const CongratulationsScreen1();
            } else {
              // Already subscribed user - go directly to main app
              logging.info('Already subscribed user - going directly to main app');
              await _progressService.markOnboardingComplete(currentUser.uid);
              
              // Track navigation decision
              // Navigation to main app
              
              targetScreen = const MainScaffold();
            }
          } else {
            // User has completed onboarding but is not a paid subscriber
            logging.info('User has completed onboarding but is not subscribed, directing to paywall');
            
            // Track navigation decision
            // Navigation to paywall after onboarding
            
            targetScreen = const PrePaywallScreen();
          }
        }
      } else {
        // If no authenticated user is found, check for debug/TestFlight with widget deep links
        bool isDebugOrTestFlight = kDebugMode;
        try {
          final isTf = await MixpanelService.isTestFlight();
          isDebugOrTestFlight = isDebugOrTestFlight || isTf;
        } catch (_) {}
        
        // Check if we have a pending widget deep link
        final prefs = await SharedPreferences.getInstance();
        final pendingWidgetDeeplink = prefs.getString('pending_widget_deeplink');
        
        if (isDebugOrTestFlight && pendingWidgetDeeplink != null) {
          // Debug/TestFlight user with widget deep link - sign in anonymously and go to MainScaffold
          logging.info('[LogLevel.info] Debug/TestFlight user with widget deep link, auto-signing in');
          
          try {
            await FirebaseAuth.instance.signInAnonymously();
            debugPrint('Debug: Anonymous auth successful for widget deep link');
            targetScreen = const MainScaffold(initialIndex: 0); // Will be handled by WelcomeVideoScreen routing
          } catch (e) {
            debugPrint('Debug: Anonymous auth failed: $e');
            targetScreen = const OnboardingPage();
          }
        } else {
          // Normal flow - start from onboarding
          logging.info('[LogLevel.info] No authenticated user, redirecting to onboarding flow');
          targetScreen = const OnboardingPage();
        }
      }
      
      // If launched via a home widget deep link
      // Respect a native flag to keep the welcome video before routing
      try {
        final prefs = await SharedPreferences.getInstance();
        final widgetDeeplink = prefs.getString('pending_widget_deeplink');
        final forceKeepVideo = prefs.getBool('force_keep_welcome_video') ?? false;

        if (widgetDeeplink != null && !forceKeepVideo) {
          // Go directly to target and clear flags
          await prefs.remove('pending_widget_deeplink');
          await prefs.remove('pending_home_navigation');
          await prefs.remove('force_keep_welcome_video');

          Widget directTarget;
          switch (widgetDeeplink) {
            case 'pledge':
              directTarget = const PledgeScreen();
              break;
            case 'panic':
              directTarget = const WhatHappeningScreen();
              break;
            case 'meditation':
              directTarget = const MeditationScreen();
              break;
            case 'home':
            default:
              directTarget = const MainScaffold(initialIndex: 0);
          }

          setState(() {
            _startScreen = directTarget;
            _isLoading = false;
          });
        } else {
          // Keep the welcome video; it will consume pending flags and route
          setState(() {
            _startScreen = WelcomeVideoScreen(
              nextScreen: targetScreen,
            );
            _isLoading = false;
          });
        }
      } catch (_) {
        // On any error, fall back to welcome video
        setState(() {
          _startScreen = WelcomeVideoScreen(
            nextScreen: targetScreen,
          );
          _isLoading = false;
        });
      }
      
      // Track app startup completion
      /*MixpanelService.trackEvent('App Startup Verification Completed', properties: {
        'stage': 'completed',
        'final_destination': targetScreen.runtimeType.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });*/
      
    } catch (e) {
      debugPrint('Error checking onboarding progress: $e');
      
      // Track error
      /*MixpanelService.trackEvent('App Startup Verification Error', properties: {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });*/
      
      // Fallback to beginning of onboarding via the welcome video
      setState(() {
        _startScreen = WelcomeVideoScreen(
          nextScreen: const OnboardingPage(),
        );
        _isLoading = false;
      });
      
      // Track fallback navigation
      // App navigation decision made - error fallback
    }
  }

  // Get the appropriate screen based on saved progress
  Future<Widget> _getTargetScreenFromProgress(OnboardingScreen? currentScreen) async {
    debugPrint('🔥 Main: _getTargetScreenFromProgress called with: $currentScreen');
    
    if (currentScreen == null) {
      // No saved progress, start from the beginning (the very first screen)
      debugPrint('🔥 Main: No saved screen, returning OnboardingPage');
      return const OnboardingPage();
    }
    
    // Resume from saved progress
    switch (currentScreen) {
      case OnboardingScreen.questionnaireScreen:
        final questionIndex = await _progressService.getQuestionnaireIndex();
        debugPrint('🔥 Main: Returning QuestionnaireScreen with index: $questionIndex');
        return QuestionnaireScreen(
          currentQuestionIndex: questionIndex,
        );
        
      case OnboardingScreen.profileInfoScreen:
        debugPrint('🔥 Main: Returning ProfileInfoScreen');
        return const ProfileInfoScreen();
        
      case OnboardingScreen.symptomsScreen:
        debugPrint('🔥 Main: Returning SymptomsScreen');
        return const SymptomsScreen();
        
      case OnboardingScreen.sugarPainpointsPageView:
        final pageIndex = await _progressService.getPainpointsPageIndex();
        debugPrint('🔥 Main: Returning OnboardingSugarPainpointsPageView with index: $pageIndex');
        return OnboardingSugarPainpointsPageView(
          initialPage: pageIndex,
        );
        
      case OnboardingScreen.benefitsPageView:
        // Restore user to their position in the benefits page view
        final pageIndex = await _progressService.getBenefitsPageIndex();
        debugPrint('🔥 Main: Returning BenefitsPageView with index: $pageIndex');
        return BenefitsPageView(
          initialPage: pageIndex,
        );
        
      case OnboardingScreen.referralCodeScreen:
        debugPrint('🔥 Main: Returning ReferralCodeScreen');
        return const ReferralCodeScreen();
        
      case OnboardingScreen.chooseGoalsScreen:
        debugPrint('🔥 Main: Returning ChooseGoalsOnboardingScreen');
        return const ChooseGoalsOnboardingScreen();
        
      case OnboardingScreen.stopprScienceBackedPlanScreen:
          debugPrint('🔥 Main: Returning StopprScienceBackedPlanScreen');
        return const StopprScienceBackedPlanScreen();
        
      case OnboardingScreen.weeksProgressionScreen:
        debugPrint('🔥 Main: Returning WeeksProgressionScreen');
        return const WeeksProgressionScreen();
        
      case OnboardingScreen.letterFromFutureScreen:
        debugPrint('🔥 Main: Returning LetterFromFutureScreen');
        return const LetterFromFutureScreen();
        
      case OnboardingScreen.readTheVowScreen:
        debugPrint('🔥 Main: Returning ReadTheVowScreen');
        return const ReadTheVowScreen();
        
      case OnboardingScreen.prePaywallScreen:
        debugPrint('🔥 Main: Returning PrePaywallScreen');
        return const PrePaywallScreen();
        
      case OnboardingScreen.analysisResultScreen:
        debugPrint('🔥 Main: Returning AnalysisResultScreen');
        return const AnalysisResultScreen();
        
      case OnboardingScreen.giveUsRatingsScreen:
        debugPrint('🔥 Main: Returning GiveUsRatingsScreen');
        return const GiveUsRatingsScreen();
        
      case OnboardingScreen.benefitsImpactScreen:
        debugPrint('🔥 Main: Returning BenefitsImpactScreen');
        return const BenefitsImpactScreen();
        
      case OnboardingScreen.onboardingScreen4:
        debugPrint('🔥 Main: Returning OnboardingScreen4');
        return const OnboardingScreen4();
      
      case OnboardingScreen.welcomeVideoScreen:
        debugPrint('🔥 Main: Returning OnboardingPage for welcomeVideoScreen');
        return const OnboardingPage();
        
      case OnboardingScreen.consumptionSummaryScreen:
        // For consumption summary, we need to return to the questionnaire
        // at the appropriate index (question 4)
        debugPrint('🔥 Main: Returning QuestionnaireScreen for consumptionSummaryScreen');
        return QuestionnaireScreen(
          currentQuestionIndex: 4,
        );
        
      case OnboardingScreen.insightsScreen:
        // For insights screen, we need to return to the questionnaire
        // at the appropriate index (after consumption summary)
        debugPrint('🔥 Main: Returning QuestionnaireScreen for insightsScreen');
        return QuestionnaireScreen(
          currentQuestionIndex: 5,
        );
        
      case OnboardingScreen.mainAppReady:
        // User has completed onboarding
        debugPrint('🔥 Main: Returning MainScaffold for mainAppReady');
        return const MainScaffold();
        
      default:
        // Default fallback to beginning of onboarding
        debugPrint('🔥 Main: Default case, returning OnboardingPage');
        return const OnboardingPage();
    }
  }

  // --- NEW: Function to handle notification opens ---
  void _handleMessageOpened(RemoteMessage message) {
    debugPrint('Message opened from background/terminated: ${message.messageId}');
    debugPrint('Message data: ${message.data}');

    // Removed handlers for winback lifetime and marketing_offer_x_tap
    debugPrint('Tapped notification type not handled: ${message.data['type']}');
  }
  
  // Reusable method for handling notification paywalls
  Future<void> _handleNotificationPaywall({
    required String notificationType,
    required String eventPrefix,
    required String placementName,
    required String triggerSource,
  }) async {
    debugPrint('$eventPrefix notification tapped! Triggering $placementName.');
    try {
      // Create a handler for paywall presentation
      PaywallPresentationHandler handler = PaywallPresentationHandler();
      
      handler.onPresent((paywallInfo) async {
        String? name = await paywallInfo.name;
        debugPrint("Notification Paywall Presented: ${name ?? 'Unknown'}");
      });

      handler.onDismiss((paywallInfo, paywallResult) async {
        String? name = await paywallInfo.name;
        String resultString = paywallResult?.toString() ?? 'null';
        debugPrint("Notification Paywall Dismissed: ${name ?? 'Unknown'}, Result: $resultString");
      });

      handler.onError((error) {
        debugPrint("Notification Paywall Error: $error");
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordError(
            error,
            StackTrace.current,
            reason: '$eventPrefix Notification Paywall Error',
          );
        }
      });

      handler.onSkip((skipReason) async {
        String reasonString = skipReason.toString();
        debugPrint("Notification Paywall Skipped: $reasonString");

        if (skipReason is PaywallSkippedReasonHoldout) {
          debugPrint("Holdout detected (details in skipReason): $reasonString");
        }
      });

      // Register placement with a feature callback to mirror pre_paywall updates
      await Superwall.shared.registerPlacement(
        placementName,
        handler: handler,
        feature: () async {
          await PostPurchaseHandler.handlePostPurchase(context);
        },
      );
      
      debugPrint('$eventPrefix Notification Push Tapped: register_placement_$placementName');
    } catch (e) {
       debugPrint('Error triggering Superwall from push tap: $e');
       if (!kDebugMode) {
         FirebaseCrashlytics.instance.recordError(
           e,
           StackTrace.current,
           reason: 'Notification Push Tap Error',
           information: ['notification_type: $notificationType'],
         );
       }
    }
  }
  
  // Helper method to detect TestFlight environment
  Future<bool> _isRunningInTestFlight() async {
    try {
      // Static channel for environment checks
      const methodChannel = MethodChannel('com.stoppr.app/environment');
      
      // Direct check for TestFlight environment
      if (Platform.isIOS) {
        final result = await methodChannel.invokeMethod<bool>('isTestFlight');
        final isTestFlight = result ?? false;
        debugPrint('📱 Is TestFlight build (direct check): $isTestFlight');
        return isTestFlight;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking TestFlight status: $e');
      // Default to false if we can't determine
      return false;
    }
  }

  // Helper method to update Firebase with subscription data
  Future<void> _updateFirebaseSubscriptionWithProductId(String productId) async {
    try {
      debugPrint('🔄 Starting _updateFirebaseSubscriptionWithProductId() with productId: $productId');
      
      // Check if running in TestFlight
      final bool isTestFlight = await _isRunningInTestFlight();
      debugPrint('🧪 Running in TestFlight: $isTestFlight');
      
      // Track the purchase source in Mixpanel
      MixpanelService.trackEvent('Subscription Purchase Confirmed', 
        properties: {
          'product_id': productId,
          'is_testflight': isTestFlight,
          'timestamp': DateTime.now().toIso8601String()
        }
      );
      
      // Check if there's a signed-in user
      var uid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('🔍 Current user ID: ${uid ?? "NULL - No user found"}');
      
      // If no user exists, create an anonymous account
      if (uid == null) {
        debugPrint('🔒 No user found. Creating anonymous account...');
        try {
          // Force sign out first to ensure clean state
          try {
            await FirebaseAuth.instance.signOut();
            debugPrint('✅ Forced sign out before creating anonymous user');
          } catch (e) {
            debugPrint('⚠️ Error during forced sign out: $e');
            // Continue with anonymous sign-in even if sign out fails
          }
          
          // Create anonymous user
          final userCredential = await FirebaseAuth.instance.signInAnonymously();
          uid = userCredential.user?.uid;
          debugPrint('✅ Successfully created anonymous user with ID: ${uid ?? "ERROR - uid still null"}');
          
          // Identify this user with all tracking systems
          if (uid != null) {
            // Identify with Superwall
            await Superwall.shared.identify(uid);
            debugPrint('✅ Identified user with Superwall');
            
            // Create basic user profile in Firestore
            debugPrint('🔄 Creating user profile in Firestore for ID: $uid');
            final appUser = AppUser(
              uid: uid,
              email: '',
              displayName: '',
              providerId: 'anonymous',
              isAnonymous: true,
              createdDuringPayment: true,  // Special flag to track users created during payment
            );
            
            // Save user profile - wait for completion
            final UserRepository userRepository = UserRepository();
            await userRepository.saveUserProfile(appUser);
            debugPrint('✅ Successfully created user profile in Firestore');
            
            // Verify user document exists in Firestore
            final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
            if (docSnapshot.exists) {
              debugPrint('✅ Verified user document exists in Firestore');
            } else {
              debugPrint('❌ ERROR: User document not found in Firestore after creation!');
            }
          } else {
            debugPrint('❌ ERROR: Anonymous user creation succeeded but uid is null!');
          }
        } catch (e) {
          debugPrint('❌ Error creating anonymous user: $e');
        }
      }
      
      // Proceed only if we have a valid uid
      if (uid != null) {
        final now = DateTime.now();
        final subscriptionStartDate = now;
        
        // Determine subscription type and expiration date based on product ID
        SubscriptionType subscriptionType;
        DateTime subscriptionExpirationDate;
        
        // Get base product ID if it's in the new format (platformID:baseID)
        String baseProductId = productId;
        if (productId.contains(':')) {
          baseProductId = productId.split(':')[0];
          debugPrint('📱 Using base product ID for subscription detection: $baseProductId');
        }
        
      // Customize subscription details based on product ID
      if (baseProductId.toLowerCase().contains('lifetime') || 
          baseProductId == 'com.stoppr.lifetime' ||
          baseProductId == 'com.stoppr.sugar.lifetime') {
        // For lifetime purchases - no expiration
        subscriptionType = SubscriptionType.paid_lifetime;
        // Lifetime: No expiration needed (one-time purchase)
        subscriptionExpirationDate = now; // Will not be stored for lifetime
        debugPrint('📅 Setting LIFETIME purchase - no expiration date');
      } else if (baseProductId.toLowerCase().contains('annual80off') ||
            baseProductId.toLowerCase() == 'sugar.app.annual80off') {
          // For the 80% off annual plan
          subscriptionType = SubscriptionType.paid_gift;
          // Annual: current date + 1 year
          subscriptionExpirationDate = DateTime(
            now.year + 1, 
            now.month, 
            now.day, 
            now.hour, 
            now.minute, 
            now.second
          );
          debugPrint('📅 Setting GIFT annual subscription - Expiring in 1 year');
        } else if (baseProductId.toLowerCase().contains('.exp1') ||
            baseProductId.toLowerCase().contains('.exp2')) {
          // For expensive annual subscriptions
          subscriptionType = SubscriptionType.paid_standard;
          // Annual: current date + 1 year
          subscriptionExpirationDate = DateTime(
            now.year + 1, 
            now.month, 
            now.day, 
            now.hour, 
            now.minute, 
            now.second
          );
          debugPrint('📅 Setting EXPENSIVE ANNUAL subscription - Expiring in 1 year');
        } else if (baseProductId.toLowerCase().contains('33off')) {
          // For the 33% off plan
          subscriptionType = SubscriptionType.paid_standard;
          // Annual: current date + 1 year
          subscriptionExpirationDate = DateTime(
            now.year + 1, 
            now.month, 
            now.day, 
            now.hour, 
            now.minute, 
            now.second
          );
          debugPrint('📅 Setting STANDARD 33% OFF subscription - Expiring in 1 year');
        } else if (baseProductId.toLowerCase().contains('cheap')) {
          // Youth subscriptions (age < 24)
          subscriptionType = SubscriptionType.paid_standard_cheap;
          if (baseProductId.toLowerCase().contains('annual')) {
            subscriptionExpirationDate = DateTime(
              now.year + 1, 
              now.month, 
              now.day, 
              now.hour, 
              now.minute, 
              now.second
            );
            debugPrint('📅 Setting YOUTH CHEAP annual subscription - Expiring in 1 year');
          } else if (baseProductId.toLowerCase().contains('monthly')) {
            subscriptionExpirationDate = DateTime(
              now.year, 
              now.month + 1, 
              now.day, 
              now.hour, 
              now.minute, 
              now.second
            );
            debugPrint('📅 Setting YOUTH CHEAP monthly subscription - Expiring in 1 month');
          } else if (baseProductId.toLowerCase().contains('weekly')) {
            subscriptionExpirationDate = now.add(const Duration(days: 7));
            debugPrint('📅 Setting YOUTH CHEAP weekly subscription - Expiring in 7 days');
          } else {
            // Default cheap to annual
            subscriptionExpirationDate = DateTime(
              now.year + 1, 
              now.month, 
              now.day, 
              now.hour, 
              now.minute, 
              now.second
            );
            debugPrint('📅 Setting YOUTH CHEAP default (annual) subscription - Expiring in 1 year');
          }
        } else if (baseProductId.toLowerCase().contains('trial')) {
        // For trial annual plans
        subscriptionType = SubscriptionType.paid_standard;
        // Annual: current date + 1 year
        subscriptionExpirationDate = DateTime(
          now.year + 1, 
          now.month, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting TRIAL annual subscription - Expiring in 1 year');
        } else if (baseProductId.toLowerCase().contains('annual')) {
        // For regular annual plans
        subscriptionType = SubscriptionType.paid_standard;
        // Annual: current date + 1 year
        subscriptionExpirationDate = DateTime(
          now.year + 1, 
          now.month, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting STANDARD annual subscription - Expiring in 1 year');
        } else if (baseProductId.toLowerCase().contains('monthly')) {
          // For monthly plans
          subscriptionType = SubscriptionType.paid_standard;
          // Monthly: current date + 1 month
          subscriptionExpirationDate = DateTime(
            now.year, 
            now.month + 1, 
            now.day, 
            now.hour, 
            now.minute, 
            now.second
          );
          debugPrint('📅 Setting STANDARD monthly subscription - Expiring in 1 month');
        } else if (baseProductId.toLowerCase().contains('weekly')) {
          // For weekly plans
          subscriptionType = SubscriptionType.paid_standard;
          // Weekly: current date + 7 days
          subscriptionExpirationDate = now.add(const Duration(days: 7));
          debugPrint('📅 Setting STANDARD weekly subscription - Expiring in 7 days');
        } else {
          // Default to standard annual if unknown
          subscriptionType = SubscriptionType.paid_standard;
          subscriptionExpirationDate = DateTime(
            now.year + 1, 
            now.month, 
            now.day, 
            now.hour, 
            now.minute, 
            now.second
          );
          debugPrint('📅 Setting DEFAULT subscription for unknown product ID - Expiring in 1 year');
        }
        
        debugPrint('📅 Subscription details - Product: $productId, Type: $subscriptionType, Start: $subscriptionStartDate, Expiration: $subscriptionExpirationDate');
        
        // Create the subscription data with TestFlight flag when appropriate
        Map<String, dynamic> subscriptionData = {
          'subscriptionStatus': subscriptionType.toString(),
          'subscriptionProductId': productId,
          'subscriptionStartDate': subscriptionStartDate,
          'subscriptionExpirationDate': subscriptionExpirationDate,
          'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
        };
        
        // Add trial expiration date for trial subscriptions (3 days from start)
        if (baseProductId.toLowerCase().contains('trial')) {
          final DateTime trialStartDate = subscriptionStartDate;
          final DateTime trialExpirationDate = trialStartDate.add(const Duration(days: 3));
          final DateTime actualSubscriptionStartDate = trialExpirationDate; // Subscription starts when trial ends
          
          subscriptionData['trialExpirationDate'] = trialExpirationDate;
          subscriptionData['isTrialActive'] = true;
          subscriptionData['trialConvertedToPaid'] = false;
          
          // Override subscription start date for trial (starts in 3 days)
          subscriptionData['subscriptionStartDate'] = actualSubscriptionStartDate;
          // Extend expiration date by 3 days since subscription starts later
          subscriptionData['subscriptionExpirationDate'] = DateTime(
            now.year + 1, 
            now.month, 
            now.day + 3, // Add 3 extra days
            now.hour, 
            now.minute, 
            now.second
          );
          
          debugPrint('📅 Trial period: ${trialStartDate.toIso8601String()} to ${trialExpirationDate.toIso8601String()}');
          debugPrint('📅 Paid subscription will start: ${actualSubscriptionStartDate.toIso8601String()}');
        }
        
        // Add TestFlight flag if needed
        if (isTestFlight) {
          subscriptionData['isTestFlightPurchase'] = true;
        }
        
        // Update Firestore directly to include all fields
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(subscriptionData, SetOptions(merge: true));
            
        // Also use the SubscriptionService to ensure all standard fields are updated
        final SubscriptionService subscriptionService = SubscriptionService();
        
        // Calculate trial expiration date for trial subscriptions
        DateTime? trialExpirationDate;
        DateTime finalSubscriptionStartDate = subscriptionStartDate;
        DateTime finalSubscriptionExpirationDate = subscriptionExpirationDate;
        
        if (baseProductId.toLowerCase().contains('trial')) {
          final DateTime trialStartDate = subscriptionStartDate;
          trialExpirationDate = trialStartDate.add(const Duration(days: 3));
          finalSubscriptionStartDate = trialExpirationDate; // Subscription starts when trial ends
          finalSubscriptionExpirationDate = trialStartDate.add(const Duration(days: 365 + 3)); // 1 year + 3 trial days
        }
        
        await subscriptionService.updateSubscriptionStatus(
          uid, 
          subscriptionType,
          productId: productId,
          startDate: finalSubscriptionStartDate,
          expirationDate: finalSubscriptionExpirationDate,
          trialExpirationDate: trialExpirationDate
        );
        
        debugPrint('📱 Updated Firebase: User granted subscription ($productId, type: $subscriptionType, TestFlight: $isTestFlight)');
      } else {
        debugPrint('❌ ERROR: Failed to get or create user ID for subscription storage');
      }
    } catch (e, stack) {
      debugPrint('⚠️ Error updating Firebase: $e');
      debugPrint('Stack trace: $stack');
    }
  }
  
  // Security check for unauthorized premium access
  Future<void> _checkForUnauthorizedSubscriptionAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Run the security check using our new method
        await _subscriptionService.checkForUnauthorizedAccess(user.uid);
        logging.info('Completed security check for unauthorized premium access');
      } catch (e) {
        logging.error('Error running security check: $e');
      }
    }
  }

  // Method to change locale
  void _setLocale(Locale locale) async {
    if (_currentLocale != locale) {
      debugPrint('🌐 Changing locale from ${_currentLocale.languageCode} to ${locale.languageCode}');
      
      try {
        // First, update the UI state
        if (mounted) {
          setState(() {
            _currentLocale = locale;
          });
          debugPrint('✅ UI locale updated to: ${locale.languageCode}');
        } else {
          debugPrint('⚠️ Widget not mounted, skipping UI locale update');
          return;
        }
        
        // Then save to SharedPreferences
        await _saveLocale(locale);
        
        debugPrint('✅ Locale change completed successfully');
        
      } catch (e) {
        debugPrint('❌ Error in _setLocale: $e');
        // Revert the UI state if saving failed
        if (mounted) {
          setState(() {
            _currentLocale = _currentLocale; // This will trigger a rebuild
          });
          MixpanelService.trackEvent('Locale Language Change Error', properties: {
            'error': e.toString(),
            'attempted_language': locale.languageCode,
          });
        } else {
          debugPrint('⚠️ Widget not mounted, skipping UI locale revert and error tracking');
        }
      }
    } else {
      debugPrint('ℹ️ Locale change requested but already set to: ${locale.languageCode}');
    }
  }

  // Load locale from SharedPreferences
  Future<void> _loadLocale() async {
    Locale localeToSet = const Locale('en'); // Default to English
    const supportedLanguages = ['en', 'es', 'de', 'zh', 'ru', 'fr', 'sk', 'cs', 'pl', 'it'];
    
    try {
      debugPrint('🌐 Loading locale...');
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString('languageCode');

      if (savedLanguageCode != null && savedLanguageCode.isNotEmpty) {
        // User has previously selected a language
        if (supportedLanguages.contains(savedLanguageCode)) {
          debugPrint('✅ Found saved locale: $savedLanguageCode');
          localeToSet = Locale(savedLanguageCode);
     
        } else {
          debugPrint(
              '⚠️ Unsupported saved language: $savedLanguageCode, using default (en)');
  
        }
      } else {
        // No saved preference, use system locale
        debugPrint('ℹ️ No saved locale found, checking system locale...');
        
        // Get system locale
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
        final systemLanguageCode = systemLocale.languageCode;
        
        debugPrint('📱 System locale detected: $systemLanguageCode');
        
        if (supportedLanguages.contains(systemLanguageCode)) {
          debugPrint('✅ Using system locale: $systemLanguageCode');
          localeToSet = Locale(systemLanguageCode);
          // Save it for next time
          await prefs.setString('languageCode', systemLanguageCode);
         
        } else {
          debugPrint('⚠️ System locale $systemLanguageCode not supported, using English');
          // Save English as default
          await prefs.setString('languageCode', 'en');
          
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading locale: $e');
      debugPrint('Stack trace: $stackTrace');
      
    } finally {
      // This block ensures the state is updated regardless of success or failure.
      _currentLocale = localeToSet;
      if (mounted) {
        setState(() {
          // The instance variable `_currentLocale` is already updated.
          // This empty setState call just tells Flutter to repaint the widget.
        });
      }
      debugPrint('✅ Locale successfully set to: ${localeToSet.languageCode}');
    }
  }

  // Save locale to SharedPreferences
  Future<void> _saveLocale(Locale locale) async {
    try {
      debugPrint('🌐 Saving locale: ${locale.languageCode}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('languageCode', locale.languageCode);
      
      // Verify the save was successful
      final savedLanguageCode = prefs.getString('languageCode');
      if (savedLanguageCode == locale.languageCode) {
        debugPrint('✅ Locale successfully saved: ${locale.languageCode}');
        // Track successful locale change
        MixpanelService.trackEvent('Language Changed Successfully', properties: {
          'new_language': locale.languageCode,
          'verification_passed': true,
        });
      } else {
        debugPrint('❌ Locale save verification failed. Expected: ${locale.languageCode}, Got: $savedLanguageCode');
        MixpanelService.trackEvent('Locale Save Verification Failed', properties: {
          'expected_language': locale.languageCode,
          'actual_saved': savedLanguageCode ?? 'null',
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving locale: $e');
      debugPrint('Stack trace: $stackTrace');
      // Track this error for debugging
      MixpanelService.trackEvent('Locale Saving Error', properties: {
        'error': e.toString(),
        'attempted_language': locale.languageCode,
      });
      rethrow; // Re-throw so the UI can handle it
    }
  }

  @override
  void willRedeemLink() {
    // Optional: track or log that a redemption is about to occur
    logging.info('Superwall willRedeemLink called');
  }

  @override
  void didRedeemLink(RedemptionResult result) {
    // Optional: track redemption result
    logging.info('Superwall didRedeemLink: ${result.toString()}');
  }

  // --- START NEW ---
  void _setupPromoCodeListener() {
    _promoCodeSubscription = AppsFlyerService().promoCodeStream.listen((promoData) {
      debugPrint(
          "[MyAppState] Promo code data received from AppsFlyerService: ${promoData.promoCode}, media source: ${promoData.mediaSource}");
      _applyPromoFromDeepLink(
        promoData.mediaSource ?? 'unknown_appsflyer_sdk_source',
        promoData.promoCode,
      );
    });
  }
  // --- END NEW ---

  // Helper method to show Don't Delete Me paywall
  Future<void> _showDontDeleteMePaywall() async {
    try {
      debugPrint('🎁 Showing Don\'t Delete Me paywall directly');
      
      // Clear the pending action first
      _quickActionsService.clearPendingAction();
      
      // Track the event
      // Don't Delete Me action triggered
      
      // Create handler for the paywall
      final handler = PaywallPresentationHandler();
      
      handler.onPresent((paywallInfo) async {
        final name = await paywallInfo.name;
        debugPrint('🎁 Quick Actions Paywall Presented: ${name ?? "unknown"}');
      });
      
      handler.onDismiss((paywallInfo, paywallResult) async {
        final resultString = paywallResult?.toString() ?? 'null';
        final name = await paywallInfo.name;
        debugPrint('🎁 Quick Actions Paywall Dismissed: ${name ?? "unknown"}, Result: $resultString');
      });
      
      handler.onError((error) {
        debugPrint('❌ Quick Actions Paywall Error: $error');
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordError(
            error,
            StackTrace.current,
            reason: 'Quick Actions Paywall Error',
          );
        }
      });
      
      // Register the placement and trigger it immediately
      await Superwall.shared.registerPlacement(
        'INSERT_YOUR_GIFT_STEP_2_PLACEMENT_ID_HERE',
        handler: handler,
        feature: () async {
          debugPrint('🎁 Don\'t Delete Me feature callback triggered');
          
          // Determine the actual purchased product ID using RevenueCat
          String purchasedProductId = Platform.isIOS 
              ? 'com.stoppr.app.annual80OFF' 
              : 'com.stoppr.sugar.app.annual80off:annual80off';
          
          try {
            debugPrint('✅ gift_step_2: Fetching CustomerInfo from RevenueCat...');
            CustomerInfo customerInfo = await Purchases.getCustomerInfo();
            
            // Define the expected product IDs
            final String annual80offId = Platform.isIOS ? 'com.stoppr.app.annual80OFF' : 'com.stoppr.sugar.app.annual80off:annual80off';
            final String annualId = Platform.isIOS ? 'com.stoppr.app.annual' : 'com.stoppr.sugar.app.annual:com-stoppr-sugar-app-annual';
            final String monthlyId = Platform.isIOS ? 'com.stoppr.app.monthly' : 'com.stoppr.sugar.app.monthly:com-stoppr-app-sugar-monthly';
            final String annualExp1Id = Platform.isIOS ? 'com.stoppr.app.annual.exp1' : 'com.stoppr.sugar.app.annual.exp1:com-stoppr-sugar-app-annual-exp1';
            final String annualExp2Id = Platform.isIOS ? 'com.stoppr.app.annual.exp2' : 'com.stoppr.sugar.app.annual.exp2:com-stoppr-sugar-app-annual-exp2';
            
            // Check active subscriptions
            if (customerInfo.activeSubscriptions.contains(annual80offId)) {
              purchasedProductId = annual80offId;
              debugPrint('✅ gift_step_2: Detected 80% OFF purchase');
            } else if (customerInfo.activeSubscriptions.contains(annualExp2Id)) {
              purchasedProductId = annualExp2Id;
              debugPrint('✅ gift_step_2: Detected EXPENSIVE ANNUAL 2 purchase');
            } else if (customerInfo.activeSubscriptions.contains(annualExp1Id)) {
              purchasedProductId = annualExp1Id;
              debugPrint('✅ gift_step_2: Detected EXPENSIVE ANNUAL 1 purchase');
            } else if (customerInfo.activeSubscriptions.contains(annualId)) {
              purchasedProductId = annualId;
              debugPrint('✅ gift_step_2: Detected ANNUAL purchase');
            } else if (customerInfo.activeSubscriptions.contains(monthlyId)) {
              purchasedProductId = monthlyId;
              debugPrint('✅ gift_step_2: Detected MONTHLY purchase');
            }
          } catch (e) {
            debugPrint('❌ gift_step_2: Error fetching CustomerInfo: $e');
          }
          
          // Update Firebase subscription and start streak
          await _updateFirebaseForGiftPurchase(purchasedProductId);
          
          // Navigate to congratulations screen after successful purchase
          if (mounted && navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const CongratulationsScreen1(),
              ),
              (_) => false,
            );
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error showing Don\'t Delete Me paywall: $e');
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Quick Actions Paywall Show Error',
        );
      }
    }
  }
  
  /// Update Firebase with subscription data after gift purchase
  Future<void> _updateFirebaseForGiftPurchase(String productId) async {
    try {
      debugPrint('🔄 gift_step_2: Starting Firebase update with productId: $productId');
      
      final uid = FirebaseAuth.instance.currentUser?.uid;
      
      if (uid == null) {
        debugPrint('❌ gift_step_2: User ID is null');
        return;
      }
      
      debugPrint('🔍 gift_step_2: Current user ID: $uid');
      
      final now = DateTime.now();
      final subscriptionStartDate = now;
      
      // Determine subscription type and expiration date based on product ID
      SubscriptionType subscriptionType;
      DateTime subscriptionExpirationDate;
      
      // Get base product ID
      String baseProductId = productId;
      if (productId.contains(':')) {
        baseProductId = productId.split(':')[0];
      }
      
      // Gift purchases are typically 80% off annual
      if (baseProductId.toLowerCase().contains('annual80off') || baseProductId.toLowerCase().contains('80off')) {
        subscriptionType = SubscriptionType.paid_gift;
        subscriptionExpirationDate = DateTime(now.year + 1, now.month, now.day, now.hour, now.minute, now.second);
      } else if (baseProductId.toLowerCase().contains('.exp1') || baseProductId.toLowerCase().contains('.exp2')) {
        subscriptionType = SubscriptionType.paid_standard;
        subscriptionExpirationDate = DateTime(now.year + 1, now.month, now.day, now.hour, now.minute, now.second);
      } else if (baseProductId.toLowerCase().contains('cheap')) {
        // Youth subscriptions (age < 24)
        subscriptionType = SubscriptionType.paid_standard_cheap;
        if (baseProductId.toLowerCase().contains('annual')) {
          subscriptionExpirationDate = DateTime(now.year + 1, now.month, now.day, now.hour, now.minute, now.second);
        } else if (baseProductId.toLowerCase().contains('monthly')) {
          subscriptionExpirationDate = DateTime(now.year, now.month + 1, now.day, now.hour, now.minute, now.second);
        } else if (baseProductId.toLowerCase().contains('weekly')) {
          subscriptionExpirationDate = now.add(const Duration(days: 7));
        } else {
          // Default cheap to annual
          subscriptionExpirationDate = DateTime(now.year + 1, now.month, now.day, now.hour, now.minute, now.second);
        }
      } else if (baseProductId.toLowerCase().contains('annual')) {
        subscriptionType = SubscriptionType.paid_standard;
        subscriptionExpirationDate = DateTime(now.year + 1, now.month, now.day, now.hour, now.minute, now.second);
      } else if (baseProductId.toLowerCase().contains('monthly')) {
        subscriptionType = SubscriptionType.paid_standard;
        subscriptionExpirationDate = DateTime(now.year, now.month + 1, now.day, now.hour, now.minute, now.second);
      } else {
        // Default to gift annual
        subscriptionType = SubscriptionType.paid_gift;
        subscriptionExpirationDate = DateTime(now.year + 1, now.month, now.day, now.hour, now.minute, now.second);
      }
      
      debugPrint('📅 gift_step_2: Subscription details - Product: $productId, Type: $subscriptionType, Start: $subscriptionStartDate, Expiration: $subscriptionExpirationDate');
      
      // Update user subscription status
      await _userRepository.updateUserSubscriptionStatus(
        uid, 
        subscriptionType,
        productId: productId,
        startDate: subscriptionStartDate,
        expirationDate: subscriptionExpirationDate
      );
      
      // Initialize streak - StreakService handles SharedPreferences, Firestore, and widget
      final streakService = StreakService();
      await streakService.setCustomStreakStartDate(now);
      debugPrint('✅ gift_step_2: Streak auto-started for paid user: $now');
      
      debugPrint('📱 gift_step_2: Updated Firebase successfully');
    } catch (e, stack) {
      debugPrint('⚠️ gift_step_2: Error updating Firebase: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  // Helper method to set Superwall attributes for current user on app startup
  Future<void> _setSuperwallAttributesForCurrentUser(String userId) async {
    try {
      // Load user data from repository
      final userData = await _userRepository.getUserProfile(userId);
      
      // Also try SharedPreferences as fallback
      final prefs = await SharedPreferences.getInstance();
      
      // Get values from Firestore or SharedPreferences fallback
      final firstName = userData?['firstName'] ?? prefs.getString('user_first_name');
      final age = userData?['age'] ?? prefs.getString('user_age');
      final gender = userData?['gender'] ?? prefs.getString('user_gender');
      final email = userData?['email'] ?? prefs.getString('user_email');
      
      // Set Superwall attributes if we have any data
      if (firstName != null || age != null || gender != null || email != null) {
        await SuperwallUtils.setUserAttributes(
          firstName: firstName,
          age: age,
          gender: gender,
          email: email,
        );
        debugPrint('✅ Set Superwall attributes for existing user on startup');
      } else {
        debugPrint('ℹ️ No user profile data found for setting Superwall attributes');
      }
    } catch (e) {
      debugPrint('❌ Error setting Superwall attributes for current user: $e');
    }
  }

  // Consume saved local-notification payload (from NotificationService._processNotificationPayload)
  Future<void> _processPendingNotificationPayload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool pending = prefs.getBool('notification_pending_processing') ?? false;
      if (!pending) return;
      final String? payload = prefs.getString('last_notification_payload');
      if (payload == null || payload.isEmpty) {
        await prefs.remove('notification_pending_processing');
        await prefs.remove('last_notification_payload');
        return;
      }
      debugPrint('Processing pending notification payload: $payload');

      // Map payloads to placements or actions
      if (payload == 'notification_push_trial') {
        // Gated paywall flows
        const String placement = 'INSERT_YOUR_NOTIFICATION_TRIAL_PLACEMENT_ID_HERE';
        final handler = PaywallPresentationHandler();
        await Superwall.shared.registerPlacement(placement, handler: handler);
        debugPrint('Registered placement for payload: $payload → $placement (⚠️ Replace INSERT_YOUR_*_PLACEMENT_ID_HERE with your actual placement IDs)');
      } else if (payload == 'gift_step_1') {
        const String placement = 'INSERT_YOUR_GIFT_STEP_1_PLACEMENT_ID_HERE';
        final handler = PaywallPresentationHandler();
        await Superwall.shared.registerPlacement(placement, handler: handler);
        debugPrint('Registered placement for payload: $payload → $placement (⚠️ Replace INSERT_YOUR_*_PLACEMENT_ID_HERE with your actual placement IDs)');
      }
      // marketing_offer_x_tap removed per request; other payloads are ignored

      // Clear flags after handling
      await prefs.remove('notification_pending_processing');
      await prefs.remove('last_notification_payload');
    } catch (e) {
      debugPrint('Error processing pending notification payload: $e');
    }
  }

}

// Temporary HomePage widget - replace with your actual home page
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
    Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Home Page',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navigate to the Superwall demo screen
                Navigator.of(context).pushNamed('/home');
              },
              child: const Text('Go to Superwall Demo'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // Reset ALL preferences and restart app flow for testing
                SharedPreferences.getInstance().then((prefs) {
                  prefs.clear(); // Clear all preferences
                  Navigator.of(context).pushReplacementNamed('/');
                });
              },
              child: const Text('Reset to First Screen'),
            ),
          ],
        ),
      ),
    );
  }
}