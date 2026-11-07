import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/book_card.dart';
import 'package:tsundoku_quest/features/shelves/data/shelf_controller.dart';
import 'package:tsundoku_quest/features/undo/presentation/undo_snack_bar.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

Book _book(String id) => Book(
      id: 'book-$id',
      title: 'テスト本 $id',
      authors: const ['著者'],
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    );

UserBook _userBook(String id, BookStatus status) => UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      book: _book(id),
      status: status,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

/// 3冊（すべて積読）を積んだ notifier を作る。
BookDataNotifier _seededNotifier() {
  final notifier = BookDataNotifier();
  for (final id in ['ub-1', 'ub-2', 'ub-3']) {
    notifier.addUserBook(_userBook(id, BookStatus.tsundoku));
  }
  return notifier;
}

Widget _app({
  required BookDataNotifier books,
  required ShelfController shelves,
  GoRouter? router,
}) {
  final overrides = [
    bookDataProvider.overrideWith((ref) => books),
    shelfControllerProvider.overrideWith((ref) => shelves),
  ];
  if (router != null) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: ThemeData.dark(),
        routerConfig: router,
      ),
    );
  }
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const BookshelfScreen(),
    ),
  );
}

/// 指定した蔵書の BookCard を指す（おすすめカード等の同名テキストと区別する）。
Finder _card(String id) =>
    find.byWidgetPredicate((w) => w is BookCard && w.book.id == id);

