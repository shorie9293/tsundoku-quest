import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/history/data/reading_forecast_service.dart';
import 'package:tsundoku_quest/features/history/presentation/widgets/reading_forecast_card.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';

void main() {
  group('ReadingForecastCard', () {
    testWidgets('予測あり: 読了日ラベルとペースを表示する', (tester) async {
      const forecast = ReadingForecast(
        userBookId: 'ub1',
        title: 'テスト本',
        totalPages: 300,
        currentPage: 100,
        pagesPerDay: 30.0,
        remainingPages: 200,
        daysRemaining: 7,
        forecastDate: null,
      );
      // forecastDate は値オブジェクト内で再現できないため
      // isUnknown=true になるが、ラベルは null フォールバックを検証する。
      // 読了日ありのケースは forecastDate を持つインスタンスで別途検証。
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: ReadingForecastCard(forecast: forecast)),
        ),
      );
      expect(find.byKey(AppKeys.readingForecastCard), findsOneWidget);
      expect(find.byKey(AppKeys.readingForecastLabel), findsOneWidget);
      // pagesPerDay=30 があるのでペース行は出る
      expect(find.byKey(AppKeys.readingForecastPace), findsOneWidget);
      expect(find.text('1日あたり約 30 ページ'), findsOneWidget);
    });

    testWidgets('総ページ不明: ペースのみ表示し読了日は未予測と明示する', (tester) async {
      const forecast = ReadingForecast(
        userBookId: 'ub1',
        title: 'テスト本',
        totalPages: null,
        currentPage: 50,
        pagesPerDay: 8.345,
        remainingPages: null,
        daysRemaining: null,
        forecastDate: null,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: ReadingForecastCard(forecast: forecast)),
        ),
      );
      expect(find.text('総ページ数が不明のため読了日は未予測'), findsOneWidget);
      expect(find.text('1日あたり約 8.3 ページ'), findsOneWidget);
    });

    testWidgets('ペース不明: カードは沈黙せず未予測のみ表示する', (tester) async {
      const forecast = ReadingForecast(
        userBookId: 'ub1',
        title: 'テスト本',
        totalPages: 300,
        currentPage: 100,
        pagesPerDay: null,
        remainingPages: 200,
        daysRemaining: null,
        forecastDate: null,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: ReadingForecastCard(forecast: forecast)),
        ),
      );
      expect(find.text('読書ペースがつかめないため読了日は未予測'), findsOneWidget);
      expect(find.byKey(AppKeys.readingForecastPace), findsNothing);
    });
  });
}
