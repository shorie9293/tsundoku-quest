/// /settings/backup ルート配線の試練
///
/// 道標 #69 / Kanban t_4d1829a9
/// app_router_test.dart の既存様式を踏襲。
/// Hive アダプタ未登録のため collect は例外を飲んで
/// 「読み込み中…」に落ちる設計（画面はクラッシュしない）。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/app_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/backup/presentation/backup_keys.dart';

void main() {
  final tempDir = Directory.systemTemp.createTempSync('hive_backup_route_');
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

  testWidgets('書庫 AppBar の導線で /settings/backup が開く', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.backupSettingsButton));
    await tester.pumpAndSettle();

    expect(find.text('バックアップ'), findsOneWidget);
    expect(find.byKey(BackupKeys.exportJsonButton), findsOneWidget);
    expect(find.byKey(BackupKeys.importButton), findsOneWidget);
  });
}
