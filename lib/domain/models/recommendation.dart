import 'user_book.dart';

/// 今日のおすすめ — 本のタイトル・著者・推薦理由・表紙URL等を含む
///
/// [Recommendation] インスタンスは [Recommendation.fromUserBook] または
/// [Recommendation.fromParams] で生成する。 [book] が指定された場合、
/// [bookTitle] と [author] は [book] から自動導出される。
class Recommendation {
  final String id;
  final String bookTitle;
  final String author;
  final String reason;
  final String? imageUrl;
  final String createdAt;
  final UserBook? book;

  const Recommendation._({
    required this.id,
    required this.bookTitle,
    required this.author,
    required this.reason,
    this.imageUrl,
    required this.createdAt,
    this.book,
  });

  /// UserBook から Recommendation を生成する
  ///
  /// [bookTitle] / [author] / [imageUrl] は [userBook] から自動導出されるが、
  /// 明示的に上書きも可能。
  factory Recommendation.fromUserBook(
    UserBook userBook, {
    required String reason,
    String? id,
    String? bookTitle,
    String? author,
    String? imageUrl,
    String? createdAt,
  }) {
    final title = bookTitle ??
        userBook.book?.title ??
        '不明なタイトル';
    final authorStr = author ??
        (userBook.book?.authors.isNotEmpty == true
            ? userBook.book!.authors.join(', ')
            : '不明な著者');
    return Recommendation._(
      id: id ?? userBook.id,
      bookTitle: title,
      author: authorStr,
      reason: reason,
      imageUrl: imageUrl ?? userBook.book?.coverImageUrl,
      createdAt: createdAt ?? userBook.createdAt,
      book: userBook,
    );
  }

  /// bookを持たない Recommendation を明示的なパラメータで生成する
  factory Recommendation.fromParams({
    required String reason,
    String id = '',
    String bookTitle = '不明なタイトル',
    String author = '不明な著者',
    String? imageUrl,
    String createdAt = '',
  }) {
    return Recommendation._(
      id: id,
      bookTitle: bookTitle,
      author: author,
      reason: reason,
      imageUrl: imageUrl,
      createdAt: createdAt,
    );
  }
}
