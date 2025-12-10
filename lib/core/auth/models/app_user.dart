import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,
    required String email,
    String? displayName,
    @Default(false) bool isEmailVerified,
    String? providerId,
    @Default(false) bool isAnonymous,
    @Default(false) bool createdDuringPayment,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);

  factory AppUser.fromFirebaseUser(firebase.User user) {
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      isEmailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
      providerId: user.providerData.isNotEmpty 
          ? user.providerData.first.providerId 
          : null,
    );
  }
} 