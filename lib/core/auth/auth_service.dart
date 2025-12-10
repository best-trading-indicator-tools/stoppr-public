import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Only import sign_in_with_apple on iOS platform
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'models/app_user.dart';
import '../repositories/user_repository.dart';
import '../analytics/crashlytics_service.dart';
import '../chat/crisp_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/superwall/superwall_purchase_controller.dart';

// Authentication result model
class AuthResult {
  final AppUser? user;
  final String? errorMessage;
  
  bool get isSuccess => user != null && errorMessage == null;

  AuthResult({this.user, this.errorMessage});
}

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();
  
  // Key constants for SharedPreferences
  static const String _notificationsEnabledKey = 'notifications_enabled_key';
  static const String _themeModeKey = 'theme_mode';
  static const String _appTrackingKey = 'app_tracking_enabled';
  
  // Changed from static final to late final to prevent issues during hot reload
  late final GoogleSignIn _googleSignIn = Platform.isIOS 
    ? GoogleSignIn(
        scopes: [
          'email',
          'https://www.googleapis.com/auth/userinfo.profile',
        ],
        clientId: EnvConfig.googleOAuthClientIdIOS ?? 
          'INSERT_YOUR_GOOGLE_OAUTH_CLIENT_ID_IOS_HERE.apps.googleusercontent.com', // Fallback for backward compatibility
      )
    : GoogleSignIn(
        scopes: [
          'email',
          'https://www.googleapis.com/auth/userinfo.profile',
        ],
        // For Android, we need to specify the server clientId to get an idToken
        serverClientId: EnvConfig.googleOAuthServerClientIdAndroid ?? 
          'INSERT_YOUR_GOOGLE_OAUTH_SERVER_CLIENT_ID_ANDROID_HERE.apps.googleusercontent.com', // Fallback for backward compatibility
      );
  
  // Create a broadcast stream controller for auth state changes
  late final StreamController<AppUser?> _authStateController;
  
  // The stream that will be exposed
  late final Stream<AppUser?> _authStream;
  
  // Store the subscription to FirebaseAuth state changes
  StreamSubscription<User?>? _firebaseAuthSubscription;
  
  // Current authenticated user
  AppUser? _currentUser;
  
  // Flag to track if we're currently processing a Google sign-in
  bool _isProcessingGoogleSignIn = false;
  
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  
  // Factory constructor to return the same instance
  factory AuthService() {
    return _instance;
  }
  
  // Private constructor for singleton
  AuthService._internal() {
    debugPrint('🔍 AuthService: Creating new instance');
    _initializeStreams();
  }
  
  void _initializeStreams() {
    // Create a broadcast controller
    _authStateController = StreamController<AppUser?>.broadcast();
    
    // Create and cache the stream
    _authStream = _authStateController.stream;
    
    // Start listening to Firebase auth state changes
    _listenToFirebaseAuth();
    
    // Initialize with current user if available
    final currentFirebaseUser = _firebaseAuth.currentUser;
    if (currentFirebaseUser != null) {
      _currentUser = AppUser.fromFirebaseUser(currentFirebaseUser);
      _authStateController.add(_currentUser);
      
      // Set user ID in Crashlytics
      CrashlyticsService.setUserIdentifier(currentFirebaseUser.uid);
    }
  }
  
  void _listenToFirebaseAuth() {
    // Cancel any existing subscription first
    _firebaseAuthSubscription?.cancel();
    
    // Create a new subscription
    _firebaseAuthSubscription = _firebaseAuth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser != null) {
        _currentUser = AppUser.fromFirebaseUser(firebaseUser);
        // Add to broadcast controller if it's still open
        if (!_authStateController.isClosed) {
          _authStateController.add(_currentUser);
        }
        
        // Set user ID in Crashlytics
        CrashlyticsService.setUserIdentifier(firebaseUser.uid);
        
        // --- START REVENUECAT LOGIN ---
        try {
          // Ensure Purchases is configured before logging in
          if (await Purchases.isConfigured) { 
            // SOFT LOGOUT: Get or create originalAppUserId for RevenueCat
            final prefs = await SharedPreferences.getInstance();
            String? originalAppUserId = prefs.getString('original_app_user_id');
            
            if (originalAppUserId == null) {
              // Create a unique ID that persists across logouts
              originalAppUserId = 'rc_${DateTime.now().millisecondsSinceEpoch}_${firebaseUser.uid.substring(0, 8)}';
              await prefs.setString('original_app_user_id', originalAppUserId);
              debugPrint('🔑 Created new originalAppUserId for RevenueCat: $originalAppUserId');
            } else {
              debugPrint('🔑 Using preserved originalAppUserId for RevenueCat: $originalAppUserId');
            }
            
            await Purchases.logIn(originalAppUserId);
            debugPrint('✅ RevenueCat login successful with originalAppUserId: $originalAppUserId');
            
            // Sync user properties to RevenueCat
            final purchaseController = SuperwallPurchaseController();
            await purchaseController.syncUserPropertiesFromFirestore(firebaseUser.uid);
          } else {
             debugPrint('⚠️ RevenueCat not configured, skipping login.');
          }
        } catch (e) {
          debugPrint('🔴 Error during RevenueCat login: $e');
          // RevenueCat network error - not sent to Crashlytics
        }
        // --- END REVENUECAT LOGIN ---
        
        // --- START MIXPANEL SYNC ---
        try {
          // Sync user properties from Firestore to Mixpanel
          await MixpanelService.syncUserPropertiesFromFirestore(firebaseUser.uid);
        } catch (e) {
          debugPrint('🔴 Error syncing user properties to Mixpanel: $e');
          // Mixpanel network error - not sent to Crashlytics
        }
        // --- END MIXPANEL SYNC ---
        
      } else {
        _currentUser = null;
        // Add null to broadcast controller if it's still open
        if (!_authStateController.isClosed) {
          _authStateController.add(null);
        }
        
        // Clear user ID in Crashlytics
        CrashlyticsService.setUserIdentifier('');
        
        // --- START REVENUECAT LOGOUT ---
        // Only logout if RevenueCat has an identified user (not anonymous)
        try {
           if (await Purchases.isConfigured) {
             final isAnonymous = await Purchases.isAnonymous;
             
             if (!isAnonymous) {
               // User is identified in RevenueCat, safe to logout
               await Purchases.logOut();
               debugPrint('✅ RevenueCat logout successful');
             } else {
               debugPrint('⚠️ RevenueCat user is anonymous, skipping logout.');
             }
           } else {
             debugPrint('⚠️ RevenueCat not configured, skipping logout.');
           }
        } catch (e) {
          debugPrint('🔴 Error during RevenueCat logout: $e');
          // RevenueCat network error - not sent to Crashlytics
        }
        // --- END REVENUECAT LOGOUT ---
      }
    }, onError: (error) {
      debugPrint('❌ Firebase auth stream error: $error');
      // Firebase auth network/temporary error - not sent to Crashlytics
    });
  }

  // Expose the broadcast stream for auth state changes
  Stream<AppUser?> get authStateChanges => _authStream;

  // Get current user
  AppUser? get currentUser => _currentUser;

  // Helper method to save user profile
  Future<void> _saveUserProfile(AppUser user) async {
    try {
      // Determine auth provider from Firebase User context
      String? providerId = user.providerId;
      String? authProviderId;
      
      // Convert to simpler auth_provider_id format
      if (providerId != null) {
        if (providerId.contains('google')) {
          authProviderId = 'google';
        } else if (providerId.contains('apple')) {
          authProviderId = 'apple';
        } else if (providerId.contains('password')) {
          authProviderId = 'email+pwd';
        } else {
          authProviderId = providerId; // Fallback to original
        }
        
        debugPrint('✅ Identified auth provider as: $authProviderId');
      }
      
      // Check if we have email information
      if (user.email.isNotEmpty) {
        // Check if this user already exists in Firestore to avoid unnecessary updates during sign-in
        final docSnapshot = await _userRepository.getUserProfile(user.uid);
        final bool userExists = docSnapshot != null;
        
        // Only update profile for new users or if the user is signing in for the first time
        if (!userExists) {
          debugPrint('✅ New user detected, saving full profile to Firestore for: ${user.uid}');
          // Pass email to UserRepository for correct anonymous status handling
          await _userRepository.updateUserProfile(
            user.uid,
            email: user.email,
            authProviderId: authProviderId,
          );
        } else {
          debugPrint('ℹ️ Existing user signed in, updating auth provider ID: ${user.uid}');
          // For existing users, just update the auth provider info
          if (providerId != null) {
            await _userRepository.updateAuthProvider(user.uid, providerId);
          }
        }
      } else {
        // For users without email, just save the basic profile
        await _userRepository.saveUserProfile(user);
      }
    } catch (e) {
      debugPrint('❌ Error saving user profile: $e');
      // Don't throw the error - we still want the auth to succeed
    }
  }

  // Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    // If already processing a sign in, return early
    if (_isProcessingGoogleSignIn) {
      debugPrint('⚠️ Already processing Google sign-in, ignoring duplicate request');
      return AuthResult(errorMessage: 'Sign in already in progress');
    }
    
    _isProcessingGoogleSignIn = true;
    int retryCount = 0;
    const maxRetries = 2;
    
    try {
      debugPrint('🔍 Starting Google sign-in flow');
      
      // Clear SharedPreferences first and foremost
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Save important settings before clearing
        final notificationsEnabled = prefs.getBool(_notificationsEnabledKey);
        final themeMode = prefs.getString(_themeModeKey);
        final appTrackingEnabled = prefs.getBool(_appTrackingKey);
        
        // Clear all preferences
        await prefs.clear();
        
        // Restore important settings after clearing
        if (notificationsEnabled != null) {
          await prefs.setBool(_notificationsEnabledKey, notificationsEnabled);
        }
        
        if (themeMode != null) {
          await prefs.setString(_themeModeKey, themeMode);
        }
        
        if (appTrackingEnabled != null) {
          await prefs.setBool(_appTrackingKey, appTrackingEnabled);
        }
        
        debugPrint('Cleared all user preferences before Google sign in');
      } catch (e) {
        debugPrint('Error clearing preferences before Google sign in: $e');
        // Continue with sign-in even if preferences clearing fails
      }
      
      // Clear any previous sign-in state first
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
          debugPrint('🔍 Signed out of previous Google session');
        }
      } catch (e) {
        debugPrint('⚠️ Error checking/clearing previous Google sign-in: $e');
        // Continue anyway
      }
      
      while (retryCount <= maxRetries) {
        try {
          // Verify scopes are properly set
          final scopes = _googleSignIn.scopes;
          debugPrint('🔍 Google Sign-In scopes: $scopes');
          
          // Attempt to sign in
          debugPrint('🔍 Calling googleSignIn.signIn() - attempt ${retryCount + 1}');
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
          
          if (googleUser == null) {
            debugPrint('⚠️ Google sign-in was cancelled by user');
            _isProcessingGoogleSignIn = false;
            return AuthResult(errorMessage: 'Sign in cancelled');
          }
          
          debugPrint('✅ Successfully signed in with Google: ${googleUser.email}');
          debugPrint('🔍 Google user details: ${googleUser.displayName}, ID: ${googleUser.id}');

          // Get auth details
          debugPrint('🔍 Getting Google authentication tokens');
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          
          if (googleAuth.accessToken == null || googleAuth.idToken == null) {
            debugPrint('❌ Google auth tokens are null: accessToken=${googleAuth.accessToken}, idToken=${googleAuth.idToken}');
            continue; // Try again
          }
          
          debugPrint('✅ Got Google authentication tokens');

          // Create credential
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          
          debugPrint('🔍 Created Firebase credential, signing in to Firebase');

          // Sign in to Firebase
          final userCredential = await _firebaseAuth.signInWithCredential(credential);
          
          debugPrint('✅ Firebase sign-in completed successfully');
          
          if (userCredential.user != null) {
            final user = AppUser.fromFirebaseUser(userCredential.user!);
            _isProcessingGoogleSignIn = false;
            return AuthResult(user: user);
          }
          
          debugPrint('❌ userCredential.user is null after successful Firebase sign-in');
          break; // Exit the retry loop if we get here
        } catch (e) {
          debugPrint('❌ Google sign-in error on attempt ${retryCount + 1}: ${e.toString()}');
          retryCount++;
          
          if (retryCount > maxRetries) {
            debugPrint('❌ Max retry attempts reached for Google sign-in');
            break;
          }
          
          debugPrint('⚠️ Retrying Google sign-in after error...');
          // Add a small delay before retrying
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
      
      _isProcessingGoogleSignIn = false;
      return AuthResult(errorMessage: 'Failed to sign in with Google after multiple attempts');
    } catch (e) {
      debugPrint('❌ Google sign-in error: ${e.toString()}');
      _isProcessingGoogleSignIn = false;
      return AuthResult(errorMessage: 'Google sign in error: ${e.toString()}');
    }
  }

  // Sign in with Apple
  Future<AuthResult> signInWithApple() async {
    try {
      debugPrint('🔍 Starting Apple sign-in flow with Firebase provider');
      
      // Clear SharedPreferences first and foremost
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Save important settings before clearing
        final notificationsEnabled = prefs.getBool(_notificationsEnabledKey);
        final themeMode = prefs.getString(_themeModeKey);
        final appTrackingEnabled = prefs.getBool(_appTrackingKey);
        
        // Clear all preferences
        await prefs.clear();
        
        // Restore important settings after clearing
        if (notificationsEnabled != null) {
          await prefs.setBool(_notificationsEnabledKey, notificationsEnabled);
        }
        
        if (themeMode != null) {
          await prefs.setString(_themeModeKey, themeMode);
        }
        
        if (appTrackingEnabled != null) {
          await prefs.setBool(_appTrackingKey, appTrackingEnabled);
        }
        
        debugPrint('Cleared all user preferences before Apple sign in');
      } catch (e) {
        debugPrint('Error clearing preferences before Apple sign in: $e');
        // Continue with sign-in even if preferences clearing fails
      }
      
      // Create an Apple provider
      final appleProvider = AppleAuthProvider();
      
      // Add required scopes
      appleProvider.addScope('email');
      appleProvider.addScope('name');
      
      // Sign in with the provider - this handles everything!
      final userCredential = await FirebaseAuth.instance.signInWithProvider(appleProvider);
      
      debugPrint('✅ Firebase sign-in with Apple completed successfully');
      
      if (userCredential.user != null) {
        final user = AppUser.fromFirebaseUser(userCredential.user!);
        // Save user profile to Firestore
        await _saveUserProfile(user);
        return AuthResult(user: user);
      } else {
        debugPrint('❌ Firebase userCredential.user is null after Apple sign-in');
        return AuthResult(errorMessage: 'Failed to create user account with Apple');
      }
    } catch (e) {
      // Generic catch-all handler for other exceptions
      debugPrint('❌ Unexpected error during Apple sign-in: ${e.toString()}');
      
      // Common Apple Sign In cancellation patterns
      if (e.toString().toLowerCase().contains('cancel') || 
          e.toString().contains('User cancelled') ||
          e.toString().contains('popup_closed') ||
          e.toString().contains('popup was closed') ||
          e.toString().contains('The operation couldn\'t be completed') ||
          // Firebase unknown error is often triggered when user cancels sign-in
          e.toString().contains('firebase_auth')) {
        debugPrint('🔍 Detected likely user cancellation from error message');
        return AuthResult(); // Return empty result without error for cancellations
      }
      
      return AuthResult(errorMessage: 'Failed to sign in with Apple: ${e.toString()}');
    }
  }


  // Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Clear SharedPreferences first and foremost
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Save important settings before clearing
        final notificationsEnabled = prefs.getBool(_notificationsEnabledKey);
        final themeMode = prefs.getString(_themeModeKey);
        final appTrackingEnabled = prefs.getBool(_appTrackingKey);
        
        // SOFT LOGOUT: Save critical IDs before clearing
        final originalAppUserId = prefs.getString('original_app_user_id');
        final firestoreUserId = prefs.getString('firestore_user_id');
        
        // Clear all preferences
        await prefs.clear();
        
        // Restore important settings after clearing
        if (notificationsEnabled != null) {
          await prefs.setBool(_notificationsEnabledKey, notificationsEnabled);
        }
        
        if (themeMode != null) {
          await prefs.setString(_themeModeKey, themeMode);
        }
        
        if (appTrackingEnabled != null) {
          await prefs.setBool(_appTrackingKey, appTrackingEnabled);
        }
        
        // SOFT LOGOUT: Restore critical IDs after clearing
        if (originalAppUserId != null) {
          await prefs.setString('original_app_user_id', originalAppUserId);
          debugPrint('✅ Restored originalAppUserId during sign in: $originalAppUserId');
        }
        
        if (firestoreUserId != null) {
          await prefs.setString('firestore_user_id', firestoreUserId);
          debugPrint('✅ Restored firestoreUserId during sign in: $firestoreUserId');
        }
        
        debugPrint('Cleared all user preferences before sign in while preserving critical IDs');
      } catch (e) {
        debugPrint('Error clearing preferences before sign in: $e');
        // Continue with sign-in even if preferences clearing fails
      }
    
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        final user = AppUser.fromFirebaseUser(userCredential.user!);
        
        // Save user profile to ensure we have database record with email
        await _saveUserProfile(user);
        
        return AuthResult(user: user);
      }
      
      return AuthResult(errorMessage: 'Failed to sign in');
    } on FirebaseAuthException catch (e) {
      return AuthResult(errorMessage: _getReadableAuthError(e));
    } catch (e) {
      return AuthResult(errorMessage: 'Error signing in: ${e.toString()}');
    }
  }

  // Sign up with email and password
  Future<AuthResult> signUpWithEmailAndPassword(String email, String password) async {
    try {
      // Clear SharedPreferences first and foremost
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Save important settings before clearing
        final notificationsEnabled = prefs.getBool(_notificationsEnabledKey);
        final themeMode = prefs.getString(_themeModeKey);
        final appTrackingEnabled = prefs.getBool(_appTrackingKey);
        
        // SOFT LOGOUT: Save critical IDs before clearing
        final originalAppUserId = prefs.getString('original_app_user_id');
        final firestoreUserId = prefs.getString('firestore_user_id');
        
        // Clear all preferences
        await prefs.clear();
        
        // Restore important settings after clearing
        if (notificationsEnabled != null) {
          await prefs.setBool(_notificationsEnabledKey, notificationsEnabled);
        }
        
        if (themeMode != null) {
          await prefs.setString(_themeModeKey, themeMode);
        }
        
        if (appTrackingEnabled != null) {
          await prefs.setBool(_appTrackingKey, appTrackingEnabled);
        }
        
        // SOFT LOGOUT: Restore critical IDs after clearing
        if (originalAppUserId != null) {
          await prefs.setString('original_app_user_id', originalAppUserId);
          debugPrint('✅ Restored originalAppUserId during sign up: $originalAppUserId');
        }
        
        if (firestoreUserId != null) {
          await prefs.setString('firestore_user_id', firestoreUserId);
          debugPrint('✅ Restored firestoreUserId during sign up: $firestoreUserId');
        }
        
        debugPrint('Cleared all user preferences before sign up while preserving critical IDs');
      } catch (e) {
        debugPrint('Error clearing preferences before sign up: $e');
        // Continue with sign-up even if preferences clearing fails
      }
      
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        final user = AppUser.fromFirebaseUser(userCredential.user!);
        
        // Save user profile to Firestore
        await _saveUserProfile(user);
        
        return AuthResult(user: user);
      }
      
      return AuthResult(errorMessage: 'Failed to create account');
    } on FirebaseAuthException catch (e) {
      return AuthResult(errorMessage: _getReadableAuthError(e));
    } catch (e) {
      return AuthResult(errorMessage: 'Error creating account: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    // Clear SharedPreferences first and foremost
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save important settings before clearing
      final notificationsEnabled = prefs.getBool(_notificationsEnabledKey);
      final themeMode = prefs.getString(_themeModeKey);
      final appTrackingEnabled = prefs.getBool(_appTrackingKey);
      
      // Clear all preferences
      await prefs.clear();
      
      // Restore important settings after clearing
      if (notificationsEnabled != null) {
        await prefs.setBool(_notificationsEnabledKey, notificationsEnabled);
      }
      
      if (themeMode != null) {
        await prefs.setString(_themeModeKey, themeMode);
      }
      
      if (appTrackingEnabled != null) {
        await prefs.setBool(_appTrackingKey, appTrackingEnabled);
      }
      
      debugPrint('Cleared all user preferences before sign out');
    } catch (e) {
      debugPrint('Error clearing preferences before sign out: $e');
      // Continue with sign-out even if preferences clearing fails
    }
    
    // Make sure we properly clean up all resources
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        debugPrint('🔍 Signed out of Google successfully');
      }
    } catch (e) {
      debugPrint('⚠️ Error signing out of Google: $e');
      // Continue with Firebase sign out anyway
    }
    
    try {
      // Reset Crisp chat session
      try {
        final crispService = CrispService();
        crispService.resetUserInformation();
        debugPrint('🔍 Reset Crisp chat session successfully');
      } catch (e) {
        debugPrint('⚠️ Error resetting Crisp chat session: $e');
        // Continue with Firebase sign out anyway
      }
      
      await _firebaseAuth.signOut();
      debugPrint('🔍 Signed out of Firebase successfully');
    } catch (e) {
      debugPrint('❌ Error signing out of Firebase: $e');
      
      // Firebase auth network error - not sent to Crashlytics
      
      throw e; // Rethrow Firebase signOut errors
    }
  }

  // Helper for Apple sign in to generate a random string
  String _generateRandomString() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return base64Url.encode(utf8.encode(random));
  }

  // Helper for Apple sign in to generate SHA256 hash
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Helper to convert Firebase auth errors to user-friendly messages
  String _getReadableAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email address';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password';
      case 'invalid-email':
        return 'Invalid email address format';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in method';
      case 'invalid-credential':
        return 'The authentication credential is invalid';
      case 'operation-not-allowed':
        return 'This operation is not allowed';
      case 'user-disabled':
        return 'This user account has been disabled';
      case 'too-many-requests':
        return 'Too many sign-in attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection';
      case 'credential-already-in-use':
        return 'This credential is already associated with another account';
      default:
        return e.message ?? 'An unknown error occurred';
    }
  }

  // Reset Google Sign-In state - can be called if you encounter issues
  Future<void> resetGoogleSignIn() async {
    debugPrint('🔍 Resetting Google Sign-In state');
    _isProcessingGoogleSignIn = false;
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        debugPrint('🔍 Signed out of Google during reset');
      }
    } catch (e) {
      debugPrint('⚠️ Error during Google Sign-In reset: $e');
    }
  }

  // Dispose to prevent memory leaks
  void dispose() {
    debugPrint('🧹 AuthService: Disposing resources');
    _firebaseAuthSubscription?.cancel();
    if (!_authStateController.isClosed) {
      _authStateController.close();
    }
    _isProcessingGoogleSignIn = false;
  }
} 