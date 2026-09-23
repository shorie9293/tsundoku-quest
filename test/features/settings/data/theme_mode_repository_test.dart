import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/settings/data/theme_mode_repository.dart';
import 'package:tsundoku_quest/features/settings/domain/theme_mode_setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadThemeMode() returns null when unset', () async {
      final repository = const ThemeModeRepository();
      expect(await repository.loadThemeMode(), isNull);
    });

    test('saveThemeMode(light) then loadThemeMode() == light', () async {
      final repository = const ThemeModeRepository();
      await repository.saveThemeMode(ThemeModeSetting.light);
      expect(await repository.loadThemeMode(), ThemeModeSetting.light);
    });

    test('saveThemeMode(dark) round-trips', () async {
      final repository = const ThemeModeRepository();
      await repository.saveThemeMode(ThemeModeSetting.dark);
      expect(await repository.loadThemeMode(), ThemeModeSetting.dark);
    });

    test('saveThemeMode(system) round-trips', () async {
      final repository = const ThemeModeRepository();
      await repository.saveThemeMode(ThemeModeSetting.system);
      expect(await repository.loadThemeMode(), ThemeModeSetting.system);
    });

    test('stored unknown value makes loadThemeMode() return null', () async {
      SharedPreferences.setMockInitialValues({
        ThemeModeRepository.key: 'blue',
      });
      final repository = const ThemeModeRepository();
      expect(await repository.loadThemeMode(), isNull);
    });

    test('save overwrites a previous value', () async {
      final repository = const ThemeModeRepository();
      await repository.saveThemeMode(ThemeModeSetting.light);
      await repository.saveThemeMode(ThemeModeSetting.dark);
      expect(await repository.loadThemeMode(), ThemeModeSetting.dark);
    });
  });
}
