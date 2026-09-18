import 'package:flutter/foundation.dart';

import 'package:tsundoku_quest/domain/models/user_book.dart';

/// 並び替え順
enum LibrarySortOrder {
  addedNewest('追加が新しい順'),
  addedOldest('追加が古い順'),
  titleAsc('書名順'),
  authorAsc('著者名順'),
  pagesDesc('ページ数が多い順'),
  completedNewest('読了が新しい順');

  final String label;
  const LibrarySortOrder(this.label);
}

/// ISO8601文字列を比較可能な値に変換（null は常に末尾扱い）
int _isoCompare(String? a, String? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1; // null は末尾
  if (b == null) return -1;
  return a.compareTo(b);
}

/// 蔵書検索のクエリ条件（不変）
@immutable
class LibraryQuery {
  final String text;

  /// 絞り込む状態。空集合 = 全状態
  final Set<BookStatus> statuses;

  /// 絞り込む棚。null = 全棚
  final String? shelfId;
  final LibrarySortOrder sortOrder;

  const LibraryQuery({
    this.text = '',
    this.statuses = const {},
    this.shelfId,
    this.sortOrder = LibrarySortOrder.addedNewest,
  });

  LibraryQuery copyWith({
    String? text,
    Set<BookStatus>? statuses,
    String? shelfId,
    bool clearShelfId = false,
    LibrarySortOrder? sortOrder,
  }) {
    return LibraryQuery(
      text: text ?? this.text,
      statuses: statuses ?? this.statuses,
      shelfId: clearShelfId ? null : (shelfId ?? this.shelfId),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// 既定値そのものか
  bool get isDefault =>
      text.isEmpty &&
      statuses.isEmpty &&
      shelfId == null &&
      sortOrder == LibrarySortOrder.addedNewest;

  /// 有効な絞り込み条件の数（テキスト有無 + statuses件数 + shelfId有無。ソートは数えない）
  int get activeFilterCount {
    var count = 0;
    if (text.isNotEmpty) count++;
    count += statuses.length;
    if (shelfId != null) count++;
    return count;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LibraryQuery &&
        other.text == text &&
        setEquals(other.statuses, statuses) &&
        other.shelfId == shelfId &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode => Object.hash(text, Object.hashAllUnordered(statuses), shelfId, sortOrder);
}

/// 蔵書の検索・絞り込み・並び替え（純粋関数のみ）
class LibraryQueryService {
  const LibraryQueryService._();

  /// 検索語の正規化:
  /// trim → 全角英数字(U+FF01..U+FF5E)と全角スペース(U+3000)を半角へ
  /// → toLowerCase → 連続空白を単一化
  static String normalize(String raw) {
    final sb = StringBuffer();
    for (final code in raw.trim().runes) {
      if (code >= 0xFF01 && code <= 0xFF5E) {
        sb.writeCharCode(code - 0xFEE0);
      } else if (code == 0x3000) {
        sb.write(' ');
      } else {
        sb.writeCharCode(code);
      }
    }
    return sb.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 書名 か いずれかの著者名 に検索語を含む（正規化後の部分一致）。
  /// 空/空白のみの検索語なら全件。
  static List<UserBook> searchByText(List<UserBook> books, String text) {
    final q = normalize(text);
    if (q.isEmpty) return List.of(books);
    return books.where((ub) {
      final book = ub.book;
      if (book == null) return false;
      if (normalize(book.title).contains(q)) return true;
      return book.authors.any((a) => normalize(a).contains(q));
    }).toList();
  }

  /// 状態で絞り込む（statuses が空なら全件）
  static List<UserBook> filterByStatus(
    List<UserBook> books,
    Set<BookStatus> statuses,
  ) {
    if (statuses.isEmpty) return List.of(books);
    return books.where((ub) => statuses.contains(ub.status)).toList();
  }

  /// 棚で絞り込む。shelfId が null なら全件。
  /// membership は shelfId -> userBookId の集合。該当棚が無ければ空リスト。
  static List<UserBook> filterByShelf(
    List<UserBook> books,
    String? shelfId,
    Map<String, Set<String>> membership,
  ) {
    if (shelfId == null) return List.of(books);
    final ids = membership[shelfId];
    if (ids == null) return const [];
    return books.where((ub) => ids.contains(ub.id)).toList();
  }

  /// 安定ソート。同時順位は id 昇順。null（completedAt 無し / pageCount 無し）は常に末尾。
  static List<UserBook> sort(List<UserBook> books, LibrarySortOrder order) {
    int compare(UserBook a, UserBook b) {
      int r;
      switch (order) {
        case LibrarySortOrder.addedNewest:
          r = _isoCompare(b.createdAt, a.createdAt);
        case LibrarySortOrder.addedOldest:
          r = _isoCompare(a.createdAt, b.createdAt);
        case LibrarySortOrder.titleAsc:
          final an = a.book?.title;
          final bn = b.book?.title;
          if (an == null && bn == null) {
            r = 0;
          } else if (an == null) {
            return _byId(a, b); // null は末尾
          } else if (bn == null) {
            return -_byId(a, b);
          } else {
            r = an.compareTo(bn);
          }
        case LibrarySortOrder.authorAsc:
          final aa = _firstAuthor(a);
          final bFirst = _firstAuthor(b);
          if (aa == null && bFirst == null) {
            r = 0;
          } else if (aa == null) {
            return _byId(a, b);
          } else if (bFirst == null) {
            return -_byId(a, b);
          } else {
            r = aa.compareTo(bFirst);
          }
        case LibrarySortOrder.pagesDesc:
          final ap = a.book?.pageCount;
          final bp = b.book?.pageCount;
          if (ap == null && bp == null) {
            r = 0;
          } else if (ap == null) {
            return _byId(a, b); // null は末尾
          } else if (bp == null) {
            return -_byId(a, b);
          } else {
            r = bp.compareTo(ap); // 降順
          }
        case LibrarySortOrder.completedNewest:
          r = _isoCompare(b.completedAt, a.completedAt);
      }
      if (r != 0) return r;
      return _byId(a, b);
    }

    final copy = List.of(books)..sort(compare);
    return copy;
  }

  static int _byId(UserBook a, UserBook b) => a.id.compareTo(b.id);

  /// 著者名のソートキー（先頭著者。空 or book null なら null）
  static String? _firstAuthor(UserBook ub) {
    final authors = ub.book?.authors;
    if (authors == null || authors.isEmpty) return null;
    return authors.first;
  }

  /// 複合適用: text → status → shelf → sort の順
  static List<UserBook> apply(
    List<UserBook> books,
    LibraryQuery query, {
    Map<String, Set<String>> membership = const {},
  }) {
    var result = searchByText(books, query.text);
    result = filterByStatus(result, query.statuses);
    result = filterByShelf(result, query.shelfId, membership);
    return sort(result, query.sortOrder);
  }

  /// 状態別件数（3状態すべてをキーに含め、0件も含む）
  static Map<BookStatus, int> countByStatus(List<UserBook> books) {
    final result = {
      for (final s in BookStatus.values) s: 0,
    };
    for (final ub in books) {
      result[ub.status] = (result[ub.status] ?? 0) + 1;
    }
    return result;
  }

  /// 'N件' 形式のラベル
  static String resultLabel(int count) => '$count件';
}
