import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/history/presentation/reading_session_log_screen.dart';

/// 読書記録フォームの全角数字回帰試練（改善提案#215）。
///
/// 日本語IMEで「４５」と入力すると int.tryParse が null を返し、
/// 読書時間が黙って 0 になり保存が弾かれていた欠陥の再発防止。
void main() {
  UserBook book(String id, String title) => UserBook(
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

  Future<void> pumpScreen(
      WidgetTester tester, _RecordingSessionRepo repo) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ReadingSessionLogScreen(
          repositoryOverride: repo,
          booksOverride: [book('ub1', 'テスト本')],
          nowOverride: () => DateTime(2026, 10, 4, 21, 30),
          sessionsOverride: const <ReadingSession>[],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.readingSessionAddButton));
    await tester.pumpAndSettle();
  }

  testWidgets('全角の時間・ページを入力すると数値として保存される', (tester) async {
    final repo = _RecordingSessionRepo();
    await pumpScreen(tester, repo);

    await tester.enterText(
      find.byKey(AppKeys.readingSessionFormDuration),
      '４５',
    );
    await tester.enterText(
      find.byKey(AppKeys.readingSessionFormStartPage),
      '１',
    );
    await tester.enterText(
      find.byKey(AppKeys.readingSessionFormEndPage),
      '１０',
    );
    await tester.tap(find.byKey(AppKeys.readingSessionFormSave));
    await tester.pumpAndSettle();

    expect(repo.created, hasLength(1));
    expect(repo.created.single.durationMinutes, 45);
    expect(repo.created.single.startPage, 1);
    expect(repo.created.single.endPage, 10);
    expect(find.text('45分'), findsOneWidget);
  });

  testWidgets('全角数字に単位が混ざった４５分はエラー表示で保存しない', (tester) async {
    final repo = _RecordingSessionRepo();
    await pumpScreen(tester, repo);

    await tester.enterText(
      find.byKey(AppKeys.readingSessionFormDuration),
      '４５分',
    );
    await tester.enterText(
      find.byKey(AppKeys.readingSessionFormStartPage),
      '１',
    );
    await tester.tap(find.byKey(AppKeys.readingSessionFormSave));
    await tester.pumpAndSettle();

    expect(repo.created, isEmpty);
    expect(find.text('読書時間は1分以上で入力してください'), findsOneWidget);
    expect(find.byKey(AppKeys.readingSessionFormDialog), findsOneWidget);
  });
}

/// 保存された ReadingSession だけを記録する最小フェイク。
class _RecordingSessionRepo implements ReadingSessionRepository {
  final List<ReadingSession> created = [];

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async =>
      List.of(created);

  @override
  Future<ReadingSession> createSession(ReadingSession session) async {
    created.add(session);
    return session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
