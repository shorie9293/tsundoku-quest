import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/reading/domain/reading_date_key.dart';

/// 読書日付キーの試練。
///
/// 保存は UTC ISO・日付キーは **ローカル暦**。
/// TZ=Asia/Tokyo / TZ=UTC の双方で緑になること（特定TZを決め打ちしない）。

/// ローカル暦の yyyy-MM-dd を期待値として組み立てる（特定TZ非依存）。
String _expectedLocal(String raw) {
  final local = DateTime.parse(raw).toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

void main() {
  group('ReadingDateKey.fromDateTime', () {
    test('UTC インスタントはローカル暦の日付になる', () {
      const raw = '2026-11-12T20:00:00.000Z';
      final key = ReadingDateKey.fromDateTime(DateTime.parse(raw));

      expect(key, _expectedLocal(raw));
      // JST(UTC+9) では 11/13 05:00 → 11/13。UTC では 11/12。
      expect(key, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      if (DateTime.parse(raw).toLocal().timeZoneOffset ==
          const Duration(hours: 9)) {
        expect(key, '2026-11-13', reason: 'JST では翌日');
      }
    });

    test('UTC 14:59Z はローカル日付と一致する（JSTなら当日）', () {
      const raw = '2026-11-12T14:59:00.000Z';
      final key = ReadingDateKey.fromDateTime(DateTime.parse(raw));

      expect(key, _expectedLocal(raw));
      if (DateTime.parse(raw).toLocal().timeZoneOffset ==
          const Duration(hours: 9)) {
        expect(key, '2026-11-12');
      }
    });

    test('生の UTC 日付を切り出す旧実装と JST では食い違う', () {
      const raw = '2026-11-12T20:00:00.000Z';
      final key = ReadingDateKey.fromDateTime(DateTime.parse(raw));
      final legacy = raw.substring(0, 10);

      // JST では旧実装('2026-11-12')が誤りであることを固定する。
      if (DateTime.parse(raw).toLocal().timeZoneOffset ==
          const Duration(hours: 9)) {
        expect(key, isNot(legacy));
      }
      expect(key, isNotEmpty);
    });

    test('月日は2桁ゼロ埋め', () {
      expect(ReadingDateKey.fromDateTime(DateTime(2026, 1, 5, 3, 4)), '2026-01-05');
      expect(ReadingDateKey.fromDateTime(DateTime(2026, 12, 31, 23, 59)),
          '2026-12-31');
    });
  });

  group('ReadingDateKey.tryFromIso', () {
    test('UTC ISO はローカル日付', () {
      const raw = '2026-11-12T20:00:00.000Z';
      expect(ReadingDateKey.tryFromIso(raw), _expectedLocal(raw));
    });

    test('日付のみ文字列はTZ非依存で安定', () {
      expect(ReadingDateKey.tryFromIso('2026-11-13'), '2026-11-13');
    });

    test('前後の空白は無視される', () {
      expect(ReadingDateKey.tryFromIso('  2026-11-13  '), '2026-11-13');
    });

    test('壊れ値でも throw せず null', () {
      for (final raw in <String?>[
        'abc',
        '',
        '   ',
        null,
        '2026-13-45T99:99:99Z',
        'not-a-date',
      ]) {
        expect(
          () => ReadingDateKey.tryFromIso(raw),
          returnsNormally,
          reason: 'raw=$raw',
        );
        expect(ReadingDateKey.tryFromIso(raw), isNull, reason: 'raw=$raw');
      }
    });
  });

  group('ReadingDateKey.uniqueSortedDescending', () {
    test('重複排除・降順・壊れ値除外', () {
      final result = ReadingDateKey.uniqueSortedDescending([
        '2026-11-10T00:00:00.000Z',
        '2026-11-12T00:00:00.000Z',
        '2026-11-10T12:00:00.000Z',
        '2026-11-11T00:00:00.000Z',
        'abc',
        '',
        null,
      ]);

      // 期待値は「ローカル日付に落としてから」組み立てる（TZ非依存）。
      final expected = <String>{
        for (final raw in [
          '2026-11-10T00:00:00.000Z',
          '2026-11-12T00:00:00.000Z',
          '2026-11-10T12:00:00.000Z',
          '2026-11-11T00:00:00.000Z',
        ])
          _expectedLocal(raw),
      }.toList()
        ..sort((a, b) => b.compareTo(a));

      expect(result, expected);
      expect(result.toSet().length, result.length, reason: '重複なし');
      for (var i = 1; i < result.length; i++) {
        expect(result[i - 1].compareTo(result[i]), greaterThan(0),
            reason: '降順であること');
      }
    });

    test('空入力・壊れ値のみなら空', () {
      expect(ReadingDateKey.uniqueSortedDescending(const []), isEmpty);
      expect(ReadingDateKey.uniqueSortedDescending(<String?>[null, '', 'x']),
          isEmpty);
    });
  });

  group('ReadingDateKey.today', () {
    test('固定クロックのローカル日付を返す', () {
      expect(
        ReadingDateKey.today(now: () => DateTime(2026, 1, 1, 0, 30)),
        '2026-01-01',
      );
    });

    test('既定クロックでも throw しない', () {
      expect(ReadingDateKey.today(),
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });
  });
}