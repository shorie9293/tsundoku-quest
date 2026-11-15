/// 親探針（イシコリドメ）: #253 表示日付のローカル暦化を独立に撃つ。
///
/// 眷属の試練は「子が実装した意味論」を固定し得るため、親は要求した不変条件を
/// 自分の言葉で撃ち直す。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/time/local_calendar_date.dart';
import 'package:tsundoku_quest/features/history/data/reading_notes_provider.dart';
import 'package:tsundoku_quest/features/history/widgets/reading_note_card.dart';
import 'package:tsundoku_quest/features/reading/domain/reading_date_key.dart';

String _localDateOf(String iso) {
  final l = DateTime.parse(iso).toLocal();
  return '${l.year.toString().padLeft(4, '0')}-'
      '${l.month.toString().padLeft(2, '0')}-'
      '${l.day.toString().padLeft(2, '0')}';
}

String _utcDateOf(String iso) => iso.substring(0, 10);

ReadingNoteItem _note(String createdAt) => ReadingNoteItem(
      id: 'n1',
      userBookId: 'b1',
      bookTitle: '探針の書',
      learnings: const ['学び'],
      action: '行動',
      createdAt: createdAt,
    );

void main() {
  group('PP1 日界: UTC切りとローカル暦が食い違う瞬間で撃つ', () {
    // JST 00:30 / 月初 / 年末 の3点。UTC では前日・前月・前年になる。
    const samples = [
      '2026-11-12T15:30:00.000Z', // JST 2026-11-13 00:30
      '2026-10-31T16:00:00.000Z', // JST 2026-11-01 01:00
      '2026-12-31T20:00:00.000Z', // JST 2027-01-01 05:00
    ];
    for (final raw in samples) {
      test('$raw はローカル暦で表示される（UTC切りとは別物）', () {
        final expected = _localDateOf(raw);
        expect(LocalCalendarDate.displayDate(raw), expected);
        // UTC 切りと一致してしまう瞬間では検出力が無いので明示的に除外
        if (_utcDateOf(raw) != expected) {
          expect(LocalCalendarDate.displayDate(raw), isNot(_utcDateOf(raw)));
        }
      });
    }

    test('JST(UTC+9) 実行時は早朝が翌日になる（TZ 依存の明示ガード）', () {
      final offsetMin = DateTime.now().timeZoneOffset.inMinutes;
      final raw = '2026-11-12T15:30:00.000Z';
      if (offsetMin >= 540) {
        expect(LocalCalendarDate.displayDate(raw), '2026-11-13');
      } else {
        expect(LocalCalendarDate.displayDate(raw), _localDateOf(raw));
      }
    });
  });

  group('PP2 正準の二重定義がない（委譲一致）', () {
    const inputs = [
      '2026-11-12T15:30:00.000Z',
      '2026-11-12',
      '2026-11-12T15:30:00+09:00',
      '',
      '   ',
      'abc',
      '2026-13-45T99:99:99Z',
      null,
    ];
    test('ReadingDateKey.tryFromIso == LocalCalendarDate.tryFromIso', () {
      for (final raw in inputs) {
        expect(
          ReadingDateKey.tryFromIso(raw),
          LocalCalendarDate.tryFromIso(raw),
          reason: '入力 $raw で二実装が分岐している',
        );
      }
    });

    test('fromDateTime も一致し、throw しない', () {
      final dts = [
        DateTime.utc(2026, 11, 12, 15, 30),
        DateTime(2026, 1, 1, 0, 0),
      ];
      for (final dt in dts) {
        expect(
          ReadingDateKey.fromDateTime(dt),
          LocalCalendarDate.fromDateTime(dt),
        );
      }
    });
  });

  group('PP3 壊れ値・短い値は生値へフォールバック（後方互換）', () {
    test('パース不能・空・null で throw せず生値を返す', () {
      expect(LocalCalendarDate.displayDate('abc'), 'abc');
      expect(LocalCalendarDate.displayDate(''), '');
      expect(LocalCalendarDate.displayDate('  '), '');
      expect(LocalCalendarDate.displayDate(null), '');
      expect(LocalCalendarDate.tryFromIso('2026-13-45T99:99:99Z'), isNull);
    });
  });

  group('PP4 画面がローカル暦を描く（widget 合成）', () {
    testWidgets('ReadingNoteCard が UTC 切りではなくローカル暦を表示する',
        (tester) async {
      const raw = '2026-11-12T15:30:00.000Z';
      final expected = _localDateOf(raw);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ReadingNoteCard(note: _note(raw))),
      ));
      await tester.pump();
      expect(find.text(expected), findsOneWidget);
      if (_utcDateOf(raw) != expected) {
        expect(find.text(_utcDateOf(raw)), findsNothing,
            reason: 'UTC 暦日が表示されている＝根治していない');
      }
    });
  });

  group('PP5 ソース不変条件: lib に実行可能な UTC 切りが残っていない', () {
    test('substring(0, 10) がコード行として残っていない（コメントは可）', () {
      final roots = [
        'lib/features/history',
        'lib/features/reading',
        'lib/core/time',
      ];
      final offenders = <String>[];
      for (final root in roots) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        for (final f in dir.listSync(recursive: true)) {
          if (f is! File || !f.path.endsWith('.dart')) continue;
          final lines = f.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i].trimLeft();
            if (line.startsWith('//')) continue;
            if (RegExp(r'substring\(\s*0\s*,\s*10\s*\)').hasMatch(line)) {
              offenders.add('${f.path}:${i + 1}');
            }
          }
        }
      }
      expect(offenders, isEmpty, reason: 'UTC 切りが残存: $offenders');
    });
  });
}
