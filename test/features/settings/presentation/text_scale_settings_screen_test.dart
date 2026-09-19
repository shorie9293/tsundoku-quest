import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/settings/data/text_scale_provider.dart';
import 'package:tsundoku_quest/features/settings/domain/text_scale_setting.dart';
import 'package:tsundoku_quest/features/settings/presentation/text_scale_settings_screen.dart';

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
        child: const MaterialApp(home: TextScaleSettingsScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows 3 RadioListTiles and selects 通常 by default',
      (tester) async {
    await pumpScreen(tester);

    final tiles = find.byType(RadioListTile<double>);
    expect(tiles, findsNWidgets(3));

    // 既定（1.0 = 通常）が選択されている
    final radioNormal =
        tester.widget<RadioListTile<double>>(find.byKey(const Key('text_scale_1.0')));
    expect(radioNormal.groupValue, 1.0);
  });

  testWidgets('tapping 大 tile updates provider state to 1.25',
      (tester) async {
    await pumpScreen(tester);

    expect(container.read(textScaleProvider), 1.0);

    await tester.tap(find.byKey(const Key('text_scale_1.25')));
    await tester.pump();

    expect(container.read(textScaleProvider), 1.25);
  });

  testWidgets('tapping 小 tile updates provider state to 0.9',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('text_scale_0.9')));
    await tester.pump();

    expect(container.read(textScaleProvider), 0.9);
    // groupValue も追従する
    final radioSmall =
        tester.widget<RadioListTile<double>>(find.byKey(const Key('text_scale_0.9')));
    expect(radioSmall.groupValue, 0.9);
  });

  testWidgets('presets cover all three scale values',
      (tester) async {
    await pumpScreen(tester);
    expect(TextScaleSetting.presets.map((p) => p.scale).toList(),
        [0.9, 1.0, 1.25]);
  });
}
