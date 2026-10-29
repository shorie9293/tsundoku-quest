import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/settings/presentation/settings_hub_screen.dart';
import 'package:tsundoku_quest/features/settings/presentation/theme_mode_settings_screen.dart';

/// 設定ハブ — 散在する設定画面への導線を1画面に集約する（Kanban #181）
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 各遷移先をフェイクへ差し替えたハブを返す。
  /// 呼ばれたビルダーは [called] に記録する。
  ({Widget hub, Set<String> called}) buildHub() {
    final called = <String>{};
    Widget fake(String id) => Scaffold(
          appBar: AppBar(title: Text('FAKE:$id')),
          body: Center(child: Text('FAKE:$id')),
        );
    final hub = SettingsHubScreen(
      themeModeBuilder: (_) {
        called.add('theme_mode');
        return fake('theme_mode');
      },
      textScaleBuilder: (_) {
        called.add('text_scale');
        return fake('text_scale');
      },
      reduceMotionBuilder: (_) {
        called.add('reduce_motion');
        return fake('reduce_motion');
      },
      appLockBuilder: (_) {
        called.add('app_lock');
        return fake('app_lock');
      },
      reminderBuilder: (_) {
        called.add('reminder');
        return fake('reminder');
      },
      quietHoursBuilder: (_) {
        called.add('quiet_hours');
        return fake('quiet_hours');
      },
      backupBuilder: (_) {
        called.add('backup');
        return fake('backup');
      },
      autoBackupBuilder: (_) {
        called.add('auto_backup');
        return fake('auto_backup');
      },
      aboutBuilder: (_) {
        called.add('about');
        return fake('about');
      },
    );
    return (hub: hub, called: called);
  }

  Future<Set<String>> pumpHub(WidgetTester tester) async {
    final built = buildHub();
    await tester.pumpWidget(MaterialApp(home: built.hub));
    await tester.pumpAndSettle();
    return built.called;
  }

  testWidgets('全設定項目が表示される', (tester) async {
    await pumpHub(tester);

    expect(find.byKey(AppKeys.settingsHubScreen), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(9));

    const labels = <String>[
      'テーマ設定',
      '文字サイズ',
      '動きを減らす',
      'アプリロック',
      '読書リマインダー',
      '静穏時間（おやすみモード）',
      'バックアップ',
      '自動バックアップ',
      'アプリについて',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('テーマ設定タップでテーマビルダーが呼ばれる', (tester) async {
    final called = await pumpHub(tester);

    await tester.tap(find.byKey(AppKeys.settingsHubItem('theme_mode')));
    await tester.pumpAndSettle();

    expect(called, contains('theme_mode'));
    expect(find.text('FAKE:theme_mode'), findsWidgets);
  });

  testWidgets('文字サイズ・動きを減らす・アプリロックの各ビルダーが呼ばれる', (tester) async {
    final called = await pumpHub(tester);

    for (final id in ['text_scale', 'reduce_motion', 'app_lock']) {
      await tester.tap(find.byKey(AppKeys.settingsHubItem(id)));
      await tester.pumpAndSettle();
      expect(find.text('FAKE:$id'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(called, containsAll(['text_scale', 'reduce_motion', 'app_lock']));
  });

  testWidgets('リマインダー・静穏時間のビルダーが呼ばれる', (tester) async {
    final called = await pumpHub(tester);

    for (final id in ['reminder', 'quiet_hours']) {
      await tester.tap(find.byKey(AppKeys.settingsHubItem(id)));
      await tester.pumpAndSettle();
      expect(find.text('FAKE:$id'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(called, containsAll(['reminder', 'quiet_hours']));
  });

  testWidgets('バックアップ・アプリについてのビルダーが呼ばれる', (tester) async {
    final called = await pumpHub(tester);

    for (final id in ['backup', 'auto_backup', 'about']) {
      await tester.tap(find.byKey(AppKeys.settingsHubItem(id)));
      await tester.pumpAndSettle();
      expect(find.text('FAKE:$id'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(called, containsAll(['backup', 'auto_backup', 'about']));
  });

  testWidgets('遷移先から戻るとハブが再表示される', (tester) async {
    await pumpHub(tester);

    await tester.tap(find.byKey(AppKeys.settingsHubItem('theme_mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.settingsHubScreen), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.settingsHubScreen), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(9));
  });

  testWidgets('テーマ設定画面の導線から設定ハブへ到達できる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ThemeModeSettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(AppKeys.settingsHubEntry),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(AppKeys.settingsHubEntry));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.settingsHubScreen), findsOneWidget);
    expect(find.text('バックアップ'), findsOneWidget);
  });
}
