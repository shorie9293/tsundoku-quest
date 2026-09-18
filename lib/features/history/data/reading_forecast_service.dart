import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';

/// 読了予測の結果（1冊分）
///
/// 全フィールドは値を正とし、null は「不明」を意味する。
class ReadingForecast {
  final String userBookId;
  final String title;
  final int? totalPages;
  final int currentPage;
  final double? pagesPerDay;
  final int? remainingPages;
  final int? daysRemaining;
  final DateTime? forecastDate;

  const ReadingForecast({
    required this.userBookId,
    required this.title,
    required this.totalPages,
    required this.currentPage,
    required this.pagesPerDay,
    required this.remainingPages,
    required this.daysRemaining,
    required this.forecastDate,
  });

  /// ペース不明または総ページ不明で読了日を算出できない状態。
  /// ペースだけは判明している場合も unknown 扱い（読了日は出せないため）。
  bool get isUnknown => forecastDate == null;

  /// すでに読了ページに到達している。
  bool get isDone {
    final total = totalPages;
    if (total == null || total <= 0) return false;
    return currentPage >= total;
  }

  /// 「あと N 日（M月d日）」形式の短い表示文。不明時は null。
  String? get forecastLabel {
    final date = forecastDate;
    if (date == null) return null;
    if (isDone) return '読了済み';
    final days = daysRemaining;
    if (days == null) return null;
    return 'あと $days 日（${date.month}/${date.day}）';
  }

  /// 「1日あたり約 N ページ」の表示文。不明時は null。
  String? get paceLabel {
    final pace = pagesPerDay;
    if (pace == null) return null;
    if (pace >= 10) {
      return '1日あたり約 ${pace.round()} ページ';
    }
    return '1日あたり約 ${pace.toStringAsFixed(1)} ページ';
  }
}

/// 読了予測を算出する純粋ロジックサービス。
///
/// Widget / Hive / Riverpod に依存せず、引数のモデルからのみ算出する。
/// データ不足（セッションなし・総ページ不明）は例外ではなく「不明」として表現する。
class ReadingForecastService {
  const ReadingForecastService._();

  /// セッション履歴から 1日あたりの読書ペース（ページ/日）を算出する。
  ///
  /// ページ実績の合計を「セッションが存在した暦日数（活動日数）」で割る。
  /// endPage 未記入のセッションはページ計上から除外するが、活動日には数える。
  /// 実績ページ 0 以下・セッションなしは null（ペース不明）。
  static double? paceFrom({
    required List<ReadingSession> sessions,
    required DateTime now,
    String? userBookId,
  }) {
    final activeDays = <DateTime>{};
    var pages = 0;
    for (final s in sessions) {
      if (userBookId != null && s.userBookId != userBookId) continue;
      final start = DateTime.tryParse(s.startedAt)?.toLocal();
      if (start == null) continue;
      activeDays.add(DateTime(start.year, start.month, start.day));
      final endPage = s.endPage;
      if (endPage == null) continue;
      final delta = endPage - s.startPage;
      if (delta > 0) pages += delta;
    }
    if (pages <= 0 || activeDays.isEmpty) return null;
    return pages / activeDays.length;
  }

  /// 進行中の1冊の読了予測を算出する。
  ///
  /// - 対象外（null）: 未開始（tsundoku）・読了済み（completed）
  /// - ペース不明・総ページ不明は [ReadingForecast.isUnknown] で表現する
  static ReadingForecast? forecast({
    required UserBook userBook,
    required List<ReadingSession> sessions,
    required DateTime now,
  }) {
    final status = userBook.status;
    if (status != BookStatus.reading) return null;

    final book = userBook.book;
    final totalPages = book?.pageCount;
    final currentPage = userBook.currentPage;
    final pace = paceFrom(
      sessions: sessions,
      now: now,
      userBookId: userBook.id,
    );

    final remaining =
        totalPages != null && totalPages > currentPage
            ? totalPages - currentPage
            : (totalPages != null ? 0 : null);

    int? daysRemaining;
    DateTime? forecastDate;
    if (remaining != null && remaining > 0 && pace != null && pace > 0) {
      daysRemaining = (remaining / pace).ceil();
      if (daysRemaining < 1) daysRemaining = 1;
      forecastDate = DateTime(
        now.year,
        now.month,
        now.day + daysRemaining,
      );
    } else if (remaining == 0) {
      daysRemaining = 0;
      forecastDate = now;
    }

    return ReadingForecast(
      userBookId: userBook.id,
      title: book?.title ?? '無題',
      totalPages: totalPages,
      currentPage: currentPage,
      pagesPerDay: pace,
      remainingPages: remaining,
      daysRemaining: daysRemaining,
      forecastDate: forecastDate,
    );
  }

  /// 目標日までに必要な 1日あたりページ数。
  ///
  /// 過去の締切は null。当日は残日数1日扱い。読了済みなら 0。
  static double? requiredDailyPages({
    required int currentPage,
    required int totalPages,
    required DateTime targetDate,
    required DateTime now,
  }) {
    if (totalPages <= 0) return null;
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final diff = target.difference(today).inDays;
    if (diff < 0) return null;
    final days = diff == 0 ? 1 : diff;
    final remaining = totalPages - currentPage;
    if (remaining <= 0) return 0.0;
    return remaining / days;
  }

  /// 進行中の本の一覧から予測リストを構築する（入力順序保持・対象外は除外）。
  static List<ReadingForecast> summaries({
    required List<UserBook> books,
    required Map<String, List<ReadingSession>> sessionsByBook,
    required DateTime now,
  }) {
    final result = <ReadingForecast>[];
    for (final ub in books) {
      final f = forecast(
        userBook: ub,
        sessions: sessionsByBook[ub.id] ?? const [],
        now: now,
      );
      if (f != null) result.add(f);
    }
    return result;
  }
}
