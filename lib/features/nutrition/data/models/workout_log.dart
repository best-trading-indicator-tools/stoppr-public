import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'workout_log.freezed.dart';
part 'workout_log.g.dart';

@JsonEnum()
enum ExerciseIntensity {
  @JsonValue('low')
  low,
  @JsonValue('medium')
  medium,
  @JsonValue('high')
  high,
}

@freezed
class WorkoutLog with _$WorkoutLog {
  const factory WorkoutLog({
    String? id,
    required String exerciseType,
    required String intensity,
    required int duration, // minutes
    required int caloriesBurned,
    @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson) required DateTime loggedAt,
    @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson) required DateTime createdAt,
    @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson) required DateTime updatedAt,
    @Default(false) bool isDeleted,
  }) = _WorkoutLog;

  factory WorkoutLog.fromJson(Map<String, dynamic> json) =>
      _$WorkoutLogFromJson(json);
}

// Helper functions for Timestamp conversion
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