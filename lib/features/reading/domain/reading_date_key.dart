/// 読書日付キー（`yyyy-MM-dd`）の生成・正規化。
///
/// **保存は UTC ISO・日付キーはローカル暦。**
/// `startedAt` / `createdAt` は `DateTime.now().toUtc().toIso8601String()`
/// （例 `'2026-11-12T15:30:00.000Z'`）で保存される。この文字列の先頭10文字を
/// そのまま日付キーにすると **UTC の暦日** になり、JST(UTC+9) では
/// 00:00〜08:59 の読書が前日に計上され、月初は前月へ落ちる。
/// そこで日付キーは必ず「UTC インスタントをローカルへ変換した暦日」で作る。
///
/// 副作用なし・throw なし（壊れた値は null を返して捨てる）。
/// Hive 実装・Supabase 実装・画面・Provider の共通経路として使う。
library;

/// 読書日付キー算出。
abstract final class ReadingDateKey {
  /// [dt] の**ローカル暦**の日付を `yyyy-MM-dd` で返す。
  ///
  /// UTC インスタントを渡しても `toLocal()` でローカルへ落としてから
  /// 年月日を取るため、日界のズレは起きない。
  static String fromDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// ISO 8601 文字列を**ローカル暦**の日付キーへ正規化する。
  ///
  /// `'2026-11-12T15:30:00.000Z'`（UTC ISO）も `'2026-11-12'`（日付のみ）も
  /// 受け付ける。日付のみ文字列は `DateTime.parse` がローカル0時として
  /// 解釈するため、そのままローカル暦になる。
  ///
  /// null・空・空白のみ・パース不能は null。**決して throw しない。**
  ///
  /// 注意: `DateTime.tryParse` は `'2026-13-45T99:99:99Z'` のような
  /// 範囲外の月日・時刻を **例外にせず繰り上げて解釈してしまう**。
  /// 壊れ値を日付キーとして通さないため、形と範囲を自前で検める。
  static String? tryFromIso(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final match = _isoPattern.firstMatch(trimmed);
      if (match == null) return null;

      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      if (month < 1 || month > 12) return null;
      if (day < 1 || day > _daysInMonth(year, month)) return null;

      final hour = match.group(4);
      final minute = match.group(5);
      final second = match.group(6);
      if (hour != null && int.parse(hour) > 23) return null;
      if (minute != null && int.parse(minute) > 59) return null;
      if (second != null && int.parse(second) > 59) return null;

      final parsed = DateTime.tryParse(trimmed);
      if (parsed == null) return null;
      return fromDateTime(parsed);
    } catch (_) {
      return null;
    }
  }

  /// 今日の**ローカル暦**の日付キー。[now] は試練用の差し替え口。
  static String today({DateTime Function() now = DateTime.now}) =>
      fromDateTime(now());

  /// ISO 文字列群を日付キーへ正規化し、**重複排除・降順**で返す。
  ///
  /// 解決できない壊れ値は捨てる（throw しない）。キーは `yyyy-MM-dd` なので
  /// 辞書順降順 = 新しい日付順となり、ストリーク計算の前提を満たす。
  static List<String> uniqueSortedDescending(Iterable<String?> raws) {
    final keys = <String>{};
    for (final raw in raws) {
      final key = tryFromIso(raw);
      if (key == null) continue;
      keys.add(key);
    }
    final result = keys.toList()..sort((a, b) => b.compareTo(a));
    return result;
  }

  /// ISO 8601 の形（日付のみ / 日付+時刻+任意のオフセット）。大文字 `Z` も小文字 `z` も許す。
  static final RegExp _isoPattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})'
    r'(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?'
    r'([Zz]|[+-]\d{2}:?\d{2})?)?$',
  );

  /// [month] の日数（うるう年も考慮。範囲外の月は呼び出し前に弾く）。
  static int _daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;
}