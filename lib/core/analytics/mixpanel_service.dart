import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:stoppr/core/config/env_config.dart';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service class for Mixpanel analytics
class MixpanelService {
  static Mixpanel? _instance;
  static MethodChannel get _environmentChannel {
    final String channelName = Platform.isIOS 
        ? 'com.stoppr.app/environment' 
        : 'com.stoppr.sugar.app/environment';
    return MethodChannel(channelName);
  }
  static bool? _isTestFlight;
  static bool? _isGooglePlayInternal;
  static bool _optOut = false;

  /// Get the Mixpanel instance
  static Mixpanel? get instance => _instance;
  
  /// Returns common properties to add to all events
  static Map<String, dynamic> _getCommonProperties() {
    final Map<String, dynamic> props = {
      'Timestamp': DateTime.now().toIso8601String(),
      'Platform': defaultTargetPlatform.toString(),
      'OS': Platform.operatingSystem,
      'OS Version': Platform.operatingSystemVersion,
    };
    
    // Add testing environment info if available
    if (_isTestFlight != null && _isTestFlight!) {
      props['TestEnvironment'] = 'TestFlight';
    } else if (_isGooglePlayInternal != null && _isGooglePlayInternal!) {
      props['TestEnvironment'] = 'GooglePlayInternal';
    }
    
    return props;
  }
  
  /// Allow users to opt out of analytics tracking
  static void optOut(bool optOut) {
    _optOut = optOut;
    
    // Fix: optOutTracking() doesn't accept parameters
    if (optOut) {
      _instance?.optOutTracking();
    } else {
      _instance?.optInTracking();
    }
    
    debugPrint('Mixpanel opt-out status set to: $optOut');
  }
  
  /// Check if the app is running in TestFlight
  static Future<bool> isTestFlight() async {
    if (_isTestFlight != null) {
      return _isTestFlight!;
    }
    
    // TestFlight is iOS-only, always return false for Android
    if (Platform.isAndroid) {
      _isTestFlight = false;
      debugPrint('Running on Android: TestFlight not available');
      return false;
    }
    
    try {
      final result = await _environmentChannel.invokeMethod<bool>('isTestFlight');
      _isTestFlight = result ?? false;
      debugPrint('Running in TestFlight: $_isTestFlight');
      return _isTestFlight!;
    } on PlatformException catch (e) {
      debugPrint('Failed to detect TestFlight environment: ${e.message}');
      return false;
    }
  }
  
  /// Check if the app is running in Google Play Internal Testing
  static Future<bool> isGooglePlayInternal() async {
    if (_isGooglePlayInternal != null) {
      return _isGooglePlayInternal!;
    }
    
    // Google Play Internal Testing is Android-only
    if (Platform.isIOS) {
      _isGooglePlayInternal = false;
      debugPrint('Running on iOS: Google Play Internal Testing not available');
      return false;
    }
    
    try {
      final result = await _environmentChannel.invokeMethod<bool>('isGooglePlayInternal');
      _isGooglePlayInternal = result ?? false;
      debugPrint('Running in Google Play Internal Testing: $_isGooglePlayInternal');
      return _isGooglePlayInternal!;
    } on PlatformException catch (e) {
      debugPrint('Failed to detect Google Play Internal Testing: ${e.message}');
      return false;
    }
  }
  
  /// Check if running in any test environment (TestFlight or Google Play Internal)
  static Future<bool> isTestEnvironment() async {
    if (Platform.isIOS) {
      return await isTestFlight();
    } else if (Platform.isAndroid) {
      return await isGooglePlayInternal();
    }
    return false;
  }

  /// Initialize Mixpanel with the API key from environment variables
  static Future<Mixpanel?> initMixpanel() async {
    if (_instance != null) {
      return _instance;
    }

    try {
      // First check if we're in a test environment
      final bool inTestEnvironment;
      String environmentName;
      
      if (Platform.isIOS) {
        inTestEnvironment = await isTestFlight();
        environmentName = inTestEnvironment ? 'TestFlight' : 'Production';
      } else {
        inTestEnvironment = await isGooglePlayInternal();
        environmentName = inTestEnvironment ? 'GooglePlayInternal' : 'Production';
      }
      
      final apiKey = EnvConfig.mixpanelApiKey;
      if (apiKey == null) {
        debugPrint('Error: Mixpanel API key is missing in .env file');
        return null;
      }
      
      // Initialize with proper options following Mixpanel documentation
      _instance = await Mixpanel.init(
        apiKey, 
        trackAutomaticEvents: true,
        optOutTrackingDefault: false,
      );
      
      // Set a default app opened event
      final Map<String, dynamic> appOpenedProps = {
        'Platform': defaultTargetPlatform.toString(),
        'OS': Platform.operatingSystem,
        'OS Version': Platform.operatingSystemVersion,
        'Environment': environmentName,
      };
      
      _instance!.track('App Opened', properties: appOpenedProps);
      
      // Set environment as a super property to be included in all events
      _instance!.registerSuperProperties({
        'Environment': environmentName,
        'OS': Platform.operatingSystem,
        'OS Version': Platform.operatingSystemVersion,
      });
      
      debugPrint('Mixpanel initialized successfully with environment: $environmentName');
      return _instance;
    } catch (e) {
      debugPrint('Failed to initialize Mixpanel: $e');
      return null;
    }
  }
  
