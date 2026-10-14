import '../../../../domain/models/user_book.dart';
import 'library_query.dart';

/// 停滞理由の分類。
enum StagnationReason {
  /// 積読のまま一度も読書を開始していない。
  neverStarted,

  /// 読書中だが現在ページが 0 のまま進捗がない。
  noPageProgress,

  /// 読書中で進捗はあるが、追加から長期間経過している。
  longReading;

  /// 日本語ラベル。
  String get label {
    switch (this) {
      case StagnationReason.neverStarted:
        return '積読（未着手）';
      case StagnationReason.noPageProgress:
        return '読書中だが進捗なし';
      case StagnationReason.longReading:
        return '読書中（長期経過）';
    }
  }
}

/// 停滞している 1 冊分の判定結果。
class StagnantBook {
  final UserBook userBook;
  final int daysStalled;
  final StagnationReason reason;

  StagnantBook({
    required this.userBook,
    required this.daysStalled,
    required this.reason,
  }) {
    if (daysStalled < 0) {
      throw ArgumentError.value(daysStalled, 'daysStalled', '負の日数は許可しない');
    }
  }

  /// 一覧表示用の日数ラベル。
  String get daysLabel => '$daysStalled日放置';

  /// 書名（book 未結合なら「（無題）」）。
  String get title => userBook.book?.title ?? '（無題）';

  /// 進捗ラベル（pageCount が不明なら null）。
  String? progressLabel() {
    final pageCount = userBook.book?.pageCount;
    if (pageCount == null || pageCount <= 0) return null;
    final page = userBook.currentPage.clamp(0, pageCount);
    return '$page / $pageCount ページ';
  }

  /// 著者名一覧（book 未結合なら空）。
  List<String> get authors => userBook.book?.authors ?? const [];
}

/// 積読・放置本の停滞判定を提供する純粋サービス。
class StagnationService {
  const StagnationService._();

  /// 既定の停滞判定閾値（日）。
  static const int defaultMinDays = 30;

  /// 選択可能な閾値チップ（日）。
  static const List<int> minDaysChoices = [30, 60, 90];

  /// [ub] の追加日時（createdAt）からの経過日数。未来日時・解析不能なら 0。
  static int daysStalledFor(UserBook ub, {required DateTime now}) {
    final added = DateTime.tryParse(ub.createdAt);
    if (added == null) return 0;
    final days = now.difference(added).inDays;
    return days < 0 ? 0 : days;
  }

  /// 読了以外で createdAt から [minDays] 以上経過した本を抽出する。
  ///
  /// createdAt 解析不能の本は判定できないため対象外。入力順を保持する。
  static List<StagnantBook> detect(
    List<UserBook> books, {
    required DateTime now,
    int minDays = defaultMinDays,
  }) {
    final entries = <StagnantBook>[];
    for (final ub in books) {
      if (ub.status == BookStatus.completed) continue;
      if (DateTime.tryParse(ub.createdAt) == null) continue;
      final days = daysStalledFor(ub, now: now);
      if (days < minDays) continue;
      entries.add(
        StagnantBook(userBook: ub, daysStalled: days, reason: reasonOf(ub)),
      );
    }
    return entries;
  }

  /// 状態と進捗から停滞理由を分類する。
  static StagnationReason reasonOf(UserBook ub) {
    if (ub.status == BookStatus.reading) {
      return ub.currentPage <= 0
          ? StagnationReason.noPageProgress
          : StagnationReason.longReading;
    }
    return StagnationReason.neverStarted;
  }

  /// 停滞日数の降順で並べ替える（非破壊）。同値は title 昇順 → id 昇順。
  static List<StagnantBook> sortByDays(List<StagnantBook> entries) {
    final sorted = List<StagnantBook>.from(entries);
    sorted.sort((a, b) {
      final byDays = b.daysStalled.compareTo(a.daysStalled);
      if (byDays != 0) return byDays;
      final byTitle = a.title.compareTo(b.title);
      if (byTitle != 0) return byTitle;
      return a.userBook.id.compareTo(b.userBook.id);
    });
    return sorted;
  }

  /// [reason] で絞り込む。null は全件。
  static List<StagnantBook> filterByReason(
    List<StagnantBook> entries,
    StagnationReason? reason,
  ) {
    if (reason == null) return List<StagnantBook>.from(entries);
    return entries.where((e) => e.reason == reason).toList();
  }

  /// 書名か著者の部分一致で絞り込む（正規化比較）。空クエリは全件。
  static List<StagnantBook> searchByText(
    List<StagnantBook> entries,
    String query,
  ) {
    final normalized = LibraryQueryService.normalize(query);
    if (normalized.isEmpty) return List<StagnantBook>.from(entries);
    return entries
        .where((e) =>
            LibraryQueryService.normalize(e.title).contains(normalized) ||
            e.authors.any((a) => LibraryQueryService.normalize(a).contains(normalized)))
        .toList();
  }

  /// 理由別の件数を数える。
  static Map<StagnationReason, int> countsByReason(List<StagnantBook> entries) {
    final counts = <StagnationReason, int>{};
    for (final entry in entries) {
      counts[entry.reason] = (counts[entry.reason] ?? 0) + 1;
    }
    return counts;
  }
}
