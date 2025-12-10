import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'accountability_partner.freezed.dart';
part 'accountability_partner.g.dart';

/// Embedded model within user document for quick accountability partner access
/// Used for widget display and in-app partner info
@freezed
class AccountabilityPartner with _$AccountabilityPartner {
  const factory AccountabilityPartner({
    /// Partner's user ID
    String? partnerId,
    
    /// Partner's first name (denormalized for quick access)
    String? partnerFirstName,
    
    /// Partner's current streak (denormalized, synced every 5 min)
    @Default(0) int partnerStreak,
    
    /// Partnership status
    /// "paired" - active partnership
    /// "pending_sent" - waiting for partner to accept our request
    /// "pending_received" - partner sent us a request, we haven't responded
    /// "solo" - no active partnership
    @Default('solo') String status,
    
    /// When the partnership was established
    @JsonKey(
      fromJson: _timestampFromJson,
      toJson: _timestampToJson,
    )
    DateTime? pairedAt,
    
    /// User ID who invited this user (AppsFlyer attribution)
    String? invitedBy,
    
    /// When partner streak was last synced
    @JsonKey(
      fromJson: _timestampFromJson,
      toJson: _timestampToJson,
    )
    DateTime? lastSyncedAt,
  }) = _AccountabilityPartner;

  factory AccountabilityPartner.fromJson(Map<String, dynamic> json) =>
      _$AccountabilityPartnerFromJson(json);
}

// Firestore Timestamp converters
DateTime? _timestampFromJson(dynamic timestamp) {
  if (timestamp == null) return null;
  if (timestamp is Timestamp) return timestamp.toDate();
  if (timestamp is String) return DateTime.parse(timestamp);
  return null;
}

dynamic _timestampToJson(DateTime? dateTime) {
  if (dateTime == null) return null;
  return Timestamp.fromDate(dateTime);
}

