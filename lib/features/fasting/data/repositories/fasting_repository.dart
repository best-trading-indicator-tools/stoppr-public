import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import '../models/fast_log.dart';

class FastingRepository {
  // Local-only persistence using SharedPreferences
  static const String _storeKey = 'fasting_logs_v1';
  static const String _cacheKey = 'fasting_active_cache_v1'; // kept for compatibility

  static List<FastLog> _logs = <FastLog>[];
  static bool _loaded = false;
  static final StreamController<List<FastLog>> _changes =
      StreamController<List<FastLog>>.broadcast();

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    _logs = raw == null ? <FastLog>[] : FastLog.decodeList(raw);
    _loaded = true;
    _emit();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeKey, FastLog.encodeList(_logs));
  }

  void _emit() => _changes.add(List<FastLog>.unmodifiable(_logs));
  void emitNow() => _emit();

  String _nextId() => DateTime.now().microsecondsSinceEpoch.toString();

  // Statistics calculations
  Future<int> getCurrentStreak() async {
    await _ensureLoaded();
    final completed = _logs
        .where((f) => f.status == 'completed' && !f.isDeleted && f.endAt != null)
        .toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    
    if (completed.isEmpty) return 0;
    
    int streak = 0;
    DateTime? lastDate;
    
    for (final fast in completed) {
      final fastDate = DateTime(fast.startAt.year, fast.startAt.month, fast.startAt.day);
      
      if (lastDate == null) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final yesterday = todayDate.subtract(const Duration(days: 1));
        
        if (fastDate.isAtSameMomentAs(todayDate) || fastDate.isAtSameMomentAs(yesterday)) {
          streak = 1;
          lastDate = fastDate;
        } else {
          break;
        }
      } else {
        final expectedDate = lastDate.subtract(const Duration(days: 1));
        if (fastDate.isAtSameMomentAs(expectedDate)) {
          streak++;
          lastDate = fastDate;
        } else {
          break;
        }
      }
    }
    
    return streak;
  }
  
  Future<int> getWeekCount() async {
    await _ensureLoaded();
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    
    return _logs
        .where((f) => 
            f.status == 'completed' && 
            !f.isDeleted && 
            f.startAt.isAfter(weekStartDate))
        .length;
  }
  
  Future<FastLog?> getLongestFast() async {
    await _ensureLoaded();
    final completed = _logs
        .where((f) => f.status == 'completed' && !f.isDeleted && f.endAt != null)
        .toList();
    
    if (completed.isEmpty) return null;
    
    FastLog? longest;
    int maxMinutes = 0;
    
    for (final fast in completed) {
      if (fast.actualMinutes > maxMinutes) {
        maxMinutes = fast.actualMinutes;
        longest = fast;
      }
    }
    
    return longest;
  }
  
  Future<int> getMonthCount() async {
    await _ensureLoaded();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    
    return _logs
        .where((f) => 
            f.status == 'completed' && 
            !f.isDeleted && 
            f.startAt.isAfter(monthStart))
        .length;
  }

  Stream<List<FastLog>> watchRecent({int days = 7}) {
    _ensureLoaded();
    final DateTime now = DateTime.now();
    final DateTime since = now.subtract(Duration(days: days + 1));
    final controller = StreamController<List<FastLog>>.broadcast();
    void push(List<FastLog> all) {
      final list = all
          .where((f) => !f.isDeleted && f.startAt.isAfter(since))
          .toList()
        ..sort((a, b) => b.startAt.compareTo(a.startAt));
      controller.add(list);
    }
    final sub = _changes.stream.listen(push);
    if (_loaded) push(_logs);
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  Future<FastLog> startFast({
    required DateTime startAt,
    required int targetMinutes,
    int milestoneMinutes = 720,
  }) async {
    await _ensureLoaded();
    // If an active fast exists, end it at the new start to let the new one take over
    for (int i = 0; i < _logs.length; i++) {
      final f = _logs[i];
      if (f.status == 'active' && f.endAt == null && !f.isDeleted) {
        final DateTime endOld = startAt;
        final int actualOld = endOld.isAfter(f.startAt)
            ? endOld.difference(f.startAt).inMinutes
            : 0;
        _logs[i] = FastLog(
          id: f.id,
          startAt: f.startAt,
          endAt: endOld,
          targetMinutes: f.targetMinutes,
          actualMinutes: actualOld,
          status: 'completed',
          createdAt: f.createdAt,
          updatedAt: DateTime.now(),
          isDeleted: f.isDeleted,
          milestoneMinutes: f.milestoneMinutes,
        );
        break;
      }
    }
    final DateTime endAt = startAt.add(Duration(minutes: targetMinutes));
    final bool overlaps = await _hasOverlap(startAt: startAt, endAt: endAt);
    if (overlaps) throw StateError('overlap');
    final DateTime now = DateTime.now();
    final FastLog log = FastLog(
      id: _nextId(),
      startAt: startAt,
      endAt: null,
      targetMinutes: targetMinutes,
      actualMinutes: 0,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      milestoneMinutes: milestoneMinutes,
    );
    _logs = <FastLog>[log, ..._logs];
    await _save();
    await _cacheActive(log);
    _emit();
    debugPrint('FastingRepository.startFast: created local fast id=${log.id}');
    
    // Schedule motivational notifications (4h, 2h, complete)
    try {
      final DateTime fastEndAt = startAt.add(Duration(minutes: targetMinutes));
      await NotificationService().scheduleFastingMotivationalNotifications(
        endAt: fastEndAt,
      );
      debugPrint('FastingRepository.startFast: Scheduled motivational notifications for fast ending at ${fastEndAt.toIso8601String()}');
    } catch (e) {
      debugPrint('FastingRepository.startFast: Failed to schedule notifications: $e');
    }
    
    return log;
  }

  Future<void> endFast(String id, DateTime endAt) async {
    await _ensureLoaded();
    for (int i = 0; i < _logs.length; i++) {
      if (_logs[i].id == id) {
        final start = _logs[i].startAt;
        final actual = endAt.difference(start).inMinutes;
        _logs[i] = FastLog(
          id: _logs[i].id,
          startAt: _logs[i].startAt,
          endAt: endAt,
          targetMinutes: _logs[i].targetMinutes,
          actualMinutes: actual,
          status: 'completed',
          createdAt: _logs[i].createdAt,
          updatedAt: DateTime.now(),
          isDeleted: _logs[i].isDeleted,
          milestoneMinutes: _logs[i].milestoneMinutes,
        );
        break;
      }
    }
    await _save();
    await _clearCachedActive();
    _emit();
    debugPrint('FastingRepository.endFast: updated local fast id=$id');
    
    // Cancel motivational notifications when fast ends
    try {
      await NotificationService().cancelFastingMotivationalNotifications();
      debugPrint('FastingRepository.endFast: Cancelled motivational notifications');
    } catch (e) {
      debugPrint('FastingRepository.endFast: Failed to cancel notifications: $e');
    }
  }

  Future<FastLog?> getActiveFast() async {
    await _ensureLoaded();
    try {
      final FastLog? log = _logs.firstWhere(
        (f) => f.status == 'active' && f.endAt == null && !f.isDeleted,
      );
      if (log != null) {
        await _cacheActive(log);
        return log;
      }
    } catch (_) {}
    return _readCachedActive();
  }

  // Create a past fast (completed) with overlap prevention
  Future<void> addPastFast({
    required DateTime startAt,
    required DateTime endAt,
    required int targetMinutes,
    int milestoneMinutes = 720,
  }) async {
    await _ensureLoaded();
    if (!endAt.isAfter(startAt)) throw StateError('invalid_range');
    final overlaps = await _hasOverlap(startAt: startAt, endAt: endAt);
    if (overlaps) throw StateError('overlap');
    final actual = endAt.difference(startAt).inMinutes;
    final now = DateTime.now();
    _logs = <FastLog>[
      FastLog(
        id: _nextId(),
        startAt: startAt,
        endAt: endAt,
        targetMinutes: targetMinutes,
        actualMinutes: actual,
        status: 'completed',
        createdAt: now,
        updatedAt: now,
        milestoneMinutes: milestoneMinutes,
      ),
      ..._logs,
    ];
    await _save();
    _emit();
  }

  Future<bool> _hasOverlap({required DateTime startAt, required DateTime endAt, String? excludeId}) async {
    await _ensureLoaded();
    for (final f in _logs) {
      if (excludeId != null && f.id == excludeId) continue;
      if (f.isDeleted) continue;
      final DateTime s = f.startAt;
      final DateTime e = f.endAt ?? DateTime(9999);
      final bool overlaps = s.isBefore(endAt) && e.isAfter(startAt);
      if (overlaps) return true;
    }
    return false;
  }

  Future<void> updateFastStart({required String id, required DateTime newStart}) async {
    await _ensureLoaded();
    for (int i = 0; i < _logs.length; i++) {
      if (_logs[i].id == id) {
        final int target = _logs[i].targetMinutes;
        final DateTime endAt = _logs[i].endAt ?? newStart.add(Duration(minutes: target));
        if (endAt.isBefore(newStart)) throw StateError('invalid_range');
        final overlaps = await _hasOverlap(startAt: newStart, endAt: endAt, excludeId: id);
        if (overlaps) throw StateError('overlap');
        _logs[i] = FastLog(
          id: _logs[i].id,
          startAt: newStart,
          endAt: _logs[i].endAt,
          targetMinutes: _logs[i].targetMinutes,
          actualMinutes: _logs[i].actualMinutes,
          status: _logs[i].status,
          createdAt: _logs[i].createdAt,
          updatedAt: DateTime.now(),
          isDeleted: _logs[i].isDeleted,
          milestoneMinutes: _logs[i].milestoneMinutes,
        );
        break;
      }
    }
    await _save();
    await _clearCachedActive();
    _emit();
    
    // Reschedule motivational notifications with new start time
    try {
      for (final f in _logs) {
        if (f.id == id && f.status == 'active') {
          final DateTime newEndAt = newStart.add(Duration(minutes: f.targetMinutes));
          await NotificationService().scheduleFastingMotivationalNotifications(
            endAt: newEndAt,
          );
          debugPrint('FastingRepository.updateFastStart: Rescheduled notifications for new end time ${newEndAt.toIso8601String()}');
          break;
        }
      }
    } catch (e) {
      debugPrint('FastingRepository.updateFastStart: Failed to reschedule notifications: $e');
    }
  }

  Future<void> updateFastTarget({required String id, required int newTargetMinutes}) async {
    await _ensureLoaded();
    for (int i = 0; i < _logs.length; i++) {
      if (_logs[i].id == id) {
        _logs[i] = FastLog(
          id: _logs[i].id,
          startAt: _logs[i].startAt,
          endAt: _logs[i].endAt,
          targetMinutes: newTargetMinutes,
          actualMinutes: _logs[i].actualMinutes,
          status: _logs[i].status,
          createdAt: _logs[i].createdAt,
          updatedAt: DateTime.now(),
          isDeleted: _logs[i].isDeleted,
          milestoneMinutes: _logs[i].milestoneMinutes,
        );
        break;
      }
    }
    await _save();
    await _clearCachedActive();
    _emit();
    
    // Reschedule motivational notifications with new target
    try {
      for (final f in _logs) {
        if (f.id == id && f.status == 'active') {
          final DateTime newEndAt = f.startAt.add(Duration(minutes: newTargetMinutes));
          await NotificationService().scheduleFastingMotivationalNotifications(
            endAt: newEndAt,
          );
          debugPrint('FastingRepository.updateFastTarget: Rescheduled notifications for new end time ${newEndAt.toIso8601String()}');
          break;
        }
      }
    } catch (e) {
      debugPrint('FastingRepository.updateFastTarget: Failed to reschedule notifications: $e');
    }
  }

  Stream<List<FastLog>> watchDay(DateTime day) {
    _ensureLoaded();
    final DateTime start = DateTime(day.year, day.month, day.day);
    final DateTime end = start.add(const Duration(days: 1));
    final controller = StreamController<List<FastLog>>.broadcast();
    void push(List<FastLog> all) {
      controller.add(
        all
            .where((f) {
              if (f.isDeleted) return false;
              final bool startsInDay = f.startAt.isAfter(start.subtract(const Duration(milliseconds: 1))) && f.startAt.isBefore(end);
              final bool endsInDay = f.endAt != null && f.endAt!.isAfter(start.subtract(const Duration(milliseconds: 1))) && f.endAt!.isBefore(end);
              final bool activeInDay = f.endAt == null && f.status == 'active' && DateTime.now().isAfter(start) && DateTime.now().isBefore(end);
              return startsInDay || endsInDay || activeInDay;
            })
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt)),
      );
    }
    final sub = _changes.stream.listen(push);
    if (_loaded) push(_logs);
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  Future<void> _cacheActive(FastLog log) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, FastLog.encodeList([log]));
  }

  Future<FastLog?> _readCachedActive() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    final list = FastLog.decodeList(raw);
    return list.isNotEmpty ? list.first : null;
  }

  Future<void> _clearCachedActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  // Firestore adapter removed; local-only repository
}


