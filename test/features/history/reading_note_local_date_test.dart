import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/features/history/data/reading_notes_provider.dart';
import 'package:tsundoku_quest/features/history/presentation/history_screen.dart';
import 'package:tsundoku_quest/features/history/widgets/reading_note_card.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';

import '../../test_helpers.dart';

/// JST 2026-11-13 00:30 に相当する UTC ISO（保存形式どおり末尾 Z）。
/// 期待値は必ずこの文字列を `DateTime.parse().toLocal()` してから算出する
/// （`DateTime.utc(...)` を期待値に据えない = UTC 切りを期待しない）。
const _jstMidnightRaw = '2026-11-12T15:30:00.000Z';

String _localDay(String raw) {
  final l = DateTime.parse(raw).toLocal();
  final y = l.year.toString().padLeft(4, '0');
  final m = l.month.toString().padLeft(2, '0');
  final d = l.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

int get _offsetMinutes =>
    DateTime.parse(_jstMidnightRaw).toLocal().timeZoneOffset.inMinutes;

ReadingNoteItem _note(String createdAt) => ReadingNoteItem(
      id: 'n1',
      userBookId: 'ub1',
      bookTitle: 'テスト本',
      learnings: const ['学び'],
      action: '行動',
      createdAt: createdAt,
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: child),
    );

Widget _historyScreenWith(List<WarTrophy> trophies) {
  final notifier = WarTrophyNotifier(null);
  for (final t in trophies) {
    notifier.addTrophy(t);
  }
  return ProviderScope(
    overrides: [warTrophyProvider.overrideWith((ref) => notifier)],
    child: MaterialApp(theme: ThemeData.dark(), home: const HistoryScreen()),
  );
}

void main() {
  setUpAll(initTestHive);
  tearDownAll(() async {
    await Hive.close();
  });

  group('ReadingNoteCard はローカル暦で日付表示する', () {
    testWidgets('JST 00:30 相当の UTC ISO がローカルの日付で出る', (tester) async {
      await tester
          .pumpWidget(_wrap(ReadingNoteCard(note: _note(_jstMidnightRaw))));

      expect(find.text(_localDay(_jstMidnightRaw)), findsOneWidget);
      if (_offsetMinutes >= 540) {
        // UTC 切りなら '2026-11-12' が出て赤になる（日界ズレの回帰検知）
        expect(find.text('2026-11-13'), findsOneWidget);
        expect(find.text('2026-11-12'), findsNothing);
      }
    });

    testWidgets('壊れ値は生値のまま表示する（後方互換）', (tester) async {
      await tester.pumpWidget(_wrap(ReadingNoteCard(note: _note('broken'))));
      expect(find.text('broken'), findsOneWidget);
    });

    testWidgets('短い文字列も生値のまま表示する（後方互換）', (tester) async {
      await tester.pumpWidget(_wrap(ReadingNoteCard(note: _note('2026'))));
      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets('月初跨ぎもローカル暦（UTC 9/30 22:00 = JST 10/01 07:00）', (tester) async {
      const raw = '2026-09-30T22:00:00.000Z';
      await tester.pumpWidget(_wrap(ReadingNoteCard(note: _note(raw))));

      expect(find.text(_localDay(raw)), findsOneWidget);
      if (_offsetMinutes >= 540) {
        expect(find.text('2026-10-01'), findsOneWidget);
        expect(find.text('2026-09-30'), findsNothing);
      }
    });
  });

  group('HistoryScreen の感想カード経路もローカル暦で日付表示する', () {
    testWidgets('JST 00:30 相当の UTC ISO がローカルの日付で出る', (tester) async {
      const trophies = [
        WarTrophy(
          id: 'trophy-utc-day',
          userBookId: 'book-1',
          userId: 'user-1',
          learnings: ['日界の学び'],
          action: '毎日読書する',
          createdAt: _jstMidnightRaw,
        ),
      ];
      await tester.pumpWidget(_historyScreenWith(trophies));
      await tester.pumpAndSettle();

      final expected = _localDay(_jstMidnightRaw);
      await tester.scrollUntilVisible(
        find.text(expected),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(expected), findsOneWidget);
      if (_offsetMinutes >= 540) {
        expect(find.text('2026-11-13'), findsOneWidget);
        expect(find.text('2026-11-12'), findsNothing);
      }
    });
  });
}
