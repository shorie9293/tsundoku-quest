import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/widgets/dungeon_background.dart';

void main() {
  group('DungeonBackground', () {
    testWidgets('should render background with gradient layers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DungeonBackground(),
        ),
      );

      // The DungeonBackground contains a Container with the gradient decoration.
      // Verify that it renders without errors.
      expect(find.byType(DungeonBackground), findsOneWidget);
      // The inner gradient container is present.
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('should render child widget on top of background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DungeonBackground(
            child: Center(
              child: Text('テスト文字', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );

      // The child text should be rendered on top.
      expect(find.text('テスト文字'), findsOneWidget);
    });

    testWidgets('should fill the available space without overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DungeonBackground(),
          ),
        ),
      );

      // Verify the DungeonBackground renders within Scaffold without overflow.
      expect(find.byType(DungeonBackground), findsOneWidget);
      // The inner gradient layers should be present.
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('should be usable as Scaffold body background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('テスト')),
            body: const DungeonBackground(
              child: Center(
                child: Text('本棚の中身', textDirection: TextDirection.ltr),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // AppBar and content should both be visible.
      expect(find.text('テスト'), findsOneWidget);
      expect(find.text('本棚の中身'), findsOneWidget);
    });
  });
}
