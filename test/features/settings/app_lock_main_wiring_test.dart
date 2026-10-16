import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/main.dart';

/// main.dart 配線試練:
/// 1) builder が AppLockGate で全画面を包んでいるか（実挙動で検証）
/// 2) 設定導線（router・書庫画面）がソース上で存在するか
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('builder 経由の配線: ロック無効なら子が表示される', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        builder: buildWithAppLockGate,
        home: Scaffold(
          key: Key('wired_home'),
          body: Text('ROUTER_CHILD'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ROUTER_CHILD'), findsOneWidget);
  });

  testWidgets('builder 経由の配線: ロック有効なら子が隠れロック画面になる', (tester) async {
    SharedPreferences.setMockInitialValues({
      'app_lock.enabled': true,
      'app_lock.method': 'passcode',
      'app_lock.passcode_hash':
          'x', // 実際の照合は fail 閉じだが、隠れことの検証には十分
    });
    await tester.pumpWidget(
      const MaterialApp(
        builder: buildWithAppLockGate,
        home: Scaffold(
          key: Key('wired_home'),
          body: Text('ROUTER_CHILD'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ROUTER_CHILD'), findsNothing);
    expect(find.byKey(AppKeys.appLockLockedMessage), findsOneWidget);
  });

  test('設定導線: router に /settings/app-lock が登録されている', () {
    final router = File('lib/app_router.dart').readAsStringSync();
    expect(router.contains("path: '/settings/app-lock'"), isTrue);
    expect(router.contains('AppLockSettingsScreen'), isTrue);
  });

  test('設定導線: 書庫画面からアプリロックへ遷移する導線がある', () {
    final bookshelf =
        File('lib/features/bookshelf/presentation/bookshelf_screen.dart')
            .readAsStringSync();
    expect(bookshelf.contains('AppKeys.appLockSettingsButton'), isTrue);
    expect(bookshelf.contains("context.push('/settings/app-lock')"), isTrue);
  });
}
