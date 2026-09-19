import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/features/settings/domain/text_scale_setting.dart';

void main() {
  group('TextScaleSetting', () {
    test('presets are 小 0.9 / 通常 1.0 / 大 1.25', () {
      expect(TextScaleSetting.presets.length, 3);
      expect(TextScaleSetting.presets[0].label, '小');
      expect(TextScaleSetting.presets[0].scale, 0.9);
      expect(TextScaleSetting.presets[1].label, '通常');
      expect(TextScaleSetting.presets[1].scale, 1.0);
      expect(TextScaleSetting.presets[2].label, '大');
      expect(TextScaleSetting.presets[2].scale, 1.25);
    });

    test('isAllowed is true for the 3 presets', () {
      expect(TextScaleSetting.isAllowed(0.9), isTrue);
      expect(TextScaleSetting.isAllowed(1.0), isTrue);
      expect(TextScaleSetting.isAllowed(1.25), isTrue);
    });

    test('isAllowed is false for unknown scales', () {
      expect(TextScaleSetting.isAllowed(0.5), isFalse);
      expect(TextScaleSetting.isAllowed(1.1), isFalse);
      expect(TextScaleSetting.isAllowed(2.0), isFalse);
    });

    test('fromScale(null) returns null', () {
      expect(TextScaleSetting.fromScale(null), isNull);
    });

    test('fromScale(unknown) returns null', () {
      expect(TextScaleSetting.fromScale(1.1), isNull);
      expect(TextScaleSetting.fromScale(3.0), isNull);
    });

    test('normalized(null) returns 1.0', () {
      expect(TextScaleSetting.normalized(null), 1.0);
    });

    test('normalized(0.9) returns 0.9', () {
      expect(TextScaleSetting.normalized(0.9), 0.9);
    });

    test('normalized(garbage) returns 1.0 (tolerance behaviour)', () {
      expect(TextScaleSetting.normalized(1.1), 1.0);
      // 0.9 に極めて近い値は 0.9 プリセットに正規化される
      expect(TextScaleSetting.normalized(0.9 + 0.0005), 0.9);
    });
  });
}
