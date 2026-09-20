/// mergeBackup / backupBooksToCsv の試練
///
/// 道標 #69 / Kanban t_4d1829a9
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_merge.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_csv.dart';

UserBook _ub(String id,
    {String title = '本',
    BookStatus status = BookStatus.tsundoku,
    String? completedAt,
    String note = ''}) {
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
    status: status,
    medium: BookMedium.physical,
    currentPage: 5,
    totalReadingMinutes: 10,
    notes: note.isEmpty ? null : note,
    completedAt: completedAt,
    createdAt: '2026-01-02T00:00:00Z',
  );
}

ReadingSession _session(String id, String userBookId) => ReadingSession(
      id: id,
      userBookId: userBookId,
      startedAt: '2026-01-03T10:00:00Z',
      startPage: 1,
      createdAt: '2026-01-03T10:00:00Z',
    );

BackupData _data({List<UserBook> books = const [], List<ReadingSession> sessions = const []}) {
  return BackupData(
    exportedAt: '2026-09-20T00:00:00Z',
    books: books,
    sessions: sessions,
  );
}

void main() {
  group('mergeBackup', () {
    test('既存に無いエントリのみ追加対象になる', () {
      final result = mergeBackup(
        incoming: _data(books: [_ub('a'), _ub('b')], sessions: [_session('s1', 'a')]),
        existingBooks: [_ub('a')],
        existingSessions: const [],
      );

      expect(result.addedBooks, 1);
      expect(result.skippedBooks, 1);
      expect(result.addedSessions, 1);
      expect(result.skippedSessions, 0);
      expect(result.newBooks.single.id, 'b');
      expect(result.newSessions.single.id, 's1');
      expect(result.isEmpty, isFalse);
    });

    test('全重複は空の結果（isEmpty）', () {
      final result = mergeBackup(
        incoming: _data(books: [_ub('a')], sessions: [_session('s1', 'a')]),
        existingBooks: [_ub('a')],
        existingSessions: [_session('s1', 'a')],
      );
      expect(result.addedBooks, 0);
      expect(result.addedSessions, 0);
      expect(result.isEmpty, isTrue);
    });

    test('incoming 内の重複 id も1回しか追加しない', () {
      final result = mergeBackup(
        incoming: _data(books: [_ub('x'), _ub('x')]),
        existingBooks: const [],
        existingSessions: const [],
      );
      expect(result.addedBooks, 1);
      expect(result.skippedBooks, 1);
      expect(result.newBooks.length, 1);
    });

    test('既存の順序は保持され incoming 順に追加される', () {
      final result = mergeBackup(
        incoming: _data(books: [_ub('c'), _ub('b')]),
        existingBooks: [_ub('a')],
        existingSessions: const [],
      );
      expect(result.newBooks.map((b) => b.id).toList(), ['c', 'b']);
    });
  });

  group('backupBooksToCsv', () {
    test('ヘッダ行とデータ行を出力する', () {
      final csv = backupBooksToCsv([
        _ub('a', title: '走れメロス', status: BookStatus.completed,
            completedAt: '2026-02-01T00:00:00Z'),
      ]);
      final lines = csv.split('\n');
      expect(lines.first, backupCsvHeader);
      expect(lines[1], contains('走れメロス'));
      expect(lines[1], contains('completed'));
      expect(lines[1], contains('2026-02-01T00:00:00Z'));
    });

    test('カンマ・引用符・改行を含む書名はエスケープされる', () {
      final csv = backupBooksToCsv([_ub('a', title: '彼女, "言った"\n改行')]);
      expect(csv, contains('"彼女, ""言った""\n改行"'));
    });

    test('book 未紐付けは空タイトル、rating 未設定は空セル', () {
      final csv = backupBooksToCsv([
        UserBook(
          id: 'a',
          userId: 'u1',
          bookId: 'book-a',
          status: BookStatus.tsundoku,
          medium: BookMedium.physical,
          createdAt: '2026-01-02T00:00:00Z',
        ),
      ]);
      final lines = csv.split('\n');
      expect(lines[1], startsWith('a,,tsundoku,'));
      // cells: id,title,status,medium,currentPage,totalReadingMinutes,rating,completedAt
      final cells = lines[1].split(',');
      expect(cells[4], '0'); // currentPage
      expect(cells[6], ''); // rating unset
    });

    test('status→id の安定ソート', () {
      final csv = backupBooksToCsv([
        _ub('2', status: BookStatus.reading),
        _ub('1', status: BookStatus.completed),
        _ub('0', status: BookStatus.completed),
      ]);
      final lines = csv.split('\n');
      expect(lines[1].startsWith('0,'), isTrue);
      expect(lines[2].startsWith('1,'), isTrue);
      expect(lines[3].startsWith('2,'), isTrue);
    });
  });
}
