import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/time/local_calendar_date.dart';
import 'package:tsundoku_quest/features/reading/domain/reading_date_key.dart';

/// [raw] の**ローカル暦**の日付。期待値は必ずここから算出する
/// （`DateTime.utc(...)` を期待値に据えない = UTC 切りを期待しない）。
String _localDay(String raw) {
  final l = DateTime.parse(raw).toLocal();
  final y = l.year.toString().padLeft(4, '0');
  final m = l.month.toString().padLeft(2, '0');
  final d = l.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 実行環境の UTC オフセット（分）。日界を跨ぐかどうかの判定に使う。
int get _offsetMinutes => DateTime.parse('2026-11-12T15:30:00.000Z')
    .toLocal()
    .timeZoneOffset
    .inMinutes;

void main() {
  group('LocalCalendarDate.fromDateTime', () {
    test('UTC インスタントはローカル暦の日付になる', () {
      final dt = DateTime.parse('2026-11-12T15:30:00.000Z');
      expect(
        LocalCalendarDate.fromDateTime(dt),
        _localDay('2026-11-12T15:30:00.000Z'),
      );
    });

    test('ローカル日時はそのままの日付になる', () {
      final dt = DateTime(2026, 11, 13, 0, 30);
      expect(LocalCalendarDate.fromDateTime(dt), '2026-11-13');
    });

    test('yyyy-MM-dd にゼロ埋めする', () {
      expect(
          LocalCalendarDate.fromDateTime(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('LocalCalendarDate.tryFromIso', () {
    test('日界（JST 00:30 相当の UTC ISO）で前日に落ちない', () {
      const raw = '2026-11-12T15:30:00.000Z';
      final result = LocalCalendarDate.tryFromIso(raw);
      expect(result, _localDay(raw));
      // オフセットが +9 以上なら UTC 暦日とは別日になるはず（UTC 切りなら赤）
      if (_offsetMinutes >= 540) {
        expect(result, '2026-11-13');
        expect(result, isNot('2026-11-12'));
      }
    });

    test('月初跨ぎ（JST 10/01 07:00 相当）', () {
      const raw = '2026-09-30T22:00:00.000Z';
      final result = LocalCalendarDate.tryFromIso(raw);
      expect(result, _localDay(raw));
      if (_offsetMinutes >= 540) {
        expect(result, '2026-10-01');
        expect(result, isNot('2026-09-30'));
      }
    });

    test('年末跨ぎ（JST 2027/01/01 08:00 相当）', () {
      const raw = '2026-12-31T23:00:00.000Z';
      final result = LocalCalendarDate.tryFromIso(raw);
      expect(result, _localDay(raw));
      if (_offsetMinutes >= 540) {
        expect(result, '2027-01-01');
        expect(result, isNot('2026-12-31'));
      }
    });

    test('日付のみ文字列はそのまま', () {
      expect(LocalCalendarDate.tryFromIso('2026-06-30'), '2026-06-30');
    });

    test('オフセット付き ISO もローカル暦へ', () {
      const raw = '2026-11-13T00:30:00+09:00';
      expect(LocalCalendarDate.tryFromIso(raw), _localDay(raw));
    });

    test('null / 空 / 空白のみ は null', () {
      expect(LocalCalendarDate.tryFromIso(null), isNull);
      expect(LocalCalendarDate.tryFromIso(''), isNull);
      expect(LocalCalendarDate.tryFromIso('   '), isNull);
    });

    test('壊れ値は throw せず null', () {
      for (final bad in [
        'abc',
        '2026-13-01',
        '2026-02-30',
        '2026-00-10',
        '2026-01-01T99:00:00Z',
        '2026-01-01T00:99:00Z',
        '2026-1-1',
        'not-a-date-2026-01-01',
        '2026-01-01T00:00:00ZZ',
        '99999999',
      ]) {
        expect(LocalCalendarDate.tryFromIso(bad), isNull, reason: bad);
      }
    });

    test('うるう年の 2/29 は通し、平年の 2/29 は弾く', () {
      expect(LocalCalendarDate.tryFromIso('2028-02-29'), '2028-02-29');
      expect(LocalCalendarDate.tryFromIso('2026-02-29'), isNull);
    });
  });

  group('LocalCalendarDate.displayDate', () {
    test('正常な UTC ISO はローカル暦の日付', () {
      const raw = '2026-11-12T15:30:00.000Z';
      expect(LocalCalendarDate.displayDate(raw), _localDay(raw));
    });

    test('壊れ値は生値をそのまま返す（後方互換・throw しない）', () {
      expect(LocalCalendarDate.displayDate('abc'), 'abc');
      expect(LocalCalendarDate.displayDate('2026-13-01'), '2026-13-01');
    });

    test('短い文字列も生値', () {
      expect(LocalCalendarDate.displayDate('2026'), '2026');
      expect(LocalCalendarDate.displayDate('short'), 'short');
    });

    test('null は空文字', () {
      expect(LocalCalendarDate.displayDate(null), '');
    });

    test('前後の空白は trim する', () {
      expect(LocalCalendarDate.displayDate('  2026-06-30  '), '2026-06-30');
    });
  });

  group('ReadingDateKey は LocalCalendarDate へ委譲する（一致）', () {
    test('fromDateTime が一致', () {
      final dt = DateTime.parse('2026-11-12T15:30:00.000Z');
      expect(
        ReadingDateKey.fromDateTime(dt),
        LocalCalendarDate.fromDateTime(dt),
      );
    });

    test('tryFromIso が一致（正常値・壊れ値とも）', () {
      for (final raw in [
        '2026-11-12T15:30:00.000Z',
        '2026-06-30',
        '2026-11-13T00:30:00+09:00',
        null,
        '',
        'abc',
        '2026-13-45T99:99:99Z',
      ]) {
        expect(
          ReadingDateKey.tryFromIso(raw),
          LocalCalendarDate.tryFromIso(raw),
          reason: '$raw',
        );
      }
    });

    test('uniqueSortedDescending は委譲後も重複排除・降順', () {
      expect(
        ReadingDateKey.uniqueSortedDescending([
          '2026-01-01T00:00:00Z',
          '2026-01-01T05:00:00Z',
          '2026-03-01T00:00:00Z',
          'broken',
          null,
        ]),
        [
          ReadingDateKey.tryFromIso('2026-03-01T00:00:00Z')!,
          ReadingDateKey.tryFromIso('2026-01-01T00:00:00Z')!,
        ],
      );
    });

    test('today は fromDateTime(now) と一致', () {
      final fixed = DateTime(2026, 11, 13, 0, 30);
      expect(
        ReadingDateKey.today(now: () => fixed),
        LocalCalendarDate.fromDateTime(fixed),
      );
    });
  });
}
