import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/features/settings/domain/reduce_motion_setting.dart';

void main() {
  group('ReduceMotionSetting', () {
    test('storageKey は system/off/on', () {
      expect(ReduceMotionSetting.system.storageKey, 'system');
      expect(ReduceMotionSetting.off.storageKey, 'off');
      expect(ReduceMotionSetting.on.storageKey, 'on');
    });

    test('fromStorageKey は既知のキーを復元する', () {
      expect(ReduceMotionSetting.fromStorageKey('on'), ReduceMotionSetting.on);
      expect(ReduceMotionSetting.fromStorageKey('off'), ReduceMotionSetting.off);
      expect(
        ReduceMotionSetting.fromStorageKey('system'),
        ReduceMotionSetting.system,
      );
    });

    test('fromStorageKey は null / 未知値を system にする', () {
      expect(ReduceMotionSetting.fromStorageKey(null), ReduceMotionSetting.system);
      expect(
        ReduceMotionSetting.fromStorageKey('unknown'),
        ReduceMotionSetting.system,
      );
      expect(ReduceMotionSetting.fromStorageKey(''), ReduceMotionSetting.system);
    });

    test('next は system→off→on→system を巡回する', () {
      expect(ReduceMotionSetting.system.next, ReduceMotionSetting.off);
      expect(ReduceMotionSetting.off.next, ReduceMotionSetting.on);
      expect(ReduceMotionSetting.on.next, ReduceMotionSetting.system);
    });

    test('forceDisableAnimations は on=true / off=false / system=null', () {
      expect(ReduceMotionSetting.on.forceDisableAnimations, isTrue);
      expect(ReduceMotionSetting.off.forceDisableAnimations, isFalse);
      expect(ReduceMotionSetting.system.forceDisableAnimations, isNull);
    });

    test('forceDisableAnimations は全値を網羅する', () {
      expect(
        ReduceMotionSetting.values
            .map((s) => s.forceDisableAnimations)
            .toList(),
        <bool?>[null, false, true],
      );
    });

    test('applyReduceMotion は system のとき data をそのまま返す', () {
      const data = MediaQueryData(
        textScaler: TextScaler.linear(1.3),
        disableAnimations: true,
      );
      final applied = applyReduceMotion(data, ReduceMotionSetting.system);
      expect(identical(applied, data), isTrue);
      expect(applied.disableAnimations, isTrue);
    });

    test('applyReduceMotion(on) は disableAnimations を true にする', () {
      const data = MediaQueryData(
        textScaler: TextScaler.linear(1.3),
        disableAnimations: false,
      );
      final applied = applyReduceMotion(data, ReduceMotionSetting.on);
      expect(applied.disableAnimations, isTrue);
      // textScaler など既存値は保持される
      expect(applied.textScaler, const TextScaler.linear(1.3));
    });

    test('applyReduceMotion(off) は端末設定を上書きして false にする', () {
      const data = MediaQueryData(disableAnimations: true);
      final applied = applyReduceMotion(data, ReduceMotionSetting.off);
      expect(applied.disableAnimations, isFalse);
    });
  });
}
