import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/streak_display.dart';
import 'package:tsundoku_quest/shared/providers/adventurer_provider.dart';

Widget testStreak(int streak) => ProviderScope(
      overrides: [
        adventurerProvider.overrideWith((ref) {
          final notifier = AdventurerNotifier();
          notifier.updateStreak(current: streak, longest: streak);
          return notifier;
        }),
      ],
      child: const MaterialApp(
        home: Scaffold(body: StreakDisplay()),
      ),
    );

void main() {
  group('StreakDisplay', () {
    testWidgets('should show streak count with fire emoji', (tester) async {
      await tester.pumpWidget(testStreak(7));
      expect(find.text('7日連続冒険中！'), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('should render nothing when streak is 0', (tester) async {
      await tester.pumpWidget(testStreak(0));
      // SizedBox.shrink renders nothing visible
      expect(find.text('🔥'), findsNothing);
    });
  });
}
