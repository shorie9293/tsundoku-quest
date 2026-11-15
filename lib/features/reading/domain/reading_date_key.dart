/// 読書日付キー（`yyyy-MM-dd`）の生成・正規化。
///
/// **保存は UTC ISO・日付キーはローカル暦。**
/// `startedAt` / `createdAt` は `DateTime.now().toUtc().toIso8601String()`
/// （例 `'2026-11-12T15:30:00.000Z'`）で保存される。この文字列の先頭10文字を
/// そのまま日付キーにすると **UTC の暦日** になり、JST(UTC+9) では
/// 00:00〜08:59 の読書が前日に計上され、月初は前月へ落ちる。
/// そこで日付キーは必ず「UTC インスタントをローカルへ変換した暦日」で作る。
///
/// 実装は [LocalCalendarDate] に一本化済み（ここは読書ドメイン向けの
/// 薄い委譲。API・戻り値・意味は不変）。副作用なし・throw なし。
/// Hive 実装・Supabase 実装・画面・Provider の共通経路として使う。
library;

import '../../../core/time/local_calendar_date.dart';

/// 読書日付キー算出。
abstract final class ReadingDateKey {
  /// [dt] の**ローカル暦**の日付を `yyyy-MM-dd` で返す。
  static String fromDateTime(DateTime dt) => LocalCalendarDate.fromDateTime(dt);

  /// ISO 8601 文字列を**ローカル暦**の日付キーへ正規化する。
  ///
  /// `'2026-11-12T15:30:00.000Z'`（UTC ISO）も `'2026-11-12'`（日付のみ）も
  /// 受け付ける。日付のみ文字列は `DateTime.parse` がローカル0時として
  /// 解釈するため、そのままローカル暦になる。
  ///
  /// null・空・空白のみ・パース不能は null。**決して throw しない。**
  /// 範囲外の月日・時刻も null（詳細は [LocalCalendarDate.tryFromIso]）。
  static String? tryFromIso(String? raw) => LocalCalendarDate.tryFromIso(raw);

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
}
