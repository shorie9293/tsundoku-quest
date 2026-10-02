import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/features/history/data/reading_notes_provider.dart';
import 'package:tsundoku_quest/features/history/domain/reading_note_query.dart';

/// ローカルヘルパ: 全フィールド指定で ReadingNoteItem を生成（const ではない）
ReadingNoteItem note({
  required String id,
  String? bookTitle,
  List<String> learnings = const [],
  String action = '',
  String? favoriteQuote,
  String createdAt = '2026-01-01T00:00:00Z',
}) {
  return ReadingNoteItem(
    id: id,
    userBookId: 'ub-$id',
    bookTitle: bookTitle,
    learnings: List.of(learnings),
    action: action,
    favoriteQuote: favoriteQuote,
    createdAt: createdAt,
  );
}

void main() {
  group('normalize', () {
    test('全角英数字を半角へ変換する', () {
      expect(ReadingNoteQueryService.normalize('ＡＢＣ１２３'), 'abc123');
    });

    test('全角スペースを半角スペースへ変換する', () {
      expect(ReadingNoteQueryService.normalize('学び　行動'), '学び 行動');
    });

    test('大文字小文字を区別しない', () {
      expect(ReadingNoteQueryService.normalize('Flutter'), 'flutter');
    });

    test('連続空白を単一スペースへ圧縮する', () {
      expect(ReadingNoteQueryService.normalize('  a   b  '), 'a b');
    });
  });

  group('matchesText', () {
    test('bookTitle に部分一致', () {
      final n = note(id: 'n1', bookTitle: 'CrystalAbc本');
      expect(ReadingNoteQueryService.matchesText(n, 'abc'), isTrue);
    });

    test('learnings のいずれかに一致', () {
      final n = note(id: 'n1', learnings: ['朝読書を続ける']);
      expect(ReadingNoteQueryService.matchesText(n, '朝読書'), isTrue);
    });

    test('action に一致', () {
      final n = note(id: 'n1', action: '明日から実践する');
      expect(ReadingNoteQueryService.matchesText(n, '実践'), isTrue);
    });

    test('favoriteQuote に一致', () {
      final n = note(id: 'n1', favoriteQuote: '継続は力なり');
      expect(ReadingNoteQueryService.matchesText(n, '力なり'), isTrue);
    });

    test('該当なしは false', () {
      final n = note(id: 'n1', bookTitle: '本A', action: 'なし');
      expect(ReadingNoteQueryService.matchesText(n, '存在しない語'), isFalse);
    });

    test('空クエリは全件 true', () {
      final n = note(id: 'n1', action: '何か');
      expect(ReadingNoteQueryService.matchesText(n, ''), isTrue);
      expect(ReadingNoteQueryService.matchesText(n, '  　 '), isTrue);
    });

    test('bookTitle が null でも落ちない', () {
      final n = note(id: 'n1', action: '実行');
      expect(ReadingNoteQueryService.matchesText(n, '本'), isFalse);
      expect(ReadingNoteQueryService.matchesText(n, '実行'), isTrue);
    });
  });

  group('filterByBooks', () {
    test('空集合は全件', () {
      final a = note(id: 'a', bookTitle: '本A');
      final b = note(id: 'b', bookTitle: '本B');
      expect(ReadingNoteQueryService.filterByBooks([a, b], {}),
          unorderedEquals([a, b]));
    });

    test('一致する書名のみ', () {
      final a = note(id: 'a', bookTitle: '本A');
      final b = note(id: 'b', bookTitle: '本B');
      expect(ReadingNoteQueryService.filterByBooks([a, b], {'本A'}), [a]);
    });

    test('bookTitle が null の note は除外', () {
      final a = note(id: 'a', bookTitle: '本A');
      final n = note(id: 'n', bookTitle: null);
      expect(ReadingNoteQueryService.filterByBooks([a, n], {'本A', 'x'}), [a]);
    });
  });

  group('filterByContent', () {
    test('空フィルタは全件', () {
      final a = note(id: 'a', learnings: ['学び']);
      final b = note(id: 'b', action: '行動');
      expect(ReadingNoteQueryService.filterByContent([a, b], {}),
          unorderedEquals([a, b]));
    });

    test('単一フィルタ hasLearning', () {
      final a = note(id: 'a', learnings: ['学び']);
      final b = note(id: 'b', action: '行動のみ');
      expect(ReadingNoteQueryService.filterByContent(
          [a, b], {ReadingNoteContentFilter.hasLearning}), [a]);
    });

    test('単一フィルタ hasAction / hasQuote', () {
      final withAction = note(id: 'a', action: 'やる');
      final withQuote = note(id: 'b', favoriteQuote: '引用');
      final bare = note(id: 'c');
      expect(
        ReadingNoteQueryService.filterByContent(
            [withAction, withQuote, bare], {ReadingNoteContentFilter.hasAction}),
        [withAction],
      );
      expect(
        ReadingNoteQueryService.filterByContent(
            [withAction, withQuote, bare], {ReadingNoteContentFilter.hasQuote}),
        [withQuote],
      );
    });

    test('複数選択は AND（学びあり + 引用あり の両方を持つ note のみ）', () {
      final both = note(
        id: 'both',
        learnings: ['学び'],
        favoriteQuote: '引用',
      );
      final onlyLearning = note(id: 'l', learnings: ['学び']);
      final onlyQuote = note(id: 'q', favoriteQuote: '引用');
      final result = ReadingNoteQueryService.filterByContent(
        [both, onlyLearning, onlyQuote],
        {
          ReadingNoteContentFilter.hasLearning,
          ReadingNoteContentFilter.hasQuote,
        },
      );
      expect(result, [both]);
    });

    test('hasQuote は空文字の引用を満たさない', () {
      final emptyQuote = note(id: 'e', favoriteQuote: '');
      expect(ReadingNoteQueryService.filterByContent(
          [emptyQuote], {ReadingNoteContentFilter.hasQuote}), isEmpty);
    });
  });

  group('sort', () {
    final older = note(id: 'old', createdAt: '2025-01-01T00:00:00Z');
    final newer = note(id: 'new', createdAt: '2026-01-01T00:00:00Z');
    final middle = note(id: 'mid', createdAt: '2025-06-01T00:00:00Z');

    test('createdNewest は createdAt 降順', () {
      expect(
        ReadingNoteQueryService.sort(
            [older, newer, middle], ReadingNoteSortOrder.createdNewest),
        [newer, middle, older],
      );
    });

    test('createdOldest は createdAt 昇順', () {
      expect(
        ReadingNoteQueryService.sort(
            [older, newer, middle], ReadingNoteSortOrder.createdOldest),
        [older, middle, newer],
      );
    });

    test('titleAsc は書名昇順', () {
      final c = note(id: 'c', bookTitle: 'C本');
      final a = note(id: 'a', bookTitle: 'A本');
      final b = note(id: 'b', bookTitle: 'B本');
      expect(ReadingNoteQueryService.sort([c, a, b], ReadingNoteSortOrder.titleAsc),
          [a, b, c]);
    });

    test('titleAsc で null bookTitle は常に末尾', () {
      final titled = note(id: 't', bookTitle: 'Z本');
      final noTitle1 = note(id: 'n1', bookTitle: null);
      final noTitle2 = note(id: 'n2', bookTitle: null);
      final result = ReadingNoteQueryService.sort(
          [noTitle2, titled, noTitle1], ReadingNoteSortOrder.titleAsc);
      expect(result, [titled, noTitle1, noTitle2]);
    });

    test('learningCountDesc は学び数降順', () {
      final one = note(id: 'one', learnings: ['x']);
      final three = note(id: 'three', learnings: ['x', 'y', 'z']);
      final two = note(id: 'two', learnings: ['x', 'y']);
      expect(
        ReadingNoteQueryService.sort(
            [one, three, two], ReadingNoteSortOrder.learningCountDesc),
        [three, two, one],
      );
    });

    test('同値は id 昇順でタイブレーク（安定ソート）', () {
      final sameDay1 = note(id: 'b2', createdAt: '2026-01-01T00:00:00Z');
      final sameDay2 = note(id: 'a1', createdAt: '2026-01-01T00:00:00Z');
      expect(
        ReadingNoteQueryService.sort(
            [sameDay1, sameDay2], ReadingNoteSortOrder.createdNewest),
        [sameDay2, sameDay1],
      );
      // 学び数が同値の場合も id 昇順
      final l1 = note(id: 'z9', learnings: ['x']);
      final l2 = note(id: 'y8', learnings: ['x']);
      expect(
        ReadingNoteQueryService.sort(
            [l1, l2], ReadingNoteSortOrder.learningCountDesc),
        [l2, l1],
      );
    });

    test('入力リストは破壊されない', () {
      final a = note(id: 'a', bookTitle: 'A本');
      final b = note(id: 'b', bookTitle: 'B本');
      final input = [b, a];
      ReadingNoteQueryService.sort(input, ReadingNoteSortOrder.titleAsc);
      expect(input, [b, a]);
    });
  });

  group('apply', () {
    test('絞込×検索×並替の合成（部分集合にソートが掛かる）', () {
      final a = note(
        id: 'a',
        bookTitle: '本A',
        learnings: ['朝の学び'],
        favoriteQuote: '引用A',
        createdAt: '2025-01-01T00:00:00Z',
      );
      final b = note(
        id: 'b',
        bookTitle: '本B',
        learnings: ['学びB'],
        createdAt: '2026-01-01T00:00:00Z',
      );
      final c = note(
        id: 'c',
        bookTitle: '本A',
        action: '行動C',
        createdAt: '2026-06-01T00:00:00Z',
      );
      final query = ReadingNoteQuery(
        text: '学び',
        bookTitles: {'本A'},
        contentFilters: {ReadingNoteContentFilter.hasLearning},
        sortOrder: ReadingNoteSortOrder.createdOldest,
      );
      // text=学び → {a, b} / bookTitles=本A → {a} / hasLearning → {a}
      // createdOldest でソート → [a]
      expect(ReadingNoteQueryService.apply([a, b, c], query), [a]);
    });

    test('件数と resultLabel の一致', () {
      final a = note(id: 'a', bookTitle: '本A');
      final b = note(id: 'b', bookTitle: '本B');
      final result = ReadingNoteQueryService.apply(
        [a, b],
        const ReadingNoteQuery(bookTitles: {'本A'}),
      );
      expect(result.length, 1);
      expect(ReadingNoteQueryService.resultLabel(result.length), '1件');
    });

    test('デフォルトクエリは元の順序を保つ（createdNewest）', () {
      final a = note(id: 'a', createdAt: '2025-01-01T00:00:00Z');
      final b = note(id: 'b', createdAt: '2026-01-01T00:00:00Z');
      expect(ReadingNoteQueryService.apply([a, b], const ReadingNoteQuery()),
          [b, a]);
    });
  });

  group('availableBookTitles', () {
    test('重複除去 / null・空除外 / 昇順', () {
      final notes = [
        note(id: '1', bookTitle: '本B'),
        note(id: '2', bookTitle: '本A'),
        note(id: '3', bookTitle: '本B'),
        note(id: '4', bookTitle: null),
        note(id: '5', bookTitle: ''),
      ];
      expect(ReadingNoteQueryService.availableBookTitles(notes), ['本A', '本B']);
    });
  });

  group('ReadingNoteQuery', () {
    test('isDefault: 既定値なら true', () {
      expect(const ReadingNoteQuery().isDefault, isTrue);
    });

    test('isDefault: 条件があれば false', () {
      expect(
        const ReadingNoteQuery(text: 'x').isDefault,
        isFalse,
      );
      expect(
        const ReadingNoteQuery(sortOrder: ReadingNoteSortOrder.titleAsc)
            .isDefault,
        isFalse,
      );
    });

    test('activeFilterCount: text(1) + bookTitles + contentFilters', () {
      const q = ReadingNoteQuery(
        text: 'abc',
        bookTitles: {'本A', '本B'},
        contentFilters: {ReadingNoteContentFilter.hasLearning},
      );
      expect(q.activeFilterCount, 4);
      expect(const ReadingNoteQuery().activeFilterCount, 0);
      // ソートは数えない
      const sorted = ReadingNoteQuery(
          sortOrder: ReadingNoteSortOrder.learningCountDesc);
      expect(sorted.activeFilterCount, 0);
    });

    test('copyWith: clearBookTitles / clearContentFilters', () {
      const base = ReadingNoteQuery(
        bookTitles: {'本A'},
        contentFilters: {ReadingNoteContentFilter.hasAction},
      );
      final clearedBooks = base.copyWith(clearBookTitles: true);
      expect(clearedBooks.bookTitles, isEmpty);
      expect(clearedBooks.contentFilters,
          {ReadingNoteContentFilter.hasAction});

      final clearedBoth = base.copyWith(
        clearBookTitles: true,
        clearContentFilters: true,
        text: 'x',
      );
      expect(clearedBoth.bookTitles, isEmpty);
      expect(clearedBoth.contentFilters, isEmpty);
      expect(clearedBoth.text, 'x');
      expect(clearedBoth.sortOrder, base.sortOrder);
    });

    test('copyWith: 値の上書き', () {
      const base = ReadingNoteQuery(text: 'a');
      final updated = base.copyWith(
        text: 'b',
        sortOrder: ReadingNoteSortOrder.createdOldest,
      );
      expect(updated.text, 'b');
      expect(updated.sortOrder, ReadingNoteSortOrder.createdOldest);
    });

    test('== / hashCode: 同条件は等価', () {
      const a = ReadingNoteQuery(
        text: 'x',
        bookTitles: {'本A', '本B'},
        contentFilters: {ReadingNoteContentFilter.hasLearning},
      );
      const b = ReadingNoteQuery(
        text: 'x',
        bookTitles: {'本B', '本A'},
        contentFilters: {ReadingNoteContentFilter.hasLearning},
      );
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);

      const c = ReadingNoteQuery(text: 'y');
      expect(a == c, isFalse);
      // 同一インスタンスは identical
      expect(a == a, isTrue);
    });
  });

  group('enum labels', () {
    test('sort order labels', () {
      expect(ReadingNoteSortOrder.createdNewest.label, '新しい順');
      expect(ReadingNoteSortOrder.createdOldest.label, '古い順');
      expect(ReadingNoteSortOrder.titleAsc.label, '書名順');
      expect(ReadingNoteSortOrder.learningCountDesc.label, '学びが多い順');
    });

    test('content filter labels', () {
      expect(ReadingNoteContentFilter.hasLearning.label, '学びあり');
      expect(ReadingNoteContentFilter.hasAction.label, '行動あり');
      expect(ReadingNoteContentFilter.hasQuote.label, '引用あり');
    });
  });
}