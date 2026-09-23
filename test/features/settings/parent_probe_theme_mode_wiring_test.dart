import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/core/theme/app_theme.dart';
import 'package:tsundoku_quest/features/settings/data/theme_mode_provider.dart';
import 'package:tsundoku_quest/features/settings/domain/theme_mode_setting.dart';
import 'package:tsundoku_quest/features/settings/presentation/theme_mode_settings_screen.dart';

/// 親（イシコリ）の探針 — 眷属が個別にしか撃たない「合成の不変条件」を撃つ。
/// 1) ライトテーマが本当に Brightness.light か（ダークの写し間違い検出）
/// 2) 画面上の選択が state と永続化の両方に到達しているか
/// 3) 再起動相当（load）で保存値が復元され、不正値は system へ落ちるか
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('親探針: テーマ定義の対称性', () {
    test('lightTheme は light、darkTheme は dark', () {
      expect(AppTheme.lightTheme.brightness, Brightness.light);
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
      expect(
        AppTheme.lightTheme.scaffoldBackgroundColor,
        isNot(AppTheme.darkTheme.scaffoldBackgroundColor),
      );
    });
  });

  group('親探針: 画面 → state → 永続化の合成', () {
    testWidgets('ダークを選ぶと state と SharedPreferences の双方に載る', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ThemeModeSettingsScreen()),
        ),
      );

      expect(container.read(themeModeProvider), ThemeModeSetting.system);

      await tester.tap(find.byKey(AppKeys.themeModeOption('dark')));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeModeSetting.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tsundoku_theme_mode'), 'dark',
          reason: 'state だけ更新して永続化を忘れる眷属の型を撃つ');
    });
  });

  group('親探針: 再起動相当の復元', () {
    test('保存値が復元され、不正値は system にフォールバックする', () async {
      SharedPreferences.setMockInitialValues({'tsundoku_theme_mode': 'light'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(themeModeProvider.notifier).load();
      expect(container.read(themeModeProvider), ThemeModeSetting.light);

      SharedPreferences.setMockInitialValues({'tsundoku_theme_mode': 'solar'});
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      await container2.read(themeModeProvider.notifier).load();
      expect(container2.read(themeModeProvider), ThemeModeSetting.system);
    });
  });
}
