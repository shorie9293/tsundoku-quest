import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/book_list_screen.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:hive/hive.dart';
import '../../test_helpers.dart';

UserBook _testBook(String id, String title, BookStatus status) => UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      book: Book(
        id: 'book-$id',
        title: title,
        authors: ['著者太郎'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      ),
      status: status,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

Widget testBookListScreen({
  String title = 'テスト一覧',
  List<UserBook> books = const [],
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: BookListScreen(title: title, books: books),
  );
}

void main() {
  setUpAll(() {
    initTestHive();
  });
  tearDownAll(() async {
    await Hive.close();
  });

  group('BookListScreen', () {
    testWidgets('should display the title in AppBar', (tester) async {
      await tester.pumpWidget(testBookListScreen(title: '登録本一覧'));
      expect(find.text('📋 登録本一覧'), findsOneWidget);
    });

    testWidgets('should display empty message when no books', (tester) async {
      await tester.pumpWidget(testBookListScreen(books: []));
      expect(find.text('表示する本がありません'), findsOneWidget);
    });

    testWidgets('should display book titles in the list', (tester) async {
      final books = [
        _testBook('1', 'ドメイン駆動設計', BookStatus.tsundoku),
        _testBook('2', 'リファクタリング', BookStatus.reading),
        _testBook('3', 'Clean Architecture', BookStatus.completed),
      ];
      await tester.pumpWidget(testBookListScreen(books: books));
      await tester.pumpAndSettle();

      expect(find.text('ドメイン駆動設計'), findsOneWidget);
      expect(find.text('リファクタリング'), findsOneWidget);
      expect(find.text('Clean Architecture'), findsOneWidget);
    });

    testWidgets('should display ListView with correct key', (tester) async {
      final books = [_testBook('1', 'テスト', BookStatus.tsundoku)];
      await tester.pumpWidget(testBookListScreen(books: books));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.bookListListView), findsOneWidget);
    });

    testWidgets('should show status labels for each book', (tester) async {
      final books = [
        _testBook('1', '積読本', BookStatus.tsundoku),
        _testBook('2', '読書中', BookStatus.reading),
        _testBook('3', '読了本', BookStatus.completed),
      ];
      await tester.pumpWidget(testBookListScreen(books: books));
      await tester.pumpAndSettle();

      // BookCard shows status labels
      expect(find.text('待機中'), findsOneWidget);
      expect(find.text('戦闘中！'), findsOneWidget);
      expect(find.text('討伐済み'), findsOneWidget);
    });
  });
}
