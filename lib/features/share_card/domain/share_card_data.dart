/// 読了達成シェアカードのデータ
library;

import 'package:meta/meta.dart';

/// シェアカード1枚分の不変データ
@immutable
class ShareCardData {
  final String title;
  final List<String> authors;
  final DateTime completedAt;
  final int pages;
  final int? rating;
  final List<String> shelves;
  final int readingMinutes;

  const ShareCardData({
    required this.title,
    this.authors = const [],
    required this.completedAt,
    this.pages = 0,
    this.rating,
    this.shelves = const [],
    this.readingMinutes = 0,
  });

  String get authorLabel =>
      authors.isEmpty ? '著者不明' : authors.join('、');

  String get dateLabel => '${completedAt.year}年'
      '${completedAt.month}月${completedAt.day}日';

  String get pagesLabel => pages > 0 ? '$pagesページ' : 'ページ数不明';

  bool get hasRating => rating != null && rating! >= 1 && rating! <= 5;
}
