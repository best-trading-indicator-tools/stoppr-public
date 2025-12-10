import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_model.freezed.dart';
part 'comment_model.g.dart';

// Helper functions for Timestamp conversion
Timestamp _timestampToJson(DateTime date) => Timestamp.fromDate(date);
DateTime _timestampFromJson(Timestamp timestamp) => timestamp.toDate();

@freezed
class CommentModel with _$CommentModel {
  const factory CommentModel({
    required String id,
    required String postId, // To know which post this comment belongs to
    required String text,
    required String authorId,
    required String authorName, // Denormalized for easy display
    @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
    required DateTime createdAt,
  }) = _CommentModel;

  factory CommentModel.fromJson(Map<String, dynamic> json) =>
      _$CommentModelFromJson(json);

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      
      // Create a safe version of the data with required fields
      final safeData = {
        'id': doc.id,
        'postId': data['postId'] ?? '',
        'text': data['text'] ?? 'No text provided',
        'authorId': data['authorId'] ?? 'unknown_user',
        'authorName': data['authorName'] ?? 'Unknown User',
        'createdAt': data['createdAt'] ?? Timestamp.now(),
      };
      
      return CommentModel.fromJson(safeData);
    } catch (e) {
      // In case of any error, return a default comment
      print('Error converting comment document ${doc.id}: $e');
      return CommentModel(
        id: doc.id,
        postId: '',
        text: 'Error loading comment',
        authorId: 'unknown',
        authorName: 'Unknown',
        createdAt: DateTime.now(),
      );
    }
  }
} 