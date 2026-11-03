import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/help/presentation/help_screen.dart';
import 'package:tsundoku_quest/features/settings/presentation/settings_hub_screen.dart';

/// 設定ハブの「遊び方・ヘルプ」導線（1本だけ追加・既存項目は不変）。
void main() {
  /// 既存項目の宣言順（accountDeletionBuilder 未指定時の並び）。
  const existingIds = <String>[
    'crash_log',
    'theme_mode',
    'text_scale',
    'reduce_motion',
    'app_lock',
    'reminder',
    'quiet_hours',
    'backup',
    'auto_backup',
    'about',
  ];

  Widget fake(String id) => Scaffold(
        appBar: AppBar(title: Text('FAKE:$id')),
        body: Center(child: Text('FAKE:$id')),
      );

  /// 11項目が同時に描画されるよう縦長の面で描く（ListView は遅延構築のため）。
  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsHubScreen(
          themeModeBuilder: (_) => fake('theme_mode'),
          textScaleBuilder: (_) => fake('text_scale'),
          reduceMotionBuilder: (_) => fake('reduce_motion'),
          appLockBuilder: (_) => fake('app_lock'),
          reminderBuilder: (_) => fake('reminder'),
          quietHoursBuilder: (_) => fake('quiet_hours'),
          backupBuilder: (_) => fake('backup'),
          autoBackupBuilder: (_) => fake('auto_backup'),
          aboutBuilder: (_) => fake('about'),
          crashLogBuilder: (_) => fake('crash_log'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<Key> hubItemKeys(WidgetTester tester) => [
        for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
          if (tile.key case final key?) key,
      ];

  testWidgets('「遊び方・ヘルプ」項目が1つだけ表示される', (tester) async {
    await pumpHub(tester);

    expect(find.byKey(AppKeys.settingsHubItem('help')), findsOneWidget);
    expect(find.text('遊び方・ヘルプ'), findsOneWidget);
  });

  testWidgets('既存項目の数と順序は変わらない', (tester) async {
    await pumpHub(tester);

    expect(hubItemKeys(tester), [
      for (final id in existingIds) AppKeys.settingsHubItem(id),
      AppKeys.settingsHubItem('help'),
    ]);
    expect(find.byType(ListTile), findsNWidgets(existingIds.length + 1));
  });

  testWidgets('タップで HelpScreen へ遷移する', (tester) async {
    await pumpHub(tester);

    await tester.tap(find.byKey(AppKeys.settingsHubItem('help')));
    await tester.pumpAndSettle();

    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.byKey(AppKeys.helpScreen), findsOneWidget);
    expect(find.byKey(AppKeys.helpSearchField), findsOneWidget);
  });
}
