// 親探針（イシコリドメ）: 一括操作の「合成」不変条件を撃つ。
//
// 子の試練は個別操作しか撃たないため、以下は親が独立に固定する:
//  P1: Undo は削除した冊を「元の位置」へ戻す（末尾追加になっていない）
//  P2: 全選択→削除→Undo でも元の並び順が完全に戻る
//  P3: 既に棚に入っている本を再度「棚へ移動」しても重複しない
//  P4: addUserBook の index 指定は範囲外をクランプする
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      title: '探針本 $id',
      authors: const ['著者'],
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    );

UserBook _userBook(String id) => UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      book: _book(id),
      status: BookStatus.tsundoku,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

BookDataNotifier _seededNotifier() {
  final notifier = BookDataNotifier();
  for (final id in ['ub-1', 'ub-2', 'ub-3', 'ub-4']) {
    notifier.addUserBook(_userBook(id));
  }
  return notifier;
}

Widget _app({required BookDataNotifier books, required ShelfController shelves}) {
  return ProviderScope(
    overrides: [
      bookDataProvider.overrideWith((ref) => books),
      shelfControllerProvider.overrideWith((ref) => shelves),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const BookshelfScreen(),
    ),
  );
}

Finder _card(String id) =>
    find.byWidgetPredicate((w) => w is BookCard && w.book.id == id);

Future<void> _revealBooks(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('hive_bulk_probe_').path);
  });
  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('P1: Undo は削除した冊を元の位置へ戻す', (tester) async {
    final books = _seededNotifier();
    final shelves = ShelfController(InMemoryShelfRepository());
    final before = books.state.userBooks.map((b) => b.id).toList();

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

    expect(books.state.userBooks.map((b) => b.id).toList(), ['ub-2', 'ub-4']);

    await tester.tap(find.byKey(undoActionKey));
    await tester.pumpAndSettle();

    expect(books.state.userBooks.map((b) => b.id).toList(), before);
  });

  testWidgets('P2: 全選択→削除→Undo で元の並び順が完全に戻る', (tester) async {
    final books = _seededNotifier();
    final shelves = ShelfController(InMemoryShelfRepository());
    final before = books.state.userBooks.map((b) => b.id).toList();

    await tester.pumpWidget(_app(books: books, shelves: shelves));
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.bulkSelectAllButton));
    await tester.pumpAndSettle();
    expect(find.text('4冊選択'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.bulkDeleteButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(books.state.userBooks, isEmpty);

    await tester.tap(find.byKey(undoActionKey));
    await tester.pumpAndSettle();
    expect(books.state.userBooks.map((b) => b.id).toList(), before);
  });

  testWidgets('P3: 既に棚にある本を再度移動しても重複しない', (tester) async {
    final books = _seededNotifier();
    final repo = InMemoryShelfRepository();
    final shelf = await repo.createShelf('棚A');
    await repo.addBookToShelf(shelf.id, 'ub-1');
    final shelves = ShelfController(repo);
    await shelves.load();

    await tester.pumpWidget(_app(books: books, shelves: shelves));
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();
    await tester.tap(_card('ub-2'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.bulkMoveToShelfButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.bulkShelfOption(shelf.id)));
    await tester.pumpAndSettle();

    final moved = shelves.state.firstWhere((s) => s.id == shelf.id);
    expect(moved.userBookIds.where((id) => id == 'ub-1').length, 1);
    expect(moved.userBookIds.contains('ub-2'), isTrue);
  });

  testWidgets('P4: addUserBook の index は範囲外をクランプする', (tester) async {
    final books = BookDataNotifier();
    books.addUserBook(_userBook('a'));
    books.addUserBook(_userBook('b'));
    books.addUserBook(_userBook('x'), index: 99);
    expect(books.state.userBooks.map((b) => b.id).toList(), ['a', 'b', 'x']);

    books.addUserBook(_userBook('y'), index: -5);
    expect(books.state.userBooks.map((b) => b.id).toList(), ['y', 'a', 'b', 'x']);

    // 既存 ID は index 指定でも「置換」（順序を動かさない）
    books.addUserBook(_userBook('a'), index: 3);
    expect(books.state.userBooks.map((b) => b.id).toList(), ['y', 'a', 'b', 'x']);
  });
}
