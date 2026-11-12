import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/reading/domain/reading_date_key.dart';

/// 親探針（独立検証）: 読書日付キーのローカル暦化。
///
/// 実装側の試練 [reading_date_key_test.dart] とは独立に、以下を撃つ:
///  1. Supabase/Hive 両リポジトリが同一の純粋関数へ委譲していること（ソース＋合成）
///  2. ストリーク判定の「今日」文字列とローカル日付キーの形式一致
///  3. 月境界（ローカル 12/01 00:30 が 11/30 に落ちない）
///  4. 壊れ値の非伝播（throw せず null）
///  5. TZ 非依存（期待値は DateTime.parse(...).toLocal() から算出）
///  6. 旧実装（UTC 先頭10文字）との差分検知力
///
/// TZ=UTC / TZ=Asia/Tokyo の双方で緑になること。特定TZの日付を決め打ちしない。

/// ローカル暦の yyyy-MM-dd（期待値生成器・TZ非依存）。
String _localCalendarKey(String raw) {
  final local = DateTime.parse(raw).toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

/// 旧実装（UTC 暦）: 保存文字列の先頭10文字をそのまま日付キーにしていた。
String _legacyUtcKey(String raw) => raw.substring(0, 10);

/// getCurrentStreak が「今日」を組み立てる式の写し（lib 側と同じ形）。
/// ローカル日付コンポーネントから `yyyy-MM-dd` を作る。
String _streakTodayString(DateTime now) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final m = today.month.toString().padLeft(2, '0');
  final d = today.day.toString().padLeft(2, '0');
  return '${today.year}-$m-$d';
}

/// getCurrentStreak 相当の先頭判定（降順 dates の [0] が今日/昨日なら 1）。
int _streakHead(List<String> datesDesc, DateTime now) {
  if (datesDesc.isEmpty) return 0;
  final todayStr = _streakTodayString(now);
  final yesterday = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 1));
  final yesterdayStr = '${yesterday.year}-'
      '${yesterday.month.toString().padLeft(2, '0')}-'
      '${yesterday.day.toString().padLeft(2, '0')}';
  if (datesDesc[0] != todayStr && datesDesc[0] != yesterdayStr) return 0;
  return 1;
}

/// リポジトリのソースから getAllReadingDates の本体だけを切り出す。
String _methodBody(String relativePath) {
  final file = File(relativePath);
  expect(file.existsSync(), isTrue, reason: '$relativePath が見つからない');
  final src = file.readAsStringSync();
  final start = src.indexOf('Future<List<String>> getAllReadingDates');
  expect(start, greaterThanOrEqualTo(0),
      reason: '$relativePath に getAllReadingDates が無い');
  var end = src.indexOf('@override', start);
  if (end < 0) end = src.length;
  return src.substring(start, end);
}

