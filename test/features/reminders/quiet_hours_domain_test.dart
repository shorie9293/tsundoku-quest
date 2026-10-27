import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_service.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_settings.dart';

/// 固定時刻（実時計と突き合わせない十分過去の UTC 時刻）。
DateTime _at(int hour, int minute) => DateTime(2020, 1, 15, hour, minute);

/// `deferUntil` はローカル時刻を返すため、瞬間（instant）で比較する。
Matcher _sameMoment(DateTime expected) => predicate<DateTime>(
      (d) => d.isAtSameMomentAs(expected),
      'same moment as $expected',
    );

void main() {
  group('QuietHoursPolicy', () {
    test('storageKey から復元でき、未知キーは defer に落ちる', () {
      expect(QuietHoursPolicy.fromStorageKey('skip'), QuietHoursPolicy.skip);
      expect(QuietHoursPolicy.fromStorageKey('defer'), QuietHoursPolicy.defer);
      expect(
          QuietHoursPolicy.fromStorageKey('unknown'), QuietHoursPolicy.defer);
      expect(QuietHoursPolicy.fromStorageKey(null), QuietHoursPolicy.defer);
      expect(QuietHoursPolicy.skip.label, isNotEmpty);
    });
  });

  group('QuietHoursSettings', () {
    test('既定値は無効・22:00〜07:00・defer', () {
      final s = QuietHoursSettings.defaults();
      expect(s.enabled, isFalse);
      expect(s.startMinutes, 22 * 60);
      expect(s.endMinutes, 7 * 60);
      expect(s.policy, QuietHoursPolicy.defer);
      expect(s.startLabel, '22:00');
      expect(s.endLabel, '07:00');
    });

    test('範囲外の時・分は ArgumentError（assert ではない）', () {
      expect(() => QuietHoursSettings(startHour: 24), throwsArgumentError);
      expect(() => QuietHoursSettings(startHour: -1), throwsArgumentError);
      expect(() => QuietHoursSettings(startMinute: 60), throwsArgumentError);
      expect(() => QuietHoursSettings(endHour: 24), throwsArgumentError);
      expect(() => QuietHoursSettings(endMinute: -1), throwsArgumentError);
    });

    test('値等価・hashCode・copyWith', () {
      final a =
          QuietHoursSettings(enabled: true, startHour: 21, startMinute: 30);
      final b =
          QuietHoursSettings(enabled: true, startHour: 21, startMinute: 30);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      final c = a.copyWith(policy: QuietHoursPolicy.skip, endHour: 8);
      expect(c.policy, QuietHoursPolicy.skip);
      expect(c.endHour, 8);
      expect(c.startHour, 21);
      expect(c.enabled, isTrue);
      expect(c, isNot(equals(a)));
    });

    test('toJson/fromJson は往復する', () {
      final s = QuietHoursSettings(
        enabled: true,
        startHour: 23,
        startMinute: 45,
        endHour: 6,
        endMinute: 15,
        policy: QuietHoursPolicy.skip,
      );
      expect(QuietHoursSettings.fromJson(s.toJson()), equals(s));
    });

    test('fromJson は破損・型不正・範囲外で既定値へフォールバックする', () {
      expect(QuietHoursSettings.fromJson({}), QuietHoursSettings.defaults());
      expect(
        QuietHoursSettings.fromJson({'enabled': 'yes'}),
        QuietHoursSettings.defaults(),
      );
      expect(
        QuietHoursSettings.fromJson({
          'enabled': true,
          'startHour': 99,
          'startMinute': 0,
          'endHour': 7,
          'endMinute': 0,
          'policy': 'defer',
        }),
        QuietHoursSettings.defaults(),
      );
      expect(
        QuietHoursSettings.fromJson({
          'enabled': true,
          'startHour': 22,
          'startMinute': 0,
          'endHour': 7,
          'endMinute': 0,
          'policy': 'bogus',
        }),
        QuietHoursSettings.defaults(),
      );
    });
  });

  group('QuietHoursService.isWithinQuietHours', () {
    test('start == end は常に抑止なし', () {
      for (final m in [0, 300, 720, 1439]) {
        expect(
          QuietHoursService.isWithinQuietHours(
              _at(0, 0).add(Duration(minutes: m)), 480, 480),
          isFalse,
        );
      }
    });

    test('通常区間 [start, end) の境界', () {
      const start = 9 * 60; // 09:00
      const end = 17 * 60; // 17:00
      expect(QuietHoursService.isWithinQuietHours(_at(8, 59), start, end),
          isFalse);
      expect(
          QuietHoursService.isWithinQuietHours(_at(9, 0), start, end), isTrue);
      expect(
          QuietHoursService.isWithinQuietHours(_at(12, 0), start, end), isTrue);
      expect(QuietHoursService.isWithinQuietHours(_at(16, 59), start, end),
          isTrue);
      expect(QuietHoursService.isWithinQuietHours(_at(17, 0), start, end),
          isFalse);
    });

    test('日跨ぎ区間 [start, 24:00) ∪ [0:00, end) の境界', () {
      const start = 22 * 60; // 22:00
      const end = 7 * 60; // 07:00
      expect(QuietHoursService.isWithinQuietHours(_at(21, 59), start, end),
          isFalse);
      expect(
          QuietHoursService.isWithinQuietHours(_at(22, 0), start, end), isTrue);
      expect(QuietHoursService.isWithinQuietHours(_at(23, 59), start, end),
          isTrue);
      expect(
          QuietHoursService.isWithinQuietHours(_at(0, 0), start, end), isTrue);
      expect(
          QuietHoursService.isWithinQuietHours(_at(6, 59), start, end), isTrue);
      expect(
          QuietHoursService.isWithinQuietHours(_at(7, 0), start, end), isFalse);
      expect(QuietHoursService.isWithinQuietHours(_at(12, 0), start, end),
          isFalse);
    });
  });

  group('QuietHoursService.deferUntil', () {
    test('通常区間内は同日の終了時刻へ', () {
      final result = QuietHoursService.deferUntil(_at(10, 30), 9 * 60, 17 * 60);
      expect(result, _sameMoment(DateTime(2020, 1, 15, 17, 0)));
    });

    test('日跨ぎ区間内は翌日の終了時刻へ', () {
      final result = QuietHoursService.deferUntil(_at(23, 30), 22 * 60, 7 * 60);
      expect(result, _sameMoment(DateTime(2020, 1, 16, 7, 0)));
    });

    test('静穏時間外は now をそのまま返す', () {
      final now = _at(12, 0);
      expect(QuietHoursService.deferUntil(now, 22 * 60, 7 * 60), now);
    });
  });

  group('QuietHoursService.resolveDelivery', () {
    test('無効なら予定時刻をそのまま返す', () {
      final scheduled = _at(23, 30);
      final s = QuietHoursSettings(enabled: false, startHour: 22, endHour: 7);
      expect(QuietHoursService.resolveDelivery(s, scheduled), scheduled);
    });

    test('静穏時間外なら予定時刻をそのまま返す', () {
      final scheduled = _at(20, 0);
      final s = QuietHoursSettings(enabled: true, startHour: 22, endHour: 7);
      expect(QuietHoursService.resolveDelivery(s, scheduled), scheduled);
    });

    test('defer なら繰延時刻を返す', () {
      final scheduled = _at(23, 30);
      final s = QuietHoursSettings(enabled: true, startHour: 22, endHour: 7);
      expect(
        QuietHoursService.resolveDelivery(s, scheduled),
        _sameMoment(DateTime(2020, 1, 16, 7, 0)),
      );
    });

    test('skip なら null（送出しない）', () {
      final scheduled = _at(2, 0);
      final s = QuietHoursSettings(
        enabled: true,
        startHour: 22,
        endHour: 7,
        policy: QuietHoursPolicy.skip,
      );
      expect(QuietHoursService.resolveDelivery(s, scheduled), isNull);
    });

    test('start == end なら抑止しない', () {
      final scheduled = _at(22, 0);
      final s = QuietHoursSettings(enabled: true, startHour: 22, endHour: 22);
      expect(QuietHoursService.resolveDelivery(s, scheduled), scheduled);
    });
  });

  group('QuietHoursService.formatMinutes', () {
    test('ゼロ埋め HH:mm に整形する', () {
      expect(QuietHoursService.formatMinutes(0), '00:00');
      expect(QuietHoursService.formatMinutes(9 * 60 + 5), '09:05');
      expect(QuietHoursService.formatMinutes(22 * 60), '22:00');
      expect(QuietHoursService.formatMinutes(1439), '23:59');
    });
  });
}
