import 'book.dart';

/// 本の読書状態
enum BookStatus {
  tsundoku('tsundoku'),
  reading('reading'),
  completed('completed');

  final String value;
  const BookStatus(this.value);

  static BookStatus fromString(String s) {
    return BookStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => BookStatus.tsundoku,
    );
  }
}

/// 本の媒体
enum BookMedium {
  physical('physical'),
  ebook('ebook'),
  audiobook('audiobook');

  final String value;
  const BookMedium(this.value);

  static BookMedium fromString(String s) {
    return BookMedium.values.firstWhere(
      (e) => e.value == s,
      orElse: () => BookMedium.physical,
    );
  }
}

/// ユーザーの蔵書（所有・読書状態）
class UserBook {
  final String id;
  final String userId;
  final String bookId;
  final Book? book; // JOIN 時に含む
  final BookStatus status;
  final BookMedium medium;
  final int currentPage;
  final int totalReadingMinutes;
  final int? rating;
  final String? startedAt;
  final String? completedAt;
  final String? notes;
  final String createdAt;

  const UserBook({
    required this.id,
    required this.userId,
    required this.bookId,
    this.book,
    required this.status,
    required this.medium,
    this.currentPage = 0,
    this.totalReadingMinutes = 0,
    this.rating,
    this.startedAt,
    this.completedAt,
    this.notes,
    required this.createdAt,
  });

  factory UserBook.fromJson(Map<String, dynamic> json) {
    return UserBook(
      id: json['id'] as String,
      userId: json['userId'] as String,
      bookId: json['bookId'] as String,
      book: json['book'] != null
          ? Book.fromJson(json['book'] as Map<String, dynamic>)
          : null,
      status: BookStatus.fromString(json['status'] as String),
      medium: BookMedium.fromString(json['medium'] as String),
      currentPage: json['currentPage'] as int? ?? 0,
      totalReadingMinutes: json['totalReadingMinutes'] as int? ?? 0,
      rating: json['rating'] as int?,
      startedAt: json['startedAt'] as String?,
      completedAt: json['completedAt'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'bookId': bookId,
      'book': book?.toJson(),
      'status': status.value,
      'medium': medium.value,
      'currentPage': currentPage,
      'totalReadingMinutes': totalReadingMinutes,
      'rating': rating,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  // ━━━ Supabase連携 ━━━

  /// Supabaseのスネークケースカラム名からUserBookを生成
  factory UserBook.fromSupabase(Map<String, dynamic> json) {
    // book のJOIN結果をcamelCaseに変換
    Map<String, dynamic>? bookJson;
    if (json['book'] != null) {
      final b = json['book'] as Map<String, dynamic>;
      bookJson = {
        'id': b['id'],
        'isbn13': b['isbn13'],
        'isbn10': b['isbn10'],
        'title': b['title'],
        'authors': b['authors'] ?? [],
        'publisher': b['publisher'],
        'publishedDate': b['published_date']?.toString(),
        'description': b['description'],
        'pageCount': b['page_count'],
        'coverImageUrl': b['cover_image_url'],
        'source': b['source'] ?? 'manual',
        'createdAt': b['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
    }

    return UserBook(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      book: bookJson != null ? Book.fromJson(bookJson) : null,
      status: BookStatus.fromString(json['status'] as String),
      medium: BookMedium.fromString(json['medium'] as String),
      currentPage: json['current_page'] as int? ?? 0,
      totalReadingMinutes: json['total_reading_minutes'] as int? ?? 0,
      rating: json['rating'] as int?,
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  /// Supabase保存用のスネークケースMapに変換
  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'status': status.value,
      'medium': medium.value,
      'current_page': currentPage,
      'total_reading_minutes': totalReadingMinutes,
      'rating': rating,
      'started_at': startedAt,
      'completed_at': completedAt,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}
