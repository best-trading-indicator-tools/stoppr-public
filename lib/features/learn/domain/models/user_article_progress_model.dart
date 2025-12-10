import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserArticleProgress extends Equatable {
  // Map where key is articleId and value is the completion timestamp
  final Map<String, DateTime> completedArticles;

  const UserArticleProgress({
    this.completedArticles = const {},
  });

  @override
  List<Object?> get props => [completedArticles];

  // Check if a specific article is completed
  bool isCompleted(String articleId) {
    return completedArticles.containsKey(articleId);
  }

  // Factory constructor from Firestore data
  factory UserArticleProgress.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    Map<String, dynamic> completedMap = data['completed_articles'] as Map<String, dynamic>? ?? {};

    Map<String, DateTime> completedArticles = completedMap.map(
      (key, value) => MapEntry(
        key,
        (value as Timestamp).toDate(), // Convert Firestore Timestamp to DateTime
      ),
    );

    return UserArticleProgress(
      completedArticles: completedArticles,
    );
  }

  // Convert to a map for Firestore
  Map<String, dynamic> toJson() {
    // Convert DateTime back to Firestore Timestamp for storage
    Map<String, Timestamp> completedTimestamps = completedArticles.map(
      (key, value) => MapEntry(key, Timestamp.fromDate(value)),
    );
    return {
      'completed_articles': completedTimestamps,
    };
  }

  // Factory constructor from JSON (e.g., Shared Preferences)
 factory UserArticleProgress.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> completedMap = json['completed_articles'] as Map<String, dynamic>? ?? {};
    Map<String, DateTime> completedArticles = completedMap.map(
      (key, value) {
        // Handle potential String format from JSON
        DateTime? dateTime = DateTime.tryParse(value.toString());
        return MapEntry(key, dateTime ?? DateTime.now()); // Use now() as fallback
       } 
    );
    return UserArticleProgress(
      completedArticles: completedArticles,
    );
  }

  // Method to convert to JSON map for SharedPreferences
  Map<String, dynamic> toJsonForPrefs() {
    Map<String, String> completedIsoStrings = completedArticles.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
     return {
      'completed_articles': completedIsoStrings,
    };
  }


  UserArticleProgress copyWith({
    Map<String, DateTime>? completedArticles,
  }) {
    return UserArticleProgress(
      completedArticles: completedArticles ?? this.completedArticles,
    );
  }
} 