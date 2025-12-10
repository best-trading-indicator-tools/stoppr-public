import 'package:flutter_dotenv/flutter_dotenv.dart';

/// A utility class to access environment variables
class EnvConfig {
  /// Get the value of an environment variable
  static String? get(String key) => dotenv.env[key];
  
  /// Get the Superwall iOS API key
  static String? get superwallIOSApiKey => dotenv.env['SUPERWALL_IOS_API_KEY'];
  
  /// Get the Superwall Android API key
  static String? get superwallAndroidApiKey => dotenv.env['SUPERWALL_ANDROID_API_KEY'];
  
  /// Get the RevenueCat iOS API key
  static String? get revenueCatIOSApiKey => dotenv.env['REVENUECAT_IOS_API_KEY'];
  
  /// Get the RevenueCat Android API key
  static String? get revenueCatAndroidApiKey => dotenv.env['REVENUECAT_ANDROID_API_KEY'];

  /// Get the Mixpanel API key
  static String? get mixpanelApiKey => dotenv.env['MIXPANEL_API_KEY'];
  
  /// Get the Crisp Website ID
  static String? get crispWebsiteId => dotenv.env['CRISP_WEBSITE_ID'];
  
  /// Get the OpenAI API key
  static String? get openaiApiKey => dotenv.env['OPENAI_API_KEY'];

  /// Get the Groq API key
  static String? get groqApiKey => dotenv.env['GROQ_API_KEY'];

  /// Get the Replicate API token
  static String? get replicateApiToken => dotenv.env['REPLICATE_API_TOKEN'];

  /// Get the AppsFlyer App ID
  static String? get appsflyerAppId => dotenv.env['APPSFLYER_APP_ID'];

  /// Get the AppsFlyer Dev Key
  static String? get appsflyerDevKey => dotenv.env['APPSFLYER_DEV_KEY'];

  /// Get the AppsFlyer OneLink Template ID
  static String? get appsflyerOneLinkTemplate => dotenv.env['APPSFLYER_ONELINK_TEMPLATE'];

  /// Get Firebase Android API Key
  static String? get firebaseAndroidApiKey => dotenv.env['FIREBASE_ANDROID_API_KEY'];

  /// Get Firebase Android App ID
  static String? get firebaseAndroidAppId => dotenv.env['FIREBASE_ANDROID_APP_ID'];

  /// Get Firebase iOS API Key
  static String? get firebaseIosApiKey => dotenv.env['FIREBASE_IOS_API_KEY'];

  /// Get Firebase iOS App ID
  static String? get firebaseIosAppId => dotenv.env['FIREBASE_IOS_APP_ID'];

  /// Get Firebase iOS Client ID
  static String? get firebaseIosClientId => dotenv.env['FIREBASE_IOS_CLIENT_ID'];

  /// Get Firebase Messaging Sender ID
  static String? get firebaseMessagingSenderId => dotenv.env['FIREBASE_MESSAGING_SENDER_ID'];

  /// Get Firebase Project ID
  static String? get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'];

  /// Get Firebase Storage Bucket
  static String? get firebaseStorageBucket => dotenv.env['FIREBASE_STORAGE_BUCKET'];

  /// Get Edamam API Key
  static String? get edamamApiKey => dotenv.env['EDAMAM_API_KEY'];

  /// Get Edamam App ID
  static String? get edamamAppId => dotenv.env['EDAMAM_APP_ID'];

  /// Get Spoonacular API Key
  static String? get spoonacularApiKey => dotenv.env['SPOONACULAR_API_KEY'];

  /// Get Google OAuth Client ID for iOS
  static String? get googleOAuthClientIdIOS => dotenv.env['GOOGLE_OAUTH_CLIENT_ID_IOS'];

  /// Get Google OAuth Server Client ID for Android
  static String? get googleOAuthServerClientIdAndroid => dotenv.env['GOOGLE_OAUTH_SERVER_CLIENT_ID_ANDROID'];

  /// Check if an environment variable is defined
  static bool has(String key) => dotenv.env.containsKey(key);
} 