import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/text/kana_fold.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/library_query.dart';
import 'package:tsundoku_quest/features/history/data/reading_notes_provider.dart';
import 'package:tsundoku_quest/features/history/domain/reading_note_query.dart';

/// UserBook のテスト用ヘルパー生成関数
UserBook makeUserBook({
  required String id,
  String? title,
  List<String> authors = const [],
  BookStatus status = BookStatus.tsundoku,
  String createdAt = '2026-01-01T00:00:00Z',
  Book? book,
}) {
  return UserBook(
    id: id,
    userId: 'u1',
    bookId: 'b-$id',
    book: book ??
        (title == null && authors.isEmpty
            ? null
            : Book(
                id: 'b-$id',
                title: title ?? '無題',
                authors: authors,
                source: BookSource.manual,
                createdAt: '2026-01-01T00:00:00Z',
              )),
    status: status,
    medium: BookMedium.physical,
    completedAt: '',
    createdAt: createdAt,
  );
}

ReadingNoteItem makeNote({required String id, String? title}) =>
    ReadingNoteItem(
      id: id,
      userBookId: 'ub-$id',
      bookTitle: title,
      learnings: const [],
      action: '',
      createdAt: '2026-09-01T00:00:00Z',
    );

void main() {
  group('foldKana: ひらがな → カタカナ', () {
    test('基本五音がカタカナになる', () {
      expect(foldKana('あいうえお'), 'アイウエオ');
    });

    test('濁音・半濁音・拗音・長音もカタカナになる', () {
      expect(foldKana('ぐりむどうわ'), 'グリムドウワ');
      expect(foldKana('ぱぴぷぺぽ'), 'パピプペポ');
      expect(foldKana('しゃしゅしょ'), 'シャシュショ');
      expect(foldKana('らーめん'), 'ラーメン');
    });

    test('小書きの ゕ・ゖ もカタカナ（ヵ・ヶ）になる', () {
      expect(foldKana('ゕ'), 'ヵ');
      expect(foldKana('ゖ'), 'ヶ');
      expect(foldKana('いっゖ'), 'イッヶ');
      expect(foldKana('ゕゖ'), 'ヵヶ');
    });
  });

  group('foldKana: 半角カナ → 全角カタカナ', () {
    test('濁点なしの半角カナが全角カタカナになる', () {
      expect(foldKana('ｱｲｳｴｵ'), 'アイウエオ');
      expect(foldKana('ｸﾞﾘﾑﾄﾞｳﾜ'), 'グリムドウワ');
    });

    test('半角濁点（ﾞ）が結合して濁音になる（表引き）', () {
      expect(foldKana('ｶﾞｷﾞｸﾞｹﾞｺﾞ'), 'ガギグゲゴ');
      expect(foldKana('ｻﾞｼﾞｽﾞｾﾞｿﾞ'), 'ザジズゼゾ');
      expect(foldKana('ﾀﾞﾁﾞﾂﾞﾃﾞﾄﾞ'), 'ダヂヅデド');
      expect(foldKana('ﾊﾞﾋﾞﾌﾞﾍﾞﾎﾞ'), 'バビブベボ');
      expect(foldKana('ｳﾞ'), 'ヴ');
      expect(foldKana('ﾜﾞ'), 'ヷ');
      expect(foldKana('ｦﾞ'), 'ヺ');
    });

    test('半角半濁点（ﾟ）が結合して半濁音になる（表引き）', () {
      expect(foldKana('ﾊﾟﾋﾟﾌﾟﾍﾟﾎﾟ'), 'パピプペポ');
    });

    test('小書き・長音・撥音の半角カナも全角になる', () {
      expect(foldKana('ｧｨｩｪｫ'), 'ァィゥェォ');
      expect(foldKana('ｬｭｮｯ'), 'ャュョッ');
      expect(foldKana('ｰﾝ'), 'ーン');
      expect(foldKana('ｦ'), 'ヲ');
    });

    test('合成先を持たない半角濁点は結合用文字として保持される', () {
      // ｱ + ﾞ は ア゛ 相当（ア+結合用濁点）。情報を落とさない。
      expect(foldKana('ｱﾞ'), 'ア\u3099');
      expect(foldKana('ｱﾟ'), 'ア\u309A');
    });
  });

  group('foldKana: 不変性', () {
    test('全角カタカナは変化しない', () {
      expect(foldKana('グリム童話'), 'グリム童話');
      expect(foldKana('ヴァイオリン'), 'ヴァイオリン');
      expect(foldKana('ヵヶ'), 'ヵヶ');
    });

    test('ASCII・数字・記号は変化しない', () {
      expect(foldKana('abc ABC 123 !?'), 'abc ABC 123 !?');
    });

    test('全角記号・漢字は変化しない', () {
      expect(foldKana('「」、。！？'), '「」、。！？');
      expect(foldKana('吾輩猫'), '吾輩猫');
    });

    test('空文字はそのまま', () {
      expect(foldKana(''), '');
    });
  });

  group('foldKana: 冪等性', () {
    const samples = [
      '',
      'あいうえお',
      'ｸﾞﾘﾑﾄﾞｳﾜ',
      'ｶﾞﾊﾟｳﾞ',
      'グリム童話',
      'abc ABC',
      'ゕゖゝゞ',
      'らーめん ｶﾞ グリム',
    ];

    for (final s in samples) {
      test('2回適用しても同じ: "$s"', () {
        final once = foldKana(s);
        expect(foldKana(once), once);
      });
    }
  });

  group('normalizeForSearch', () {
    test('ひらがなクエリはカタカナへ寄せられる', () {
      expect(LibraryQueryService.normalizeForSearch('ぐりむ'), 'グリム');
      expect(ReadingNoteQueryService.normalizeForSearch('ぐりむ'), 'グリム');
    });

    test('半角カナクエリは全角カタカナへ寄せられる', () {
      expect(LibraryQueryService.normalizeForSearch('ｸﾞﾘﾑ'), 'グリム');
      expect(ReadingNoteQueryService.normalizeForSearch('ｸﾞﾘﾑ'), 'グリム');
    });

    test('既存 normalize の戻り値は変わらない（回帰防止）', () {
      expect(LibraryQueryService.normalize('Ａｂｃ１２３'), 'abc123');
      expect(LibraryQueryService.normalize('ａｂ　ｃｄ'), 'ab cd');
      expect(LibraryQueryService.normalize('ぐりむ'), 'ぐりむ');
      expect(ReadingNoteQueryService.normalize('ぐりむ'), 'ぐりむ');
      expect(ReadingNoteQueryService.normalize('Ａｂｃ　ｄ'), 'abc d');
    });
  });

  group('検索統合: LibraryQueryService.searchByText', () {
    final books = [
      makeUserBook(id: 'a', title: 'グリム童話', authors: ['グリム兄弟']),
      makeUserBook(id: 'b', title: '銀河鉄道の夜', authors: ['宮沢賢治']),
      makeUserBook(id: 'c', title: 'こころ', authors: ['夏目漱石']),
      makeUserBook(id: 'd'), // book が null
    ];

    test('書名がカタカナでも「ひらがな」クエリでヒットする', () {
      final r = LibraryQueryService.searchByText(books, 'ぐりむ');
      expect(r.map((e) => e.id).toList(), ['a']);
    });

    test('半角カナ入力でもヒットする（濁点合成込み）', () {
      final r = LibraryQueryService.searchByText(books, 'ｸﾞﾘﾑ');
      expect(r.map((e) => e.id).toList(), ['a']);
    });

    test('カタカナ表記のままでも従来どおりヒットする', () {
      final r = LibraryQueryService.searchByText(books, 'グリム');
      expect(r.map((e) => e.id).toList(), ['a']);
    });

    test('著者名（カタカナ）もひらがなクエリでヒットする', () {
      // 書名は漢字のみ。ヒットは著者名経由でのみ成立する。
      final authorOnly = [
        makeUserBook(id: 'x', title: '童話集', authors: ['グリム']),
      ];
      final r = LibraryQueryService.searchByText(authorOnly, 'ぐりむ');
      expect(r.map((e) => e.id).toList(), ['x']);
      expect(
        LibraryQueryService.searchByText(authorOnly, 'ｸﾞﾘﾑ')
            .map((e) => e.id)
            .toList(),
        ['x'],
      );
    });

    test('ひらがな書名は従来どおりひらがなでヒットする', () {
      final r = LibraryQueryService.searchByText(books, 'こころ');
      expect(r.map((e) => e.id).toList(), ['c']);
      // カタカナクエリでも同じ書名に届く
      expect(
        LibraryQueryService.searchByText(books, 'ココロ')
            .map((e) => e.id)
            .toList(),
        ['c'],
      );
    });

    test('既存検索が壊れない（漢字・ASCII・空クエリ・book null）', () {
      expect(
        LibraryQueryService.searchByText(books, '銀河').map((e) => e.id).toList(),
        ['b'],
      );
      expect(LibraryQueryService.searchByText(books, '   ').length, 4);
      expect(LibraryQueryService.searchByText(books, 'zzz'), isEmpty);
    });

    test('apply 経由でもかな揺れ検索が効く', () {
      final r = LibraryQueryService.apply(
        books,
        const LibraryQuery(text: 'ぐりむ'),
      );
      expect(r.map((e) => e.id).toList(), ['a']);
    });
  });

  group('検索統合: ReadingNoteQueryService.matchesText', () {
    test('書名がカタカナでもひらがなクエリで一致する', () {
      final note = makeNote(id: 'a', title: 'グリム童話');
      expect(ReadingNoteQueryService.matchesText(note, 'ぐりむ'), isTrue);
      expect(ReadingNoteQueryService.matchesText(note, 'ｸﾞﾘﾑ'), isTrue);
      expect(ReadingNoteQueryService.matchesText(note, 'グリム'), isTrue);
      expect(ReadingNoteQueryService.matchesText(note, 'ぞう'), isFalse);
    });
  });
}
