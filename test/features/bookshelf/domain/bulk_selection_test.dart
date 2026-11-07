import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/bulk_selection.dart';

UserBook _book(String id) => UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      status: BookStatus.tsundoku,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  group('BulkSelection: 生成と基本状態', () {
    test('empty は 0 件で選択中ではない', () {
      const selection = BulkSelection.empty();
      expect(selection.count, 0);
      expect(selection.ids, isEmpty);
      expect(selection.isSelecting, isFalse);
    });

    test('of は渡した順序を保持する', () {
      final selection = BulkSelection.of(['c', 'a', 'b']);
      expect(selection.ids, ['c', 'a', 'b']);
    });

    test('of は重複を排除する', () {
      final selection = BulkSelection.of(['a', 'b', 'a']);
      expect(selection.count, 2);
      expect(selection.ids, ['a', 'b']);
    });

    test('of は空の Iterable を受け取れる', () {
      final selection = BulkSelection.of(const <String>[]);
      expect(selection.count, 0);
      expect(selection.isSelecting, isFalse);
    });

    test('isSelecting は 1 件以上で true（境界）', () {
      expect(BulkSelection.of(['a']).isSelecting, isTrue);
      expect(BulkSelection.of(['a', 'b']).isSelecting, isTrue);
    });
  });

  group('BulkSelection: contains / ids', () {
    test('contains は含まれる ID で true', () {
      final selection = BulkSelection.of(['a', 'b']);
      expect(selection.contains('a'), isTrue);
      expect(selection.contains('b'), isTrue);
    });

    test('contains は含まれない ID で false', () {
      final selection = BulkSelection.of(['a']);
      expect(selection.contains('z'), isFalse);
      expect(const BulkSelection.empty().contains('a'), isFalse);
    });

    test('ids は挿入順を保った List を返す', () {
      final selection = BulkSelection.of(['z', 'y', 'x']);
      expect(selection.ids, ['z', 'y', 'x']);
    });

    test('ids は外部から変更できない', () {
      final selection = BulkSelection.of(['a']);
      expect(() => selection.ids.add('b'), throwsUnsupportedError);
    });

    test('ids を書き換えても内部状態は変わらない', () {
      final selection = BulkSelection.of(['a']);
      final snapshot = selection.ids;
      expect(snapshot, ['a']);
      expect(selection.contains('b'), isFalse);
    });
  });

  group('BulkSelection: toggle', () {
    test('toggle で未選択 ID を追加できる', () {
      final selection = const BulkSelection.empty().toggle('a');
      expect(selection.contains('a'), isTrue);
      expect(selection.count, 1);
    });

    test('toggle で選択済み ID を削除できる', () {
      final selection = BulkSelection.of(['a', 'b']).toggle('a');
      expect(selection.contains('a'), isFalse);
      expect(selection.ids, ['b']);
    });

    test('toggle は元インスタンスを破壊しない', () {
      final original = BulkSelection.of(['a']);
      final toggled = original.toggle('b');
      expect(original.contains('b'), isFalse);
      expect(original.count, 1);
      expect(toggled.contains('b'), isTrue);
      expect(toggled.count, 2);
    });

    test('同じ ID を 2 回 toggle すると元の集合に戻る', () {
      final original = BulkSelection.of(['a', 'b']);
      final twice = original.toggle('c').toggle('c');
      expect(twice, original);
    });

    test('toggle は既存順序を保持し新規を末尾に足す', () {
      final selection = BulkSelection.of(['b', 'a']).toggle('c');
      expect(selection.ids, ['b', 'a', 'c']);
    });

    test('toggle で全件解除すると isSelecting が false になる', () {
      final selection = BulkSelection.of(['a']).toggle('a');
      expect(selection.isSelecting, isFalse);
      expect(selection.count, 0);
    });
  });

  group('BulkSelection: selectAll / clear', () {
    test('selectAll は空選択から全件を選ぶ', () {
      final selection = const BulkSelection.empty().selectAll(['a', 'b']);
      expect(selection.ids, ['a', 'b']);
      expect(selection.count, 2);
    });

    test('selectAll は既存選択を保持しつつ追加する', () {
      final selection = BulkSelection.of(['a']).selectAll(['b', 'c']);
      expect(selection.ids, ['a', 'b', 'c']);
    });

    test('selectAll は重複を追加しない', () {
      final selection = BulkSelection.of(['a', 'b']).selectAll(['a', 'b', 'c']);
      expect(selection.ids, ['a', 'b', 'c']);
      expect(selection.count, 3);
    });

    test('selectAll は元インスタンスを破壊しない', () {
      final original = BulkSelection.of(['a']);
      original.selectAll(['b']);
      expect(original.ids, ['a']);
    });

    test('clear は空選択を返す', () {
      final selection = BulkSelection.of(['a', 'b']).clear();
      expect(selection.count, 0);
      expect(selection.isSelecting, isFalse);
      expect(selection, const BulkSelection.empty());
    });

    test('clear は元インスタンスを破壊しない', () {
      final original = BulkSelection.of(['a']);
      original.clear();
      expect(original.contains('a'), isTrue);
    });
  });

  group('BulkSelection: 等価性', () {
    test('同一集合なら順序が違っても等価', () {
      expect(BulkSelection.of(['a', 'b']), BulkSelection.of(['b', 'a']));
    });

    test('等価な集合は hashCode も一致する', () {
      expect(
        BulkSelection.of(['a', 'b']).hashCode,
        BulkSelection.of(['b', 'a']).hashCode,
      );
    });

    test('要素が違えば非等価', () {
      expect(BulkSelection.of(['a']), isNot(BulkSelection.of(['b'])));
    });

    test('件数が違えば非等価', () {
      expect(BulkSelection.of(['a']), isNot(BulkSelection.of(['a', 'b'])));
    });

    test('空同士は等価', () {
      expect(BulkSelection.of(const <String>[]), const BulkSelection.empty());
    });
  });

  group('buildBulkDeletePlan', () {
    final books = [_book('1'), _book('2'), _book('3')];

    test('選択された本だけを削除対象にする', () {
      final plan = buildBulkDeletePlan(
        books: books,
        selection: BulkSelection.of(['2']),
      );
      expect(plan.toDelete.map((b) => b.id), ['2']);
      expect(plan.unknownIds, isEmpty);
    });

    test('toDelete は books の元の並び順を保つ', () {
      final plan = buildBulkDeletePlan(
        books: books,
        selection: BulkSelection.of(['3', '1']),
      );
      expect(plan.toDelete.map((b) => b.id), ['1', '3']);
    });

    test('books に無い選択 ID は unknownIds に入る', () {
      final plan = buildBulkDeletePlan(
        books: books,
        selection: BulkSelection.of(['2', 'ghost']),
      );
      expect(plan.toDelete.map((b) => b.id), ['2']);
      expect(plan.unknownIds, ['ghost']);
    });

    test('空選択なら toDelete も unknownIds も空', () {
      final plan = buildBulkDeletePlan(
        books: books,
        selection: const BulkSelection.empty(),
      );
      expect(plan.toDelete, isEmpty);
      expect(plan.unknownIds, isEmpty);
    });

    test('books が空でも選択 ID は全て unknownIds になる', () {
      final plan = buildBulkDeletePlan(
        books: const [],
        selection: BulkSelection.of(['a', 'b']),
      );
      expect(plan.toDelete, isEmpty);
      expect(plan.unknownIds, ['a', 'b']);
    });

    test('toDelete は元の UserBook インスタンスを保持する', () {
      final plan = buildBulkDeletePlan(
        books: books,
        selection: BulkSelection.of(['2']),
      );
      expect(identical(plan.toDelete.single, books[1]), isTrue);
    });
  });

  group('mergeShelfBookIds', () {
    test('重複する ID は追加しない', () {
      final merged = mergeShelfBookIds(
        existing: ['a', 'b'],
        adding: ['b', 'c'],
      );
      expect(merged, ['a', 'b', 'c']);
    });

    test('既存の順序を保つ', () {
      final merged = mergeShelfBookIds(
        existing: ['c', 'a', 'b'],
        adding: ['z'],
      );
      expect(merged, ['c', 'a', 'b', 'z']);
    });

    test('既存が空なら追加分のみを返す', () {
      final merged = mergeShelfBookIds(
        existing: const [],
        adding: ['x', 'y'],
      );
      expect(merged, ['x', 'y']);
    });

    test('追加分が空なら既存をそのまま返す', () {
      final merged = mergeShelfBookIds(
        existing: ['a', 'b'],
        adding: const [],
      );
      expect(merged, ['a', 'b']);
    });

    test('追加分自体の重複も排除する', () {
      final merged = mergeShelfBookIds(
        existing: ['a'],
        adding: ['b', 'b', 'c'],
      );
      expect(merged, ['a', 'b', 'c']);
    });

    test('両方空なら空リストを返す', () {
      final merged = mergeShelfBookIds(existing: const [], adding: const []);
      expect(merged, isEmpty);
    });

    test('返り値は外部から変更できない', () {
      final merged = mergeShelfBookIds(existing: ['a'], adding: ['b']);
      expect(() => merged.add('c'), throwsUnsupportedError);
    });

    test('入力リストを破壊しない', () {
      final existing = ['a'];
      final adding = ['b'];
      mergeShelfBookIds(existing: existing, adding: adding);
      expect(existing, ['a']);
      expect(adding, ['b']);
    });
  });
}
