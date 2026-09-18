import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/library_query.dart';

/// UserBook のテスト用ヘルパー生成関数
UserBook makeUserBook({
  required String id,
  String? title,
  List<String> authors = const [],
  int? pageCount,
  BookStatus status = BookStatus.tsundoku,
  String? completedAt,
  String createdAt = '2026-01-01T00:00:00Z',
  Book? book,
}) {
  return UserBook(
    id: id,
    userId: 'u1',
    bookId: 'b-$id',
    book: book ??
        (title == null && authors.isEmpty && pageCount == null
            ? null
            : Book(
                id: 'b-$id',
                title: title ?? '無題',
                authors: authors,
                source: BookSource.manual,
                createdAt: '2026-01-01T00:00:00Z',
                pageCount: pageCount,
              )),
    status: status,
    medium: BookMedium.physical,
    completedAt: completedAt ?? '',
    createdAt: createdAt,
  );
}

void main() {
  group('LibraryQueryService.normalize', () {
    test('前後の半角空白を削除する', () {
      expect(LibraryQueryService.normalize('  abc  '), 'abc');
    });

    test('大文字を小文字にする', () {
      expect(LibraryQueryService.normalize('AbC'), 'abc');
    });

    test('全角英数字を半角にする', () {
      expect(LibraryQueryService.normalize('Ａｂｃ１２３'), 'abc123');
    });

    test('全角記号を半角にする', () {
      expect(LibraryQueryService.normalize('！？'), '!?');
    });

    test('全角スペースを半角スペースにする', () {
      expect(LibraryQueryService.normalize('ａｂ　ｃｄ'), 'ab cd');
    });

    test('連続空白を単一の半角スペースに単一化する', () {
      expect(LibraryQueryService.normalize('a   b　　c'), 'a b c');
    });

    test('空白のみの検索語は空文字になる', () {
      expect(LibraryQueryService.normalize('　  '), '');
    });

    test('日本語は変換されず保持される', () {
      expect(LibraryQueryService.normalize('吾輩は猫である'), '吾輩は猫である');
    });
  });

  group('LibraryQueryService.searchByText', () {
    final books = [
      makeUserBook(id: 'a', title: '吾輩は猫である', authors: ['夏目 漱石']),
      makeUserBook(id: 'b', title: '銀河鉄道の夜', authors: ['宮沢賢治']),
      makeUserBook(id: 'c', title: 'こころ', authors: ['夏目漱石']),
      makeUserBook(id: 'd'), // book が null
    ];

    test('書名の部分一致で絞り込める', () {
      final r = LibraryQueryService.searchByText(books, '猫');
      expect(r.map((e) => e.id), ['a']);
    });

    test('著者名の部分一致で絞り込める', () {
      final r = LibraryQueryService.searchByText(books, '宮沢');
      expect(r.map((e) => e.id), ['b']);
    });

    test('いずれかの著者名に一致すればヒットする', () {
      final r = LibraryQueryService.searchByText(books, '夏目');
      expect(r.map((e) => e.id).toSet(), {'a', 'c'});
    });

    test('書名と著者名どちらにも一致しない語は0件', () {
      expect(LibraryQueryService.searchByText(books, '存在しない'), isEmpty);
    });

    test('正規化後の一致（大文字・全角）でヒットする', () {
      final english = [
        makeUserBook(id: 'e', title: 'Clean Code', authors: ['Robert Martin']),
      ];
      expect(LibraryQueryService.searchByText(english, 'ＣＬＥＡＮ').map((e) => e.id), ['e']);
      expect(LibraryQueryService.searchByText(english, 'robert').map((e) => e.id), ['e']);
    });

    test('空検索語なら全件返す', () {
      expect(LibraryQueryService.searchByText(books, '').length, 4);
    });

    test('空白のみの検索語なら全件返す', () {
      expect(LibraryQueryService.searchByText(books, ' 　').length, 4);
    });

    test('book が null の蔵書は検索にヒットしない（落ちない）', () {
      expect(LibraryQueryService.searchByText(books, '無題'), isEmpty);
    });

    test('入力リストを破壊的に変更しない', () {
      final copy = List.of(books);
      LibraryQueryService.searchByText(books, '夏目');
      expect(books, equals(copy));
    });
  });

  group('LibraryQueryService.filterByStatus', () {
    final books = [
      makeUserBook(id: 'a', title: 'x', status: BookStatus.tsundoku),
      makeUserBook(id: 'b', title: 'y', status: BookStatus.reading),
      makeUserBook(id: 'c', title: 'z', status: BookStatus.completed),
    ];

    test('指定状態のみに絞り込める', () {
      final r = LibraryQueryService.filterByStatus(books, {BookStatus.reading});
      expect(r.map((e) => e.id), ['b']);
    });

    test('複数状態指定（OR条件）', () {
      final r = LibraryQueryService.filterByStatus(
        books,
        {BookStatus.tsundoku, BookStatus.completed},
      );
      expect(r.map((e) => e.id).toSet(), {'a', 'c'});
    });

    test('空集合なら全件返す', () {
      expect(LibraryQueryService.filterByStatus(books, {}).length, 3);
    });
  });

  group('LibraryQueryService.filterByShelf', () {
    final books = [
      makeUserBook(id: 'a', title: 'x'),
      makeUserBook(id: 'b', title: 'y'),
    ];
    final membership = {
      'shelf1': {'a'},
      'shelf2': {'a', 'b'},
    };

    test('shelfId が null なら全件返す', () {
      expect(
        LibraryQueryService.filterByShelf(books, null, membership).length,
        2,
      );
    });

    test('棚のメンバーのみ絞り込める', () {
      final r = LibraryQueryService.filterByShelf(books, 'shelf1', membership);
      expect(r.map((e) => e.id), ['a']);
    });

    test('membership に存在しない棚IDなら空リスト', () {
      expect(
        LibraryQueryService.filterByShelf(books, 'unknown', membership),
        isEmpty,
      );
    });

    test('membership が空なら空リスト', () {
      expect(
        LibraryQueryService.filterByShelf(books, 'shelf1', const {}),
        isEmpty,
      );
    });
  });

  group('LibraryQueryService.sort', () {
    test('addedNewest: createdAt 降順', () {
      final books = [
        makeUserBook(id: 'old', createdAt: '2026-01-01T00:00:00Z'),
        makeUserBook(id: 'new', createdAt: '2026-03-01T00:00:00Z'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.addedNewest);
      expect(r.map((e) => e.id), ['new', 'old']);
    });

    test('addedOldest: createdAt 昇順', () {
      final books = [
        makeUserBook(id: 'new', createdAt: '2026-03-01T00:00:00Z'),
        makeUserBook(id: 'old', createdAt: '2026-01-01T00:00:00Z'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.addedOldest);
      expect(r.map((e) => e.id), ['old', 'new']);
    });

    test('titleAsc: 書名昇順', () {
      final books = [
        makeUserBook(id: '2', title: '銀河鉄道の夜'),
        makeUserBook(id: '1', title: '吾輩は猫である'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.titleAsc);
      expect(r.map((e) => e.id), ['1', '2']);
    });

    test('titleAsc: 書名が同値なら id 昇順', () {
      final books = [
        makeUserBook(id: 'b', title: '同一'),
        makeUserBook(id: 'a', title: '同一'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.titleAsc);
      expect(r.map((e) => e.id), ['a', 'b']);
    });

    test('authorAsc: 先頭著者名の昇順', () {
      final books = [
        makeUserBook(id: '2', title: 't2', authors: ['宮沢賢治']),
        makeUserBook(id: '1', title: 't1', authors: ['夏目漱石']),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.authorAsc);
      expect(r.map((e) => e.id), ['1', '2']);
    });

    test('pagesDesc: ページ数降順', () {
      final books = [
        makeUserBook(id: '1', title: 'a', pageCount: 100),
        makeUserBook(id: '2', title: 'b', pageCount: 300),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.pagesDesc);
      expect(r.map((e) => e.id), ['2', '1']);
    });

    test('pagesDesc: pageCount null は末尾', () {
      final books = [
        makeUserBook(id: 'null1', title: 'a'),
        makeUserBook(id: '2', title: 'b', pageCount: 300),
        makeUserBook(id: 'null2', title: 'c'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.pagesDesc);
      expect(r.map((e) => e.id), ['2', 'null1', 'null2']);
    });

    test('completedNewest: completedAt null は末尾', () {
      final books = [
        makeUserBook(id: 'n', title: 'a'),
        makeUserBook(id: '2', title: 'b', completedAt: '2026-02-01T00:00:00Z'),
        makeUserBook(id: '1', title: 'c', completedAt: '2026-01-01T00:00:00Z'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.completedNewest);
      expect(r.map((e) => e.id), ['2', '1', 'n']);
    });

    test('同時順位は id 昇順で安定', () {
      final books = [
        makeUserBook(id: 'c', createdAt: '2026-01-01T00:00:00Z'),
        makeUserBook(id: 'a', createdAt: '2026-01-01T00:00:00Z'),
        makeUserBook(id: 'b', createdAt: '2026-01-01T00:00:00Z'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.addedNewest);
      expect(r.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('入力リストを破壊的に変更しない', () {
      final books = [
        makeUserBook(id: '2', title: '銀河鉄道の夜'),
        makeUserBook(id: '1', title: '吾輩は猫である'),
      ];
      final before = List.of(books);
      LibraryQueryService.sort(books, LibrarySortOrder.titleAsc);
      expect(books, equals(before));
    });
  });

  group('LibraryQueryService.apply', () {
    final books = [
      makeUserBook(
        id: 'a',
        title: '吾輩は猫である',
        authors: ['夏目漱石'],
        pageCount: 300,
        status: BookStatus.reading,
        createdAt: '2026-02-01T00:00:00Z',
      ),
      makeUserBook(
        id: 'b',
        title: '銀河鉄道の夜',
        authors: ['宮沢賢治'],
        pageCount: 200,
        status: BookStatus.reading,
        createdAt: '2026-03-01T00:00:00Z',
      ),
      makeUserBook(
        id: 'c',
        title: 'こころ',
        authors: ['夏目漱石'],
        pageCount: 250,
        status: BookStatus.completed,
        completedAt: '2026-04-01T00:00:00Z',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    ];
    final membership = {
      'shelf1': {'a', 'c'},
    };

    test('検索+状態+棚+ソートの複合適用', () {
      final query = const LibraryQuery(
        text: '夏目',
        statuses: {BookStatus.reading},
        shelfId: 'shelf1',
        sortOrder: LibrarySortOrder.pagesDesc,
      );
      final r = LibraryQueryService.apply(books, query, membership: membership);
      // 夏目著書 → a(reading), c(completed) → reading のみ → a
      expect(r.map((e) => e.id), ['a']);
    });

    test('既定クエリなら追加が新しい順で全件', () {
      final r = LibraryQueryService.apply(books, const LibraryQuery());
      expect(r.map((e) => e.id), ['b', 'a', 'c']);
    });

    test('membership 未指定でも shelfId null なら問題なく動く', () {
      final r = LibraryQueryService.apply(books, const LibraryQuery());
      expect(r.length, 3);
    });
  });

  group('LibraryQueryService.countByStatus', () {
    test('3状態すべてをキーに含め、0件も含む', () {
      final books = [
        makeUserBook(id: 'a', title: 'x', status: BookStatus.tsundoku),
        makeUserBook(id: 'b', title: 'y', status: BookStatus.tsundoku),
        makeUserBook(id: 'c', title: 'z', status: BookStatus.reading),
      ];
      final r = LibraryQueryService.countByStatus(books);
      expect(r.keys.toSet(), BookStatus.values.toSet());
      expect(r[BookStatus.tsundoku], 2);
      expect(r[BookStatus.reading], 1);
      expect(r[BookStatus.completed], 0);
    });

    test('空リストならすべて0', () {
      final r = LibraryQueryService.countByStatus(const []);
      expect(r[BookStatus.tsundoku], 0);
      expect(r[BookStatus.reading], 0);
      expect(r[BookStatus.completed], 0);
    });
  });

  group('LibraryQueryService.resultLabel', () {
    test("'N件' 形式のラベルを返す", () {
      expect(LibraryQueryService.resultLabel(0), '0件');
      expect(LibraryQueryService.resultLabel(12), '12件');
    });
  });

  group('LibrarySortOrder.label', () {
    test('日本語ラベルを持つ', () {
      expect(LibrarySortOrder.addedNewest.label, '追加が新しい順');
      expect(LibrarySortOrder.addedOldest.label, '追加が古い順');
      expect(LibrarySortOrder.titleAsc.label, '書名順');
      expect(LibrarySortOrder.authorAsc.label, '著者名順');
      expect(LibrarySortOrder.pagesDesc.label, 'ページ数が多い順');
      expect(LibrarySortOrder.completedNewest.label, '読了が新しい順');
    });
  });

  group('LibraryQuery.isDefault / activeFilterCount', () {
    test('既定値そのものは isDefault が true', () {
      expect(const LibraryQuery().isDefault, isTrue);
    });

    test('テキストがあれば isDefault は false', () {
      expect(const LibraryQuery(text: '猫').isDefault, isFalse);
    });

    test('statuses があれば isDefault は false', () {
      expect(
        const LibraryQuery(statuses: {BookStatus.reading}).isDefault,
        isFalse,
      );
    });

    test('shelfId があれば isDefault は false', () {
      expect(const LibraryQuery(shelfId: 's1').isDefault, isFalse);
    });

    test('ソートだけ変えても isDefault は false', () {
      expect(
        const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc).isDefault,
        isFalse,
      );
    });

    test('activeFilterCount: 既定は0', () {
      expect(const LibraryQuery().activeFilterCount, 0);
    });

    test('activeFilterCount: テキスト1 + statuses2 + shelf1 = 4（ソートは数えない）', () {
      final q = const LibraryQuery(
        text: '猫',
        statuses: {BookStatus.reading, BookStatus.completed},
        shelfId: 's1',
        sortOrder: LibrarySortOrder.titleAsc,
      );
      expect(q.activeFilterCount, 4);
    });
  });

  group('LibraryQuery.copyWith / == / hashCode', () {
    test('copyWith で text を変える', () {
      const q = LibraryQuery();
      expect(q.copyWith(text: '猫').text, '猫');
      expect(q.copyWith(text: '猫').sortOrder, LibrarySortOrder.addedNewest);
    });

    test('copyWith で statuses を変える', () {
      const q = LibraryQuery();
      expect(q.copyWith(statuses: {BookStatus.reading}).statuses, {BookStatus.reading});
    });

    test('copyWith で shelfId を設定する', () {
      const q = LibraryQuery();
      expect(q.copyWith(shelfId: 's1').shelfId, 's1');
    });

    test('copyWith(clearShelfId: true) で shelfId を解除する', () {
      const q = LibraryQuery(shelfId: 's1');
      expect(q.copyWith(clearShelfId: true).shelfId, isNull);
    });

    test('copyWith(clearShelfId: true) は新規 shelfId 指定より優先する', () {
      const q = LibraryQuery(shelfId: 's1');
      expect(q.copyWith(shelfId: 's2', clearShelfId: true).shelfId, isNull);
    });

    test('== と hashCode: 同じ内容は等しい', () {
      const a = LibraryQuery(text: '猫', shelfId: 's1');
      const b = LibraryQuery(text: '猫', shelfId: 's1');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('==: statuses の順序に依存しない', () {
      const a = LibraryQuery(statuses: {BookStatus.reading, BookStatus.completed});
      const b = LibraryQuery(statuses: {BookStatus.completed, BookStatus.reading});
      expect(a, equals(b));
    });

    test('==: 違う内容は等しくない', () {
      const a = LibraryQuery(text: '猫');
      const b = LibraryQuery(text: '犬');
      expect(a == b, isFalse);
    });
  });
}
