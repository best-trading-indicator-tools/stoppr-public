import 'dart:convert';

class FastLog {
  final String id;
  final DateTime startAt;
  final DateTime? endAt;
  final int targetMinutes;
  final int actualMinutes;
  final String status; // active | completed | cancelled
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final int milestoneMinutes; // e.g., 12h = 720

  const FastLog({
    required this.id,
    required this.startAt,
    this.endAt,
    required this.targetMinutes,
    required this.actualMinutes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.milestoneMinutes = 720,
  });

  bool get isActive => status == 'active' && endAt == null;

  int get elapsedMinutes {
    final DateTime end = endAt ?? DateTime.now();
    return end.difference(startAt).inMinutes.clamp(0, 1 << 31);
  }

  double get progress => targetMinutes > 0
      ? (elapsedMinutes / targetMinutes).clamp(0.0, 1.0)
      : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'start_at': startAt.toIso8601String(),
        'end_at': endAt?.toIso8601String(),
        'target_minutes': targetMinutes,
        'actual_minutes': actualMinutes,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted,
        'milestone_minutes': milestoneMinutes,
      };

  static FastLog fromJson(Map<String, dynamic> json) => FastLog(
        id: json['id'] as String,
        startAt: DateTime.parse(json['start_at'] as String),
        endAt: json['end_at'] != null
            ? DateTime.parse(json['end_at'] as String)
            : null,
        targetMinutes: (json['target_minutes'] as num).toInt(),
        actualMinutes: (json['actual_minutes'] as num).toInt(),
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        isDeleted: (json['is_deleted'] as bool?) ?? false,
        milestoneMinutes: (json['milestone_minutes'] as num?)?.toInt() ?? 720,
      );

  static String encodeList(List<FastLog> logs) => jsonEncode(
        logs.map((e) => e.toJson()).toList(),
      );

  static List<FastLog> decodeList(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(FastLog.fromJson)
          .toList();
    } catch (_) {
      return <FastLog>[];
    }
  }
}


