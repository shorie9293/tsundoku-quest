import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';

void main() {
  group('ReadingQueueEntry', () {
    test('正常生成できる', () {
      final now = DateTime(2026, 9, 21, 10);
      final entry = ReadingQueueEntry(
        userBookId: 'ub-1',
        position: 1,
        addedAt: now,
      );
      expect(entry.userBookId, 'ub-1');
      expect(entry.position, 1);
      expect(entry.addedAt, now);
    });

    test('空文字 userBookId は ArgumentError', () {
      expect(
        () => ReadingQueueEntry(
          userBookId: '',
          position: 1,
          addedAt: DateTime(2026),
        ),
        throwsArgumentError,
      );
    });

    test('position < 1 は ArgumentError', () {
      expect(
        () => ReadingQueueEntry(
          userBookId: 'ub-1',
          position: 0,
          addedAt: DateTime(2026),
        ),
        throwsArgumentError,
      );
      expect(
        () => ReadingQueueEntry(
          userBookId: 'ub-1',
          position: -1,
          addedAt: DateTime(2026),
        ),
        throwsArgumentError,
      );
    });

    test('copyWith は指定フィールドのみ差し替える', () {
      final base = ReadingQueueEntry(
        userBookId: 'ub-1',
        position: 2,
        addedAt: DateTime(2026, 9, 21),
      );
      final moved = base.copyWith(position: 5);
      expect(moved.position, 5);
      expect(moved.userBookId, 'ub-1');
      expect(moved.addedAt, base.addedAt);

      final redated = base.copyWith(addedAt: DateTime(2027));
      expect(redated.addedAt, DateTime(2027));
      expect(redated.position, 2);
    });

    test('toJson / fromJson の往復', () {
      final entry = ReadingQueueEntry(
        userBookId: 'ub-42',
        position: 3,
        addedAt: DateTime(2026, 9, 21, 12, 34),
      );
      final restored = ReadingQueueEntry.fromJson(entry.toJson());
      expect(restored, entry);
    });

    test('fromJson: userBookId 欠落は FormatException', () {
      expect(
        () => ReadingQueueEntry.fromJson({'position': 1, 'addedAt': '2026-01-01T00:00:00.000'}),
        throwsFormatException,
      );
    });

    test('fromJson: position 型不一致は FormatException', () {
      expect(
        () => ReadingQueueEntry.fromJson({
          'userBookId': 'ub-1',
          'position': 'one',
          'addedAt': '2026-01-01T00:00:00.000',
        }),
        throwsFormatException,
      );
    });

    test('fromJson: addedAt 欠落・不正は FormatException', () {
      expect(
        () => ReadingQueueEntry.fromJson({'userBookId': 'ub-1', 'position': 1}),
        throwsFormatException,
      );
      expect(
        () => ReadingQueueEntry.fromJson({
          'userBookId': 'ub-1',
          'position': 1,
          'addedAt': 'not-a-date',
        }),
        throwsFormatException,
      );
    });

    test('== / hashCode: userBookId と position で比較', () {
      final a = ReadingQueueEntry(
        userBookId: 'ub-1',
        position: 1,
        addedAt: DateTime(2026),
      );
      final b = ReadingQueueEntry(
        userBookId: 'ub-1',
        position: 1,
        addedAt: DateTime(2027),
      );
      final c = ReadingQueueEntry(
        userBookId: 'ub-2',
        position: 1,
        addedAt: DateTime(2026),
      );
      final d = ReadingQueueEntry(
        userBookId: 'ub-1',
        position: 2,
        addedAt: DateTime(2026),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a, isNot(d));
    });
  });
}
