import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/recommendation.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/recommendation_card.dart';

void main() {
  group('RecommendationCard', () {
    Widget buildTestWidget(Recommendation recommendation) {
      return MaterialApp(
        home: Scaffold(
          body: RecommendationCard(recommendation: recommendation),
        ),
      );
    }

    testWidgets('shows book title, author, and reason', (tester) async {
      final book = Book(
        id: 'b1',
        title: '推奨される本',
        authors: ['偉大な著者'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      final userBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'b1',
        book: book,
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      );
      final recommendation = Recommendation.fromUserBook(
        userBook,
        reason: '今日のランダムな一冊',
      );

      await tester.pumpWidget(buildTestWidget(recommendation));
      await tester.pumpAndSettle();

      // Section header
      expect(find.text('🎯 今日のおすすめ'), findsOneWidget);

      // Book title
      expect(find.text('推奨される本'), findsOneWidget);

      // Author
      expect(find.text('偉大な著者'), findsOneWidget);

      // Reason
      expect(find.text('今日のランダムな一冊'), findsOneWidget);

      // Button
      expect(find.text('読書を始める'), findsOneWidget);
    });

    testWidgets('shows correct content for old book recommendation', (tester) async {
      final book = Book(
        id: 'b1',
        title: '放置された本',
        authors: ['有名な著者'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      final userBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'b1',
        book: book,
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: DateTime.now().subtract(const Duration(days: 35)).toIso8601String(),
      );
      final recommendation = Recommendation.fromUserBook(
        userBook,
        reason: '35日間待機中の冒険',
      );

      await tester.pumpWidget(buildTestWidget(recommendation));
      await tester.pumpAndSettle();

      // Section header
      expect(find.text('🎯 今日のおすすめ'), findsOneWidget);

      // Book title
      expect(find.text('放置された本'), findsOneWidget);

      // Author
      expect(find.text('有名な著者'), findsOneWidget);

      // Reason with day count
      expect(find.text('35日間待機中の冒険'), findsOneWidget);

      // Button
      expect(find.text('読書を始める'), findsOneWidget);
    });

    testWidgets('recommendation card has semantics wrappers', (tester) async {
      final book = Book(
        id: 'b1',
        title: 'セマンティクス本',
        authors: ['著者'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      final userBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'b1',
        book: book,
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: DateTime.now().toIso8601String(),
      );
      final recommendation = Recommendation.fromUserBook(
        userBook,
        reason: '今日のランダムな一冊',
      );

      await tester.pumpWidget(buildTestWidget(recommendation));
      await tester.pumpAndSettle();

      // Should find Semantics widgets
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
