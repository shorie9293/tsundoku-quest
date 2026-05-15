import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/recommendation.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/recommendation/presentation/widgets/recommendation_card.dart';

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

      expect(find.text('🎯 今日のおすすめ'), findsOneWidget);
      expect(find.text('推奨される本'), findsOneWidget);
      expect(find.text('偉大な著者'), findsOneWidget);
      expect(find.text('今日のランダムな一冊'), findsOneWidget);
      expect(find.text('読書を始める'), findsOneWidget);
    });

    testWidgets('shows cover image when imageUrl is provided', (tester) async {
      final recommendation = Recommendation.fromParams(
        id: 'rec-1',
        bookTitle: 'カバー付き本',
        author: 'カバー著者',
        reason: 'おすすめ',
        imageUrl: 'https://example.com/cover.jpg',
        createdAt: '2026-01-01T00:00:00Z',
      );

      await tester.pumpWidget(buildTestWidget(recommendation));
      await tester.pumpAndSettle();

      // Should have an Image.network widget
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('does not show cover image when imageUrl is null', (tester) async {
      final book = Book(
        id: 'b1',
        title: 'カバー無し本',
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
        reason: 'おすすめ',
      );

      await tester.pumpWidget(buildTestWidget(recommendation));
      await tester.pumpAndSettle();

      // Should NOT have Image widget since imageUrl is null
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('has AppKey', (tester) async {
      final recommendation = Recommendation.fromParams(
        id: 'rec-1',
        bookTitle: 'キー本',
        author: '著者',
        reason: 'おすすめ',
        createdAt: '2026-01-01T00:00:00Z',
      );

      await tester.pumpWidget(buildTestWidget(recommendation));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.recommendationCard), findsOneWidget);
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

      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
