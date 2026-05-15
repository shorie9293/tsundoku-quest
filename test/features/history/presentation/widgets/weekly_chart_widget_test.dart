import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/history/presentation/widgets/weekly_chart_widget.dart';

void main() {
  group('WeeklyChartWidget', () {
    testWidgets('should display title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WeeklyChartWidget(weeklyMinutes: [10, 20, 30, 0, 15, 45, 60]),
              ),
            ),
          ),
        ),
      );

      expect(find.text('📊 週間読書'), findsOneWidget);
    });

    testWidgets('should display total weekly minutes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WeeklyChartWidget(weeklyMinutes: [10, 20, 30, 0, 15, 45, 60]),
              ),
            ),
          ),
        ),
      );

      expect(find.text('今週の合計: 180分'), findsOneWidget);
    });

    testWidgets('should handle empty weekly data', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WeeklyChartWidget(weeklyMinutes: [0, 0, 0, 0, 0, 0, 0]),
              ),
            ),
          ),
        ),
      );

      expect(find.text('今週の合計: 0分'), findsOneWidget);
    });

    testWidgets('should display day labels', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WeeklyChartWidget(weeklyMinutes: [10, 20, 30, 0, 15, 45, 60]),
              ),
            ),
          ),
        ),
      );

      // Should show at least one weekday label
      const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
      final foundAny = weekdays.any((d) => find.text(d).evaluate().isNotEmpty);
      expect(foundAny, true);
    });
  });
}
