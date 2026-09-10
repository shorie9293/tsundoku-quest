import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';

/// Supabase 失敗時に Hive へフォールバックする読書セッションリポジトリ。
///
/// 禍津: readingScreen の startSession がオフライン等で失敗すると
/// _sessionId が null のままになり、その後の読書時間がどこにも
/// 永続化されず消失していた。
///
/// 方針:
/// - startSession: プライマリ（Supabase）失敗 → ローカル（Hive）で作成し、
///   id に 'local:' プレフィックスを付けてローカル発である印を付ける
/// - endSession: 'local:' 付き id はローカルで完結。それ以外はプライマリへ
/// - 集計系（getAllReadingDates 等）はプライマリとローカルをマージ
class FallbackReadingSessionRepository implements ReadingSessionRepository {
  final ReadingSessionRepository _primary;
  final ReadingSessionRepository _local;
  final BoxManagerInterface _boxManager;

  /// ローカル発セッションのプレフィックス
  static const _localPrefix = 'local:';

  /// 同期処理の再入防止ガード
  bool _isSyncing = false;

  FallbackReadingSessionRepository({
    required ReadingSessionRepository primary,
    required ReadingSessionRepository local,
    required BoxManagerInterface boxManager,
  })  : _primary = primary,
        _local = local,
        _boxManager = boxManager;

  /// オンライン復帰時にローカルで完結したセッションを Supabase へ同期する。
  ///
  /// ローカル退避セッションの完了データは「プレフィックス無しの元キー」に
  /// 保存されている（_local.endSession が更新するため）。
  /// 同期には createSession を使い、元の startedAt/endedAt/duration を
  /// 保持したまま INSERT する（タイムスタンプのシフト防止）。
  /// 再実行防止のため _isSyncing ガードを持つ。
  Future<void> syncLocalSessionsToRemote() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final box = await _boxManager.getBox<ReadingSession>(
          BoxNames.readingSessions);
      final markedIds = box.values
          .where((s) => s.id.startsWith(_localPrefix))
          .map((s) => s.id)
          .toList();
      for (final markedId in markedIds) {
        try {
          final rawId = markedId.substring(_localPrefix.length);
          // 完了データは元キー（プレフィックス無し）に保存されている
          final completed = box.get(rawId);
          if (completed == null) continue;

          await _primary.createSession(completed);

          // 同期成功 → local: 印行と元キー行の両方を削除。
          // 元キー行を残すと集計系（getTotalReadingMinutesAll 等）が
          // primary と local を加算するため同一セッションを二重カウントする。
          await box.delete(markedId);
          await box.delete(rawId);
          await box.flush();
        } catch (e) {
          debugPrint('⚠️ [FallbackSession] 同期失敗（次回再試行）: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [FallbackSession] 同期処理失敗: $e');
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async {
    try {
      return await _primary.startSession(userBookId, startPage);
    } catch (e) {
      debugPrint('⚠️ [FallbackSession] startSession 失敗、ローカルに退避: $e');
      final session = await _local.startSession(userBookId, startPage);
      // ローカル発セッションであることを示すプレフィックス付きIDで上書き保存
      // （元の session.id キーは保持する。endSession が sessionId を剥がして
      //  元キーで検索するため削除すると Session not found になる）
      final localMarked = ReadingSession(
        id: '$_localPrefix${session.id}',
        userBookId: session.userBookId,
        startedAt: session.startedAt,
        startPage: session.startPage,
        createdAt: session.createdAt,
      );
      final box =
          await _boxManager.getBox<ReadingSession>(BoxNames.readingSessions);
      await box.put(localMarked.id, localMarked);
      await box.flush();
      return localMarked;
    }
  }

  @override
  Future<ReadingSession> endSession(
    String sessionId,
    int endPage,
    int durationMinutes,
  ) async {
    if (sessionId.startsWith(_localPrefix)) {
      return _local.endSession(
          sessionId.substring(_localPrefix.length), endPage, durationMinutes);
    }
    return _primary.endSession(sessionId, endPage, durationMinutes);
  }

  @override
  Future<ReadingSession> createSession(ReadingSession session) async {
    return _primary.createSession(session);
  }

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) async {
    try {
      return await _primary.getByUserBook(userBookId);
    } catch (_) {
      return _local.getByUserBook(userBookId);
    }
  }

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async {
    try {
      return await _primary.getRecentSessions(limit: limit);
    } catch (_) {
      return _local.getRecentSessions(limit: limit);
    }
  }

  @override
  Future<List<String>> getAllReadingDates() async {
    List<String> primaryDates = const [];
    try {
      primaryDates = await _primary.getAllReadingDates();
    } catch (_) {}
    final localDates = await _local.getAllReadingDates();
    final merged = {...primaryDates, ...localDates}.toList()
      ..sort((a, b) => b.compareTo(a));
    return merged;
  }

  @override
  Future<int> getTotalReadingMinutes(String userBookId) async {
    int primaryMinutes = 0;
    try {
      primaryMinutes = await _primary.getTotalReadingMinutes(userBookId);
    } catch (_) {}
    final localMinutes = await _local.getTotalReadingMinutes(userBookId);
    return primaryMinutes + localMinutes;
  }

  @override
  Future<int> getTotalReadingMinutesAll() async {
    int primaryMinutes = 0;
    try {
      primaryMinutes = await _primary.getTotalReadingMinutesAll();
    } catch (_) {}
    final localMinutes = await _local.getTotalReadingMinutesAll();
    return primaryMinutes + localMinutes;
  }

  @override
  Future<int> getTotalPagesReadAll() async {
    int primaryPages = 0;
    try {
      primaryPages = await _primary.getTotalPagesReadAll();
    } catch (_) {}
    final localPages = await _local.getTotalPagesReadAll();
    return primaryPages + localPages;
  }

  @override
  Future<List<int>> getWeeklyReadingMinutes() async {
    List<int> primaryWeekly = List.filled(7, 0);
    try {
      primaryWeekly = await _primary.getWeeklyReadingMinutes();
    } catch (_) {}
    final localWeekly = await _local.getWeeklyReadingMinutes();
    return List.generate(
        7, (i) => primaryWeekly[i] + localWeekly[i]);
  }

  @override
  Future<int> getCurrentStreak() async {
    final dates = await getAllReadingDates();
    if (dates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final yesterday = today.subtract(const Duration(days: 1));
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
}
