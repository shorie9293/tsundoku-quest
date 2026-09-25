import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_heatmap_service.dart';

ReadingSession _session({
  required String id,
  required String startedAt,
  int? durationMinutes,
}) {
  return ReadingSession(
    id: id,
    userBookId: 'ub-$id',
    startedAt: startedAt,
    startPage: 1,
    durationMinutes: durationMinutes,
    createdAt: startedAt,
  );
}

void main() {
  group('ReadingHabitHeatmapService slotOfHour', () {
    test('境界値で正しいslotに変換する', () {
      expect(ReadingHabitHeatmapService.slotOfHour(0), 0);
      expect(ReadingHabitHeatmapService.slotOfHour(3), 0);
      expect(ReadingHabitHeatmapService.slotOfHour(4), 1);
      expect(ReadingHabitHeatmapService.slotOfHour(20), 5);
      expect(ReadingHabitHeatmapService.slotOfHour(23), 5);
      expect(ReadingHabitHeatmapService.slotOfHour(24), 5);
      expect(ReadingHabitHeatmapService.slotOfHour(-1), 0);
    });
  });

  group('ReadingHabitHeatmapService labels', () {
    test('slotLabel・weekdayLabel の正常系と範囲外', () {
      expect(ReadingHabitHeatmapService.slotLabel(0), '0-3時');
      expect(ReadingHabitHeatmapService.slotLabel(5), '20-23時');
      expect(ReadingHabitHeatmapService.slotLabel(-1), '—');
      expect(ReadingHabitHeatmapService.slotLabel(6), '—');
      expect(ReadingHabitHeatmapService.weekdayLabel(1), '月');
      expect(ReadingHabitHeatmapService.weekdayLabel(7), '日');
      expect(ReadingHabitHeatmapService.weekdayLabel(0), '—');
      expect(ReadingHabitHeatmapService.weekdayLabel(8), '—');
    });
  });

  group('ReadingHabitHeatmapService.parseStartedAt', () {
    test('Z付きISO文字列をtoLocal込みで解釈する', () {
      final dt = ReadingHabitHeatmapService.parseStartedAt(
        '2026-09-23T01:00:00Z',
      );
      expect(dt, isNotNull);
      // toLocal() 済みであること（UTCと同一オブジェクトではない可能性・型確認）
      expect(dt!.timeZoneOffset, DateTime.now().timeZoneOffset);
    });

    test('空文字・不正文字列はnull', () {
      expect(ReadingHabitHeatmapService.parseStartedAt(''), isNull);
      expect(ReadingHabitHeatmapService.parseStartedAt('not-a-date'), isNull);
    });
  });

  group('ReadingHabitHeatmapService.build', () {
    test('空リストは全0の42セル・isEmpty・busiestがnull', () {
      final hm = ReadingHabitHeatmapService.build(sessions: const []);
      expect(hm.cells.length, 42);
      expect(hm.cells.every((c) => c.minutes == 0), isTrue);
      expect(hm.isEmpty, isTrue);
      expect(hm.maxMinutes, 0);
      expect(hm.totalMinutes, 0);
      expect(hm.totalSessions, 0);
      expect(hm.busiestWeekday, isNull);
      expect(hm.busiestSlot, isNull);
      expect(hm.busiestLabel, '—');
    });

    test('不正日付のセッションは集計外', () {
      final hm = ReadingHabitHeatmapService.build(sessions: [
        _session(id: 'bad', startedAt: 'not-a-date', durationMinutes: 60),
      ]);
      expect(hm.totalSessions, 0);
      expect(hm.totalMinutes, 0);
      expect(hm.isEmpty, isTrue);
    });

    test('単一セッションを正しいセルに集計する', () {
      // 2026-09-23 は水曜(3)。10時 → slot 2
      final hm = ReadingHabitHeatmapService.build(sessions: [
        _session(id: 'a', startedAt: '2026-09-23T10:00:00', durationMinutes: 45),
      ]);
      expect(hm.totalSessions, 1);
      expect(hm.totalMinutes, 45);
      expect(hm.maxMinutes, 45);
      final cell = hm.cellAt(3, 2);
      expect(cell.minutes, 45);
      expect(cell.isEmpty, isFalse);
      expect(hm.busiestWeekday, 3);
      expect(hm.busiestSlot, 2);
      expect(hm.busiestLabel, '水曜 8-11時');
    });

    test('複数セッションの分を合算し、null/負のdurationMinutesは0扱い', () {
      final hm = ReadingHabitHeatmapService.build(sessions: [
        _session(id: 'a', startedAt: '2026-09-21T09:00:00', durationMinutes: 30),
        _session(id: 'b', startedAt: '2026-09-21T11:00:00', durationMinutes: 20),
        _session(id: 'c', startedAt: '2026-09-21T10:00:00'), // null → 0
        _session(
          id: 'd',
          startedAt: '2026-09-21T08:00:00',
          durationMinutes: -5,
        ), // 負 → 0
      ]);
      expect(hm.totalSessions, 4);
      expect(hm.totalMinutes, 50);
      expect(hm.cellAt(1, 2).minutes, 50);
      expect(hm.maxMinutes, 50);
    });

    test('levelOf: 0・max=0・4段階の境界', () {
      final hm = ReadingHabitHeatmapService.build(sessions: [
        _session(id: 'a', startedAt: '2026-09-21T10:00:00', durationMinutes: 80),
        _session(id: 'b', startedAt: '2026-09-22T10:00:00', durationMinutes: 60),
        _session(id: 'c', startedAt: '2026-09-23T10:00:00', durationMinutes: 40),
        _session(id: 'd', startedAt: '2026-09-24T10:00:00', durationMinutes: 20),
        _session(id: 'e', startedAt: '2026-09-25T10:00:00', durationMinutes: 10),
      ]);
      // max=80: 20→0.25→1, 40→0.5→2, 60→0.75→3, 80→1.0→4, 10→0.125→1... <=0.25→1
      expect(hm.levelOf(hm.cellAt(1, 2)), 4); // 月 80
      expect(hm.levelOf(hm.cellAt(2, 2)), 3); // 火 60
      expect(hm.levelOf(hm.cellAt(3, 2)), 2); // 水 40
      expect(hm.levelOf(hm.cellAt(4, 2)), 1); // 木 20
      expect(hm.levelOf(hm.cellAt(5, 2)), 1); // 金 10
      expect(hm.levelOf(hm.cellAt(6, 2)), 0); // 土 0
      // max=0 の場合
      final zero = ReadingHabitHeatmapService.build(sessions: [
        _session(id: 'z', startedAt: '2026-09-21T10:00:00'), // 0分
      ]);
      expect(zero.maxMinutes, 0);
      expect(zero.levelOf(zero.cellAt(1, 2)), 0);
    });

    test('busiestWeekday: 同数なら月優先（番号が小さい方）', () {
      final hm = ReadingHabitHeatmapService.build(sessions: [
        _session(id: 'a', startedAt: '2026-09-21T10:00:00', durationMinutes: 30),
        _session(id: 'b', startedAt: '2026-09-25T10:00:00', durationMinutes: 30),
      ]);
      // 月(1)と金(5)が同数 → 月
      expect(hm.busiestWeekday, 1);
    });

    test('busiestSlot: 同数なら番号が小さい方', () {
      final hm = ReadingHabitHeatmapService.build(sessions: [
        _session(id: 'a', startedAt: '2026-09-21T05:00:00', durationMinutes: 30),
        _session(id: 'b', startedAt: '2026-09-21T21:00:00', durationMinutes: 30),
      ]);
      // slot1(4-7時)とslot5(20-23時)が同数 → slot1
      expect(hm.busiestSlot, 1);
    });

    test('weekdayTotals・slotTotals の合計が totalMinutes と一致', () {
      final hm = ReadingHabitHeatmapService.build(sessions: [
        _session(id: 'a', startedAt: '2026-09-21T10:00:00', durationMinutes: 30),
        _session(id: 'b', startedAt: '2026-09-22T22:00:00', durationMinutes: 45),
        _session(id: 'c', startedAt: '2026-09-27T15:00:00', durationMinutes: 25),
      ]);
      expect(hm.weekdayTotals.length, 7);
      expect(hm.slotTotals.length, 6);
      expect(
        hm.weekdayTotals.fold<int>(0, (s, v) => s + v),
        hm.totalMinutes,
      );
      expect(hm.slotTotals.fold<int>(0, (s, v) => s + v), hm.totalMinutes);
      expect(hm.cellAt(7, 3).minutes, 25); // 日曜 12-15時
    });

    test('cellAt・cells のindex対応が一致する', () {
      final hm = ReadingHabitHeatmapService.build(sessions: [
        _session(id: 'a', startedAt: '2026-09-27T20:00:00', durationMinutes: 60),
      ]);
      // 日曜(7) 20時 → slot5 → index = 6*6+5 = 41
      expect(hm.cells[41].minutes, 60);
      expect(hm.cellAt(7, 5).minutes, 60);
      expect(hm.cells[41].weekday, 7);
      expect(hm.cells[41].slot, 5);
      expect(hm.cells[0].isEmpty, isTrue);
    });
  });
}