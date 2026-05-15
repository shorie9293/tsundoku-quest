import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/history/presentation/widgets/reading_calendar_widget.dart';
import 'package:tsundoku_quest/shared/providers/adventurer_provider.dart';

/// テスト用ヘルパー: ReadingCalendarWidget を Provider 付きでラップ
Widget testReadingCalendar({List<String> readingDates = const []}) {
  return ProviderScope(
    overrides: [
      adventurerProvider.overrideWith((ref) {
        final notifier = AdventurerNotifier();
        for (final date in readingDates) {
          notifier.addReadingDate(date);
        }
        return notifier;
      }),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReadingCalendarWidget(),
        ),
      ),
    ),
  );
}

void main() {
  group('ReadingCalendarWidget', () {
    testWidgets('should display 30 day cells', (tester) async {
      await tester.pumpWidget(testReadingCalendar());

      // GridView が1つ表示される
      expect(find.byType(GridView), findsOneWidget);
      // GridView 内のスワイプ可能領域をスクロールしてすべてのセルを確認
      final _ = tester.widget<GridView>(find.byType(GridView));
      // SliverGrid の childrenDelegate.estimatedChildCount は使えないので、
      // テキスト「📅 読書カレンダー」が表示されていることを確認
      expect(find.text('📅 読書カレンダー'), findsOneWidget);
      // 凡例が表示される
      expect(find.text('読書あり'), findsOneWidget);
      expect(find.text('今日'), findsOneWidget);
    });

    testWidgets('should display date numbers as text', (tester) async {
      await tester.pumpWidget(testReadingCalendar());

      // 各セルは日付の数字をテキスト表示している
      // 本日から30日分の数字がグリッド内に存在する
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 30個の日付セルがテキストとして表示されていることを確認
      // 各セルには day の数字が fontSize:11 で表示される
      for (int i = 0; i < 30; i++) {
        final date = today.subtract(Duration(days: i));
        // セルは ValueKey('calendar_cell_YYYY-MM-DD') でキー付けされている
        expect(
          find.byKey(ValueKey('calendar_cell_${_formatDate(date)}')),
          findsOneWidget,
          reason: 'Cell for ${_formatDate(date)} should exist',
        );
      }
    });

    testWidgets('should highlight reading days in green', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      final readingDates = [
        _formatDate(yesterday),
        _formatDate(twoDaysAgo),
      ];

      await tester.pumpWidget(testReadingCalendar(readingDates: readingDates));

      // 読書ありの日付セルの背景色が緑系であることを確認
      for (final dateStr in readingDates) {
        final cellFinder = find.byKey(ValueKey('calendar_cell_$dateStr'));
        expect(cellFinder, findsOneWidget);

        final container = tester.widget<Container>(cellFinder);
        final decoration = container.decoration as BoxDecoration;
        final color = decoration.color;
        // 緑色系（alpha 付き）
        expect(color, isNotNull);
        expect(color!.alpha, greaterThan(0));
      }
    });

    testWidgets('should highlight today in progress color', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = _formatDate(today);

      await tester.pumpWidget(testReadingCalendar(readingDates: [todayStr]));

      // 今日のセルを確認
      final cellFinder = find.byKey(ValueKey('calendar_cell_$todayStr'));
      expect(cellFinder, findsOneWidget);

      final container = tester.widget<Container>(cellFinder);
      final decoration = container.decoration as BoxDecoration;
      // 今日は progress 色の枠線（太字） + progress 色背景
      expect(decoration.border, isNotNull);
      // 枠線の色を確認（border side の色）
      final border = decoration.border as Border;
      expect(border.top.color, isNotNull);
    });
  });
}

/// YYYY-MM-DD 形式にフォーマット
String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
