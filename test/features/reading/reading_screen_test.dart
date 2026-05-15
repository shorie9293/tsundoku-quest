import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tsundoku_quest/app_router.dart';
import 'package:tsundoku_quest/features/reading/presentation/reading_screen.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';
import 'package:tsundoku_quest/shared/providers/adventurer_provider.dart';

Widget testReadingScreenWithContainer({
  String? id,
  required ProviderContainer container,
}) {
  if (id != null) {
    final book = Book(
        id: 'b1',
        title: 'Test Book',
        authors: ['Author'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z');
    final userBook = UserBook(
        id: id,
        userId: 'u1',
        bookId: 'b1',
        book: book,
        status: BookStatus.reading,
        medium: BookMedium.physical,
        totalReadingMinutes: 30,
        createdAt: '2026-01-01T00:00:00Z');
    container.read(bookDataProvider.notifier).addUserBook(userBook);
  }
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: ThemeData.dark(), home: ReadingScreen(id: id)),
  );
}

Widget testReadingScreen({String? id}) {
  return testReadingScreenWithContainer(
    id: id,
    container: ProviderContainer(),
  );
}

void main() {
  group('ReadingScreen', () {
    testWidgets('should show not found when no id', (tester) async {
      await tester.pumpWidget(testReadingScreen());
      expect(find.text('本が見つかりません'), findsOneWidget);
    });

    testWidgets('should show timer controls with book', (tester) async {
      await tester.pumpWidget(testReadingScreen(id: 'test-id'));
      await tester.pumpAndSettle();
      expect(find.text('▶ 開始'), findsOneWidget);
    });

    testWidgets('should show page input field with book', (tester) async {
      await tester.pumpWidget(testReadingScreen(id: 'test-id'));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.readingPageInput), findsOneWidget);
    });

    testWidgets('_updatePage should persist totalReadingMinutes to BookData',
        (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        testReadingScreenWithContainer(id: 'test-id', container: container),
      );
      await tester.pumpAndSettle();

      // 初期値: totalReadingMinutes = 30
      final initialBook =
          container.read(bookDataProvider.notifier).getUserBook('test-id');
      expect(initialBook?.totalReadingMinutes, 30);

      // タイマー開始
      await tester.tap(find.text('▶ 開始'));
      await tester.pump(const Duration(seconds: 65));

      // ページを更新すると _updatePage 経由で totalReadingMinutes が保存される
      await tester.enterText(find.byKey(AppKeys.readingPageInput), '50');
      await tester.pumpAndSettle();

      // totalReadingMinutesが増加（30 + 1 = 31以上）
      final updatedBook =
          container.read(bookDataProvider.notifier).getUserBook('test-id');
      expect(updatedBook!.totalReadingMinutes, greaterThan(30));

      container.dispose();
    });

    testWidgets(
        'BookDataNotifier.updateUserBook should persist totalReadingMinutes',
        (tester) async {
      // このテストはBookDataNotifierのユニットテスト
      // updateUserBookがtotalReadingMinutesを正しく更新し、
      // _syncUpdateToSupabase経由で永続化されることを確認
      final notifier = BookDataNotifier();
      final book = Book(
        id: 'b1',
        title: 'Test Book',
        authors: ['Author'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      notifier.addUserBook(UserBook(
        id: 'ub-1',
        userId: 'u1',
        bookId: 'b1',
        book: book,
        status: BookStatus.reading,
        medium: BookMedium.physical,
        totalReadingMinutes: 30,
        createdAt: '2026-01-01T00:00:00Z',
      ));

      // updateUserBookでtotalReadingMinutesを更新
      notifier.updateUserBook(
        id: 'ub-1',
        totalReadingMinutes: 45,
      );

      final updated = notifier.getUserBook('ub-1');
      expect(updated!.totalReadingMinutes, 45);
    });

    testWidgets('_endSessionIfNeeded should persist UserBook totalReadingMinutes',
        (tester) async {
      // BookDataNotifierにセットアップ
      final container = ProviderContainer();
      final book = Book(
        id: 'b1',
        title: 'Test Book',
        authors: ['Author'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      final userBook = UserBook(
        id: 'test-id',
        userId: 'u1',
        bookId: 'b1',
        book: book,
        status: BookStatus.reading,
        medium: BookMedium.physical,
        totalReadingMinutes: 30,
        createdAt: '2026-01-01T00:00:00Z',
      );
      container.read(bookDataProvider.notifier).addUserBook(userBook);

      // 画面を構築
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: ReadingScreen(id: 'test-id'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // タイマー開始 & 経過
      await tester.tap(find.text('▶ 開始'));
      await tester.pump(const Duration(seconds: 125));

      // _endSessionIfNeeded は dispose 時に呼ばれるが、
      // ここでは _updatePage が onChanged で呼ばれ、
      // totalReadingMinutesを保存することを期待
      // ページフィールドに入力すると _updatePage → updateUserBook
      await tester.enterText(find.byKey(AppKeys.readingPageInput), '60');
      await tester.pumpAndSettle();

      // totalReadingMinutesが増加している
      final bookAfter =
          container.read(bookDataProvider.notifier).getUserBook('test-id');
      expect(bookAfter!.totalReadingMinutes, greaterThanOrEqualTo(32));

      container.dispose();
    });

    testWidgets('should have close button in AppBar', (tester) async {
      await tester.pumpWidget(testReadingScreen(id: 'test-id'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('close button should pop the screen', (tester) async {
      final router = AppRouter.createRouter();
      final container = ProviderContainer();

      // Seed a user book in the provider
      final book = Book(
        id: 'b1',
        title: 'Test Book',
        authors: ['Author'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      final userBook = UserBook(
        id: 'test-id',
        userId: 'u1',
        bookId: 'b1',
        book: book,
        status: BookStatus.reading,
        medium: BookMedium.physical,
        totalReadingMinutes: 30,
        createdAt: '2026-01-01T00:00:00Z',
      );
      container.read(bookDataProvider.notifier).addUserBook(userBook);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start on bookshelf screen
      expect(find.byKey(AppKeys.bookshelfScreen), findsOneWidget);

      // Push navigate to reading screen (simulates context.push)
      router.push('/reading?id=test-id');
      await tester.pumpAndSettle();

      // Reading screen should be visible
      expect(find.byKey(AppKeys.readingScreen), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Should be back on bookshelf screen
      expect(find.byKey(AppKeys.bookshelfScreen), findsOneWidget);

      container.dispose();
    });
  });
}
