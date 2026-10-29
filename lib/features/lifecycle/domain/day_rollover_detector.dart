/// 前面復帰時に「日付が変わったか」を判定する純粋クラス。
///
/// 判定はローカル暦（年/月/日）で行う。`DateTime.utc` は混ぜない。
/// 端末時計の巻き戻し（タイムゾーン変更・手動変更・NTP補正）で
/// 過去日へ引きずり込まれないよう、[DayRolloverResult.clockWentBack] の
/// ときは [lastSeen] を据え置く（クランプ）。例外は投げない。
enum DayRolloverResult { sameDay, rolledOver, clockWentBack }

class DayRolloverDetector {
  DayRolloverDetector({required DateTime lastSeen}) : _lastSeen = lastSeen;

  DateTime _lastSeen;

  DateTime get lastSeen => _lastSeen;

  /// [now] を判定し、必要に応じて内部の最終観測時刻を更新する。
  DayRolloverResult check(DateTime now) {
    final last = _lastSeen;
    final sameCalendarDay =
        last.year == now.year && last.month == now.month && last.day == now.day;

    if (sameCalendarDay) {
      _lastSeen = now;
      return DayRolloverResult.sameDay;
    }
    if (now.isAfter(last)) {
      _lastSeen = now;
      return DayRolloverResult.rolledOver;
    }
    // 暦日が変わり、かつ now が過去 → 時計の巻き戻し。lastSeen は触らない。
    return DayRolloverResult.clockWentBack;
  }
}
