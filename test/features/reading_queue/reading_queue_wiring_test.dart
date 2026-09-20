/// 書庫導線 → /reading-queue ルート配線の試練
///
/// backup_route_test.dart の既存様式を踏襲。
/// Hive を一切開かないため、repository は InMemory へ差し替え
/// （Hive 未初期化の zone 汚染を回避）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/app_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_provider.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_repository.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget testApp() {
    return ProviderScope(
      overrides: [
        readingQueueRepositoryProvider
            .overrideWithValue(InMemoryReadingQueueRepository()),
      ],
      child: MaterialApp.router(
        theme: ThemeData.dark(),
        routerConfig: AppRouter.createRouter(isSignedIn: () => true),
      ),
    );
  }

  testWidgets('書庫 AppBar の導線ボタンで /reading-queue が開く', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(AppKeys.readingQueueButton), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.readingQueueButton));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(AppKeys.readingQueueScreen), findsOneWidget);
    expect(find.text('📖 次に読む'), findsOneWidget);
    expect(find.byKey(AppKeys.readingQueueEmpty), findsOneWidget);
  });
}
