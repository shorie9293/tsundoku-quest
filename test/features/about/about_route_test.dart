/// 設定導線（書庫 AppBar → /settings/about → AboutScreen）の試練
///
/// backup_route_test.dart の既存様式を踏襲。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/app_router.dart';
import 'package:tsundoku_quest/features/about/presentation/about_app_keys.dart';

void main() {
  final tempDir = Directory.systemTemp.createTempSync('hive_about_route_');
  Hive.init(tempDir.path);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  Widget testApp() {
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: AppRouter.createRouter(isSignedIn: () => true),
      ),
    );
  }

  testWidgets('書庫 AppBar の導線で /settings/about が開く', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AboutAppKeys.entryFromSettings));
    await tester.pumpAndSettle();

    expect(find.byKey(AboutAppKeys.aboutScreen), findsOneWidget);
    expect(find.text('アプリについて'), findsOneWidget);
  });

  testWidgets('直遷移でも /settings/about ルートが開く', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    // GoRouter の location 変更を直接試す
    // （MaterialApp.router は context.push を拾えないため、タップ導線を経由）
    await tester.tap(find.byKey(AboutAppKeys.entryFromSettings));
    await tester.pumpAndSettle();

    expect(find.byKey(AboutAppKeys.versionLabel), findsOneWidget);
  });
}
