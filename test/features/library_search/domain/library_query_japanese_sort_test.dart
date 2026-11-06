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
  String createdAt = '2026-01-01T00:00:00Z',
}) {
  return UserBook(
    id: id,
    userId: 'u1',
    bookId: 'b-$id',
    book: title == null
        ? null
        : Book(
            id: 'b-$id',
            title: title,
            authors: authors,
            source: BookSource.manual,
            createdAt: '2026-01-01T00:00:00Z',
            pageCount: pageCount,
          ),
    status: status,
    medium: BookMedium.physical,
    completedAt: '',
    createdAt: createdAt,
  );
}

void main() {
  group('LibraryQueryService.sort / titleAsc 日本語かな順', () {
    test('かな同士は五十音順（あ→ん）になる', () {
      final books = [
        makeUserBook(id: '4', title: 'ん'),
        makeUserBook(id: '1', title: 'あ'),
        makeUserBook(id: '3', title: 'う'),
        makeUserBook(id: '2', title: 'い'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.titleAsc);
      expect(r.map((e) => e.id), ['1', '2', '3', '4']);
    });

    test('カタカナが「ん」の後ろへ落ちず、ひらがなと混在して並ぶ', () {
      final books = [
        makeUserBook(id: 'kara', title: 'カラス'),
        makeUserBook(id: 'ahi', title: 'あひる'),
        makeUserBook(id: 'iro', title: 'いろは'),
        makeUserBook(id: 'n', title: 'ん'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.titleAsc);
      // コードポイント順だと カラス(30AB) が ん(3093) より後ろになる
      expect(r.map((e) => e.id), ['ahi', 'iro', 'kara', 'n']);
    });

    test('半角カナもかなとして扱われる', () {
      final books = [
        makeUserBook(id: 'inu', title: 'いぬ'),
        makeUserBook(id: 'half', title: 'ｱﾋﾙ'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.titleAsc);
      expect(r.map((e) => e.id), ['half', 'inu']);
    });

    test('漢字など非かなはかなの後ろ（従来どおり漢字同士はコードポイント順）', () {
      final books = [
        makeUserBook(id: 'gin', title: '銀河鉄道の夜'),
        makeUserBook(id: 'ai', title: 'あい'),
        makeUserBook(id: 'wagahai', title: '吾輩は猫である'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.titleAsc);
      expect(r.map((e) => e.id), ['ai', 'wagahai', 'gin']);
    });

    test('book が null の行は titleAsc でも末尾のまま', () {
      final books = [
        makeUserBook(id: 'zzz'), // book null
        makeUserBook(id: 'b', title: 'ん'),
        makeUserBook(id: 'aaa'), // book null
        makeUserBook(id: 'a', title: 'あ'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.titleAsc);
      expect(r.map((e) => e.id), ['a', 'b', 'aaa', 'zzz']);
    });

    test('かな表記ゆれで同値なら id 昇順（安定ソート維持）', () {
      final books = [
        makeUserBook(id: 'b', title: 'ココロ'),
        makeUserBook(id: 'a', title: 'こころ'),
        makeUserBook(id: 'c', title: 'さくら'),
      ];
      final r = LibraryQueryService.sort(books, LibrarySortOrder.titleAsc);
      expect(r.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('入力リストを破壊的に変更しない（日本語ソートでも）', () {
      final books = [
        makeUserBook(id: 'kara', title: 'カラス'),
        makeUserBook(id: 'ahi', title: 'あひる'),
      ];
      final before = List.of(books);
      LibraryQueryService.sort(books, LibrarySortOrder.titleAsc);
      expect(books, equals(before));
    });
  });
}