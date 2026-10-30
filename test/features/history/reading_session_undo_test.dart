// 読書記録の削除 Undo（元に戻す）配線の widget 試練。
//
// fake リポジトリは同ディレクトリの既存試練（reading_session_log_screen_test.dart）
// の流儀をそのまま流用する。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/history/presentation/reading_session_log_screen.dart';
import 'package:tsundoku_quest/features/reading/domain/reading_session_editor_service.dart';
import 'package:tsundoku_quest/features/undo/presentation/undo_snack_bar.dart';

/// InMemory フェイク（全メソッド実装・create/update/delete は内部リストを実更新）
class InMemorySessionRepo implements ReadingSessionRepository {
  final List<ReadingSession> sessions;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  InMemorySessionRepo([List<ReadingSession>? initial])
      : sessions = List.of(initial ?? const []);

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async {
    final sorted = List.of(sessions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<ReadingSession> createSession(ReadingSession session) async {
    createCalls++;
    sessions.add(session);
    return session;
  }

  @override
  Future<void> updateSession(ReadingSession session) async {
    updateCalls++;
    final i = sessions.indexWhere((s) => s.id == session.id);
    if (i >= 0) {
      sessions[i] = session;
    } else {
      sessions.add(session);
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    deleteCalls++;
    sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) async =>
      sessions.where((s) => s.userBookId == userBookId).toList();

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async {
    final s = ReadingSession(
      id: 'started',
      userBookId: userBookId,
      startedAt: DateTime.now().toUtc().toIso8601String(),
      startPage: startPage,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    sessions.add(s);
    return s;
  }

  @override
  Future<ReadingSession> endSession(
      String sessionId, int endPage, int durationMinutes) async {
    final i = sessions.indexWhere((s) => s.id == sessionId);
    final s = sessions[i];
    final updated = ReadingSession(
      id: s.id,
      userBookId: s.userBookId,
      startedAt: s.startedAt,
      endedAt: DateTime.now().toUtc().toIso8601String(),
      startPage: s.startPage,
      endPage: endPage,
      durationMinutes: durationMinutes,
      createdAt: s.createdAt,
    );
    sessions[i] = updated;
    return updated;
  }

  @override
  Future<List<String>> getAllReadingDates() async => const [];

  @override
  Future<int> getTotalReadingMinutes(String userBookId) async => 0;

  @override
  Future<int> getTotalReadingMinutesAll() async => 0;

  @override
  Future<int> getTotalPagesReadAll() async => 0;

  @override
  Future<List<int>> getWeeklyReadingMinutes() async =>
      List<int>.filled(7, 0, growable: false);

  @override
  Future<int> getCurrentStreak() async => 0;

  @override
  Future<int> getLongestStreak() async => 0;
}

ReadingSession _session(String id, String userBookId, int duration) {
  return ReadingSessionEditorService.buildManual(
    id: id,
    userBookId: userBookId,
    startedAt: DateTime(2026, 10, 3, 10, 0),
    durationMinutes: duration,
    startPage: 1,
    endPage: 10,
    createdAt: DateTime(2026, 10, 3, 12, 0),
  );
}

UserBook _book(String id, String title) => UserBook(
      id: id,
      userId: 'u1',
      bookId: 'b_$id',
      book: Book(
        id: 'b_$id',
        title: title,
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      ),
      status: BookStatus.reading,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

Future<void> _pumpScreen(
  WidgetTester tester, {
  required InMemorySessionRepo repo,
}) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: ReadingSessionLogScreen(
        repositoryOverride: repo,
        booksOverride: [_book('ub1', 'テスト本')],
        nowOverride: () => DateTime(2026, 10, 4, 21, 30),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// 削除ボタン→確認ダイアログ「削除」までを踏む。
Future<void> _deleteFirstSession(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(AppKeys.readingSessionDeleteButton(id)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(AppKeys.readingSessionDeleteConfirm));
  await tester.pumpAndSettle();
}

/// SnackBar の 5 秒タイマーを流し切る（pending timer を残さない）。
Future<void> _drainSnackBar(WidgetTester tester) async {
  // 表示アニメーション完了後に 5 秒タイマーが始まるため、まず settle する
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('削除すると確認後に SnackBar へ「元に戻す」が出る', (tester) async {
    final repo = InMemorySessionRepo([_session('s1', 'ub1', 30)]);
    await _pumpScreen(tester, repo: repo);

    await _deleteFirstSession(tester, 's1');

    // 削除は即時実行のまま（確認ダイアログは既存挙動）
    expect(repo.deleteCalls, 1);
    expect(find.byKey(AppKeys.readingSessionLogEmpty), findsOneWidget);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('読書記録を削除しました'), findsOneWidget);
    expect(find.byKey(undoActionKey), findsOneWidget);
    expect(find.text('元に戻す'), findsOneWidget);

    await _drainSnackBar(tester);
  });

  testWidgets('「元に戻す」タップで同一 id の記録が復元され一覧に戻る', (tester) async {
    final repo = InMemorySessionRepo([_session('s1', 'ub1', 30)]);
    await _pumpScreen(tester, repo: repo);
    await _deleteFirstSession(tester, 's1');

    await tester.tap(find.byKey(undoActionKey));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
    expect(repo.deleteCalls, 1);
    expect(repo.sessions, hasLength(1));
    expect(repo.sessions.single.id, 's1');
    expect(repo.sessions.single.durationMinutes, 30);
    expect(repo.sessions.single.startPage, 1);
    expect(repo.sessions.single.endPage, 10);

    // 一覧に戻っている（空状態ではない）
    expect(find.byKey(AppKeys.readingSessionLogEmpty), findsNothing);
    expect(find.text('テスト本'), findsOneWidget);
    expect(find.text('30分'), findsOneWidget);

    await _drainSnackBar(tester);
  });

  testWidgets('「元に戻す」を押さずに時間が経過すると復元されない', (tester) async {
    final repo = InMemorySessionRepo([_session('s1', 'ub1', 30)]);
    await _pumpScreen(tester, repo: repo);
    await _deleteFirstSession(tester, 's1');

    expect(repo.sessions, isEmpty);

    // 何もタップせず 10 秒経過させても自動復元はされない
    await _drainSnackBar(tester);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 0);
    expect(repo.sessions, isEmpty);
    expect(find.byKey(AppKeys.readingSessionLogEmpty), findsOneWidget);
    expect(find.text('テスト本'), findsNothing);
  });

  testWidgets('二重復元しない: 一度戻した後に再度 SnackBar の取り消しは効かない', (tester) async {
    final repo = InMemorySessionRepo([_session('s1', 'ub1', 30)]);
    await _pumpScreen(tester, repo: repo);
    await _deleteFirstSession(tester, 's1');

    await tester.tap(find.byKey(undoActionKey));
    await tester.pumpAndSettle();
    expect(repo.createCalls, 1);

    // SnackBar は閉じている → 取り消しアクションは存在しない
    expect(find.byKey(undoActionKey), findsNothing);
    expect(repo.sessions, hasLength(1));

    await _drainSnackBar(tester);
  });
}
