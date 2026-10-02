import 'package:flutter/foundation.dart';

import '../data/reading_notes_provider.dart';

/// 並び替え順
enum ReadingNoteSortOrder {
  createdNewest('新しい順'),
  createdOldest('古い順'),
  titleAsc('書名順'),
  learningCountDesc('学びが多い順');

  final String label;
  const ReadingNoteSortOrder(this.label);
}

/// 感想の内容フィルタ（複数選択時は AND = 全て満たす）
enum ReadingNoteContentFilter {
  hasLearning('学びあり'),
  hasAction('行動あり'),
  hasQuote('引用あり');

  final String label;
  const ReadingNoteContentFilter(this.label);
}

/// 読書感想の検索・絞り込みクエリ条件（不変）
@immutable
class ReadingNoteQuery {
  final String text;

  /// 絞り込む書名。空集合 = 全書籍
  final Set<String> bookTitles;

  /// 絞り込む内容フィルタ。空集合 = 全件。複数選択時は AND
  final Set<ReadingNoteContentFilter> contentFilters;
  final ReadingNoteSortOrder sortOrder;

  const ReadingNoteQuery({
    this.text = '',
    this.bookTitles = const {},
    this.contentFilters = const {},
    this.sortOrder = ReadingNoteSortOrder.createdNewest,
  });

  ReadingNoteQuery copyWith({
    String? text,
    Set<String>? bookTitles,
    Set<ReadingNoteContentFilter>? contentFilters,
    ReadingNoteSortOrder? sortOrder,
    bool clearBookTitles = false,
    bool clearContentFilters = false,
  }) {
    return ReadingNoteQuery(
      text: text ?? this.text,
      bookTitles:
          clearBookTitles ? const {} : (bookTitles ?? this.bookTitles),
      contentFilters: clearContentFilters
          ? const {}
          : (contentFilters ?? this.contentFilters),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// 既定値そのものか
  bool get isDefault =>
      text.isEmpty &&
      bookTitles.isEmpty &&
      contentFilters.isEmpty &&
      sortOrder == ReadingNoteSortOrder.createdNewest;

  /// 有効な絞り込み条件の数（テキスト有無 + 書名件数 + 内容フィルタ件数。ソートは数えない）
  int get activeFilterCount {
    var count = 0;
    if (text.isNotEmpty) count++;
    count += bookTitles.length;
    count += contentFilters.length;
    return count;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReadingNoteQuery &&
        other.text == text &&
        setEquals(other.bookTitles, bookTitles) &&
        setEquals(other.contentFilters, contentFilters) &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode => Object.hash(
        text,
        Object.hashAllUnordered(bookTitles),
        Object.hashAllUnordered(contentFilters),
        sortOrder,
      );
}

/// 読書感想の検索・絞り込み・並び替え（純粋関数のみ）
class ReadingNoteQueryService {
  const ReadingNoteQueryService._();

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

  /// 書名 か いずれかの学び か 行動 か 引用 に検索語を含む（正規化後の部分一致）。
  /// 空/空白のみの検索語なら全件。
  static bool matchesText(ReadingNoteItem note, String text) {
    final q = normalize(text);
    if (q.isEmpty) return true;
    if (note.bookTitle != null && normalize(note.bookTitle!).contains(q)) {
      return true;
    }
    if (note.learnings.any((l) => normalize(l).contains(q))) return true;
    if (normalize(note.action).contains(q)) return true;
    final quote = note.favoriteQuote;
    if (quote != null && normalize(quote).contains(q)) return true;
    return false;
  }

  /// 書名で絞り込む（titles が空なら全件）。bookTitle が null の note は除外。
  static List<ReadingNoteItem> filterByBooks(
    List<ReadingNoteItem> notes,
    Set<String> titles,
  ) {
    if (titles.isEmpty) return List.of(notes);
    return notes
        .where((n) => n.bookTitle != null && titles.contains(n.bookTitle))
        .toList();
  }

  /// 内容フィルタで絞り込む（filters が空なら全件）。AND 意味論。
  static List<ReadingNoteItem> filterByContent(
    List<ReadingNoteItem> notes,
    Set<ReadingNoteContentFilter> filters,
  ) {
    if (filters.isEmpty) return List.of(notes);
    return notes.where((n) {
      for (final f in filters) {
        switch (f) {
          case ReadingNoteContentFilter.hasLearning:
            if (n.learnings.isEmpty) return false;
          case ReadingNoteContentFilter.hasAction:
            if (n.action.isEmpty) return false;
          case ReadingNoteContentFilter.hasQuote:
            if (n.favoriteQuote == null || n.favoriteQuote!.isEmpty) {
              return false;
            }
        }
      }
      return true;
    }).toList();
  }

  /// 安定ソート。同時順位は id 昇順。null bookTitle は titleAsc で常に末尾。
  static List<ReadingNoteItem> sort(
    List<ReadingNoteItem> notes,
    ReadingNoteSortOrder order,
  ) {
    int compare(ReadingNoteItem a, ReadingNoteItem b) {
      int r;
      switch (order) {
        case ReadingNoteSortOrder.createdNewest:
          r = b.createdAt.compareTo(a.createdAt);
        case ReadingNoteSortOrder.createdOldest:
          r = a.createdAt.compareTo(b.createdAt);
        case ReadingNoteSortOrder.titleAsc:
          final at = a.bookTitle;
          final bt = b.bookTitle;
          if (at == null && bt == null) {
            r = 0;
          } else if (at == null) {
            return 1; // null は末尾
          } else if (bt == null) {
            return -1;
          } else {
            r = at.compareTo(bt);
          }
        case ReadingNoteSortOrder.learningCountDesc:
          r = b.learnings.length.compareTo(a.learnings.length);
      }
      if (r != 0) return r;
      return a.id.compareTo(b.id);
    }

    final copy = List.of(notes)..sort(compare);
    return copy;
  }

  /// 複合適用: text → bookTitles → contentFilters → sort の順
  static List<ReadingNoteItem> apply(
    List<ReadingNoteItem> notes,
    ReadingNoteQuery query,
  ) {
    var result =
        notes.where((n) => matchesText(n, query.text)).toList();
    result = filterByBooks(result, query.bookTitles);
    result = filterByContent(result, query.contentFilters);
    return sort(result, query.sortOrder);
  }

  /// 書名の選択肢（null・空文字を除いた distinct、昇順）
  static List<String> availableBookTitles(List<ReadingNoteItem> notes) {
    final titles = <String>{
      for (final n in notes)
        if (n.bookTitle != null && n.bookTitle!.isNotEmpty) n.bookTitle!,
    };
    final list = titles.toList()..sort();
    return list;
  }

  /// 'N件' 形式のラベル
  static String resultLabel(int count) => '$count件';
}