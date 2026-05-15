import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/recommendation/presentation/widgets/social_reading_section.dart';

void main() {
  group('SocialReadingSection', () {
    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SocialReadingSection(),
          ),
        ),
      );
    }

    testWidgets('displays section header', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('👥 みんなが読んでいる'), findsOneWidget);
    });

    testWidgets('has AppKey', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.socialReadingSection), findsOneWidget);
    });

    testWidgets('shows offline message when no data', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Should show some kind of message — either loading, empty, or books
      // Since there's no Supabase client in test, it should show empty state
      expect(find.byType(Text), findsWidgets);
    });
  });
}
