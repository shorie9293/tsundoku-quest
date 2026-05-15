/// 書誌情報の取得元
enum BookSource {
  openbd('openbd'),
  googleBooks('google_books'),
  rakuten('rakuten'),
  manual('manual');

  final String value;
  const BookSource(this.value);

  static BookSource fromString(String s) {
    return BookSource.values.firstWhere(
      (e) => e.value == s,
      orElse: () => BookSource.manual,
    );
  }
}

/// 書誌マスター
class Book {
  final String id;
  final String? isbn13;
  final String? isbn10;
  final String title;
  final List<String> authors;
  final String? publisher;
  final String? publishedDate;
  final String? description;
  final int? pageCount;
  final String? coverImageUrl;
  final BookSource source;
  final String createdAt;

  const Book({
    required this.id,
    this.isbn13,
    this.isbn10,
    required this.title,
    this.authors = const [],
    this.publisher,
    this.publishedDate,
    this.description,
    this.pageCount,
    this.coverImageUrl,
    required this.source,
    required this.createdAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      isbn13: json['isbn13'] as String?,
      isbn10: json['isbn10'] as String?,
      title: json['title'] as String,
      authors: (json['authors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      publisher: json['publisher'] as String?,
      publishedDate: json['publishedDate'] as String?,
      description: json['description'] as String?,
      pageCount: json['pageCount'] as int?,
      coverImageUrl: json['coverImageUrl'] as String?,
      source: BookSource.fromString(json['source'] as String),
      createdAt: json['createdAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isbn13': isbn13,
      'isbn10': isbn10,
      'title': title,
      'authors': authors,
      'publisher': publisher,
      'publishedDate': publishedDate,
      'description': description,
      'pageCount': pageCount,
      'coverImageUrl': coverImageUrl,
      'source': source.value,
      'createdAt': createdAt,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Book &&
        other.id == id &&
        other.isbn13 == isbn13 &&
        other.isbn10 == isbn10 &&
        other.title == title &&
        _listEquals(other.authors, authors) &&
        other.publisher == publisher &&
        other.publishedDate == publishedDate &&
        other.description == description &&
        other.pageCount == pageCount &&
        other.coverImageUrl == coverImageUrl &&
        other.source == source &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        isbn13,
        isbn10,
        title,
        Object.hashAll(authors),
        publisher,
        publishedDate,
        description,
        pageCount,
        coverImageUrl,
        source,
        createdAt,
      );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
