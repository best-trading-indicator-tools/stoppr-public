import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'partnership.freezed.dart';
part 'partnership.g.dart';

/// Partnership document in accountability_partnerships collection
/// Represents a pairing between two users
@freezed
class Partnership with _$Partnership {
  const factory Partnership({
    /// Firestore document ID
    required String id,
    
    /// First user's ID
    required String user1Id,
    
    /// Second user's ID
    required String user2Id,
    
    /// First user's name (denormalized)
    required String user1Name,
    
    /// Second user's name (denormalized)
    required String user2Name,
    
    /// Partnership status
    /// "active" - both accepted, partnership is active
    /// "pending" - one user sent request, waiting for other to accept
    /// "declined" - request was declined
    /// "ended" - partnership was terminated
    @Default('pending') String status,
    
    /// User ID who initiated the partnership (sent the request)
    required String initiatedBy,
    
    /// How the partnership was created
    /// "random" - matched from pool
    /// "invite_link" - friend invited via AppsFlyer link
    /// "direct" - manual search/add (future)
    @Default('random') String inviteMethod,
    
    /// When partnership was created
    @JsonKey(
      fromJson: _timestampFromJsonRequired,
      toJson: _timestampToJson,
    )
    required DateTime createdAt,
    
    /// When partnership was accepted (null if still pending)
    @JsonKey(
      fromJson: _timestampFromJson,
      toJson: _timestampToJson,
    )
    DateTime? acceptedAt,
    
    /// When partnership was ended (null if still active)
    @JsonKey(
      fromJson: _timestampFromJson,
      toJson: _timestampToJson,
    )
    DateTime? endedAt,
    
    /// User ID who ended the partnership
    String? endedBy,
    
    /// Reason for ending
    /// "manual" - user chose to unpair
    /// "partner_unsubscribed" - partner cancelled subscription
    /// "partner_inactive" - partner inactive 30+ days
    /// "expired" - pending request expired after 7 days
    String? endReason,
  }) = _Partnership;

  factory Partnership.fromJson(Map<String, dynamic> json) =>
      _$PartnershipFromJson(json);
}

/// Entry in accountability_pool collection for random matching
@freezed
class PoolEntry with _$PoolEntry {
  const factory PoolEntry({
    /// User's ID
    required String userId,
    
    /// User's first name
    required String firstName,
    
    /// User's current streak
    @Default(0) int currentStreak,
    
    /// Whether actively looking for partner
    @Default(true) bool lookingForPartner,
    
    /// When added to pool
    @JsonKey(
      fromJson: _timestampFromJsonRequired,
      toJson: _timestampToJson,
    )
    required DateTime addedToPoolAt,
    
    /// Whether user has active subscription
    @Default(true) bool isSubscribed,
    
    /// Last time user was active in app
    @JsonKey(
      fromJson: _timestampFromJsonRequired,
      toJson: _timestampToJson,
    )
    required DateTime lastActive,
    
    /// Optional matching preferences
    @Default(PoolPreferences()) PoolPreferences preferences,
  }) = _PoolEntry;

  factory PoolEntry.fromJson(Map<String, dynamic> json) =>
      _$PoolEntryFromJson(json);
}

/// Matching preferences for finding partners
@freezed
class PoolPreferences with _$PoolPreferences {
  const factory PoolPreferences({
    /// Preferred streak range for matching
    /// "any" - match with anyone
    /// "similar" - match with users within 10 days of own streak
    @Default('any') String streakRange,
  }) = _PoolPreferences;

  factory PoolPreferences.fromJson(Map<String, dynamic> json) =>
      _$PoolPreferencesFromJson(json);
}

// Firestore Timestamp converters
DateTime? _timestampFromJson(dynamic timestamp) {
  if (timestamp == null) return null;
  if (timestamp is Timestamp) return timestamp.toDate();
  if (timestamp is String) return DateTime.parse(timestamp);
  return null;
}

DateTime _timestampFromJsonRequired(dynamic timestamp) {
  if (timestamp is Timestamp) return timestamp.toDate();
  if (timestamp is String) return DateTime.parse(timestamp);
  return DateTime.now(); // Fallback for required fields
}

dynamic _timestampToJson(DateTime? dateTime) {
  if (dateTime == null) return null;
  return Timestamp.fromDate(dateTime);
}

