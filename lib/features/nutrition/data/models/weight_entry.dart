import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'weight_entry.freezed.dart';
part 'weight_entry.g.dart';

@freezed
class WeightEntry with _$WeightEntry {
  const factory WeightEntry({
    String? id,
    required double weightKg,
    @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
    required DateTime loggedAt,
    @Default('manual') String source,
  }) = _WeightEntry;

  factory WeightEntry.fromJson(Map<String, dynamic> json) =>
      _$WeightEntryFromJson(json);
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


