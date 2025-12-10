import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/app_user.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  // Initial state
  const factory AuthState.initial() = Initial;

  // Loading state (during auth operations)
  const factory AuthState.loading() = Loading;

  // User is authenticated
  const factory AuthState.authenticated(AppUser user) = Authenticated;

  // User is authenticated with subscription information
  const factory AuthState.authenticatedWithSubscription(
    AppUser user, 
    {@Default(false) bool isPaidUser, 
     @Default('free') String subscriptionStatus}) = AuthenticatedWithSubscription;
  
  // Navigation state for paid users (skip onboarding)
  const factory AuthState.authenticatedPaidUser(AppUser user) = AuthenticatedPaidUser;
  
  // Navigation state for free users (continue onboarding)
  const factory AuthState.authenticatedFreeUser(AppUser user) = AuthenticatedFreeUser;

  // User is not authenticated
  const factory AuthState.unauthenticated() = Unauthenticated;

  // Error state
  const factory AuthState.error(String message) = Error;
} 