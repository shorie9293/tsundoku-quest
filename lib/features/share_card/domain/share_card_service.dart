/// 読了シェアカード生成の純粋ロジック
library;

import '../../../../domain/models/book_shelf.dart';
import '../../../../domain/models/user_book.dart';
import 'share_card_data.dart';

class ShareCardService {
  ShareCardService._();

  static DateTime? _tryParse(String? s) {
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  /// UserBook からシェアカードを組み立てる。
  /// status!=completed または completedAt が null/パース不能なら ArgumentError。
  static ShareCardData build({
    required UserBook book,
    List<BookShelf> shelves = const [],
  }) {
    if (book.status != BookStatus.completed) {
      throw ArgumentError('completed でない本はシェアカードにできない');
    }
    final completed = _tryParse(book.completedAt);
    if (completed == null) {
      throw ArgumentError('completedAt が不正');
    }

    final shelfNames = [
      for (final shelf in shelves)
        if (shelf.userBookIds.contains(book.id)) shelf.name,
    ];

    final rating = book.rating;
    final validRating = (rating != null && rating >= 1 && rating <= 5)
        ? rating
        : null;

    return ShareCardData(
      title: book.book?.title ?? '無題の書',
      authors: book.book?.authors ?? const [],
      completedAt: completed,
      pages: book.currentPage < 0 ? 0 : book.currentPage,
      rating: validRating,
      shelves: shelfNames,
      readingMinutes:
          book.totalReadingMinutes < 0 ? 0 : book.totalReadingMinutes,
    );
  }

  /// 有効な読了のうち completedAt 最新のもの。
  /// 同時刻タイブレークは book.id 昇順。無ければ null。
  static ShareCardData? buildLatest({
    required List<UserBook> books,
    List<BookShelf> shelves = const [],
  }) {
    final recents = recent(books: books, shelves: shelves, limit: 1);
    return recents.isEmpty ? null : recents.first;
  }

  /// 新しい順・タイブレーク id 昇順・limit<=0 は空・不正要素は黙って除外。
  static List<ShareCardData> recent({
    required List<UserBook> books,
    List<BookShelf> shelves = const [],
    int limit = 10,
  }) {
    if (limit <= 0) return const [];
    final valid = <(DateTime, String, ShareCardData)>[];
    for (final book in books) {
      try {
        final data = build(book: book, shelves: shelves);
        valid.add((data.completedAt, book.id, data));
      } on ArgumentError {
        // 不正要素は黙って除外
      }
    }
    valid.sort((a, b) {
      final byDate = b.$1.compareTo(a.$1);
      if (byDate != 0) return byDate;
      return a.$2.compareTo(b.$2);
    });
    return valid.take(limit).map((e) => e.$3).toList();
  }

  /// SNS/メモ共有用テキスト
  static String shareText(ShareCardData d) {
    final lines = <String>[
      '『${d.title}』を読了しました📖',
      '著者: ${d.authorLabel}',
      '読了日: ${d.dateLabel}',
    ];
    if (d.pages > 0) {
      lines.add('ページ数: ${d.pagesLabel}');
    }
    if (d.hasRating) {
      lines.add(
        '評価: ${'★' * d.rating!}${'☆' * (5 - d.rating!)}',
      );
    }
    if (d.readingMinutes > 0) {
      final h = d.readingMinutes ~/ 60;
      final m = d.readingMinutes % 60;
      lines.add(h == 0 ? '読書時間: ${m}分' : '読書時間: ${h}時間${m}分');
    }
    if (d.shelves.isNotEmpty) {
      lines.add('棚: ${d.shelves.join('、')}');
    }
    lines.add('#積読クエスト');
    return lines.join('\n');
  }
}
