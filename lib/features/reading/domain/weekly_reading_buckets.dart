/// 直近7日の読書時間バケット。
///
/// Hive 実装・Supabase 実装の双方から呼ばれる純粋モジュール。
/// 副作用なし・throw なし（壊れた startedAt は null を返して捨てる）。
///
/// バケット番号は **ローカル暦** 基準：
///   index 0 = 6日前 … index 6 = 今日
/// 以前の実装は UTC のインスタント（時刻付き）を起点に `inDays` で
/// 割っていたため全バケットが1日ずれ、index 6 が常に0になっていた。
library;

/// 名前付きフィールド `startedAt` / `durationMinutes` を持つサンプル。
typedef ReadingSample = ({String startedAt, int? durationMinutes});

/// 直近7日の読書時間バケット算出。
abstract final class WeeklyReadingBuckets {
  /// バケット数（= 直近7日）。
  static const int days = 7;

  /// `now` の**ローカル暦の日付**から6日前の**ローカル0時**を返す。
  ///
  /// 例: now = 2026-11-12 18:00 (JST) → 2026-11-06 00:00 (ローカル)。
  /// 時刻成分は必ず落とす。日付の繰り下げは暦演算（DateTime の正規化）で行い、
  /// Duration 加減算による DST の 1 時間ずれを避ける。
  static DateTime weekStart(DateTime now) {
    final local = now.toLocal();
    return DateTime(local.year, local.month, local.day - (days - 1));
  }

  /// クエリ下限用の ISO 文字列（UTC・`Z` 付き）。
  ///
  /// `weekStart(now)` を UTC へ変換したもの。Supabase の `started_at` は
  /// UTC ISO で保存されるため、ローカル週初めをそのまま UTC 化して渡す。
  /// 例: JST 2026-11-12 18:00 → '2026-11-05T15:00:00.000Z'。
  static String weekStartIso(DateTime now) =>
      weekStart(now).toUtc().toIso8601String();

  /// `startedAt` をローカル日付に落とし、`weekStartLocal` との日数差を返す。
  ///
  /// [startedAt] は `'2026-11-12T09:00:00.000Z'`（UTC ISO）または
  /// `'2026-11-12'`（日付のみ）。後者はそのままローカル日付として扱う。
  ///
  /// 戻り値は 0..6。範囲外（負・7以上）・パース不能・空文字は null。
  /// **決して throw しない。**
  static int? indexFor(String startedAt, DateTime weekStartLocal) {
    final day = _localDayOf(startedAt);
    if (day == null) return null;

    // 両者を「UTC の暦日付」に正規化してから差を取る。
    // これで difference().inDays の切り捨てや DST の影響を受けない。
    final startDay = DateTime.utc(
      weekStartLocal.year,
      weekStartLocal.month,
      weekStartLocal.day,
    );
    final targetDay = DateTime.utc(day.year, day.month, day.day);
    final diff = targetDay.difference(startDay).inDays;

    if (diff < 0 || diff >= days) return null;
    return diff;
  }

  /// [samples] を集計し、長さ [days] の読書分バケットを返す。
  ///
  /// index 0 = 6日前 … index 6 = 今日。
  /// `durationMinutes` が null のサンプルは加算しない。
  /// [indexFor] が null を返すサンプルは捨てる。合計は捨てた分を除いた
  /// `durationMinutes` の総和と一致する。
  static List<int> build(Iterable<ReadingSample> samples,
      {required DateTime now}) {
    final start = weekStart(now);
    final buckets = List<int>.filled(days, 0);
    for (final sample in samples) {
      final minutes = sample.durationMinutes;
      if (minutes == null) continue;
      final index = indexFor(sample.startedAt, start);
      if (index == null) continue;
      buckets[index] += minutes;
    }
    return buckets;
  }

  /// `startedAt` のローカル暦日付（時刻 0:00）を返す。解釈できなければ null。
  static DateTime? _localDayOf(String startedAt) {
    final raw = startedAt.trim();
    if (raw.isEmpty) return null;
    try {
      final parsed = DateTime.parse(raw);
      // 'Z' 付きは UTC インスタントなのでローカルへ変換する。
      // 'Z' なし（日付のみ・オフセットなし）は既にローカル暦として解釈済み。
      final local = parsed.isUtc ? parsed.toLocal() : parsed;
      return DateTime(local.year, local.month, local.day);
    } catch (_) {
      return null;
    }
  }
}
