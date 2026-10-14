/// 書庫導線 → /stagnant-books ルート配線の試練
///
/// reading_queue_wiring_test.dart の既存様式を踏襲。
/// Hive を一切開かないため、BookDataNotifier をインメモリで差し替え
/// （Hive 未初期化の zone 汚染を回避）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/app_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  UserBook testBook(String id, String title, BookStatus status,
          String createdAt) =>
      UserBook(
        id: id,
        userId: 'user-1',
        bookId: 'book-$id',
        book: Book(
          id: 'book-$id',
          title: title,
          authors: ['著者'],
          source: BookSource.manual,
          createdAt: createdAt,
        ),
        status: status,
        medium: BookMedium.physical,
        createdAt: createdAt,
      );

  Widget testApp() {
    final now = DateTime.now();
    final old =
        now.subtract(const Duration(days: 100)).toIso8601String();
    final recent =
        now.subtract(const Duration(days: 5)).toIso8601String();
    final notifier = BookDataNotifier();
    notifier.addUserBook(testBook('stagnant-1', '放置本A', BookStatus.tsundoku, old));
    notifier.addUserBook(
        testBook('fresh-1', '新しい本', BookStatus.tsundoku, recent));

    return ProviderScope(
      overrides: [
        bookDataProvider.overrideWith((ref) => notifier),
      ],
      child: MaterialApp.router(
        theme: ThemeData.dark(),
        routerConfig: AppRouter.createRouter(isSignedIn: () => true),
      ),
    );
  }

  testWidgets('書庫 AppBar の導線ボタンで /stagnant-books が開く', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(AppKeys.stagnantBooksButton), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.stagnantBooksButton));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(AppKeys.stagnantBooksScreen), findsOneWidget);
    expect(find.text('⏳ 積読放置'), findsOneWidget);
    // 100日放置の本は検出され、5日の本は対象外
    expect(find.byKey(AppKeys.stagnantBooksRow('stagnant-1')), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksRow('fresh-1')), findsNothing);
    expect(find.byKey(AppKeys.stagnantBooksEmpty), findsNothing);
  });
}