/// 全カードが一画面に収まる縦長ビューポートにしてから描画を落ち着かせる。
///
/// スクロール位置に依存すると DailyQuest の非同期読み込みで高さが変わり
/// タップ座標がずれるため、最初から全冊が見える大きさにする。
Future<void> _revealBooks(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('hive_bulk_ui_').path);
  });
  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('本カードの長押しで選択モードに入る', (tester) async {
    final books = _seededNotifier();
    final shelves = ShelfController(InMemoryShelfRepository());

    await tester.pumpWidget(_app(books: books, shelves: shelves));
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();

    expect(find.text('1冊選択'), findsOneWidget);
    expect(find.byKey(AppKeys.bulkSelectionBar), findsOneWidget);
    expect(find.byKey(AppKeys.bookCardCheckbox('ub-1')), findsOneWidget);
    // 通常モードの AppBar アイコンは選択モードでは出ない
    expect(find.byKey(AppKeys.librarySearchButton), findsNothing);
  });

  testWidgets('選択モード中のタップでトグルし件数表示が変わる', (tester) async {
    final books = _seededNotifier();
    final shelves = ShelfController(InMemoryShelfRepository());

    await tester.pumpWidget(_app(books: books, shelves: shelves));
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();
    expect(find.text('1冊選択'), findsOneWidget);

    await tester.tap(_card('ub-2'));
    await tester.pumpAndSettle();
    expect(find.text('2冊選択'), findsOneWidget);

    await tester.tap(_card('ub-2'));
    await tester.pumpAndSettle();
    expect(find.text('1冊選択'), findsOneWidget);
  });

  testWidgets('全選択で全冊が選択される', (tester) async {
    final books = _seededNotifier();
    final shelves = ShelfController(InMemoryShelfRepository());

    await tester.pumpWidget(_app(books: books, shelves: shelves));
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.bulkSelectAllButton));
    await tester.pumpAndSettle();

    expect(find.text('3冊選択'), findsOneWidget);
  });

  testWidgets('閉じると通常モードに戻り、タップで読書画面へ遷移できる', (tester) async {
    final books = _seededNotifier();
    final shelves = ShelfController(InMemoryShelfRepository());
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const BookshelfScreen()),
        GoRoute(
          path: '/reading',
          builder: (_, __) => const Scaffold(body: Center(child: Text('読書画面'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(books: books, shelves: shelves, router: router),
    );
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.bulkSelectionBar), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.bulkClearSelectionButton));
    await tester.pumpAndSettle();

    expect(find.text('📚 書庫'), findsOneWidget);
    expect(find.byKey(AppKeys.bulkSelectionBar), findsNothing);
    expect(find.byKey(AppKeys.librarySearchButton), findsOneWidget);

    // 通常モードのタップ＝読書画面遷移が復活している
    await tester.tap(_card('ub-1'));
    await tester.pumpAndSettle();
    expect(find.text('読書画面'), findsOneWidget);
  });

  testWidgets('選択0件のときは操作バーを出さない', (tester) async {
    final books = _seededNotifier();
    final shelves = ShelfController(InMemoryShelfRepository());

    await tester.pumpWidget(_app(books: books, shelves: shelves));
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.bulkSelectionBar), findsOneWidget);

    // 同じ本をもう一度タップして選択解除
    await tester.tap(_card('ub-1'));
    await tester.pumpAndSettle();

    expect(find.text('0冊選択'), findsOneWidget);
    expect(find.byKey(AppKeys.bulkSelectionBar), findsNothing);
  });

  testWidgets('一括削除は確認後に選択した本だけを消す', (tester) async {
    final books = _seededNotifier();
    final shelves = ShelfController(InMemoryShelfRepository());

    await tester.pumpWidget(_app(books: books, shelves: shelves));
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();
    await tester.tap(_card('ub-3'));
    await tester.pumpAndSettle();
    expect(find.text('2冊選択'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.bulkDeleteButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.confirmDialog), findsOneWidget);
    expect(find.text('選択した本を削除しますか？'), findsOneWidget);

    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();

    expect(
      books.state.userBooks.map((b) => b.id).toList(),
      ['ub-2'],
    );
    expect(find.byKey(AppKeys.bulkSelectionBar), findsNothing);
  });

  testWidgets('Undo で削除した全冊が元の順序で戻る', (tester) async {
    final books = _seededNotifier();
    final shelves = ShelfController(InMemoryShelfRepository());

    await tester.pumpWidget(_app(books: books, shelves: shelves));
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();
    await tester.tap(_card('ub-3'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.bulkDeleteButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();

    expect(books.state.userBooks.map((b) => b.id).toList(), ['ub-2']);

    await tester.tap(find.byKey(undoActionKey));
    await tester.pumpAndSettle();

    expect(
      books.state.userBooks.map((b) => b.id).toList(),
      ['ub-1', 'ub-2', 'ub-3'],
    );
  });

  testWidgets('棚へ移動で選択分が ShelfController に追加される', (tester) async {
    final books = _seededNotifier();
    final repo = InMemoryShelfRepository();
    final shelf = await repo.createShelf('棚A');
    final shelves = ShelfController(repo);

    await tester.pumpWidget(_app(books: books, shelves: shelves));
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();
    await tester.tap(_card('ub-2'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.bulkMoveToShelfButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.bulkShelfPicker), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.bulkShelfOption(shelf.id)));
    await tester.pumpAndSettle();

    final moved = shelves.state.firstWhere((s) => s.id == shelf.id);
    expect(moved.userBookIds, ['ub-1', 'ub-2']);
    expect(find.text('2冊を「棚A」へ移動しました'), findsOneWidget);
    expect(find.byKey(AppKeys.bulkSelectionBar), findsNothing);
  });

  testWidgets('棚が空のときは案内を表示する', (tester) async {
    final books = _seededNotifier();
    final shelves = ShelfController(InMemoryShelfRepository());

    await tester.pumpWidget(_app(books: books, shelves: shelves));
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.bulkMoveToShelfButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.bulkShelfPicker), findsOneWidget);
    expect(find.byKey(AppKeys.bulkShelfEmpty), findsOneWidget);
    expect(find.text('棚がありません'), findsOneWidget);
  });

  testWidgets('通常モードの既存挙動（AppBar とスワイプ削除）は不変', (tester) async {
    final books = _seededNotifier();
    final shelves = ShelfController(InMemoryShelfRepository());

    await tester.pumpWidget(_app(books: books, shelves: shelves));
    await _revealBooks(tester);

    expect(find.text('📚 書庫'), findsOneWidget);
    expect(find.byKey(AppKeys.librarySearchButton), findsOneWidget);
    expect(find.byKey(AppKeys.readingQueueButton), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksButton), findsOneWidget);
    expect(find.byKey(AppKeys.reminderSettingsButton), findsOneWidget);
    expect(find.byKey(AppKeys.textScaleSettingsButton), findsOneWidget);
    expect(find.byKey(AppKeys.themeModeEntry), findsOneWidget);
    expect(find.byKey(AppKeys.reduceMotionEntry), findsOneWidget);
    expect(find.byKey(AppKeys.appLockSettingsButton), findsOneWidget);
    expect(find.byKey(AppKeys.backupSettingsButton), findsOneWidget);
    expect(find.byKey(AppKeys.bulkSelectionBar), findsNothing);

    // スワイプ削除の確認ダイアログは従来どおり出る
    await tester.drag(_card('ub-1'), const Offset(-900, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.confirmDialog), findsOneWidget);
    expect(find.text('本を削除しますか？'), findsOneWidget);
  });

  testWidgets('BookCard は selected 指定でチェックアイコンを表示する', (tester) async {
    final userBook = _userBook('ub-1', BookStatus.tsundoku);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: BookCard(
          book: userBook,
          onTap: () {},
          onEdit: () {},
          selectionMode: true,
          selected: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.bookCardCheckbox('ub-1')), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
