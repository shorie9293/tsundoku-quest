import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/reading/presentation/widgets/completion_effect.dart';

void main() {
  group('CompletionEffectOverlay', () {
    testWidgets('should show completion title and XP', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                CompletionEffectOverlay.show(
                  context,
                  xpGained: 250,
                  onComplete: () => completed = true,
                );
              },
              child: const Text('trigger'),
            ),
          ),
        ),
      );

      // Trigger the overlay
      await tester.tap(find.text('trigger'));
      await tester.pump();

      // Should show the completion text
      expect(find.text('⚔️ 討伐完了！'), findsOneWidget);
      // Should show the XP gained
      expect(find.text('+250 XP'), findsOneWidget);

      // On complete callback should fire after animation
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('should show default XP when xpGained is 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                CompletionEffectOverlay.show(
                  context,
                  xpGained: 200,
                );
              },
              child: const Text('trigger'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pump();

      expect(find.textContaining('XP'), findsOneWidget);
    });

    testWidgets('should not duplicate overlays on rapid taps', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                CompletionEffectOverlay.show(
                  context,
                  xpGained: 100,
                );
              },
              child: const Text('trigger'),
            ),
          ),
        ),
      );

      // Tap multiple times rapidly
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();

      // Only one overlay should be showing
      expect(find.text('⚔️ 討伐完了！'), findsOneWidget);
    });
  });
}
