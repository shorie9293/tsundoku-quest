import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/xp_bar.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';

Widget testXpBar(
    {int level = 1,
    int xp = 0,
    int xpToNextLevel = 100,
    String title = 'Apprentice'}) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: XpBar(
          level: level,
          xp: xp,
          xpToNextLevel: xpToNextLevel,
          title: title,
        ),
      ),
    ),
  );
}

void main() {
  group('XpBar', () {
    testWidgets('should display level and title', (tester) async {
      await tester.pumpWidget(testXpBar(level: 5, title: 'Book Explorer'));

      expect(find.text('Lv.5'), findsOneWidget);
      expect(find.text('Book Explorer'), findsOneWidget);
    });

    testWidgets('should display XP progress text', (tester) async {
      await tester.pumpWidget(testXpBar(xp: 50, xpToNextLevel: 100));

      expect(find.text('50 / 100 XP'), findsOneWidget);
    });

    testWidgets('should have AppKey set', (tester) async {
      await tester.pumpWidget(testXpBar());

      expect(find.byKey(AppKeys.xpBar), findsOneWidget);
    });

    testWidgets('should show progress bar', (tester) async {
      await tester.pumpWidget(testXpBar(xp: 30, xpToNextLevel: 100));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
