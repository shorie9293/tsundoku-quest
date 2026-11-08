import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_deletion_plan.dart';

void main() {
  group('BookDeletionPlan', () {
    test('ステップ順が固定（sessions→shelves→readingQueue→quickMemoDraft→trophies）',
        () {
      final plan = BookDeletionPlan.forBook('ub-1');

      expect(plan.steps, [
        BookDeletionStep.sessions,
        BookDeletionStep.shelves,
        BookDeletionStep.readingQueue,
        BookDeletionStep.quickMemoDraft,
        BookDeletionStep.trophies,
      ]);
    });

    test('enum の宣言順と一致する', () {
      final plan = BookDeletionPlan.forBook('ub-1');

      expect(plan.steps, BookDeletionStep.values);
    });

    test('空文字の userBookId は ArgumentError', () {
      expect(() => BookDeletionPlan.forBook(''), throwsArgumentError);
      expect(
        () => BookDeletionPlan(userBookId: ''),
        throwsArgumentError,
      );
    });

    test('空白のみの userBookId も ArgumentError', () {
      expect(() => BookDeletionPlan.forBook('   '), throwsArgumentError);
    });

    test('userBookId を保持する', () {
      expect(BookDeletionPlan.forBook('ub-42').userBookId, 'ub-42');
    });

    test('同一入力で同一順序・同値（純粋）', () {
      final a = BookDeletionPlan.forBook('ub-1');
      final b = BookDeletionPlan.forBook('ub-1');

      expect(a.steps, b.steps);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('steps は呼出側で変更できない', () {
      final plan = BookDeletionPlan.forBook('ub-1');

      expect(() => plan.steps.add(BookDeletionStep.trophies), throwsUnsupportedError);
    });
  });
}
