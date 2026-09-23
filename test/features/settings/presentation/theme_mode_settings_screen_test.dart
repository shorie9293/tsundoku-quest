import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/settings/data/theme_mode_provider.dart';
import 'package:tsundoku_quest/features/settings/domain/theme_mode_setting.dart';
import 'package:tsundoku_quest/features/settings/presentation/theme_mode_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ThemeModeSettingsScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows 3 RadioListTiles and selects システム by default',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(RadioListTile<ThemeModeSetting>), findsNWidgets(3));
    expect(find.text('ライト'), findsOneWidget);
    expect(find.text('ダーク'), findsOneWidget);
    expect(find.text('システム'), findsOneWidget);

    // 既定（system）が選択されている
    final radioSystem = tester.widget<RadioListTile<ThemeModeSetting>>(
      find.byKey(const Key('theme_mode_system')),
    );
    expect(radioSystem.groupValue, ThemeModeSetting.system);
  });

  testWidgets('tapping ダーク tile updates provider state to dark',
      (tester) async {
    await pumpScreen(tester);

    expect(container.read(themeModeProvider), ThemeModeSetting.system);

    await tester.tap(find.byKey(AppKeys.themeModeOption('dark')));
    await tester.pump();

    expect(container.read(themeModeProvider), ThemeModeSetting.dark);
    final radioDark = tester.widget<RadioListTile<ThemeModeSetting>>(
      find.byKey(const Key('theme_mode_dark')),
    );
    expect(radioDark.groupValue, ThemeModeSetting.dark);
  });

  testWidgets('tapping ライト tile updates provider state to light',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(AppKeys.themeModeOption('light')));
    await tester.pump();

    expect(container.read(themeModeProvider), ThemeModeSetting.light);
    // groupValue も追従する
    final radioLight = tester.widget<RadioListTile<ThemeModeSetting>>(
      find.byKey(const Key('theme_mode_light')),
    );
    expect(radioLight.groupValue, ThemeModeSetting.light);
  });

  testWidgets('each option tile exposes the expected AppKeys', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(AppKeys.themeModeOption('light')), findsOneWidget);
    expect(find.byKey(AppKeys.themeModeOption('dark')), findsOneWidget);
    expect(find.byKey(AppKeys.themeModeOption('system')), findsOneWidget);
  });
}
