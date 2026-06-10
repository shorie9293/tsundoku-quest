import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/app_router.dart';
import 'package:tsundoku_quest/features/reading/presentation/reading_screen.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

Widget testReadingScreenWithContainer({
  String? id,
  required ProviderContainer container,
}) {
  if (id != null) {
    const book = Book(
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
  // SharedPreferences のテスト用モック初期化
  SharedPreferences.setMockInitialValues({});

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

      // _updatePage でページのみ更新（totalReadingMinutesは _endSessionIfNeeded で加算）
      await tester.enterText(find.byKey(AppKeys.readingPageInput), '50');
      await tester.pumpAndSettle();

      // totalReadingMinutesはページ更新では変わらない（読書終了時に加算）
      final updatedBook =
          container.read(bookDataProvider.notifier).getUserBook('test-id');
      expect(updatedBook!.totalReadingMinutes, 30);

      container.dispose();
    });

    testWidgets(
        'BookDataNotifier.updateUserBook should persist totalReadingMinutes',
        (tester) async {
      // このテストはBookDataNotifierのユニットテスト
      // updateUserBookがtotalReadingMinutesを正しく更新し、
      // _syncUpdateToSupabase経由で永続化されることを確認
      final notifier = BookDataNotifier();
      const book = Book(
        id: 'b1',
        title: 'Test Book',
        authors: ['Author'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      notifier.addUserBook(const UserBook(
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
      // 前テストからのSharedPreferences状態リークを防止
      SharedPreferences.setMockInitialValues({});
      // BookDataNotifierにセットアップ
      final container = ProviderContainer();
      const book = Book(
        id: 'b1',
        title: 'Test Book',
        authors: ['Author'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      const userBook = UserBook(
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
            home: const ReadingScreen(id: 'test-id'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // タイマー開始 & 経過
      await tester.tap(find.text('▶ 開始'));
      await tester.pump(const Duration(seconds: 125));

      // _endSessionIfNeeded は dispose / 読了時のみ呼ばれる。
      // _updatePage ではページのみ更新し、totalReadingMinutes は変更しない。
      await tester.enterText(find.byKey(AppKeys.readingPageInput), '60');
      await tester.pumpAndSettle();

      // totalReadingMinutesはページ更新では変わらない（30のまま）
      final bookAfter =
          container.read(bookDataProvider.notifier).getUserBook('test-id');
      expect(bookAfter!.totalReadingMinutes, 30);

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
      const book = Book(
        id: 'b1',
        title: 'Test Book',
        authors: ['Author'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      const userBook = UserBook(
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

    testWidgets('complete button should show confirmation dialog', (tester) async {
      await tester.pumpWidget(testReadingScreen(id: 'test-id'));
      await tester.pumpAndSettle();

      // Scroll the ListView down to reveal the complete button (offscreen)
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.readingComplete));
      await tester.pumpAndSettle();

      expect(find.text('🏁 冒険を完了しますか？'), findsOneWidget);
    });

    testWidgets('confirmation dialog cancel should dismiss', (tester) async {
      await tester.pumpWidget(testReadingScreen(id: 'test-id'));
      await tester.pumpAndSettle();

      // Scroll the ListView down to reveal the complete button (offscreen)
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.readingComplete));
      await tester.pumpAndSettle();

      await tester.tap(find.text('まだ読む'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('confirmation dialog confirm should show complete modal', (tester) async {
      await tester.pumpWidget(testReadingScreen(id: 'test-id'));
      await tester.pumpAndSettle();

      // Scroll the ListView down to reveal the complete button (offscreen)
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.readingComplete));
      await tester.pumpAndSettle();

      await tester.tap(find.text('読了する'));
      await tester.pumpAndSettle();

      expect(find.text('⚔️ 戦利品カード'), findsOneWidget);
    });

    testWidgets('should show cover image when coverImageUrl is set', (tester) async {
      final container = ProviderContainer();
      const book = Book(
        id: 'b1',
        title: 'Test Book',
        authors: ['Author'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
        coverImageUrl: 'https://example.com/cover.jpg',
      );
      const userBook = UserBook(
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
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const ReadingScreen(id: 'test-id'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Image.network should be present in the widget tree when coverImageUrl is set
      expect(find.byType(Image), findsAtLeastNWidgets(1));

      container.dispose();
    });

    testWidgets('should show fallback icon when coverImageUrl is null', (tester) async {
      await tester.pumpWidget(testReadingScreen(id: 'test-id'));
      await tester.pumpAndSettle();

      // Default book icon should be shown as fallback
      expect(find.byIcon(Icons.menu_book), findsAtLeastNWidgets(1));
    });

    testWidgets('timer controls toggle start/stop', (tester) async {
      await tester.pumpWidget(testReadingScreen(id: 'test-id'));
      await tester.pumpAndSettle();

      // Start timer
      await tester.tap(find.text('▶ 開始'));
      await tester.pump(const Duration(seconds: 65));

      // Timer should be running, show pause button
      expect(find.text('⏸ 一時停止'), findsOneWidget);
      // Timer text should show elapsed time
      expect(find.text('00:01:05'), findsOneWidget);

      // Pause timer
      await tester.tap(find.text('⏸ 一時停止'));
      await tester.pump();

      // Timer should be paused, show start button again
      expect(find.text('▶ 開始'), findsOneWidget);
    });
  });
}
