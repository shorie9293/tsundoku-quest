import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal_service.dart';

UserBook _ub({
  required String id,
  BookStatus status = BookStatus.completed,
  String? completedAt,
}) {
  return UserBook(
    id: id,
    userId: 'u1',
    bookId: 'book-$id',
    book: Book(
      id: 'book-$id',
      title: 'Book $id',
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    ),
    status: status,
    medium: BookMedium.physical,
    completedAt: completedAt,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  final now = DateTime.utc(2026, 9, 13, 12);

  group('monthlyProgress', () {
    test('当月の読了数のみ集計する', () {
      final books = [
        _ub(id: 'a', completedAt: '2026-09-05T10:00:00Z'),
        _ub(id: 'b', completedAt: '2026-09-20T10:00:00Z'),
        _ub(id: 'c', completedAt: '2026-08-31T10:00:00Z'),
        _ub(id: 'd', completedAt: '2026-09-01T00:00:00Z'),
      ];
      final progress = ReadingGoalService.monthlyProgress(
        books: books,
        goal: const ReadingGoal(monthlyTarget: 3),
        now: now,
      );
      expect(progress.achieved, 2);
      expect(progress.target, 3);
      expect(progress.remaining, 1);
    });

    test('未来日付・未読了・日付不正は集計外', () {
      final books = [
        _ub(id: 'future', completedAt: '2026-10-01T00:00:00Z'),
        _ub(id: 'reading', status: BookStatus.reading, completedAt: '2026-09-02T00:00:00Z'),
        _ub(id: 'null-date'),
        _ub(id: 'bad-date', completedAt: 'not-a-date'),
        _ub(id: 'ok', completedAt: '2026-09-02T00:00:00Z'),
      ];
      final progress = ReadingGoalService.monthlyProgress(
        books: books,
        goal: const ReadingGoal(monthlyTarget: 1),
        now: now,
      );
      expect(progress.achieved, 1);
      expect(progress.isAchieved, isTrue);
    });

    test('目標未設定でも達成数は数える', () {
      final books = [_ub(id: 'a', completedAt: '2026-09-05T10:00:00Z')];
      final progress = ReadingGoalService.monthlyProgress(
        books: books,
        goal: const ReadingGoal.empty(),
        now: now,
      );
      expect(progress.achieved, 1);
      expect(progress.isSet, isFalse);
    });

    test('月跨ぎ・年跨ぎを跨いだ過去は含めない', () {
      final books = [
        _ub(id: 'prev-year', completedAt: '2025-09-10T00:00:00Z'),
        _ub(id: 'prev-month', completedAt: '2026-08-10T00:00:00Z'),
      ];
      final progress = ReadingGoalService.monthlyProgress(
        books: books,
        goal: const ReadingGoal(monthlyTarget: 5),
        now: now,
      );
      expect(progress.achieved, 0);
    });
  });

  group('yearlyProgress', () {
    test('当年の読了を月を問わず集計する', () {
      final books = [
        _ub(id: 'jan', completedAt: '2026-01-05T10:00:00Z'),
        _ub(id: 'sep', completedAt: '2026-09-05T10:00:00Z'),
        _ub(id: 'dec-next', completedAt: '2027-01-01T00:00:00Z'),
        _ub(id: 'old', completedAt: '2025-12-31T00:00:00Z'),
      ];
      final progress = ReadingGoalService.yearlyProgress(
        books: books,
        goal: const ReadingGoal(yearlyTarget: 12),
        now: now,
      );
      expect(progress.achieved, 2);
      expect(progress.remaining, 10);
    });
  });

  group('completedBetween', () {
    test('期間内（両端含む）の読了数を返す', () {
      final books = [
        _ub(id: 'start', completedAt: '2026-09-01T00:00:00Z'),
        _ub(id: 'end', completedAt: '2026-09-30T00:00:00Z'),
        _ub(id: 'out', completedAt: '2026-10-01T00:00:00Z'),
      ];
      final count = ReadingGoalService.completedBetween(
        books: books,
        start: DateTime.utc(2026, 9, 1),
        end: DateTime.utc(2026, 9, 30),
      );
      expect(count, 2);
    });

    test('開始が終了より後なら0', () {
      final count = ReadingGoalService.completedBetween(
        books: [_ub(id: 'a', completedAt: '2026-09-05T00:00:00Z')],
        start: DateTime.utc(2026, 10, 1),
        end: DateTime.utc(2026, 9, 1),
      );
      expect(count, 0);
    });
  });
}
