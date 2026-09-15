import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/book_shelf.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/share_card/domain/share_card_service.dart';

UserBook _ub({
  required String id,
  BookStatus status = BookStatus.completed,
  String? completedAt,
  String? title,
  List<String> authors = const [],
  int currentPage = 0,
  int? rating,
  int totalReadingMinutes = 0,
}) {
  return UserBook(
    id: id,
    userId: 'u1',
    bookId: 'book-$id',
    book: title == null
        ? null
        : Book(
            id: 'book-$id',
            title: title,
            authors: authors,
            source: BookSource.manual,
            createdAt: '2026-01-01T00:00:00Z',
          ),
    status: status,
    medium: BookMedium.physical,
    currentPage: currentPage,
    rating: rating,
    totalReadingMinutes: totalReadingMinutes,
    completedAt: completedAt,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

BookShelf _shelf(String id, String name, List<String> userBookIds) {
  return BookShelf(
    id: id,
    name: name,
    colorValue: 0,
    createdAt: '2026-01-01T00:00:00Z',
    userBookIds: userBookIds,
  );
}

void main() {
  group('ShareCardService.build', () {
    test('読了本からカードを組み立てる', () {
      final data = ShareCardService.build(
        book: _ub(
          id: 'a',
          completedAt: '2026-09-15T10:00:00Z',
          title: '積読のすすめ',
          authors: const ['山田太郎'],
          currentPage: 320,
          rating: 4,
          totalReadingMinutes: 95,
        ),
      );
      expect(data.title, '積読のすすめ');
      expect(data.authors, const ['山田太郎']);
      expect(data.completedAt, DateTime.utc(2026, 9, 15, 10));
      expect(data.pages, 320);
      expect(data.rating, 4);
      expect(data.readingMinutes, 95);
    });

    test('書誌が無い場合は 無題の書 / 著者不明 にフォールバックする', () {
      final data = ShareCardService.build(
        book: _ub(id: 'a', completedAt: '2026-09-15T10:00:00Z'),
      );
      expect(data.title, '無題の書');
      expect(data.authors, isEmpty);
      expect(data.authorLabel, '著者不明');
    });

    test('未読了の蔵書は ArgumentError', () {
      expect(
        () => ShareCardService.build(
          book: _ub(id: 'a', status: BookStatus.reading, completedAt: '2026-09-15T10:00:00Z'),
        ),
        throwsArgumentError,
      );
      expect(
        () => ShareCardService.build(book: _ub(id: 'b', status: BookStatus.tsundoku)),
        throwsArgumentError,
      );
    });

    test('completedAt が null / パース不能なら ArgumentError', () {
      expect(
        () => ShareCardService.build(book: _ub(id: 'a')),
        throwsArgumentError,
      );
      expect(
        () => ShareCardService.build(
          book: _ub(id: 'b', completedAt: 'not-a-date'),
        ),
        throwsArgumentError,
      );
    });

    test('範囲外の評価は null に丸める', () {
      final zero = ShareCardService.build(
        book: _ub(id: 'a', completedAt: '2026-09-15T10:00:00Z', rating: 0),
      );
      final over = ShareCardService.build(
        book: _ub(id: 'b', completedAt: '2026-09-15T10:00:00Z', rating: 6),
      );
      expect(zero.rating, isNull);
      expect(over.rating, isNull);
    });

    test('負のページ数・読書時間は 0 に丸める', () {
      final data = ShareCardService.build(
        book: _ub(
          id: 'a',
          completedAt: '2026-09-15T10:00:00Z',
          currentPage: -5,
          totalReadingMinutes: -30,
        ),
      );
      expect(data.pages, 0);
      expect(data.readingMinutes, 0);
    });

    test('所属する棚のみを入力順で採用する', () {
      final shelves = [
        _shelf('s1', '積読', const ['a']),
        _shelf('s2', '技術書', const ['a', 'z']),
        _shelf('s3', '趣味', const ['z']),
      ];
      final data = ShareCardService.build(
        book: _ub(id: 'a', completedAt: '2026-09-15T10:00:00Z'),
        shelves: shelves,
      );
      expect(data.shelves, ['積読', '技術書']);
    });

    test('どの棚にも属さなければ shelves は空', () {
      final data = ShareCardService.build(
        book: _ub(id: 'a', completedAt: '2026-09-15T10:00:00Z'),
        shelves: [_shelf('s1', '積読', const ['b'])],
      );
      expect(data.shelves, isEmpty);
    });
  });

  group('ShareCardService.buildLatest', () {
    test('最新の読了を選ぶ', () {
      final latest = ShareCardService.buildLatest(
        books: [
          _ub(id: 'old', completedAt: '2026-01-01T00:00:00Z', title: 'Old'),
          _ub(id: 'new', completedAt: '2026-09-01T00:00:00Z', title: 'New'),
        ],
      );
      expect(latest?.title, 'New');
    });

    test('同時刻は book.id 昇順で決着する', () {
      final latest = ShareCardService.buildLatest(
        books: [
          _ub(id: 'b', completedAt: '2026-09-01T00:00:00Z', title: 'B'),
          _ub(id: 'a', completedAt: '2026-09-01T00:00:00Z', title: 'A'),
        ],
      );
      expect(latest?.title, 'A');
    });

    test('読了本が無ければ null', () {
      expect(ShareCardService.buildLatest(books: const []), isNull);
      expect(
        ShareCardService.buildLatest(
          books: [
            _ub(id: 'a', status: BookStatus.reading, completedAt: '2026-09-01T00:00:00Z'),
            _ub(id: 'b', completedAt: 'bad'),
          ],
        ),
        isNull,
      );
    });
  });

  group('ShareCardService.recent', () {
    test('新しい順に並べ、不正要素は黙って除外する', () {
      final list = ShareCardService.recent(
        books: [
          _ub(id: 'mid', completedAt: '2026-05-01T00:00:00Z', title: 'Mid'),
          _ub(id: 'bad', completedAt: 'oops'),
          _ub(id: 'new', completedAt: '2026-09-01T00:00:00Z', title: 'New'),
          _ub(id: 'reading', status: BookStatus.reading, completedAt: '2026-09-02T00:00:00Z'),
          _ub(id: 'old', completedAt: '2026-01-01T00:00:00Z', title: 'Old'),
        ],
      );
      expect(list.map((e) => e.title), ['New', 'Mid', 'Old']);
    });

    test('limit で切り詰める', () {
      final list = ShareCardService.recent(
        limit: 2,
        books: [
          _ub(id: 'a', completedAt: '2026-09-01T00:00:00Z'),
          _ub(id: 'b', completedAt: '2026-08-01T00:00:00Z'),
          _ub(id: 'c', completedAt: '2026-07-01T00:00:00Z'),
        ],
      );
      expect(list.length, 2);
    });

    test('limit<=0 は空を返す', () {
      expect(
        ShareCardService.recent(
          limit: 0,
          books: [_ub(id: 'a', completedAt: '2026-09-01T00:00:00Z')],
        ),
        isEmpty,
      );
    });
  });

  group('ShareCardService.shareText', () {
    test('最小構成のテキスト', () {
      final text = ShareCardService.shareText(
        ShareCardService.build(
          book: _ub(id: 'a', completedAt: '2026-09-15T10:00:00Z', title: '積読のすすめ'),
        ),
      );
      expect(text, '『積読のすすめ』を読了しました📖\n著者: 著者不明\n読了日: 2026年9月15日\n#積読クエスト');
    });

    test('ページ・評価・読書時間・棚を含む完全なテキスト', () {
      final text = ShareCardService.shareText(
        ShareCardService.build(
          book: _ub(
            id: 'a',
            completedAt: '2026-09-15T10:00:00Z',
            title: '積読のすすめ',
            authors: const ['山田太郎'],
            currentPage: 320,
            rating: 4,
            totalReadingMinutes: 125,
          ),
          shelves: [_shelf('s1', '技術書', const ['a'])],
        ),
      );
      expect(text, contains('ページ数: 320ページ'));
      expect(text, contains('評価: ★★★★☆'));
      expect(text, contains('読書時間: 2時間5分'));
      expect(text, contains('棚: 技術書'));
      expect(text.endsWith('#積読クエスト'), isTrue);
    });

    test('1時間未満は分のみ表示する', () {
      final data = ShareCardService.build(
        book: _ub(
          id: 'a',
          completedAt: '2026-09-15T10:00:00Z',
          totalReadingMinutes: 45,
        ),
      );
      expect(ShareCardService.shareText(data), contains('読書時間: 45分'));
    });

    test('ページ0・未評価・読書時間0 の行は出力しない', () {
      final text = ShareCardService.shareText(
        ShareCardService.build(
          book: _ub(id: 'a', completedAt: '2026-09-15T10:00:00Z'),
        ),
      );
      expect(text.contains('ページ数:'), isFalse);
      expect(text.contains('評価:'), isFalse);
      expect(text.contains('読書時間:'), isFalse);
      expect(text.contains('棚:'), isFalse);
    });
  });
}
