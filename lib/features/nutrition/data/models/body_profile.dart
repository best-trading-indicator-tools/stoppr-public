import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'body_profile.freezed.dart';
part 'body_profile.g.dart';

@freezed
class BodyProfile with _$BodyProfile {
  const factory BodyProfile({
    required double? heightCm,
    required double? goalWeightKg,
    @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
    required DateTime updatedAt,
  }) = _BodyProfile;

  factory BodyProfile.fromJson(Map<String, dynamic> json) =>
      _$BodyProfileFromJson(json);
}

DateTime _timestampFromJson(dynamic timestamp) {
  if (timestamp is Timestamp) {
    return timestamp.toDate();
  } else if (timestamp is Map && timestamp['seconds'] != null) {
    return DateTime.fromMillisecondsSinceEpoch(
      timestamp['seconds'] * 1000 + (timestamp['nanoseconds'] ?? 0) ~/ 1000000,
    );
  }
  return DateTime.now();
}

dynamic _timestampToJson(DateTime dateTime) {
  return Timestamp.fromDate(dateTime);
}


