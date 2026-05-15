import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/recommendation/presentation/recommendation_screen.dart';

void main() {
  group('RecommendationScreen', () {
    Widget buildTestWidget() {
      return ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const RecommendationScreen(),
        ),
      );
    }

    testWidgets('displays AppBar with title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('おすすめ'), findsOneWidget);
    });

    testWidgets('has AppKey', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.recommendationScreen), findsOneWidget);
    });

    testWidgets('displays もっと見る button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('もっと見る'), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      // Don't pump to settle — check for CircularProgressIndicator during loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
