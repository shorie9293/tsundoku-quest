import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/xp_bar.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';

void main() {
  group('XpBar', () {
    Widget buildTestWidget({
      int level = 5,
      int xp = 50,
      int xpToNextLevel = 100,
      String title = '書庫の見習い',
    }) {
      return MaterialApp(
        home: Scaffold(
          body: XpBar(
            level: level,
            xp: xp,
            xpToNextLevel: xpToNextLevel,
            title: title,
          ),
        ),
      );
    }

    testWidgets('displays level and title', (tester) async {
      await tester.pumpWidget(buildTestWidget(level: 5, title: '書庫の見習い'));

      expect(find.text('Lv.5'), findsOneWidget);
      expect(find.text('書庫の見習い'), findsOneWidget);
    });

    testWidgets('displays XP progress text', (tester) async {
      await tester.pumpWidget(buildTestWidget(xp: 50, xpToNextLevel: 100));

      expect(find.text('50 / 100 XP'), findsOneWidget);
    });

    testWidgets('has LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('progress is 0 when xpToNextLevel is 0', (tester) async {
      await tester.pumpWidget(buildTestWidget(xp: 50, xpToNextLevel: 0));

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.0);
    });

    testWidgets('has XpBar key', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byKey(AppKeys.xpBar), findsOneWidget);
    });
  });
}
