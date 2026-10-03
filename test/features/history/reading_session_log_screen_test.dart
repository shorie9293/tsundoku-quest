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

/// InMemory フェイク（全メソッド実装・create/update/delete は内部リストを実更新）
class InMemorySessionRepo implements ReadingSessionRepository {
  final List<ReadingSession> sessions;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int reloadCalls = 0;

  InMemorySessionRepo([List<ReadingSession>? initial])
      : sessions = List.of(initial ?? const []);

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async {
    reloadCalls++;
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

ReadingSession _session(
  String id,
  String userBookId,
  int duration, {
  int startPage = 1,
  int? endPage,
  DateTime? createdAt,
}) {
  return ReadingSessionEditorService.buildManual(
    id: id,
    userBookId: userBookId,
    startedAt: DateTime(2026, 10, 3, 10, 0),
    durationMinutes: duration,
    startPage: startPage,
    endPage: endPage,
    createdAt: createdAt ?? DateTime(2026, 10, 3, 12, 0),
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
  required List<UserBook> books,
  List<ReadingSession>? initialSessions,
}) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: ReadingSessionLogScreen(
        repositoryOverride: repo,
        booksOverride: books,
        nowOverride: () => DateTime(2026, 10, 4, 21, 30),
        sessionsOverride: initialSessions,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.byKey(AppKeys.readingSessionAddButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('セッションが空のとき空状態メッセージを表示する', (tester) async {
    final repo = InMemorySessionRepo();
    await _pumpScreen(tester, repo: repo, books: [_book('ub1', 'テスト本')]);

    expect(find.byKey(AppKeys.readingSessionLogEmpty), findsOneWidget);
    expect(find.byKey(AppKeys.readingSessionLogList), findsNothing);
  });

  testWidgets('初期一覧に書籍名・日付・時間・ページ範囲が表示される', (tester) async {
    final repo = InMemorySessionRepo([
      _session('s1', 'ub1', 90, startPage: 10, endPage: 30),
    ]);
    await _pumpScreen(tester, repo: repo, books: [_book('ub1', '吾輩は猫である')]);

    expect(find.byKey(AppKeys.readingSessionLogList), findsOneWidget);
    expect(find.text('吾輩は猫である'), findsOneWidget);
    expect(find.text('1時間30分'), findsOneWidget);
    expect(find.text('2026-10-03'), findsOneWidget);
    expect(find.text('p.10〜30'), findsOneWidget);
  });

  testWidgets('手動記録: フォーム入力→保存で createSession が呼ばれ一覧に追加される',
      (tester) async {
    final repo = InMemorySessionRepo();
    await _pumpScreen(tester, repo: repo, books: [_book('ub1', 'テスト本')]);
    await _openForm(tester);

    expect(find.byKey(AppKeys.readingSessionFormDialog), findsOneWidget);
    // 書籍は最初の本がデフォルト選択済み
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormDuration), '30');
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormStartPage), '1');
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormEndPage), '10');
    await tester.tap(find.byKey(AppKeys.readingSessionFormSave));
    await tester.pumpAndSettle();

    expect(repo.createCalls, 1);
    expect(find.text('テスト本'), findsOneWidget);
    expect(find.text('30分'), findsOneWidget);
    expect(find.byKey(AppKeys.readingSessionLogEmpty), findsNothing);
  });

  testWidgets('バリデーション: 読書時間0で保存→エラー表示され createSession は呼ばれない',
      (tester) async {
    final repo = InMemorySessionRepo();
    await _pumpScreen(tester, repo: repo, books: [_book('ub1', 'テスト本')]);
    await _openForm(tester);

    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormDuration), '0');
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormStartPage), '1');
    await tester.tap(find.byKey(AppKeys.readingSessionFormSave));
    await tester.pumpAndSettle();

    expect(find.text('読書時間は1分以上で入力してください'), findsOneWidget);
    expect(repo.createCalls, 0);
    // ダイアログは閉じたまま
    expect(find.byKey(AppKeys.readingSessionFormDialog), findsOneWidget);
  });

  testWidgets('編集: 既存行の編集→保存で updateSession が呼ばれる', (tester) async {
    final repo = InMemorySessionRepo([
      _session('s1', 'ub1', 30, startPage: 1, endPage: 5),
    ]);
    await _pumpScreen(tester, repo: repo, books: [_book('ub1', 'テスト本')]);

    await tester.tap(find.byKey(AppKeys.readingSessionEditButton('s1')));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.readingSessionFormDialog), findsOneWidget);

    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormDuration), '120');
    await tester.tap(find.byKey(AppKeys.readingSessionFormSave));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.sessions.first.durationMinutes, 120);
    expect(find.text('2時間'), findsOneWidget);
  });

  testWidgets('削除: 削除ボタン→確認ダイアログ→deleteSession が呼ばれ一覧から消える',
      (tester) async {
    final repo = InMemorySessionRepo([
      _session('s1', 'ub1', 30),
    ]);
    await _pumpScreen(tester, repo: repo, books: [_book('ub1', 'テスト本')]);

    await tester.tap(find.byKey(AppKeys.readingSessionDeleteButton('s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.readingSessionDeleteConfirm));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    expect(find.byKey(AppKeys.readingSessionLogEmpty), findsOneWidget);
    expect(find.text('テスト本'), findsNothing);
  });

  testWidgets('削除確認でキャンセルすると削除されない', (tester) async {
    final repo = InMemorySessionRepo([
      _session('s1', 'ub1', 30),
    ]);
    await _pumpScreen(tester, repo: repo, books: [_book('ub1', 'テスト本')]);

    await tester.tap(find.byKey(AppKeys.readingSessionDeleteButton('s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.readingSessionFormCancel).last);
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 0);
    expect(find.text('テスト本'), findsOneWidget);
  });

  testWidgets('追加・編集・削除後に getRecentSessions が再読込され一覧が更新される',
      (tester) async {
    final repo = InMemorySessionRepo();
    await _pumpScreen(tester, repo: repo, books: [_book('ub1', 'テスト本')]);
    final reloadsAfterInit = repo.reloadCalls;

    // 追加
    await _openForm(tester);
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormDuration), '45');
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormStartPage), '2');
    await tester.tap(find.byKey(AppKeys.readingSessionFormSave));
    await tester.pumpAndSettle();
    expect(repo.reloadCalls, greaterThan(reloadsAfterInit));

    // 編集（追加されたセッションの ID を使う）
    final addedId = repo.sessions.last.id;
    final reloadsAfterAdd = repo.reloadCalls;
    await tester.tap(find.byKey(AppKeys.readingSessionEditButton(addedId)));
    await tester.pumpAndSettle();
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormDuration), '60');
    await tester.tap(find.byKey(AppKeys.readingSessionFormSave));
    await tester.pumpAndSettle();
    expect(repo.reloadCalls, greaterThan(reloadsAfterAdd));
    expect(find.text('1時間'), findsOneWidget);

    // 削除
    final reloadsAfterEdit = repo.reloadCalls;
    await tester
        .tap(find.byKey(AppKeys.readingSessionDeleteButton(addedId)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.readingSessionDeleteConfirm));
    await tester.pumpAndSettle();
    expect(repo.reloadCalls, greaterThan(reloadsAfterEdit));
    expect(find.byKey(AppKeys.readingSessionLogEmpty), findsOneWidget);
  });
}
