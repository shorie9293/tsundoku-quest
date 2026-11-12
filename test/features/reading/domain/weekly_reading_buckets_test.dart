import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/reading/domain/weekly_reading_buckets.dart';

/// 直近7日の読書時間バケットの試練。
///
/// startedAt は UTC ISO 文字列（'2026-11-12T09:00:00.000Z'）または日付のみ
/// 文字列（'2026-11-12'）。バケットは**ローカル暦**で切る。
/// 端末が JST(+0900) である前提の固定値を使う箇所にはその旨を明記する。
void main() {
  // 2026-11-12 は木曜日。ローカル暦で 6 日前 = 2026-11-06（金曜日）。
  final now = DateTime(2026, 11, 12, 18, 0);

  group('WeeklyReadingBuckets.days', () {
    test('7 日である', () {
      expect(WeeklyReadingBuckets.days, 7);
    });
  });

  group('weekStart', () {
    test('ローカル0時に落ち、now のローカル日付 -6 日になる', () {
      final ws = WeeklyReadingBuckets.weekStart(now);

      expect(ws.isUtc, isFalse);
      expect(ws.year, 2026);
      expect(ws.month, 11);
      expect(ws.day, 6);
      expect(ws.hour, 0);
      expect(ws.minute, 0);
      expect(ws.second, 0);
      expect(ws.millisecond, 0);
      expect(ws.microsecond, 0);
      expect(ws.isAtSameMomentAs(DateTime(2026, 11, 6)), isTrue);
    });

    test('月をまたぐ場合も暦どおりに遡る', () {
      final ws = WeeklyReadingBuckets.weekStart(DateTime(2026, 3, 3, 9, 30));
      expect(ws.isAtSameMomentAs(DateTime(2026, 2, 25)), isTrue);
    });

    test('now が0時ちょうどでも同じローカル日付基準になる', () {
      final ws = WeeklyReadingBuckets.weekStart(DateTime(2026, 11, 12, 0, 0));
      expect(ws.isAtSameMomentAs(DateTime(2026, 11, 6)), isTrue);
    });
  });

  group('indexFor', () {
    test('今日のセッションは index 6 に入る', () {
      final ws = WeeklyReadingBuckets.weekStart(now);
      // JST では 2026-11-12 18:00（= 今日）
      expect(WeeklyReadingBuckets.indexFor('2026-11-12T09:00:00.000Z', ws), 6);
    });

    test('6日前のセッションは index 0 に入り、捨てられない', () {
      final ws = WeeklyReadingBuckets.weekStart(now);
      // JST では 2026-11-06 09:30
      expect(WeeklyReadingBuckets.indexFor('2026-11-06T00:30:00.000Z', ws), 0);
    });

    test('日付のみ文字列もローカル日付として扱う', () {
      final ws = WeeklyReadingBuckets.weekStart(now);
      expect(WeeklyReadingBuckets.indexFor('2026-11-12', ws), 6);
      expect(WeeklyReadingBuckets.indexFor('2026-11-06', ws), 0);
      expect(WeeklyReadingBuckets.indexFor('2026-11-09', ws), 3);
    });

    test('UTC日付ではなくローカル日付で数える', () {
      // 2026-11-11T16:00:00Z は JST で 2026-11-12 01:00。
      // UTC の日付(11-11)で数えると index 5 になってしまう。
      const raw = '2026-11-11T16:00:00.000Z';
      final ws = WeeklyReadingBuckets.weekStart(now);
      final local = DateTime.parse(raw).toLocal();
      final localDay = DateTime(local.year, local.month, local.day);
      final expected = localDay.difference(ws).inDays;

      expect(WeeklyReadingBuckets.indexFor(raw, ws), expected);
      if (local.day != 11) {
        // JST 端末では「今日」= index 6。UTC 日付実装なら 5 で落ちる。
        expect(WeeklyReadingBuckets.indexFor(raw, ws), 6);
      }
    });

    test('範囲外は null（7日以上前・未来）', () {
      final ws = WeeklyReadingBuckets.weekStart(now);
      expect(WeeklyReadingBuckets.indexFor('2026-11-05T09:00:00.000Z', ws),
          isNull);
      expect(WeeklyReadingBuckets.indexFor('2020-01-01T00:00:00.000Z', ws),
          isNull);
      expect(WeeklyReadingBuckets.indexFor('2027-01-01T00:00:00.000Z', ws),
          isNull);
    });

    test('壊れた入力でも throw せず null を返す', () {
      final ws = WeeklyReadingBuckets.weekStart(now);
      expect(() => WeeklyReadingBuckets.indexFor('', ws), returnsNormally);
      expect(() => WeeklyReadingBuckets.indexFor('not-a-date', ws),
          returnsNormally);
      expect(() => WeeklyReadingBuckets.indexFor('2026-13-45', ws),
          returnsNormally);
      expect(() => WeeklyReadingBuckets.indexFor('   ', ws), returnsNormally);

      expect(WeeklyReadingBuckets.indexFor('', ws), isNull);
      expect(WeeklyReadingBuckets.indexFor('not-a-date', ws), isNull);
      expect(WeeklyReadingBuckets.indexFor('2026-13-45', ws), isNull);
      expect(WeeklyReadingBuckets.indexFor('   ', ws), isNull);
    });
  });

  group('build', () {
    test('今日読書したら index 6 が 0 でない', () {
      final buckets = WeeklyReadingBuckets.build(
        const [(startedAt: '2026-11-12T09:00:00.000Z', durationMinutes: 42)],
        now: now,
      );

      expect(buckets.length, 7);
      expect(buckets[6], 42);
      expect(buckets[6], isNot(0));
    });

    test('6日前のセッションは index 0 に入る（捨てられない）', () {
      final buckets = WeeklyReadingBuckets.build(
        const [(startedAt: '2026-11-06T00:30:00.000Z', durationMinutes: 15)],
        now: now,
      );

      expect(buckets[0], 15);
    });

    test('index 0..6 が 6日前..今日に順に対応する', () {
      final buckets = WeeklyReadingBuckets.build(
        const [
          (startedAt: '2026-11-06T05:00:00.000Z', durationMinutes: 1),
          (startedAt: '2026-11-07T05:00:00.000Z', durationMinutes: 10),
          (startedAt: '2026-11-08T05:00:00.000Z', durationMinutes: 100),
          (startedAt: '2026-11-09T05:00:00.000Z', durationMinutes: 1000),
          (startedAt: '2026-11-10T05:00:00.000Z', durationMinutes: 10000),
          (startedAt: '2026-11-11T05:00:00.000Z', durationMinutes: 2),
          (startedAt: '2026-11-12T05:00:00.000Z', durationMinutes: 20),
        ],
        now: now,
      );

      expect(buckets, [1, 10, 100, 1000, 10000, 2, 20]);
    });

    test('合計が入力 durationMinutes 合計と一致する（捨てた分を除く）', () {
      const samples = [
        (startedAt: '2026-11-12T09:00:00.000Z', durationMinutes: 30),
        (startedAt: '2026-11-12T10:00:00.000Z', durationMinutes: 25),
        (startedAt: '2026-11-11T09:00:00.000Z', durationMinutes: 5),
        (startedAt: '2026-11-06T00:30:00.000Z', durationMinutes: 7),
        // 以下は捨てられる
        (startedAt: '2026-11-12T11:00:00.000Z', durationMinutes: null),
        (startedAt: 'not-a-date', durationMinutes: 999),
        (startedAt: '', durationMinutes: 999),
        (startedAt: '2020-01-01T00:00:00.000Z', durationMinutes: 999),
      ];

      final buckets = WeeklyReadingBuckets.build(samples, now: now);
      final expected = samples
          .where((s) => s.durationMinutes != null)
          .where((s) =>
              WeeklyReadingBuckets.indexFor(
                  s.startedAt, WeeklyReadingBuckets.weekStart(now)) !=
              null)
          .fold<int>(0, (sum, s) => sum + s.durationMinutes!);

      expect(expected, 67);
      expect(buckets.fold<int>(0, (a, b) => a + b), expected);
      expect(buckets.fold<int>(0, (a, b) => a + b), 67);
    });

    test('durationMinutes が null のサンプルは加算しない', () {
      final buckets = WeeklyReadingBuckets.build(
        const [
          (startedAt: '2026-11-12T09:00:00.000Z', durationMinutes: null),
          (startedAt: '2026-11-12T10:00:00.000Z', durationMinutes: 8),
        ],
        now: now,
      );

      expect(buckets[6], 8);
      expect(buckets.fold<int>(0, (a, b) => a + b), 8);
    });

    test('空・全滅入力でも長さは常に7', () {
      expect(WeeklyReadingBuckets.build(const [], now: now).length, 7);
      expect(
        WeeklyReadingBuckets.build(
          const [
            (startedAt: 'not-a-date', durationMinutes: 10),
            (startedAt: '2020-01-01T00:00:00.000Z', durationMinutes: 10),
          ],
          now: now,
        ).length,
        7,
      );
      expect(
        WeeklyReadingBuckets.build(
          const [(startedAt: '2026-11-12T09:00:00.000Z', durationMinutes: 3)],
          now: now,
        ).length,
        7,
      );
    });

    test('壊れた入力があっても throw せず、該当バケットに入らない', () {
      late List<int> buckets;
      expect(
        () => buckets = WeeklyReadingBuckets.build(
          const [
            (startedAt: '', durationMinutes: 10),
            (startedAt: 'not-a-date', durationMinutes: 10),
            (startedAt: '2020-01-01T00:00:00.000Z', durationMinutes: 10),
            (startedAt: '2026-11-12T09:00:00.000Z', durationMinutes: 4),
          ],
          now: now,
        ),
        returnsNormally,
      );

      expect(buckets.length, 7);
      expect(buckets.fold<int>(0, (a, b) => a + b), 4);
    });

    test('呼び出しごとに新しいリストを返す（呼び出し元で壊れない）', () {
      final a = WeeklyReadingBuckets.build(const [], now: now);
      final b = WeeklyReadingBuckets.build(const [], now: now);
      a[0] = 99;
      expect(b[0], 0);
    });
  });
}
