/// BackupScreen / InMemoryBackupRepository の試練
///
/// 道標 #69 / Kanban t_4d1829a9
/// Hive 未初期化で走る（フェイク注入のみ・zone 汚染回避）。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/backup/data/backup_repository.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';
import 'package:tsundoku_quest/features/backup/presentation/backup_keys.dart';
import 'package:tsundoku_quest/features/backup/presentation/backup_screen.dart';

UserBook _ub(String id, {String title = '本'}) {
  return UserBook(
    id: id,
    userId: 'u1',
    bookId: 'book-$id',
    book: Book(
      id: 'book-$id',
      title: title,
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    ),
    status: BookStatus.tsundoku,
    medium: BookMedium.physical,
    createdAt: '2026-01-02T00:00:00Z',
  );
}

/// 共有を記録するフェイク
class _FakeShareGateway implements BackupShareGateway {
  final List<String> sharedBodies = [];
  final List<String> sharedMimeTypes = [];

  @override
  Future<void> shareFile({
    required String fileName,
    required String mimeType,
    required String body,
  }) async {
    sharedBodies.add(body);
    sharedMimeTypes.add(mimeType);
  }
}

Widget _wrap(BackupScreen screen) => MaterialApp(home: screen);

void main() {
  group('InMemoryBackupRepository', () {
    test('collect が現状態を返す', () async {
      final repo = InMemoryBackupRepository(books: [_ub('a')]);
      final data = await repo.collect();
      expect(data.bookCount, 1);
      expect(data.books.single.id, 'a');
    });

    test('restore が新規のみ追加し、2回目はスキップ', () async {
      final repo = InMemoryBackupRepository(books: [_ub('a')]);
      final incoming = BackupData(
        exportedAt: '2026-09-20T00:00:00Z',
        books: [_ub('a'), _ub('b')],
        sessions: [
          const ReadingSession(
            id: 's1',
            userBookId: 'b',
            startedAt: '2026-01-03T10:00:00Z',
            startPage: 1,
            createdAt: '2026-01-03T10:00:00Z',
          ),
        ],
      );

      final first = await repo.restore(incoming);
      expect(first.addedBooks, 1);
      expect(first.addedSessions, 1);
      expect(repo.books.map((b) => b.id), containsAll(['a', 'b']));

      final second = await repo.restore(incoming);
      expect(second.addedBooks, 0);
      expect(second.addedSessions, 0);
      expect(repo.books.length, 2);
    });

    test('goal 付き復元で目標が保存される', () async {
      final repo = InMemoryBackupRepository();
      await repo.restore(BackupData(
        exportedAt: '2026-09-20T00:00:00Z',
        books: const [],
        goal: const ReadingGoalSnapshot(monthlyTarget: 3, yearlyTarget: 30),
      ));
      expect(repo.goal?.monthlyTarget, 3);
    });
  });

  group('BackupScreen', () {
    testWidgets('件数サマリを表示する', (tester) async {
      final repo = InMemoryBackupRepository(books: [_ub('a'), _ub('b')]);
      await tester.pumpWidget(_wrap(BackupScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.byKey(BackupKeys.summary), findsOneWidget);
      expect(find.textContaining('蔵書 2 冊'), findsOneWidget);
    });

    testWidgets('空ペーストで取り込むとエラーメッセージ', (tester) async {
      final repo = InMemoryBackupRepository();
      await tester.pumpWidget(_wrap(BackupScreen(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(BackupKeys.importButton));
      await tester.pumpAndSettle();

      expect(find.byKey(BackupKeys.resultMessage), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(BackupKeys.resultMessage)).data,
        contains('貼り付けてください'),
      );
    });

    testWidgets('正しいJSON貼付で復元され件数が表示される', (tester) async {
      final repo = InMemoryBackupRepository(books: [_ub('a')]);
      await tester.pumpWidget(_wrap(BackupScreen(repository: repo)));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(BackupKeys.importField),
        jsonEncode(_pasteJson()),
      );
      await tester.tap(find.byKey(BackupKeys.importButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('追加 蔵書1冊'), findsOneWidget);
      expect(repo.books.length, 2);
    });

    testWidgets('JSON書き出しで共有ゲートウェイが呼ばれる', (tester) async {
      final repo = InMemoryBackupRepository(books: [_ub('a', title: '銀河鉄道の夜')]);
      final gateway = _FakeShareGateway();
      await tester.pumpWidget(_wrap(BackupScreen(
        repository: repo,
        shareGateway: gateway,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(BackupKeys.exportJsonButton));
      await tester.pumpAndSettle();

      expect(gateway.sharedBodies, hasLength(1));
      expect(gateway.sharedBodies.single, contains('tsundoku_quest_backup'));
      expect(gateway.sharedMimeTypes.single, 'application/json');
      expect(find.textContaining('書き出しました'), findsOneWidget);
    });

    testWidgets('CSV書き出しで text/csv が共有される', (tester) async {
      final repo = InMemoryBackupRepository(books: [_ub('a')]);
      final gateway = _FakeShareGateway();
      await tester.pumpWidget(_wrap(BackupScreen(
        repository: repo,
        shareGateway: gateway,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(BackupKeys.exportCsvButton));
      await tester.pumpAndSettle();

      expect(gateway.sharedBodies.single, contains('id,title,status'));
      expect(gateway.sharedMimeTypes.single, 'text/csv');
    });
  });
}

Map<String, dynamic> _pasteJson() {
  return {
    'tsundoku_quest_backup': true,
    'version': 1,
    'exportedAt': '2026-09-20T00:00:00Z',
    'books': [_ub('b').toJson()],
    'readingSessions': const [],
    'readingGoal': null,
  };
}
