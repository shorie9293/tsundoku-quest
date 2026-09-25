import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/history/presentation/widgets/reading_habit_heatmap.dart';

ReadingSession _session({
  required String startedAt,
  int minutes = 30,
}) {
  return ReadingSession(
    id: 's-$startedAt-$minutes',
    userBookId: 'ub1',
    startedAt: startedAt,
    startPage: 1,
    endPage: 20,
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

Finder _keyFinder(Key key) => find.byKey(key);

void main() {
  testWidgets('① 空リスト → empty が1件・grid は0件', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_keyFinder(AppKeys.readingHabitEmpty), findsOneWidget);
    expect(_keyFinder(AppKeys.readingHabitGrid), findsNothing);
  });

  testWidgets('⑦ 不正日付セッションのみ → empty 扱い', (tester) async {
    await tester.pumpWidget(_wrap([_session(startedAt: 'not-a-date')]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_keyFinder(AppKeys.readingHabitEmpty), findsOneWidget);
    expect(_keyFinder(AppKeys.readingHabitGrid), findsNothing);
  });

  testWidgets('② セッションあり → grid 1件・empty 0件', (tester) async {
    await tester.pumpWidget(_wrap([_session(startedAt: '2026-09-22T21:00:00')]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_keyFinder(AppKeys.readingHabitGrid), findsOneWidget);
    expect(_keyFinder(AppKeys.readingHabitEmpty), findsNothing);
  });

  testWidgets('③④⑤⑥ 火曜20-23時のセッション2件 → busiest・集計・レジェンド', (tester) async {
    await tester.pumpWidget(_wrap([
      _session(startedAt: '2026-09-22T20:00:00', minutes: 40),
      _session(startedAt: '2026-09-22T22:30:00', minutes: 50),
    ]));
    await tester.pump(const Duration(milliseconds: 100));

    // ③ 特定セル（火曜・slot5）が存在
    expect(_keyFinder(AppKeys.readingHabitCell(2, 5)), findsOneWidget);
    // ④ busiest ラベルに '火曜' と '20-23時'
    final busiest =
        tester.widget<Text>(_keyFinder(AppKeys.readingHabitBusiest)).data!;
    expect(busiest, contains('火曜'));
    expect(busiest, contains('20-23時'));
    // ⑤ 集計値
    expect(busiest, contains('合計 90分・2回'));
    // ⑥ レジェンド
    expect(_keyFinder(AppKeys.readingHabitLegend), findsOneWidget);
  });

  testWidgets('⑧ 曜日ラベル 月..日 が各1件以上', (tester) async {
    await tester.pumpWidget(_wrap([_session(startedAt: '2026-09-22T21:00:00')]));
    await tester.pump(const Duration(milliseconds: 100));
    for (final label in ['月', '火', '水', '木', '金', '土', '日']) {
      expect(find.text(label), findsWidgets, reason: 'missing $label');
    }
  });

  testWidgets('⑨ slotLabel 0-3時 / 20-23時 が出る', (tester) async {
    await tester.pumpWidget(_wrap([
      _session(startedAt: '2026-09-21T02:00:00'),
      _session(startedAt: '2026-09-22T21:00:00'),
    ]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('0-3時'), findsOneWidget);
    expect(find.text('20-23時'), findsOneWidget);
  });

  testWidgets('⑩ 複数時間帯で濃淡（0 と 4 のセルが両方ある）', (tester) async {
    await tester.pumpWidget(_wrap([
      // 火曜 20-23時: 90分（=max, level4）
      _session(startedAt: '2026-09-22T20:00:00', minutes: 90),
      // 水曜 8-11時: 10分（ratio 0.11 → level1）
      _session(startedAt: '2026-09-23T09:00:00', minutes: 10),
    ]));
    await tester.pump(const Duration(milliseconds: 100));
    final hot = tester.widget<Container>(
      _keyFinder(AppKeys.readingHabitCell(2, 5)),
    );
    final cool = tester.widget<Container>(
      _keyFinder(AppKeys.readingHabitCell(3, 2)),
    );
    final hotColor = (hot.decoration as BoxDecoration).color;
    final coolColor = (cool.decoration as BoxDecoration).color;
    expect(hotColor != coolColor, isTrue);
  });
}