  /// Identify user with Mixpanel
  static void identifyUser(String userId, {
    String? name,
    String? email,
    String? age,
    String? gender,
    Map<String, dynamic>? additionalProperties
  }) {
    if (_instance == null) {
      debugPrint('Cannot identify user: Mixpanel not initialized');
      return;
    }
    
    try {
      debugPrint('Identifying user with Mixpanel: $userId');
      _instance!.identify(userId);
      
      // Set user properties
      if (name != null) {
        _instance!.getPeople().set("\$name", name);
      }
      
      if (email != null) {
        _instance!.getPeople().set("\$email", email);
      }
      
      if (age != null) {
        _instance!.getPeople().set("age", age);
      }
      
      if (gender != null) {
        _instance!.getPeople().set("gender", gender);
      }
      
      // Set any additional properties
      if (additionalProperties != null) {
        additionalProperties.forEach((key, value) {
          _instance!.getPeople().set(key, value);
        });
      }
      
      debugPrint('User identified successfully with Mixpanel');
    } catch (e) {
      debugPrint('Error identifying user with Mixpanel: $e');
    }
  }
  
  /// Synchronize user properties from Firestore to Mixpanel
  static Future<void> syncUserPropertiesFromFirestore(String userId) async {
    if (_instance == null) {
      debugPrint('Cannot sync user properties: Mixpanel not initialized');
      return;
    }
    
    try {
      debugPrint('Syncing user properties from Firestore to Mixpanel for user: $userId');
      
      // Get user data from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      
      if (!userDoc.exists || userDoc.data() == null) {
        debugPrint('User document not found in Firestore: $userId');
        return;
      }
      
      final userData = userDoc.data()!;
      final mixpanelProps = <String, dynamic>{};
      
      // Ensure we identify the user first
      _instance!.identify(userId);
      
      // Map basic properties
      if (userData['firstName'] != null) {
        mixpanelProps['\$name'] = userData['firstName'];
      } else if (userData['displayName'] != null) {
        mixpanelProps['\$name'] = userData['displayName'];
      }
      
      if (userData['email'] != null) {
        mixpanelProps['\$email'] = userData['email'];
      }
      
      // Copy standard properties
      final standardProps = {
        'age': 'age',
        'gender': 'gender',
        'isAnonymous': 'isAnonymous',
        'auth_provider_id': 'auth_provider',
        'os': 'OS',
        'os_version': 'OS Version',
      };
      
      standardProps.forEach((firestore, mixpanel) {
        if (userData[firestore] != null) {
          mixpanelProps[mixpanel] = userData[firestore];
        }
      });
      
      // Ensure OS properties are set even if not in Firestore
      if (!mixpanelProps.containsKey('OS')) {
        mixpanelProps['OS'] = Platform.operatingSystem;
      }
      if (!mixpanelProps.containsKey('OS Version')) {
        mixpanelProps['OS Version'] = Platform.operatingSystemVersion;
      }
      
      // Handle Locale and Country (with fallback to device derivation)
      String? finalLocale = userData['locale'] as String?;
      String? finalCountry = userData['country'] as String?;
      bool updateFirestoreNeeded = false;
      
      if (finalLocale == null || finalLocale.isEmpty) {
        finalLocale = Platform.localeName;
        if (finalLocale.isNotEmpty) {
          mixpanelProps['locale'] = finalLocale;
          updateFirestoreNeeded = true; // Need to save derived locale
        }
      } else {
        mixpanelProps['locale'] = finalLocale;
      }
      
      if (finalCountry == null || finalCountry.isEmpty) {
        if (finalLocale.contains('_') || finalLocale.contains('-')) {
          final separator = finalLocale.contains('_') ? '_' : '-';
          final parts = finalLocale.split(separator);
          if (parts.length > 1 && parts[1].isNotEmpty) {
            finalCountry = parts[1];
            mixpanelProps['country'] = finalCountry;
            updateFirestoreNeeded = true; // Need to save derived country
          }
        }
      } else {
        mixpanelProps['country'] = finalCountry;
      }
      
      // Update Firestore with derived values if needed
      if (updateFirestoreNeeded) {
        Map<String, dynamic> firestoreUpdate = {
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (mixpanelProps.containsKey('locale')) {
          firestoreUpdate['locale'] = mixpanelProps['locale'];
        }
        if (mixpanelProps.containsKey('country')) {
          firestoreUpdate['country'] = mixpanelProps['country'];
        }
        FirebaseFirestore.instance.collection('users').doc(userId).update(firestoreUpdate)
          .catchError((e) => debugPrint('Error updating Firestore with derived locale/country: $e'));
      }
      
      // Handle dates properly
      final dateFields = {
        'createdAt': 'account_creation_date',
        'subscriptionStartDate': 'subscription_start_date',
        'subscriptionExpirationDate': 'subscription_expiration_date',
        'subscriptionUpdatedAt': 'subscription_updated_at',
      };
      
      dateFields.forEach((firestore, mixpanel) {
        if (userData[firestore] != null) {
          // Convert Timestamp to ISO string for better readability in Mixpanel
          final timestamp = userData[firestore] as Timestamp;
          mixpanelProps[mixpanel] = timestamp.toDate().toIso8601String();
        }
      });
      
      // Add subscription details
      if (userData['subscriptionStatus'] != null) {
        mixpanelProps['subscription_status'] = userData['subscriptionStatus'];
      }
      
      if (userData['subscriptionProductId'] != null) {
        mixpanelProps['subscription_product_id'] = userData['subscriptionProductId'];
      }
      
      // Calculate subscription active state
      if (userData['subscriptionStatus'] != null) {
        final String status = userData['subscriptionStatus'] as String;
        final bool isSubscribed = status.contains('paid');
        mixpanelProps['is_subscribed'] = isSubscribed;
      }
      
      // Set properties one by one, not as a map
      mixpanelProps.forEach((key, value) {
        _instance!.getPeople().set(key, value);
      });
      
      debugPrint('Successfully synced user properties from Firestore to Mixpanel: ${mixpanelProps.keys.join(", ")}');
    } catch (e) {
      debugPrint('Error syncing user properties to Mixpanel: $e');
    }
  }
  
  /// Track a custom event
  static void trackEvent(String eventName, {Map<String, dynamic>? properties}) {
    // Skip if user has opted out
    if (_optOut) {
      return;
    }
    
    // Create properties map if not provided
    final props = properties ?? <String, dynamic>{};
    
    // Add common properties
    props.addAll(_getCommonProperties());
    
    // Check if Mixpanel is initialized
    if (_instance == null) {
      debugPrint('⚠️ Mixpanel not initialized, event not tracked: $eventName');
      return;
    }
    
    // Track the event (environment is already included as super property)
    _instance!.track(eventName, properties: props);
    debugPrint('📊 Tracked event: $eventName');
    
    if (kDebugMode) {
      debugPrint('📊 Event properties: $props');
    }
    
    // Refresh TestFlight status for next time if not known
    if (_isTestFlight == null) {
      isTestFlight().then((isTestFlightMode) {
        debugPrint('📊 Updated TestFlight status: $isTestFlightMode');
      });
    }
  }
  
  /// Set a user profile property in Mixpanel
  static void setUserProfileProperty(String propertyName, dynamic value) {
    if (_instance == null) {
      debugPrint('Cannot set user profile property: Mixpanel not initialized');
      return;
    }
    
    // Skip if user has opted out
    if (_optOut) {
      debugPrint('User has opted out of tracking. Property not set: $propertyName');
      return;
    }
    
    try {
      _instance!.getPeople().set(propertyName, value);
      debugPrint('📊 Set user profile property: $propertyName = $value');
    } catch (e) {
      debugPrint('Error setting user profile property $propertyName: $e');
    }
  }
  
  /// Track sign up event
  static void trackSignUp(String signupType) {
    trackEvent('Auth Sign Up Completed', properties: {
      'Signup Type': signupType
    });
  }
  
  /// Track page view event
  static void trackPageView(String pageUrl, {Map<String, dynamic>? additionalProps}) {
    final Map<String, dynamic> properties = {
      'PageUrl': pageUrl,
      'Timestamp': DateTime.now().toIso8601String(),
    };
    
    // Add any additional properties
    if (additionalProps != null) {
      properties.addAll(additionalProps);
    }
    
    // Use a more specific event name that includes the page name
    trackEvent('$pageUrl Page Viewed', properties: properties);
  }
  
  /// Track button tap event
  static void trackButtonTap(String buttonName, {String? screenName, Map<String, dynamic>? additionalProps}) {
    final screenContext = screenName ?? 'Unknown';
    final Map<String, dynamic> properties = {
      'Button': buttonName,
      'Screen': screenContext,
      'Timestamp': DateTime.now().toIso8601String(),
    };
    
    // Add any additional properties
    if (additionalProps != null) {
      properties.addAll(additionalProps);
    }
    
    // Use a more specific event name that includes the button and screen
    trackEvent('$screenContext Button Tap - $buttonName', properties: properties);
  }
  
  /// Track when a notification is scheduled
  static void trackNotificationScheduled(String notificationType, {
    DateTime? scheduledTime, 
    String? title,
    String? audienceType,
    Map<String, dynamic>? additionalProps
  }) {
    final Map<String, dynamic> properties = {
      'notification_type': notificationType,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (scheduledTime != null) {
      properties['scheduled_time'] = scheduledTime.toIso8601String();
    }
    
    if (title != null) {
      properties['title'] = title;
    }
    
    if (audienceType != null) {
      properties['audience_type'] = audienceType;
    }
    
    // Add any additional properties
    if (additionalProps != null) {
      properties.addAll(additionalProps);
    }
    
    trackEvent('Notification Scheduled', properties: properties);
  }
  
  /// Track when a notification is sent immediately (not scheduled)
  static void trackNotificationSent(String notificationType, {
    String? title,
    Map<String, dynamic>? additionalProps
  }) {
    final Map<String, dynamic> properties = {
      'notification_type': notificationType,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (title != null) {
      properties['title'] = title;
    }
    
    // Add any additional properties
    if (additionalProps != null) {
      properties.addAll(additionalProps);
    }
    
    trackEvent('Notification Sent', properties: properties);
  }
  
  /// Track when a notification is tapped by the user
  static void trackNotificationTapped(String notificationType, {
    String? notificationId,
    String? actionId,
    Map<String, dynamic>? additionalProps
  }) {
    final Map<String, dynamic> properties = {
      'notification_type': notificationType,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (notificationId != null) {
      properties['notification_id'] = notificationId;
    }
    
    if (actionId != null) {
      properties['action_id'] = actionId;
    }
    
    // Add any additional properties
    if (additionalProps != null) {
      properties.addAll(additionalProps);
    }
    
    trackEvent('Notification Tapped', properties: properties);
  }
  
  /// Track detailed purchase/billing errors with comprehensive information
  /// This method captures all available error details for better reporting and analysis
  static void trackPurchaseError({
    required String errorType,
    required String errorSource, // e.g., 'PlatformException', 'RestorePurchases', 'SuperwallError'
    String? errorCode,
    String? errorMessage,
    String? errorDetails,
    String? stackTrace,
    String? underlyingError,
    String? userId,
    String? appUserId,
    String? productId,
    String? platform,
    Map<String, dynamic>? additionalContext,
  }) {
    final Map<String, dynamic> properties = {
      'error_type': errorType,
      'error_source': errorSource,
      'timestamp': DateTime.now().toIso8601String(),
      'platform': platform ?? (Platform.isIOS ? 'iOS' : 'Android'),
    };
    
    // Add error details if available
    if (errorCode != null) properties['error_code'] = errorCode;
    if (errorMessage != null) properties['error_message'] = errorMessage;
    if (errorDetails != null) properties['error_details'] = errorDetails;
    if (stackTrace != null) properties['stack_trace'] = stackTrace;
    if (underlyingError != null) properties['underlying_error'] = underlyingError;
    
    // Add user context if available
    if (userId != null) properties['user_id'] = userId;
    if (appUserId != null) properties['app_user_id'] = appUserId;
    
    // Add product context if available
    if (productId != null) properties['product_id'] = productId;
    
    // Add any additional context
    if (additionalContext != null) {
      properties.addAll(additionalContext);
    }
    
    // Track with comprehensive event name for easy filtering
    trackEvent('Purchase_Error_Detailed', properties: properties);
  }
} 