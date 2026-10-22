import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

Widget _screen({ProviderContainer? container}) {
  if (container == null) {
    return const ProviderScope(
      child: MaterialApp(home: BookshelfScreen()),
    );
  }
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: BookshelfScreen()),
  );
}

Book _book(String id) => Book(
      id: id,
      title: 'テスト本 $id',
      authors: const ['著者'],
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    );

UserBook _userBook(String id, BookStatus status) => UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      book: _book('book-$id'),
      status: status,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('hive_semantics_').path);
  });
  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('主要な操作要素に semantics identifier が付与されている', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    // AppBar の各アイコンボタン
    expect(find.bySemanticsIdentifier('btn_bookshelf_search'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_bookshelf_reading_queue'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_bookshelf_stagnant_books'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_bookshelf_reminder_settings'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_bookshelf_text_scale'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_bookshelf_theme_mode'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_bookshelf_reduce_motion'),
        findsOneWidget);
    expect(
        find.bySemanticsIdentifier('btn_bookshelf_app_lock'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_bookshelf_backup'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_bookshelf_about'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_bookshelf_shelf_management'),
        findsOneWidget);

    // 一覧は外側で1回だけ包まれている（重複発行なし）
    expect(find.bySemanticsIdentifier('list_bookshelf'), findsOneWidget);

    // 空状態とその導線（ListView の下方にあり遅延描画されるためスクロールしてから検証）
    await tester.scrollUntilVisible(
      find.text('書庫はまだ空です'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('sec_bookshelf_empty'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_empty_state_explore'),
        findsOneWidget);

    handle.dispose();
  });

  testWidgets('既存の AppKeys が引き続き解決できる', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.bookshelfScreen), findsOneWidget);
    expect(find.byKey(AppKeys.librarySearchButton), findsOneWidget);
    expect(find.byKey(AppKeys.readingQueueButton), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksButton), findsOneWidget);
    expect(find.byKey(AppKeys.reminderSettingsButton), findsOneWidget);
    expect(find.byKey(AppKeys.textScaleSettingsButton), findsOneWidget);
    expect(find.byKey(AppKeys.themeModeEntry), findsOneWidget);
    expect(find.byKey(AppKeys.reduceMotionEntry), findsOneWidget);
    expect(find.byKey(AppKeys.appLockSettingsButton), findsOneWidget);
    expect(find.byKey(AppKeys.backupSettingsButton), findsOneWidget);
  });

  testWidgets('蔵書がある場合も一覧 identifier は重複しない', (tester) async {
    final handle = tester.ensureSemantics();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(bookDataProvider.notifier)
        .addUserBook(_userBook('ub-1', BookStatus.tsundoku));
    container
        .read(bookDataProvider.notifier)
        .addUserBook(_userBook('ub-2', BookStatus.reading));

    await tester.pumpWidget(_screen(container: container));
    await tester.pumpAndSettle();

    // 画面上部（スクロール前）の要素
    expect(find.bySemanticsIdentifier('list_bookshelf'), findsOneWidget);
    expect(
        find.bySemanticsIdentifier('btn_recommendation_card'), findsOneWidget);
    expect(find.bySemanticsIdentifier('sec_daily_quest'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('待機中の冒険'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('sec_books_tsundoku'), findsOneWidget);

    // 行ごとの identifier は本 id を含む一意な文字列
    expect(find.bySemanticsIdentifier('item_book_ub-1'), findsOneWidget);

    handle.dispose();
  });
}
