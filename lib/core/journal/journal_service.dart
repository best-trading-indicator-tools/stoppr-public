import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class JournalEntry {
  final String id;
  final String? title;
  final String content;
  final DateTime createdAt;
  final bool isRelapseEntry;

  JournalEntry({
    required this.id,
    this.title,
    required this.content,
    required this.createdAt,
    this.isRelapseEntry = false,
  });

  JournalEntry copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    bool? isRelapseEntry,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isRelapseEntry: isRelapseEntry ?? this.isRelapseEntry,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'isRelapseEntry': isRelapseEntry,
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      isRelapseEntry: json['isRelapseEntry'] ?? false,
    );
  }
}

class JournalService {
  static const String _storageKey = 'journal_entries';

  // Get all journal entries
  Future<List<JournalEntry>> getJournalEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_storageKey) ?? [];
    
    return entriesJson
        .map((json) => JournalEntry.fromJson(jsonDecode(json)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by newest first
  }

  // Add a new journal entry
  Future<void> addJournalEntry({
    String? title,
    required String content,
    bool isRelapseEntry = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getJournalEntries();
    
    final newEntry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      createdAt: DateTime.now(),
      isRelapseEntry: isRelapseEntry,
    );
    
    entries.add(newEntry);
    
    final entriesJsonList = entries
        .map((entry) => jsonEncode(entry.toJson()))
        .toList();
    
    await prefs.setStringList(_storageKey, entriesJsonList);
  }

  // Add a journal entry specifically for relapse feelings
  Future<void> addRelapseJournalEntry({
    String? title,
    required String content,
  }) async {
    return addJournalEntry(
      title: title ?? 'Relapse Reflection',
      content: content,
      isRelapseEntry: true,
    );
  }

  // Delete a journal entry
  Future<void> deleteJournalEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getJournalEntries();
    
    final filteredEntries = entries.where((entry) => entry.id != id).toList();
    
    final entriesJsonList = filteredEntries
        .map((entry) => jsonEncode(entry.toJson()))
        .toList();
    
    await prefs.setStringList(_storageKey, entriesJsonList);
  }

  // Update a journal entry
  Future<void> updateJournalEntry(JournalEntry updatedEntry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getJournalEntries();
    
    final index = entries.indexWhere((entry) => entry.id == updatedEntry.id);
    if (index != -1) {
      entries[index] = updatedEntry;
      
      final entriesJsonList = entries
          .map((entry) => jsonEncode(entry.toJson()))
          .toList();
      
      await prefs.setStringList(_storageKey, entriesJsonList);
    }
  }
} 