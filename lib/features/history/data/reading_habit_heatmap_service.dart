import 'package:tsundoku_quest/domain/models/reading_session.dart';

/// 曜日×時間帯（4時間刻み）の読書量セル
class ReadingHabitCell {
  final int weekday; // 1=月 .. 7=日 (DateTime.weekday と同値)
  final int slot; // 0..5 (0=0-3時, 1=4-7時, 2=8-11時, 3=12-15時, 4=16-19時, 5=20-23時)
  final int minutes; // 合計読書時間（分・0以上）

  const ReadingHabitCell({
    required this.weekday,
    required this.slot,
    required this.minutes,
  });

  bool get isEmpty => minutes <= 0;
}

/// 曜日×時間帯ヒートマップの集計結果（7曜日×6時間帯=42セル・常にゼロ埋め）
class ReadingHabitHeatmap {
  /// 42件。index = (weekday-1)*6 + slot
  final List<ReadingHabitCell> cells;
  final int maxMinutes; // 最大セルの分（全0なら0）
  final int totalMinutes; // 合計分
  final int totalSessions; // 集計対象になったセッション数（日時が解釈できたもの）
  final int? busiestWeekday; // 曜日合計が最大の曜日（同数は曜日番号が小さい方=月優先）。全0なら null
  final int? busiestSlot; // 時間帯合計が最大の slot（同数は slot が小さい方）。全0なら null

  const ReadingHabitHeatmap({
    required this.cells,
    required this.maxMinutes,
    required this.totalMinutes,
    required this.totalSessions,
    required this.busiestWeekday,
    required this.busiestSlot,
  });

  bool get isEmpty => totalSessions == 0;

  /// 指定曜日・時間帯のセルを返す（weekday: 1..7, slot: 0..5）
  ReadingHabitCell cellAt(int weekday, int slot) =>
      cells[(weekday - 1) * ReadingHabitHeatmapService.slotCount + slot];

  /// 0..4 の濃淡レベル
  int levelOf(ReadingHabitCell cell) {
    if (cell.minutes <= 0) return 0;
    if (maxMinutes <= 0) return 0;
    final ratio = cell.minutes / maxMinutes;
    if (ratio <= 0.25) return 1;
    if (ratio <= 0.5) return 2;
    if (ratio <= 0.75) return 3;
    return 4;
  }

  /// 曜日ごとの合計（長さ7・index0=月曜）
  List<int> get weekdayTotals => [
        for (var w = 1; w <= 7; w++)
          [
            for (var s = 0; s < ReadingHabitHeatmapService.slotCount; s++)
              cellAt(w, s).minutes,
          ].fold<int>(0, (s, m) => s + m),
      ];

  /// 時間帯ごとの合計（長さ6）
  List<int> get slotTotals => [
        for (var s = 0; s < ReadingHabitHeatmapService.slotCount; s++)
          [
            for (var w = 1; w <= 7; w++) cellAt(w, s).minutes,
          ].fold<int>(0, (sum, m) => sum + m),
      ];

  /// 例 '火曜 20-23時' / 記録なければ '—'
  String get busiestLabel => busiestWeekday == null || busiestSlot == null
      ? '—'
      : '${ReadingHabitHeatmapService.weekdayLabel(busiestWeekday!)}曜 '
          '${ReadingHabitHeatmapService.slotLabel(busiestSlot!)}';
}

/// 曜日×時間帯の読書習慣ヒートマップを集計する純粋ロジックサービス
///
/// Widget / Hive / Riverpod に依存せず、引数のセッションリストからのみ集計する。
/// 不正な日付は黙って集計外とする（例外を投げない）。
class ReadingHabitHeatmapService {
  const ReadingHabitHeatmapService._();

  static const int slotHours = 4;
  static const int slotCount = 6;

  /// hour を 0..23 に clamp したうえで slot (0..5) に変換する
  static int slotOfHour(int hour) {
    final h = hour.clamp(0, 23);
    return h ~/ slotHours;
  }

  /// slot の表示ラベル（'0-3時' / '20-23時'・範囲外は '—'）
  static String slotLabel(int slot) {
    if (slot < 0 || slot >= slotCount) return '—';
    final start = slot * slotHours;
    final end = start + slotHours - 1;
    return '$start-$end時';
  }

  /// 曜日の表示ラベル（1->'月' … 7->'日'・範囲外は '—'）
  static String weekdayLabel(int weekday) {
    const labels = ['月', '火', '水', '木', '金', '土', '日'];
    if (weekday < 1 || weekday > 7) return '—';
    return labels[weekday - 1];
  }

  /// startedAt をローカル時刻の DateTime に解釈する（失敗時は null・例外を投げない）
  static DateTime? parseStartedAt(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// セッション群からヒートマップを集計する
  static ReadingHabitHeatmap build({required List<ReadingSession> sessions}) {
    final minutes = List<int>.filled(7 * slotCount, 0);
    var totalSessions = 0;
    var totalMinutes = 0;
    for (final session in sessions) {
      final dt = parseStartedAt(session.startedAt);
      if (dt == null) continue;
      totalSessions += 1;
      final dm = session.durationMinutes;
      final mins = dm != null && dm > 0 ? dm : 0;
      final weekday = dt.weekday;
      final slot = slotOfHour(dt.hour);
      minutes[(weekday - 1) * slotCount + slot] += mins;
      totalMinutes += mins;
    }
    final maxMinutes =
        minutes.fold<int>(0, (m, v) => v > m ? v : m);

    var busiestWeekday = 1;
    var busiestSlot = 0;
    var weekdayBest = -1;
    for (var w = 1; w <= 7; w++) {
      var total = 0;
      for (var s = 0; s < slotCount; s++) {
        total += minutes[(w - 1) * slotCount + s];
      }
      if (total > weekdayBest) {
        weekdayBest = total;
        busiestWeekday = w;
      }
    }
    var slotBest = -1;
    for (var s = 0; s < slotCount; s++) {
      var total = 0;
      for (var w = 1; w <= 7; w++) {
        total += minutes[(w - 1) * slotCount + s];
      }
      if (total > slotBest) {
        slotBest = total;
        busiestSlot = s;
      }
    }
    if (totalMinutes <= 0) {
      busiestWeekday = -1;
      busiestSlot = -1;
    }
    return ReadingHabitHeatmap(
      cells: [
        for (var w = 1; w <= 7; w++)
          for (var s = 0; s < slotCount; s++)
            ReadingHabitCell(
              weekday: w,
              slot: s,
              minutes: minutes[(w - 1) * slotCount + s],
            ),
      ],
      maxMinutes: maxMinutes,
      totalMinutes: totalMinutes,
      totalSessions: totalSessions,
      busiestWeekday: busiestWeekday >= 1 ? busiestWeekday : null,
      busiestSlot: busiestSlot >= 0 ? busiestSlot : null,
    );
  }
}