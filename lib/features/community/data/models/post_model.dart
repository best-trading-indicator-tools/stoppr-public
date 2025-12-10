import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_model.freezed.dart';
part 'post_model.g.dart';

// Helper functions for Timestamp conversion
Timestamp _timestampToJson(DateTime date) => Timestamp.fromDate(date);
DateTime _timestampFromJson(Timestamp timestamp) => timestamp.toDate();

@freezed
class PostModel with _$PostModel {
  const factory PostModel({
    required String id,
    required String title,
    required String content,
    required String authorId,
    required String authorName, // Denormalized for easy display
    @Default(0) int authorStreak, // Add author's streak
    @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
    required DateTime createdAt,
    @Default(0) int upvotes,
    @Default([]) List<String> upvotedBy, // List of user IDs who upvoted
    @Default(0) int commentCount, // Denormalized for efficiency
    @Default(false) bool sample, // Flag to identify sample posts
  }) = _PostModel;

  factory PostModel.fromJson(Map<String, dynamic> json) =>
      _$PostModelFromJson(json);

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    // Create a safe version of the data with required fields
    final safeData = {
      'id': doc.id,
      'title': data['title'] ?? 'Untitled Post',
      'content': data['content'] ?? 'No content provided',
      'authorId': data['authorId'] ?? 'unknown_user',
      'authorName': data['authorName'] ?? 'Unknown User',
      'authorStreak': data['authorStreak'] ?? 0, // Add authorStreak retrieval
      'createdAt': data['createdAt'] ?? Timestamp.now(),
      'upvotes': data['upvotes'] ?? 0,
      'upvotedBy': data['upvotedBy'] ?? <String>[],
      'commentCount': data['commentCount'] ?? 0,
      'sample': data['sample'] ?? false, // Add sample flag with default false
    };
    
    return PostModel.fromJson(safeData);
  }
} 