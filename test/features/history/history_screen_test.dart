import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/history/presentation/history_screen.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';

Widget testHistoryScreen() {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const HistoryScreen(),
    ),
  );
}

void main() {
  group('HistoryScreen', () {
    testWidgets('should display app bar with title', (tester) async {
      await tester.pumpWidget(testHistoryScreen());

      expect(find.text('📊 足跡'), findsOneWidget);
    });

    testWidgets('should display monthly stats grid', (tester) async {
      await tester.pumpWidget(testHistoryScreen());

      expect(find.byKey(AppKeys.monthlyStatsGrid), findsOneWidget);
    });

    testWidgets('should display reading calendar widget', (tester) async {
      await tester.pumpWidget(testHistoryScreen());
      // カレンダーWidgetまでスクロールして表示
      await tester.scrollUntilVisible(
        find.byKey(AppKeys.readingCalendar),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // ReadingCalendarWidget が AppKeys.readingCalendar で存在する
      expect(find.byKey(AppKeys.readingCalendar), findsOneWidget);
    });

    testWidgets('should display calendar title', (tester) async {
      await tester.pumpWidget(testHistoryScreen());
      // カレンダーのタイトルまでスクロール
      await tester.scrollUntilVisible(
        find.text('📅 読書カレンダー'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('📅 読書カレンダー'), findsOneWidget);
    });
  });
}
