import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/settings/data/theme_mode_provider.dart';
import 'package:tsundoku_quest/features/settings/data/theme_mode_repository.dart';
import 'package:tsundoku_quest/features/settings/domain/theme_mode_setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  ProviderContainer createContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = createContainer();
  });

  group('ThemeModeController', () {
    test('default state == system', () {
      expect(container.read(themeModeProvider), ThemeModeSetting.system);
    });

    test('setMode(dark) updates state and persists', () async {
      await container.read(themeModeProvider.notifier).setMode(
            ThemeModeSetting.dark,
          );

      expect(container.read(themeModeProvider), ThemeModeSetting.dark);
      final saved = await const ThemeModeRepository().loadThemeMode();
      expect(saved, ThemeModeSetting.dark);
    });

    test('setMode(light) round-trips through storage', () async {
      await container.read(themeModeProvider.notifier).setMode(
            ThemeModeSetting.light,
          );

      expect(container.read(themeModeProvider), ThemeModeSetting.light);
      final saved = await const ThemeModeRepository().loadThemeMode();
      expect(saved, ThemeModeSetting.light);
    });

    test('load() restores a previously saved dark', () async {
      SharedPreferences.setMockInitialValues({
        ThemeModeRepository.key: 'dark',
      });

      await container.read(themeModeProvider.notifier).load();

      expect(container.read(themeModeProvider), ThemeModeSetting.dark);
    });

    test('load() falls back to system when unset', () async {
      await container.read(themeModeProvider.notifier).load();
      expect(container.read(themeModeProvider), ThemeModeSetting.system);
    });

    test('load() falls back to system when stored value is invalid',
        () async {
      SharedPreferences.setMockInitialValues({
        ThemeModeRepository.key: 'blue',
      });

      await container.read(themeModeProvider.notifier).load();

      expect(container.read(themeModeProvider), ThemeModeSetting.system);
    });
  });
}
