import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/recommendation.dart';
import 'package:tsundoku_quest/features/recommendation/presentation/widgets/recommendation_card.dart';
import 'package:tsundoku_quest/features/recommendation/presentation/widgets/recommendation_list.dart';

void main() {
  group('RecommendationList', () {
    Widget buildTestWidget(List<Recommendation> recommendations) {
      return MaterialApp(
        home: Scaffold(
          body: RecommendationList(recommendations: recommendations),
        ),
      );
    }

    testWidgets('displays list of recommendations', (tester) async {
      final rec1 = Recommendation.fromParams(
        id: 'rec-1',
        bookTitle: '本1',
        author: '著者1',
        reason: 'おすすめ1',
        createdAt: '2026-01-01T00:00:00Z',
      );
      final rec2 = Recommendation.fromParams(
        id: 'rec-2',
        bookTitle: '本2',
        author: '著者2',
        reason: 'おすすめ2',
        createdAt: '2026-01-01T00:00:00Z',
      );

      await tester.pumpWidget(buildTestWidget([rec1, rec2]));
      await tester.pumpAndSettle();

      expect(find.text('本1'), findsOneWidget);
      expect(find.text('本2'), findsOneWidget);
      expect(find.byType(RecommendationCard), findsNWidgets(2));
    });

    testWidgets('displays empty when no recommendations', (tester) async {
      await tester.pumpWidget(buildTestWidget([]));
      await tester.pumpAndSettle();

      expect(find.byType(RecommendationCard), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('has AppKey', (tester) async {
      final rec = Recommendation.fromParams(
        id: 'rec-1',
        bookTitle: 'キー本',
        author: '著者',
        reason: 'おすすめ',
        createdAt: '2026-01-01T00:00:00Z',
      );

      await tester.pumpWidget(buildTestWidget([rec]));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.recommendationList), findsOneWidget);
    });
  });
}
