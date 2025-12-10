import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Article extends Equatable {
  final String id;
  final String title;
  final String category;
  final int order;
  // final String? content; // Content can be loaded separately or later
  final String? contentPath; // Path to the markdown file in assets

  const Article({
    required this.id,
    required this.title,
    required this.category,
    required this.order,
    // this.content,
    this.contentPath,
  });

  @override
  // List<Object?> get props => [id, title, category, order, content];
  List<Object?> get props => [id, title, category, order, contentPath];

  // Factory constructor to create an Article from a Firestore document
  factory Article.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Article(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      order: data['order'] ?? 0,
      // content: data['content'], // Content might not always be present in list views
      contentPath: data['contentPath'], // Get path from Firestore
    );
  }

   // Method to create an Article from a map (e.g., when reading from other sources)
  factory Article.fromJson(Map<String, dynamic> json, {required String id}) {
    return Article(
      id: id,
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      order: json['order'] ?? 0,
      // content: json['content'],
      contentPath: json['contentPath'],
    );
  }

  // Method to convert Article instance to a map, useful for saving
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'category': category,
      'order': order,
      // if (content != null) 'content': content,
      if (contentPath != null) 'contentPath': contentPath, // Save path to Firestore
    };
  }


  Article copyWith({
    String? id,
    String? title,
    String? category,
    int? order,
    // String? content,
    String? contentPath,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      order: order ?? this.order,
      // content: content ?? this.content,
      contentPath: contentPath ?? this.contentPath,
    );
  }
} 