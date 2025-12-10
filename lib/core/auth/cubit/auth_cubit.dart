import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../auth_service.dart';
import 'auth_state.dart';
import '../models/app_user.dart';
import '../../repositories/user_repository.dart';
import '../../subscription/subscription_service.dart';
import '../../../features/onboarding/data/services/onboarding_progress_service.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserRepository _userRepository = UserRepository();
  final SubscriptionService _subscriptionService;
  final OnboardingProgressService _progressService = OnboardingProgressService();
  StreamSubscription<AppUser?>? _authSubscription;
  int _signInRetryCount = 0;
  static const int _maxSignInRetries = 2;
  bool _isRecoveringFromStreamError = false;
  
  // Add a flag to track if we're in the middle of authentication flow
  // This prevents duplicate navigation states from being emitted
  bool _isHandlingAuthFlow = false;
  
  // Track user ID we're already processing to prevent duplicate transitions
  String? _currentlyProcessingUserId;

  AuthCubit({
    required AuthService authService,
    SubscriptionService? subscriptionService,
  }) : _authService = authService, 
       _subscriptionService = subscriptionService ?? SubscriptionService(),
       super(const AuthState.initial()) {
    // Listen to auth state changes from the service
    _subscribeToAuthChanges();
  }
  
  void _subscribeToAuthChanges() {
    try {
      // Cancel any existing subscription first
      _authSubscription?.cancel();
      _authSubscription = null;
      
      // Create a new subscription with error handling
      _authSubscription = _authService.authStateChanges.listen(
        (user) async {
          debugPrint('AuthCubit: Received auth state change: ${user != null ? 'Logged in' : 'Logged out'}');
          if (user != null) {
            // --- ADDED: Special case for Apple Reviewer --- 
            if (user.email == 'applereviews2025@gmail.com' || user.email == 'hello@stoppr.app') {
              debugPrint('AuthCubit: Apple Reviewer or Admin account logged in (${user.email}). Bypassing subscription check, setting paid_gift status, marking onboarding complete, and navigating directly to HomeScreen.');
              
              // Mark as handling and set user ID to prevent duplicate processing
              _currentlyProcessingUserId = user.uid;
              _isHandlingAuthFlow = true; 
              
              try {
                // 1. Mark onboarding as complete for the reviewer
                await _progressService.markOnboardingComplete(user.uid);
                debugPrint('AuthCubit: Marked onboarding complete for Apple Reviewer.');
                
                // 2. Set subscription status to paid_gift with a far-future expiration
                final farFutureExpiration = DateTime.now().add(const Duration(days: 365 * 10)); // 10 years from now
                await _userRepository.updateUserSubscriptionStatus(
                  user.uid, 
                  SubscriptionType.paid_gift, 
                  productId: 'apple_reviewer_gift', // Assign a specific product ID
                  expirationDate: farFutureExpiration
                );
                debugPrint('AuthCubit: Set subscription status to paid_gift for Apple Reviewer (expires: ${farFutureExpiration.toIso8601String()}).');

                // 3. Emit the state that navigates to home screen
                emit(AuthState.authenticatedPaidUser(user));
                debugPrint('AuthCubit: Emitted authenticatedPaidUser state for Apple Reviewer.');
                
              } catch (e) {
                debugPrint('AuthCubit: Error during special processing for Apple Reviewer: $e');
                // If updates fail, still try to emit the navigation state so they are not blocked
                // But also emit an error state first so it might be logged/seen
                emit(AuthState.error('Failed to update reviewer status: $e'));
                // Fallback to emitting the navigation state anyway
                 if (!_isHandlingAuthFlow) { // Check flag again in case of async issues
                   _isHandlingAuthFlow = true; 
                 }
                emit(AuthState.authenticatedPaidUser(user)); 
              } finally {
                 // Reset the flag *after* emitting the final state for this flow
                 _isHandlingAuthFlow = false; 
              }
              
              return; // Skip normal subscription check for the reviewer
            }
            // --- END ADDED --- 

            // Check if we're already processing this user's authentication flow
            if (_currentlyProcessingUserId == user.uid && _isHandlingAuthFlow) {
              debugPrint('AuthCubit: Already processing auth flow for user ${user.uid}, skipping duplicate state transition');
              return;
            }
            
            // Mark that we're starting to process this user
            _currentlyProcessingUserId = user.uid;
            _isHandlingAuthFlow = true;
            
            // First emit the basic authenticated state immediately
            emit(AuthState.authenticated(user));
            
            // Then check subscription status and emit the appropriate navigation state
            _checkUserSubscriptionStatus(user);
          } else {
            // Reset processing flags for logout
            _currentlyProcessingUserId = null;
            _isHandlingAuthFlow = false;
            emit(const AuthState.unauthenticated());
          }
        },
        onError: (error) {
          debugPrint('AuthCubit: Auth stream error: $error');
          
          // If we're already trying to recover from a stream error, don't retry again
          if (_isRecoveringFromStreamError) {
            debugPrint('AuthCubit: Already recovering from stream error, emitting error state');
            emit(AuthState.error('Authentication error: $error'));
            return;
          }
          
          // Try to recover from stream errors
          _isRecoveringFromStreamError = true;
          
          // If the error is related to streams, attempt to re-subscribe
          if (error.toString().contains('Stream') || 
              error.toString().contains('listen') ||
              error.toString().contains('subscription')) {
            
            debugPrint('AuthCubit: Detected stream-related error, attempting to re-subscribe');
            
            // Wait a moment before attempting to reconnect
            Future.delayed(const Duration(milliseconds: 500), () {
              debugPrint('AuthCubit: Re-subscribing after stream error');
              try {
                _subscribeToAuthChanges();
                _isRecoveringFromStreamError = false;
              } catch (e) {
                debugPrint('AuthCubit: Failed to re-subscribe after stream error: $e');
                emit(AuthState.error('Failed to recover from authentication error: $e'));
                _isRecoveringFromStreamError = false;
              }
            });
          } else {
            // For other errors, just emit the error state
            emit(AuthState.error('Authentication error: $error'));
            _isRecoveringFromStreamError = false;
          }
        },
        cancelOnError: false, // Don't cancel on error so we can handle it
      );
      
      debugPrint('AuthCubit: Successfully subscribed to auth state changes');
    } catch (e) {
      debugPrint('AuthCubit: Error setting up auth subscription: $e');
      emit(AuthState.error('Failed to initialize authentication: $e'));
    }
  }

  // Check the user's subscription status and emit the appropriate state
  Future<void> _checkUserSubscriptionStatus(AppUser user) async {
    try {
      debugPrint('AuthCubit: Checking subscription status for user ${user.uid} via RevenueCat');
      
      // Get live customer info directly from RevenueCat
      final customerInfo = await Purchases.getCustomerInfo();
      
      // Determine paid status based on active entitlements (preferred)
      // or active subscriptions as a fallback
      final bool isPaid = customerInfo.entitlements.active.isNotEmpty || 
                          customerInfo.activeSubscriptions.isNotEmpty;
                          
      // Determine a simple subscription status string for the detailed state
      String subscriptionStatusString = 'free';
      if (isPaid) {
        // Check specific entitlements if needed, or default to paid_standard
        if (customerInfo.entitlements.active.containsKey('premium_gift')) {
           subscriptionStatusString = 'paid_gift';
        } else {
           subscriptionStatusString = 'paid_standard';
        }
      }
      
      // Log the live status
      debugPrint('AuthCubit: Live RevenueCat check result: isPaid=$isPaid, StatusString=$subscriptionStatusString, Entitlements=${customerInfo.entitlements.active.keys}, Subscriptions=${customerInfo.activeSubscriptions}');
      
      // First emit detailed subscription info based on live data
      emit(AuthState.authenticatedWithSubscription(
        user,
        isPaidUser: isPaid,
        subscriptionStatus: subscriptionStatusString,
      ));
      
      // Then emit navigation state based on the live paid status
      if (isPaid) {
        debugPrint('AuthCubit: User is PAID (Live Check) - emitting authenticatedPaidUser for navigation');
        // Mark onboarding as complete for paid subscribers
        await _progressService.markOnboardingComplete(user.uid);
        emit(AuthState.authenticatedPaidUser(user));
      } else {
        debugPrint('AuthCubit: User is FREE (Live Check) - emitting authenticatedFreeUser for navigation');
        emit(AuthState.authenticatedFreeUser(user));
      }
    } catch (e) {
      debugPrint('AuthCubit: Error checking RevenueCat customer info: $e');
      
      // On error, default to free user to be safe
      debugPrint('AuthCubit: Defaulting to free user due to RevenueCat error');
      emit(AuthState.authenticatedFreeUser(user));
    } finally {
      // Reset processing flag when the auth flow is complete
      _isHandlingAuthFlow = false;
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    debugPrint('🔐 AuthCubit: signInWithGoogle called');
    emit(const AuthState.loading());
    _signInRetryCount = 0;
    
    await _attemptGoogleSignIn();
  }
  
  // Helper method for Google sign-in with retry logic
  Future<void> _attemptGoogleSignIn() async {
    try {
      debugPrint('AuthCubit: Starting Google sign-in attempt ${_signInRetryCount + 1}');
      final result = await _authService.signInWithGoogle();
      
      if (result.errorMessage != null) {
        debugPrint('AuthCubit: Google sign-in error: ${result.errorMessage}');
        
        // Check if we should retry
        if (_signInRetryCount < _maxSignInRetries && 
            !result.errorMessage!.contains('cancelled') &&
            !result.errorMessage!.contains('already in progress')) {
          
          _signInRetryCount++;
          debugPrint('AuthCubit: Retrying Google sign-in (attempt ${_signInRetryCount})');
          
          // Small delay before retry
          await Future.delayed(const Duration(milliseconds: 800));
          
          // Try to reset any lingering Google sign-in state first
          await _authService.resetGoogleSignIn();
          
          return _attemptGoogleSignIn();
        }
        
        // If user cancelled or we've reached max retries, emit error state
        emit(AuthState.error(result.errorMessage!));
      }
      // Auth state changes will be handled by the stream
      
      // But if there was no error and also no user (edge case), reset handling flag
      if (result.user == null && result.errorMessage == null) {
        debugPrint('AuthCubit: Google sign-in completed without user or error, clearing flag');
        _isHandlingAuthFlow = false;
      }
    } catch (e) {
      debugPrint('AuthCubit: Unexpected error during Google sign-in: $e');
      emit(AuthState.error('Failed to sign in with Google: ${e.toString()}'));
      
      // Reset flag on error
      _isHandlingAuthFlow = false;
    }
  }
  
  // Sign in with Apple
  Future<void> signInWithApple() async {
    debugPrint('🔐 AuthCubit: signInWithApple called');
    emit(const AuthState.loading());
    String? originalUserId = _currentlyProcessingUserId; // Keep track of user before operation
    
    try {
      final result = await _authService.signInWithApple();
      
      if (result.errorMessage != null) {
        debugPrint('AuthCubit: Apple sign-in error: ${result.errorMessage}');
        
        final errorLower = result.errorMessage!.toLowerCase();
        
        if (errorLower.contains('cancel') || 
            errorLower.contains('cancelled') || 
            errorLower.contains('canceled') ||
            result.errorMessage!.contains('Error 1001') ||
            result.errorMessage!.contains('AuthorizationErrorCode') ||
            result.errorMessage!.contains('Error 1000')) {
          debugPrint('AuthCubit: User cancelled Apple sign-in or common Apple error, emitting unauthenticated state');
          emit(const AuthState.unauthenticated());
        } else {
          emit(AuthState.error(result.errorMessage!));
        }
        
        _isHandlingAuthFlow = false;
      } else if (result.user != null) {
        // **** START NEW LOGIC ****
        // AuthService call succeeded, proceed even if the stream might not fire for re-auth.
        debugPrint('AuthCubit: Apple sign-in successful via AuthService. User: ${result.user!.uid}. Checking state manually.');

        // Check if we're already processing this specific user
        if (_currentlyProcessingUserId == result.user!.uid && _isHandlingAuthFlow) {
           debugPrint('AuthCubit: Already handling auth flow for ${result.user!.uid}, letting existing flow complete.');
           // Do nothing - allow the existing flow triggered by the stream (if any) to complete.
           // The loading state will eventually be cleared by that flow.
        } else {
           // Start processing this authenticated user
           _currentlyProcessingUserId = result.user!.uid;
           _isHandlingAuthFlow = true; // Mark as handling
           
           debugPrint('AuthCubit: Emitting Authenticated and checking subscription status manually for ${result.user!.uid}');
           // Emit basic authenticated state first
           emit(AuthState.authenticated(result.user!));
           // Directly call the subscription check - this will emit the final state and reset _isHandlingAuthFlow
           await _checkUserSubscriptionStatus(result.user!); 
        }
        // **** END NEW LOGIC ****
      } else {
        // Handle the edge case: no error, but no user either (e.g., cancellation detected in service)
        debugPrint('AuthCubit: Apple sign-in completed without user or error (likely cancellation), emitting unauthenticated.');
         _isHandlingAuthFlow = false; // Reset flag
         _currentlyProcessingUserId = null; // Clear user ID
         emit(const AuthState.unauthenticated()); // Emit unauthenticated to stop loader
      }
    } catch (e) {
      debugPrint('AuthCubit: Unexpected error during Apple sign-in: $e');
      
      // Don't show error for Firebase unknown errors (usually means user cancelled)
      if (e.toString().contains('firebase_auth')) {
        debugPrint('AuthCubit: Detected Firebase unknown error, treating as cancellation');
        emit(const AuthState.unauthenticated());
      } else {
        emit(AuthState.error('Failed to sign in with Apple: ${e.toString()}'));
      }
      
      // Reset flag on error
      _isHandlingAuthFlow = false;
    }
  }

  // Sign in with email and password
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    emit(const AuthState.loading());
    
    try {
      debugPrint('AuthCubit: Starting email sign-in');
      final result = await _authService.signInWithEmailAndPassword(email, password);
      
      if (result.errorMessage != null) {
        debugPrint('AuthCubit: Email sign-in error: ${result.errorMessage}');
        emit(AuthState.error(result.errorMessage!));
        
        // Reset flag on error
        _isHandlingAuthFlow = false;
      } else {
        debugPrint('AuthCubit: Email sign-in successful');
      }
    } catch (e) {
      debugPrint('AuthCubit: Unexpected error during email sign-in: $e');
      emit(AuthState.error('Failed to sign in with email: ${e.toString()}'));
      
      // Reset flag on error
      _isHandlingAuthFlow = false;
    }
    // No need to emit authenticated state as the stream will handle that
  }

  // Sign up with email and password
  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    emit(const AuthState.loading());
    
    try {
      debugPrint('AuthCubit: Starting email sign-up');
      final result = await _authService.signUpWithEmailAndPassword(email, password);
      
      if (result.errorMessage != null) {
        debugPrint('AuthCubit: Email sign-up error: ${result.errorMessage}');
        emit(AuthState.error(result.errorMessage!));
        
        // Reset flag on error
        _isHandlingAuthFlow = false;
      } else {
        debugPrint('AuthCubit: Email sign-up successful');
      }
    } catch (e) {
      debugPrint('AuthCubit: Unexpected error during email sign-up: $e');
      emit(AuthState.error('Failed to sign up: ${e.toString()}'));
      
      // Reset flag on error
      _isHandlingAuthFlow = false;
    }
    // No need to emit authenticated state as the stream will handle that
  }

  // Sign out
  Future<void> signOut() async {
    emit(const AuthState.loading());
    
    try {
      debugPrint('AuthCubit: Starting sign-out');
      await _authService.signOut();
      debugPrint('AuthCubit: Sign-out successful');
      // The stream will handle the unauthenticated state
      
      // Reset processing flags for logout
      _currentlyProcessingUserId = null;
      _isHandlingAuthFlow = false;
    } catch (e) {
      debugPrint('AuthCubit: Error during sign-out: $e');
      emit(AuthState.error('Failed to sign out: ${e.toString()}'));
      
      // Reset flag on error
      _isHandlingAuthFlow = false;
    }
  }

  // Get the current authenticated user directly
  AppUser? getCurrentUser() {
    return _authService.currentUser;
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    super.close();
  }
} 