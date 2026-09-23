import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/features/settings/domain/theme_mode_setting.dart';

void main() {
  group('ThemeModeSetting', () {
    test('has 3 values with correct storageKey and label', () {
      expect(ThemeModeSetting.values.length, 3);
      expect(ThemeModeSetting.light.storageKey, 'light');
      expect(ThemeModeSetting.light.label, 'ライト');
      expect(ThemeModeSetting.dark.storageKey, 'dark');
      expect(ThemeModeSetting.dark.label, 'ダーク');
      expect(ThemeModeSetting.system.storageKey, 'system');
      expect(ThemeModeSetting.system.label, 'システム');
    });

    group('fromStorageKey', () {
      test('returns light for "light"', () {
        expect(ThemeModeSetting.fromStorageKey('light'),
            ThemeModeSetting.light);
      });

      test('returns dark for "dark"', () {
        expect(
            ThemeModeSetting.fromStorageKey('dark'), ThemeModeSetting.dark);
      });

      test('returns system for "system"', () {
        expect(ThemeModeSetting.fromStorageKey('system'),
            ThemeModeSetting.system);
      });

      test('returns system for null', () {
        expect(
            ThemeModeSetting.fromStorageKey(null), ThemeModeSetting.system);
      });

      test('returns system for unknown values', () {
        expect(ThemeModeSetting.fromStorageKey('blue'),
            ThemeModeSetting.system);
        expect(ThemeModeSetting.fromStorageKey(''),
            ThemeModeSetting.system);
        expect(ThemeModeSetting.fromStorageKey('LIGHT'),
            ThemeModeSetting.system);
      });
    });

    group('next', () {
      test('cycles light → dark → system → light', () {
        expect(ThemeModeSetting.light.next, ThemeModeSetting.dark);
        expect(ThemeModeSetting.dark.next, ThemeModeSetting.system);
        expect(ThemeModeSetting.system.next, ThemeModeSetting.light);
      });

      test('three next() calls return to the original value', () {
        for (final mode in ThemeModeSetting.values) {
          var current = mode;
          for (var i = 0; i < 3; i++) {
            current = current.next;
          }
          expect(current, mode);
        }
      });
    });

    group('toThemeMode', () {
      test('maps to Flutter ThemeMode', () {
        expect(ThemeModeSetting.light.toThemeMode(), ThemeMode.light);
        expect(ThemeModeSetting.dark.toThemeMode(), ThemeMode.dark);
        expect(ThemeModeSetting.system.toThemeMode(), ThemeMode.system);
      });
    });
  });
}
