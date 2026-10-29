import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/lifecycle/domain/day_rollover_detector.dart';

void main() {
  group('DayRolloverDetector', () {
    test('ローカル暦が同一なら sameDay を返し lastSeen を now に更新する', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 23, 50, 0));

      expect(
        detector.check(DateTime(2026, 10, 29, 23, 58, 30)),
        DayRolloverResult.sameDay,
      );
      expect(detector.lastSeen, DateTime(2026, 10, 29, 23, 58, 30));
    });

    test('暦日が変わり now が後なら rolledOver を返し lastSeen を now に更新する', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 23, 50, 0));

      expect(
        detector.check(DateTime(2026, 10, 30, 0, 5, 0)),
        DayRolloverResult.rolledOver,
      );
      expect(detector.lastSeen, DateTime(2026, 10, 30, 0, 5, 0));
    });

    test('暦日が変わり now が前なら clockWentBack。lastSeen は据え置き（クランプ）', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 10, 30, 0, 5, 0));

      expect(
        detector.check(DateTime(2026, 10, 29, 23, 0, 0)),
        DayRolloverResult.clockWentBack,
      );
      // 巻き戻しで lastSeen を過去に引きずり込まない（例外も投げない）
      expect(detector.lastSeen, DateTime(2026, 10, 30, 0, 5, 0));
    });

    test('跨ぎ判定の直後は同日扱いに戻る（rolledOver → sameDay）', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 23, 50, 0));

      expect(
        detector.check(DateTime(2026, 10, 30, 0, 5, 0)),
        DayRolloverResult.rolledOver,
      );
      expect(
        detector.check(DateTime(2026, 10, 30, 7, 0, 0)),
        DayRolloverResult.sameDay,
      );
      expect(detector.lastSeen, DateTime(2026, 10, 30, 7, 0, 0));
    });

    test('翌日跨ぎを繰り返すたびに rolledOver を返す', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 22, 0, 0));

      expect(
        detector.check(DateTime(2026, 10, 30, 1, 0, 0)),
        DayRolloverResult.rolledOver,
      );
      expect(
        detector.check(DateTime(2026, 10, 31, 1, 0, 0)),
        DayRolloverResult.rolledOver,
      );
      expect(detector.lastSeen, DateTime(2026, 10, 31, 1, 0, 0));
    });

    test('月・年を跨ぐ場合も rolledOver（ローカル暦で判定）', () {
      final detector =
          DayRolloverDetector(lastSeen: DateTime(2026, 12, 31, 23, 30, 0));

      expect(
        detector.check(DateTime(2027, 1, 1, 0, 10, 0)),
        DayRolloverResult.rolledOver,
      );
      expect(detector.lastSeen, DateTime(2027, 1, 1, 0, 10, 0));
    });
  });
}