void main() {
  group('1. Supabase/Hive の合成（同一の純粋関数への委譲）', () {
    const hiveSrc = 'lib/features/reading/data/hive_reading_session_repository.dart';
    const supaSrc =
        'lib/features/reading/data/supabase_reading_session_repository.dart';

    test('両実装の getAllReadingDates が ReadingDateKey に委譲している', () {
      for (final path in [hiveSrc, supaSrc]) {
        final body = _methodBody(path);
        expect(body, contains('ReadingDateKey.uniqueSortedDescending'),
            reason: '$path が純粋関数へ委譲していない');
        // 旧実装（UTC 先頭10文字切り出し）の痕跡が残っていないこと。
        expect(body, isNot(contains(RegExp(r'substring\(\s*0\s*,\s*10\s*\)'))),
            reason: '$path に旧 UTC 切り出しが残存');
        expect(body, isNot(contains("split('T')")),
            reason: '$path に旧 UTC 切り出しが残存');
      }
    });

    test('同じ startedAt 集合なら両経路の日付キー集合が一致する', () {
      final rawSessions = <Map<String, dynamic>>[
        {'started_at': '2026-11-12T15:30:00.000Z'},
        {'started_at': '2026-11-12T16:00:00.000Z'},
        {'started_at': '2026-11-13T02:00:00.000Z'},
        {'started_at': null},
        {'started_at': 'abc'},
      ];

      // Hive: セッションの startedAt をそのまま渡す。
      final hiveKeys = ReadingDateKey.uniqueSortedDescending(
        rawSessions.map((s) => s['started_at'] as String?),
      );

      // Supabase: row['started_at'] を String のみ取り出して渡す。
      String? asString(Object? v) => v is String ? v : null;
      final supaKeys = ReadingDateKey.uniqueSortedDescending(
        rawSessions.map((row) => asString(row['started_at'])),
      );

      expect(supaKeys, hiveKeys);
      // 壊れ値は両経路で捨てられ、ローカル暦の日付のみが残る。
      final expected = <String>{
        for (final raw in const [
          '2026-11-12T15:30:00.000Z',
          '2026-11-12T16:00:00.000Z',
          '2026-11-13T02:00:00.000Z',
        ])
          _localCalendarKey(raw),
      }.toList()
        ..sort((a, b) => b.compareTo(a));
      expect(hiveKeys, expected);
    });
  });

  group('2. ストリークの縫い目（JST 深夜0:30 の読書を今日と数える）', () {
    test('深夜0:30 の読書の日付キーが「今日」文字列と一致し streak=1', () {
      // JST 2026-11-13 00:30 = UTC 2026-11-12 15:30Z（＝UTC では前日）
      const raw = '2026-11-12T15:30:00.000Z';
      final instant = DateTime.parse(raw);

      final key = ReadingDateKey.tryFromIso(raw)!;
      expect(key, _localCalendarKey(raw));
      expect(key, ReadingDateKey.fromDateTime(instant));
      expect(key, ReadingDateKey.today(now: () => instant));

      // getCurrentStreak の「今日」文字列と同じ形式・同じ値であること。
      expect(_streakTodayString(instant), key,
          reason: 'ストリークの今日文字列とローカル日付キーの形式が不一致');

      final datesDesc = ReadingDateKey.uniqueSortedDescending([raw]);
      expect(datesDesc.first, _streakTodayString(instant));
      expect(_streakHead(datesDesc, instant), 1);
    });

    test('深夜0:30 と同日 23:00 の読書は 1 日として畳まれる', () {
      final late = DateTime(2026, 11, 13, 0, 30);
      final night = DateTime(2026, 11, 13, 23, 0);
      final keys = ReadingDateKey.uniqueSortedDescending([
        late.toUtc().toIso8601String(),
        night.toUtc().toIso8601String(),
      ]);
      expect(keys, [ReadingDateKey.fromDateTime(late)]);
      expect(keys.length, 1, reason: '同一ローカル日の二重計上');
    });
  });

  group('3. 月初跨ぎ（月境界）', () {
    test('ローカル 2026-12-01 00:30 は 2026-11-30 に落ちない', () {
      final local = DateTime(2026, 12, 1, 0, 30);
      final raw = local.toUtc().toIso8601String();

      final key = ReadingDateKey.tryFromIso(raw)!;
      expect(key, _localCalendarKey(raw));
      expect(key, '2026-12-01');
      expect(key, isNot('2026-11-30'));
      expect(ReadingDateKey.fromDateTime(local), '2026-12-01');
    });

    test('ローカル 2026-01-01 00:10 は前年 12-31 に落ちない', () {
      final local = DateTime(2026, 1, 1, 0, 10);
      final raw = local.toUtc().toIso8601String();

      expect(ReadingDateKey.tryFromIso(raw), '2026-01-01');
      expect(ReadingDateKey.tryFromIso(raw), isNot('2025-12-31'));
    });
  });

  group('4. 壊れ値の非伝播', () {
    test('throw せず null を返す', () {
      const broken = <String?>[
        'abc',
        '',
        '   ',
        null,
        '2026-02-30T00:00:00Z', // 存在しない日
        '2026-13-45T99:99:99Z', // 範囲外の月日・時刻
        '2026-11-12T24:00:00Z', // 範囲外の時
        '2026-11-12T10:60:00Z', // 範囲外の分
        '2026-11-12T10:00:60Z', // 範囲外の秒
        '2026-1-1', // 桁不足
      ];

      for (final raw in broken) {
        late String? actual;
        expect(
          () => actual = ReadingDateKey.tryFromIso(raw),
          returnsNormally,
          reason: 'raw=${raw == null ? 'null' : '"$raw"'} で throw した',
        );
        expect(actual, isNull, reason: 'raw=${raw == null ? 'null' : '"$raw"'}');
      }
    });

    test('壊れ値は uniqueSortedDescending からも消える', () {
      final keys = ReadingDateKey.uniqueSortedDescending(
        const [null, 'abc', '', '   ', '2026-02-30T00:00:00Z', '2026-11-12'],
      );
      expect(keys, ['2026-11-12']);
    });
  });

  group('5. TZ 非依存（期待値は toLocal 由来）', () {
    test('複数の ISO で期待値と一致する', () {
      const raws = [
        '2026-11-12T15:30:00.000Z',
        '2026-11-12T23:59:59.000Z',
        '2026-01-01T00:00:00.000Z',
        '2026-06-30T12:34:56.000Z',
        '2026-12-31T15:00:00.000Z',
        '2026-03-01T00:00:00+09:00',
        '2026-02-28T23:00:00-05:00',
      ];
      for (final raw in raws) {
        expect(ReadingDateKey.tryFromIso(raw), _localCalendarKey(raw),
            reason: 'raw=$raw');
      }
    });

    test('today は差し替えた now のローカル暦を返す', () {
      final now = DateTime(2026, 7, 4, 0, 30);
      expect(ReadingDateKey.today(now: () => now), '2026-07-04');
      expect(ReadingDateKey.today(now: () => now), _streakTodayString(now));
    });
  });

  group('6. 回帰検知力（旧 UTC 切り出しとの差分）', () {
    test('ローカル暦と UTC 暦がずれる時刻では旧実装と値が異なる', () {
      // 日界付近のインスタント群。UTC 環境では offset=0 なので一致し得るため条件付き。
      const raws = [
        '2026-11-12T15:30:00.000Z', // JST 翌日 00:30
        '2026-11-12T23:30:00.000Z', // JST 翌日 08:30
        '2026-12-31T15:30:00.000Z', // JST 翌年 01-01
        '2026-01-01T02:00:00.000Z', // 負オフセットで前年
      ];

      var divergentCases = 0;
      for (final raw in raws) {
        final newKey = ReadingDateKey.tryFromIso(raw)!;
        final oldKey = _legacyUtcKey(raw);
        expect(newKey, _localCalendarKey(raw), reason: 'raw=$raw');
        if (newKey != oldKey) {
          divergentCases++;
          expect(newKey, isNot(oldKey), reason: 'raw=$raw で旧実装と同値');
        }
        // 一致する場合はそのインスタントのローカル暦日と UTC 暦日が同じ日、
        // つまり日界を跨いでいないケース（UTC 環境では常にこちら）。
      }

      // Asia/Tokyo では少なくとも 1 件は差が出る（検知力の証明）。
      if (DateTime.now().timeZoneOffset == const Duration(hours: 9)) {
        expect(divergentCases, greaterThan(0),
            reason: 'JST なのに旧実装との差分を 1 件も検知できていない');
      }
    });

    test('月境界の旧実装は前月へ落ちる（JST のみ差分）', () {
      final local = DateTime(2026, 12, 1, 0, 30);
      final raw = local.toUtc().toIso8601String();
      final newKey = ReadingDateKey.tryFromIso(raw)!;
      final oldKey = _legacyUtcKey(raw);

      expect(newKey, '2026-12-01');
      if (newKey != oldKey) {
        expect(oldKey, '2026-11-30', reason: '旧実装の再現に失敗');
      }
    });
  });
}
