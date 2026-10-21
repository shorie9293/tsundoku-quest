import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/settings/data/reduce_motion_provider.dart';
import 'package:tsundoku_quest/features/settings/data/reduce_motion_repository.dart';
import 'package:tsundoku_quest/features/settings/domain/reduce_motion_setting.dart';
import 'package:tsundoku_quest/features/settings/presentation/reduce_motion_settings_screen.dart';

Key _optionKey(ReduceMotionSetting setting) =>
    ValueKey('reduce_motion_option_${setting.storageKey}');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('3つの選択肢と説明カードを描画する', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ReduceMotionSettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(RadioListTile<ReduceMotionSetting>), findsNWidgets(3));
    expect(find.text('システムに従う'), findsOneWidget);
    expect(find.text('動きを有効'), findsOneWidget);
    expect(find.text('動きを減らす'), findsOneWidget);
    // WCAG 2.3.3 配慮の説明カード
    expect(find.textContaining('WCAG'), findsOneWidget);

    for (final setting in ReduceMotionSetting.values) {
      expect(find.byKey(_optionKey(setting)), findsOneWidget);
    }
  });

  testWidgets('Provider 経由のタップで state が更新される', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReduceMotionSettingsScreen()),
      ),
    );
    await tester.pump();

    expect(container.read(reduceMotionProvider), ReduceMotionSetting.system);

    await tester.tap(find.byKey(_optionKey(ReduceMotionSetting.on)));
    await tester.pump();

    expect(container.read(reduceMotionProvider), ReduceMotionSetting.on);
  });

  testWidgets('注入した repository に保存が到達する（Provider 無しで動作）',
      (tester) async {
    final repository = InMemoryReduceMotionRepository();

    await tester.pumpWidget(
      MaterialApp(home: ReduceMotionSettingsScreen(repository: repository)),
    );
    await tester.pump();

    expect(find.byType(RadioListTile<ReduceMotionSetting>), findsNWidgets(3));

    await tester.tap(find.byKey(_optionKey(ReduceMotionSetting.off)));
    await tester.pump();
    await tester.pump();

    expect(repository.saveCount, 1);
    expect(repository.saved, ReduceMotionSetting.off);
  });

  testWidgets('注入 repository は保存済みの値を初期選択として読み込む', (tester) async {
    final repository = InMemoryReduceMotionRepository();
    await repository.saveReduceMotion(ReduceMotionSetting.on);

    await tester.pumpWidget(
      MaterialApp(home: ReduceMotionSettingsScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump();

    final group = tester.widget<RadioGroup<ReduceMotionSetting>>(
      find.byType(RadioGroup<ReduceMotionSetting>),
    );
    expect(group.groupValue, ReduceMotionSetting.on);
  });
}
