import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/history/presentation/widgets/reading_habit_heatmap.dart';

/// 親の探針（合成の不変条件を撃つ）
///
/// 眷属は「セルが在るか」「文言が出るか」を個別にしか撃たない。
/// ここでは ①サービス集計 ↔ 画面表示の合成 ②濃淡レベルの表引き
/// ③記録なしセルの色 ④durationMinutes 欠落（回数は数えるが分は0）を撃つ。
ReadingSession _session({
  required String startedAt,
  int? minutes = 30,
}) {
  return ReadingSession(
    id: 'p-$startedAt-$minutes',
    userBookId: 'ub-probe',
    startedAt: startedAt,
    startPage: 1,
    endPage: 10,
    durationMinutes: minutes,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

Widget _wrap(List<ReadingSession> sessions) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReadingHabitHeatmap(sessionsOverride: sessions),
        ),
      ),
    ),
  );
}

Color? _cellColor(WidgetTester tester, int weekday, int slot) {
  final container =
      tester.widget<Container>(find.byKey(AppKeys.readingHabitCell(weekday, slot)));
  return (container.decoration as BoxDecoration).color;
}

void main() {
  testWidgets('探針1: 最大セル(level4)でも描画が落ちず、色はパレット最濃', (tester) async {
    await tester.pumpWidget(_wrap([
      // 火曜 20-23時 = 120分（=max → level4）
      _session(startedAt: '2026-09-22T20:00:00', minutes: 120),
      // 水曜 8-11時 = 30分（ratio 0.25 → level1）
      _session(startedAt: '2026-09-23T09:00:00', minutes: 30),
    ]));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    final hot = _cellColor(tester, 2, 5);
    final cool = _cellColor(tester, 3, 2);
    final none = _cellColor(tester, 1, 0);
    expect(hot, isNotNull);
    expect(hot == cool, isFalse, reason: 'level4 と level1 が同色では濃淡が伝わらない');
    expect(cool == none, isFalse, reason: 'level1 と 0 が同色では記録の有無が伝わらない');
    expect(hot == none, isFalse);
  });

  testWidgets('探針2: 画面の busiest・合計表示が集計と一致する（合成）', (tester) async {
    await tester.pumpWidget(_wrap([
      _session(startedAt: '2026-09-22T20:00:00', minutes: 60), // 火 20-23
      _session(startedAt: '2026-09-22T21:30:00', minutes: 30), // 火 20-23
      _session(startedAt: '2026-09-21T09:00:00', minutes: 25), // 月 8-11
      _session(startedAt: 'invalid-date', minutes: 999), // 集計外
    ]));
    await tester.pump(const Duration(milliseconds: 100));

    final label =
        tester.widget<Text>(find.byKey(AppKeys.readingHabitBusiest)).data!;
    // 火曜合計 90分 > 月曜 25分、時間帯は slot5 が最大
    expect(label, contains('火曜'));
    expect(label, contains('20-23時'));
    // 不正日付の 999分 と 1回は混入しない（合計=115分 / 3回）
    expect(label, contains('合計 115分・3回'));
  });

  testWidgets('探針3: durationMinutes 欠落は回数に数え分は0（空扱いにしない）', (tester) async {
    await tester.pumpWidget(_wrap([
      _session(startedAt: '2026-09-24T22:00:00', minutes: null),
    ]));
    await tester.pump(const Duration(milliseconds: 100));

    // 有効な日時が1件あるので「記録なし」ではなく grid を出す
    expect(find.byKey(AppKeys.readingHabitGrid), findsOneWidget);
    expect(find.byKey(AppKeys.readingHabitEmpty), findsNothing);
    final label =
        tester.widget<Text>(find.byKey(AppKeys.readingHabitBusiest)).data!;
    expect(label, contains('合計 0分・1回'));
    expect(label, contains('—'), reason: '分が全て0なら busiest は求められない');
    // そのセルは「記録なし」の色
    expect(_cellColor(tester, 4, 5), _cellColor(tester, 1, 0));
  });

  testWidgets('探針4: 曜日・時間帯の総当りに cell キーが揃う（7×6=42）', (tester) async {
    await tester.pumpWidget(_wrap([
      _session(startedAt: '2026-09-22T20:00:00', minutes: 30),
    ]));
    await tester.pump(const Duration(milliseconds: 100));

    for (var weekday = 1; weekday <= 7; weekday++) {
      for (var slot = 0; slot < 6; slot++) {
        expect(
          find.byKey(AppKeys.readingHabitCell(weekday, slot)),
          findsOneWidget,
          reason: 'cell($weekday,$slot) が無い',
        );
      }
    }
  });
}
