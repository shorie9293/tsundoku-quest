/// Hive implementation of ReadingSessionRepository
///
/// Uses the 'reading_sessions_box' Hive box for session persistence.
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:uuid/uuid.dart';

class HiveReadingSessionRepository implements ReadingSessionRepository {
  final BoxManagerInterface _boxManager;
  static const _uuid = Uuid();

  HiveReadingSessionRepository(this._boxManager);

  Box<ReadingSession>? _box;

  Future<Box<ReadingSession>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await _boxManager.getBox<ReadingSession>(BoxNames.readingSessions);
    return _box!;
  }

  // ── Read operations ──

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) async {
    try {
      final box = await _getBox();
      final all = BoxHelper.loadCollection(box);
      return all
          .where((s) => s.userBookId == userBookId)
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    } catch (e) {
      debugPrint('[HiveReadingSessionRepo] getByUserBook failed: $e');
      return [];
    }
  }

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async {
    try {
      final box = await _getBox();
      final all = BoxHelper.loadCollection(box);
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all.take(limit).toList();
    } catch (e) {
      debugPrint('[HiveReadingSessionRepo] getRecentSessions failed: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getAllReadingDates() async {
    try {
      final box = await _getBox();
      final all = BoxHelper.loadCollection(box);
      final dateSet = <String>{};
      for (final session in all) {
        final dateStr = session.startedAt.length >= 10
            ? session.startedAt.substring(0, 10)
            : session.startedAt;
        dateSet.add(dateStr);
      }
      final result = dateSet.toList()..sort((a, b) => b.compareTo(a));
      return result;
    } catch (e) {
      debugPrint('[HiveReadingSessionRepo] getAllReadingDates failed: $e');
      return [];
    }
  }

  @override
  Future<int> getTotalReadingMinutes(String userBookId) async {
    try {
      final sessions = await getByUserBook(userBookId);
      return sessions.fold<int>(
        0,
        (sum, s) => sum + (s.durationMinutes ?? 0),
      );
    } catch (e) {
      debugPrint('[HiveReadingSessionRepo] getTotalReadingMinutes failed: $e');
      return 0;
    }
  }

  // ── Write operations ──

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async {
    final box = await _getBox();
    final now = DateTime.now().toUtc().toIso8601String();
    final session = ReadingSession(
      id: _uuid.v4(),
      userBookId: userBookId,
      startedAt: now,
      startPage: startPage,
      createdAt: now,
    );
    await box.put(session.id, session);
    await box.flush();
    return session;
  }

  @override
  Future<ReadingSession> endSession(
    String sessionId,
    int endPage,
    int durationMinutes,
  ) async {
    final box = await _getBox();
    final existing = box.get(sessionId);
    if (existing == null) {
      throw StateError('Session not found: $sessionId');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = ReadingSession(
      id: existing.id,
      userBookId: existing.userBookId,
      startedAt: existing.startedAt,
      endedAt: now,
      startPage: existing.startPage,
      endPage: endPage,
      durationMinutes: durationMinutes,
      createdAt: existing.createdAt,
    );
    await box.put(sessionId, updated);
    await box.flush();
    return updated;
  }

  // ━━━ Aggregation methods ━━━

  @override
  Future<int> getTotalReadingMinutesAll() async {
    try {
      final box = await _getBox();
      final all = BoxHelper.loadCollection(box);
      return all.fold<int>(
        0,
        (sum, s) => sum + (s.durationMinutes ?? 0),
      );
    } catch (e) {
      debugPrint('[HiveReadingSessionRepo] getTotalReadingMinutesAll failed: $e');
      return 0;
    }
  }

  @override
  Future<int> getTotalPagesReadAll() async {
    try {
      final box = await _getBox();
      final all = BoxHelper.loadCollection(box);
      return all.fold<int>(0, (sum, s) {
        if (s.endPage != null) {
          final pages = s.endPage! - s.startPage;
          if (pages > 0) return sum + pages;
        }
        return sum;
      });
    } catch (e) {
      debugPrint('[HiveReadingSessionRepo] getTotalPagesReadAll failed: $e');
      return 0;
    }
  }

  @override
  Future<List<int>> getWeeklyReadingMinutes() async {
    try {
      final box = await _getBox();
      final all = BoxHelper.loadCollection(box);
      final now = DateTime.now().toUtc();
      final weekStart = now.subtract(const Duration(days: 6));
      final dailyMinutes = List.filled(7, 0);

      for (final session in all) {
        if (session.durationMinutes == null) continue;
        try {
          final ts = session.startedAt.length >= 10
              ? session.startedAt.substring(0, 10)
              : session.startedAt;
          final date = DateTime.parse(ts);
          final diff = date.difference(weekStart).inDays;
          if (diff >= 0 && diff < 7) {
            dailyMinutes[diff] += session.durationMinutes!;
          }
        } catch (_) {}
      }
      return dailyMinutes;
    } catch (e) {
      debugPrint('[HiveReadingSessionRepo] getWeeklyReadingMinutes failed: $e');
      return List.filled(7, 0);
    }
  }

  @override
  Future<int> getCurrentStreak() async {
    final dates = await getAllReadingDates();
    if (dates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    if (dates[0] != todayStr && dates[0] != yesterdayStr) return 0;

    int streak = 1;
    for (int i = 1; i < dates.length; i++) {
      final current = DateTime.parse(dates[i - 1]);
      final prev = DateTime.parse(dates[i]);
      if (current.difference(prev).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Future<int> getLongestStreak() async {
    final dates = await getAllReadingDates();
    if (dates.isEmpty) return 0;

    int longest = 1;
    int current = 1;
    for (int i = 1; i < dates.length; i++) {
      final prev = DateTime.parse(dates[i - 1]);
      final curr = DateTime.parse(dates[i]);
      if (prev.difference(curr).inDays == 1) {
        current++;
      } else {
        if (current > longest) longest = current;
        current = 1;
      }
    }
    if (current > longest) longest = current;
    return longest;
  }

  /// Close the underlying box
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
