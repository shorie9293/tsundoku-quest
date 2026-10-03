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

/// 親探針：眷属が個別操作しか撃たない「合成の不変条件」を撃つ。
///  - 編集は同一 id を保持する（新規 UUID で増殖しない）
///  - 編集は userBookId を保持する
///  - 本が0件なら追加は emptyBook でブロックされる
///  - 追加したセッションの日付は注入 now のローカル日付で表示される
class _ProbeRepo implements ReadingSessionRepository {
  final List<ReadingSession> sessions;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  _ProbeRepo([List<ReadingSession>? initial])
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
  Future<ReadingSession> startSession(String userBookId, int startPage) async =>
      throw UnimplementedError();

  @override
  Future<ReadingSession> endSession(
          String sessionId, int endPage, int durationMinutes) async =>
      throw UnimplementedError();

  @override
  Future<List<String>> getAllReadingDates() async => const [];

  @override
  Future<int> getTotalReadingMinutes(String userBookId) async => 0;

  @override
  Future<int> getTotalReadingMinutesAll() async => 0;

  @override
  Future<int> getTotalPagesReadAll() async => 0;

  @override
  Future<List<int>> getWeeklyReadingMinutes() async => List.filled(7, 0);

  @override
  Future<int> getCurrentStreak() async => 0;

  @override
  Future<int> getLongestStreak() async => 0;
}

ReadingSession _session(String id, String userBookId, int duration) =>
    ReadingSessionEditorService.buildManual(
      id: id,
      userBookId: userBookId,
      startedAt: DateTime(2026, 10, 3, 10, 0),
      durationMinutes: duration,
      startPage: 1,
      createdAt: DateTime(2026, 10, 3, 12, 0),
    );

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

Future<void> _pump(
  WidgetTester tester, {
  required _ProbeRepo repo,
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

void main() {
  testWidgets('探針: 編集は同一 id を保持し新規 UUID で増殖しない', (tester) async {
    final repo = _ProbeRepo([_session('s1', 'ub1', 30)]);
    await _pump(tester, repo: repo, books: [_book('ub1', 'テスト本')]);

    await tester.tap(find.byKey(AppKeys.readingSessionEditButton('s1')));
    await tester.pumpAndSettle();
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormDuration), '120');
    await tester.tap(find.byKey(AppKeys.readingSessionFormSave));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.createCalls, 0, reason: '編集は create を呼んではならない');
    expect(repo.sessions.length, 1, reason: '編集でセッションが増殖してはならない');
    expect(repo.sessions.first.id, 's1', reason: '編集は id を保持せよ');
  });

  testWidgets('探針: 編集は userBookId を保持する', (tester) async {
    final repo = _ProbeRepo([_session('s1', 'ub1', 30)]);
    await _pump(tester, repo: repo, books: [_book('ub1', 'テスト本')]);

    await tester.tap(find.byKey(AppKeys.readingSessionEditButton('s1')));
    await tester.pumpAndSettle();
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormDuration), '60');
    await tester.tap(find.byKey(AppKeys.readingSessionFormSave));
    await tester.pumpAndSettle();

    expect(repo.sessions.first.userBookId, 'ub1');
    expect(repo.sessions.first.durationMinutes, 60);
  });

  testWidgets('探針: 本が0件なら追加は emptyBook でブロックされる', (tester) async {
    final repo = _ProbeRepo();
    await _pump(tester, repo: repo, books: const []);

    await tester.tap(find.byKey(AppKeys.readingSessionAddButton));
    await tester.pumpAndSettle();
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormDuration), '30');
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormStartPage), '1');
    await tester.tap(find.byKey(AppKeys.readingSessionFormSave));
    await tester.pumpAndSettle();

    expect(find.text('本を選択してください'), findsOneWidget);
    expect(repo.createCalls, 0);
  });

  testWidgets('探針: 追加したセッションの日付は注入 now のローカル日付で表示される',
      (tester) async {
    final repo = _ProbeRepo();
    await _pump(tester, repo: repo, books: [_book('ub1', 'テスト本')]);

    await tester.tap(find.byKey(AppKeys.readingSessionAddButton));
    await tester.pumpAndSettle();
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormDuration), '10');
    await tester
        .enterText(find.byKey(AppKeys.readingSessionFormStartPage), '1');
    await tester.tap(find.byKey(AppKeys.readingSessionFormSave));
    await tester.pumpAndSettle();

    expect(find.text('2026-10-04'), findsOneWidget,
        reason: 'フォーム既定日付は注入した now のローカル日付であること');
  });
}
