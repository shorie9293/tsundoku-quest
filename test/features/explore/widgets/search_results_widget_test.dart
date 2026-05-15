import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/features/explore/presentation/widgets/search_results_widget.dart';

Widget createTestApp(List<Book> books, {void Function(Book)? onAddBook}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SearchResultsWidget(
        books: books,
        onAddBook: onAddBook ?? (_) {},
      ),
    ),
  );
}

Book createTestBook({
  String id = '1',
  String title = 'テストの本',
  List<String> authors = const ['著者A'],
  String? publisher,
  String? coverImageUrl,
}) {
  return Book(
    id: id,
    title: title,
    authors: authors,
    publisher: publisher,
    coverImageUrl: coverImageUrl,
    source: BookSource.rakuten,
    createdAt: DateTime.now().toUtc().toIso8601String(),
  );
}

void main() {
  group('SearchResultsWidget', () {
    testWidgets('should display book cards with title and author',
        (tester) async {
      final books = [
        createTestBook(id: '1', title: '本A', authors: ['作者A']),
        createTestBook(id: '2', title: '本B', authors: ['作者B']),
      ];

      await tester.pumpWidget(createTestApp(books));
      await tester.pumpAndSettle();

      expect(find.text('本A'), findsOneWidget);
      expect(find.text('本B'), findsOneWidget);
      expect(find.text('作者A'), findsOneWidget);
      expect(find.text('作者B'), findsOneWidget);
      expect(find.byKey(AppKeys.searchResultsList), findsOneWidget);
    });

    testWidgets('should display publisher when available', (tester) async {
      final books = [
        createTestBook(
          id: '1',
          title: '本A',
          authors: ['作者A'],
          publisher: 'テスト出版',
        ),
      ];

      await tester.pumpWidget(createTestApp(books));
      await tester.pumpAndSettle();

      expect(find.text('テスト出版'), findsOneWidget);
    });

    testWidgets('should show placeholder icon when no cover image',
        (tester) async {
      final books = [
        createTestBook(id: '1', title: '表紙なしの本', coverImageUrl: null),
      ];

      await tester.pumpWidget(createTestApp(books));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.book), findsOneWidget);
    });

    testWidgets('should call onAddBook when add button is pressed',
        (tester) async {
      final books = [
        createTestBook(id: '1', title: '追加する本', authors: ['作者']),
      ];

      Book? addedBook;
      await tester.pumpWidget(
        createTestApp(books, onAddBook: (book) => addedBook = book),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.searchResultItem));
      await tester.pumpAndSettle();

      expect(addedBook, isNotNull);
      expect(addedBook!.title, '追加する本');
    });

    testWidgets('should render Image.network when coverImageUrl is provided',
        (tester) async {
      final books = [
        createTestBook(
          id: '1',
          title: '表紙あり',
          coverImageUrl: 'https://example.com/cover.jpg',
        ),
      ];

      await tester.pumpWidget(createTestApp(books));
      await tester.pumpAndSettle();

      // Image.network widget exists (even if it fails to load in test env)
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('should render add button with correct key', (tester) async {
      final books = [
        createTestBook(id: '1', title: '本A'),
      ];

      await tester.pumpWidget(createTestApp(books));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.searchResultItem), findsOneWidget);
    });
  });
}
