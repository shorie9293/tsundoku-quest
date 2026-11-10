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
import 'package:tsundoku_quest/features/bookshelf/data/book_restore_service.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_restore_plan.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/book_card.dart';
import 'package:tsundoku_quest/features/shelves/data/shelf_controller.dart';
import 'package:tsundoku_quest/features/undo/presentation/undo_snack_bar.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

UserBook _userBook(String id) => UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      book: Book(
        id: 'book-$id',
        title: 'テスト本 $id',
        authors: const ['著者'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      ),
      status: BookStatus.tsundoku,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

Finder _card(String id) =>
    find.byWidgetPredicate((w) => w is BookCard && w.book.id == id);

Future<void> _revealBooks(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('hive_bulk_undo_').path);
  });
  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('既存の一括削除 Undo は意味論不変（元の順序で全冊戻る）', (tester) async {
    final restoreObserved = <BookRestoreStep>[];
    final restoreService = BookRestoreService(onStep: restoreObserved.add);
    final notifier = BookDataNotifier(
      null,
      null,
      null,
      null,
      null,
      null,
      restoreService,
    );
    for (final id in ['ub-1', 'ub-2', 'ub-3']) {
      notifier.addUserBook(_userBook(id));
    }

    await tester.pumpWidget(ProviderScope(
      overrides: [
        bookDataProvider.overrideWith((ref) => notifier),
        shelfControllerProvider
            .overrideWith((ref) => ShelfController(InMemoryShelfRepository())),
      ],
      child: const MaterialApp(home: BookshelfScreen()),
    ));
    await _revealBooks(tester);

    await tester.longPress(_card('ub-1'));
    await tester.pumpAndSettle();
    await tester.tap(_card('ub-3'));
    await tester.pumpAndSettle();
    expect(find.text('2冊選択'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.bulkDeleteButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(notifier.state.userBooks.map((b) => b.id), ['ub-2']);
    expect(find.text('2冊を削除しました'), findsOneWidget);

    await tester.tap(find.byKey(undoActionKey));
    await tester.pumpAndSettle();

    expect(
      notifier.state.userBooks.map((b) => b.id),
      ['ub-1', 'ub-2', 'ub-3'],
    );
    // 一括削除の Undo は従来どおり addUserBook(index:) 経路のみ。
    // 連鎖復元サービスには一切触れない（意味論不変の番人）。
    expect(restoreObserved, isEmpty);
  });

  testWidgets('単体削除は従来どおり確認ダイアログを経てから消える', (tester) async {
    final notifier = BookDataNotifier()..addUserBook(_userBook('ub-1'));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        bookDataProvider.overrideWith((ref) => notifier),
        shelfControllerProvider
            .overrideWith((ref) => ShelfController(InMemoryShelfRepository())),
      ],
      child: const MaterialApp(home: BookshelfScreen()),
    ));
    await _revealBooks(tester);

    await tester.drag(_card('ub-1'), const Offset(-900, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.confirmDialog), findsOneWidget);
    expect(find.text('本を削除しますか？'), findsOneWidget);

    // キャンセルすれば消えない
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(notifier.state.userBooks.map((b) => b.id), ['ub-1']);
  });
}
