/// 蔵書・読書履歴エクスポート（バックアップ）の純粋ロジック試練
///
/// 道標 #69 / Kanban t_4d1829a9
/// Hive 未初期化で走る（フェイク注入のみ）— zone 汚染回避。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_exporter.dart';

UserBook _ub({
  required String id,
  required String title,
  BookStatus status = BookStatus.tsundoku,
}) {
  return UserBook(
    id: id,
    userId: 'user-1',
    bookId: 'book-$id',
    book: Book(
      id: 'book-$id',
      title: title,
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    ),
    status: status,
    medium: BookMedium.physical,
    currentPage: 10,
    totalReadingMinutes: 30,
    createdAt: '2026-01-02T00:00:00Z',
  );
}

void main() {
  group('BackupData 不変条件', () {
    test('负の件数は ArgumentError', () {
      expect(
        () => BackupData(
          exportedAt: '2026-09-20T00:00:00Z',
          books: const [],
          sessions: const [],
          goal: null,
          bookCount: -1,
          sessionCount: -1,
        ),
        throwsArgumentError,
      );
    });

    test('件数とリスト長の不一致は ArgumentError', () {
      expect(
        () => BackupData(
          exportedAt: '2026-09-20T00:00:00Z',
          books: const [],
          sessions: const [],
          goal: null,
          bookCount: 1,
          sessionCount: 0,
        ),
        throwsArgumentError,
      );
    });

    test('整合データは生成できる', () {
      final data = BackupData(
        exportedAt: '2026-09-20T00:00:00Z',
        books: [_ub(id: 'a', title: '走れメロス')],
        sessions: const [],
        goal: null,
        bookCount: 1,
        sessionCount: 0,
      );
      expect(data.bookCount, 1);
    });

    test('books 未指定の場合はリスト長が採用される', () {
      final data = BackupData(
        exportedAt: '2026-09-20T00:00:00Z',
        books: [
          _ub(id: 'a', title: 'XX'),
          _ub(id: 'b', title: 'YY'),
        ],
        sessions: const [],
      );
      expect(data.bookCount, 2);
      expect(data.sessionCount, 0);
    });
  });

  group('BackupData JSON ラウンドトリップ', () {
    test('toJson → fromJson で復元できる', () {
      final original = BackupData(
        exportedAt: '2026-09-20T00:00:00Z',
        books: [_ub(id: 'a', title: '吾輩は猫である')],
        sessions: [
          const ReadingSession(
            id: 's1',
            userBookId: 'a',
            startedAt: '2026-01-03T10:00:00Z',
            endedAt: '2026-01-03T10:30:00Z',
            startPage: 1,
            endPage: 30,
            durationMinutes: 30,
            createdAt: '2026-01-03T10:30:00Z',
          ),
        ],
        goal: const ReadingGoalSnapshot(monthlyTarget: 3, yearlyTarget: 40),
        bookCount: 1,
        sessionCount: 1,
      );

      final json = original.toJson();
      final restored = BackupData.fromJson(json);

      expect(restored.exportedAt, original.exportedAt);
      expect(restored.bookCount, 1);
      expect(restored.sessionCount, 1);
      expect(restored.books.single.id, 'a');
      expect(restored.books.single.book?.title, '吾輩は猫である');
      expect(restored.sessions.single.id, 's1');
      expect(restored.goal?.monthlyTarget, 3);
      expect(restored.goal?.yearlyTarget, 40);
    });

    test('破損 JSON（books が配列でない）でも例外を投げない', () {
      final data = BackupData.fromJson({
        'exportedAt': '2026-09-20T00:00:00Z',
        'books': 'corrupted',
        'readingSessions': null,
        'goal': 'corrupted',
        'bookCount': 'x',
        'sessionCount': 'x',
      });
      expect(data.books, isEmpty);
      expect(data.sessions, isEmpty);
      expect(data.bookCount, 0);
      expect(data.sessionCount, 0);
      expect(data.goal, isNull);
    });
  });

  group('BackupExporter.buildData', () {
    test('蔵書・セッション・目標を集めて BackupData を組み立てる', () async {
      final books = [
        _ub(id: 'a', title: 'A本'),
        _ub(id: 'b', title: 'B本'),
      ];
      const sessions = [
        ReadingSession(
          id: 's1',
          userBookId: 'a',
          startedAt: '2026-01-03T10:00:00Z',
          startPage: 1,
          createdAt: '2026-01-03T10:00:00Z',
        ),
      ];

      final exporter = BackupExporter(
        booksLoader: () async => books,
        sessionsLoader: () async => sessions,
        goalLoader: () async => const ReadingGoalSnapshot(
          monthlyTarget: 2,
          yearlyTarget: 24,
          updatedAt: '2026-09-01T00:00:00Z',
        ),
        now: () => DateTime.utc(2026, 9, 20, 12),
      );

      final data = await exporter.buildData();

      expect(data.bookCount, 2);
      expect(data.sessionCount, 1);
      expect(data.exportedAt, '2026-09-20T12:00:00.000Z');
      expect(data.goal?.monthlyTarget, 2);
      expect(data.books.first.book?.title, 'A本');
    });

    test('目標未設定は goal=null に落ちる', () async {
      final exporter = BackupExporter(
        booksLoader: () async => const [],
        sessionsLoader: () async => const [],
        goalLoader: () async => const ReadingGoalSnapshot.empty(),
        now: () => DateTime.utc(2026, 9, 20),
      );

      final data = await exporter.buildData();
      expect(data.goal, isNull);
    });

    test('booksLoader 失敗時は ArgumentError を投げる（握りつぶさない）', () async {
      final exporter = BackupExporter(
        booksLoader: () async => throw StateError('box closed'),
        sessionsLoader: () async => const [],
        goalLoader: () async => const ReadingGoalSnapshot.empty(),
      );

      await expectLater(exporter.buildData(), throwsStateError);
    });
  });

  group('BackupExporter.exportJson', () {
    test('JSON 文字列は.toJson の逆整合で復元できる', () async {
      final exporter = BackupExporter(
        booksLoader: () async => [_ub(id: 'a', title: '銀河鉄道の夜')],
        sessionsLoader: () async => const [],
        goalLoader: () async => const ReadingGoalSnapshot.empty(),
        now: () => DateTime.utc(2026, 9, 20),
      );

      final json = await exporter.exportJson();
      expect(json, contains('tsundoku_quest_backup'));

      final restored =
          BackupData.fromJson(backupJsonDecode(json) as Map<String, dynamic>);
      expect(restored.bookCount, 1);
      expect(restored.books.single.book?.title, '銀河鉄道の夜');
    });
  });
}
