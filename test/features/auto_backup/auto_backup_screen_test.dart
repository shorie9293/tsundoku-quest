/// 自動バックアップ閲覧画面の試練
///
/// 改善提案 #188 続編。一覧・復元確認・共有・今すぐバックアップ。
/// pumpAndSettle は使わず pump + pump(Duration) で進める。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_sharer.dart';
import 'package:tsundoku_quest/features/auto_backup/presentation/auto_backup_screen.dart';

/// 復元呼び出しを記録するフェイク
class _FakeRestorer implements AutoBackupRestorer {
  final List<String> restored = [];
  bool ok = true;

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    restored.add(fileName);
    return AutoBackupRestoreResult(
      ok: ok,
      message: ok ? '復元しました' : '復元できませんでした',
      safetyFileName: 'auto_backup_20261029.json',
    );
  }
}

/// 共有呼び出しを記録するフェイク
class _FakeSharer implements AutoBackupSharer {
  final List<String> sharedNames = [];
  final List<String> sharedBodies = [];

  @override
  Future<void> share(String fileName, String json) async {
    sharedNames.add(fileName);
    sharedBodies.add(json);
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _wrap(Widget child) => MaterialApp(home: child);

List<String?> _rowTitles(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((t) => (t.title as Text?)?.data)
    .toList();

void main() {
  late InMemoryAutoBackupStore store;
  final now = DateTime(2026, 10, 29, 9, 30); // ローカル暦

  setUp(() async {
    store = InMemoryAutoBackupStore(now: () => now);
    await store.write('auto_backup_20261001.json', '{"day":1}');
    await store.write('auto_backup_20261003.json', '{"day":3}');
    await store.write('auto_backup_20261002.json', '{"day":2}');
  });

  testWidgets('一覧は新しい順に表示される', (tester) async {
    await tester.pumpWidget(_wrap(AutoBackupScreen(
      store: store,
      now: () => now,
    )));
    await _settle(tester);

    final titles = _rowTitles(tester);
    expect(titles, hasLength(3));
    // 同日書き込みなので createdAt は同一 → fileName 降順（新しい日付が先）
    expect(titles.first, startsWith('2026-10-29 09:30'));
    final fileNames = [
      'auto_backup_20261003.json',
      'auto_backup_20261002.json',
      'auto_backup_20261001.json'
    ];
    for (final name in fileNames) {
      expect(find.byKey(ValueKey('auto_backup_row_$name')), findsOneWidget);
    }
  });

  testWidgets('0件は空状態を出す', (tester) async {
    final empty = InMemoryAutoBackupStore(now: () => now);
    await tester
        .pumpWidget(_wrap(AutoBackupScreen(store: empty, now: () => now)));
    await _settle(tester);

    expect(find.text('バックアップはまだありません'), findsOneWidget);
  });

  testWidgets('壊れた JSON は復元ボタンを出さない（共有は出る）', (tester) async {
    final broken = InMemoryAutoBackupStore(now: () => now);
    await broken.write('auto_backup_20261005.json', 'not json');
    await broken.write('auto_backup_20261004.json', '{"ok":true}');

    await tester.pumpWidget(_wrap(AutoBackupScreen(
      store: broken,
      now: () => now,
      restorer: _FakeRestorer(),
      sharer: _FakeSharer(),
    )));
    await _settle(tester);

    expect(
        find.byKey(
            const ValueKey('auto_backup_restore_auto_backup_20261005.json')),
        findsNothing);
    expect(
        find.byKey(
            const ValueKey('auto_backup_restore_auto_backup_20261004.json')),
        findsOneWidget);
    expect(
        find.byKey(
            const ValueKey('auto_backup_share_auto_backup_20261005.json')),
        findsOneWidget);
  });

  testWidgets('未注入なら復元・共有の導線を出さない', (tester) async {
    await tester
        .pumpWidget(_wrap(AutoBackupScreen(store: store, now: () => now)));
    await _settle(tester);

    expect(find.byIcon(Icons.restore), findsNothing);
    expect(find.byIcon(Icons.ios_share), findsNothing);
    expect(
      find.byKey(
          const ValueKey('auto_backup_restore_auto_backup_20261003.json')),
      findsNothing,
    );
  });

  testWidgets('確認ダイアログ OK で復元が呼ばれ、結果が SnackBar に出る', (tester) async {
    final restorer = _FakeRestorer();
    await tester.pumpWidget(_wrap(AutoBackupScreen(
      store: store,
      now: () => now,
      restorer: restorer,
    )));
    await _settle(tester);

    await tester.tap(find.byKey(
        const ValueKey('auto_backup_restore_auto_backup_20261003.json')));
    await _settle(tester);

    expect(find.text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'), findsOneWidget);

    await tester.tap(find.text('復元する'));
    await _settle(tester);

    expect(restorer.restored, ['auto_backup_20261003.json']);
    expect(find.text('復元しました'), findsOneWidget);
  });

  testWidgets('確認ダイアログ キャンセルでは復元を呼ばない', (tester) async {
    final restorer = _FakeRestorer();
    await tester.pumpWidget(_wrap(AutoBackupScreen(
      store: store,
      now: () => now,
      restorer: restorer,
    )));
    await _settle(tester);

    await tester.tap(find.byKey(
        const ValueKey('auto_backup_restore_auto_backup_20261003.json')));
    await _settle(tester);
    await tester.tap(find.text('キャンセル'));
    await _settle(tester);

    expect(restorer.restored, isEmpty);
  });

  testWidgets('復元が例外を投げても SnackBar に収める', (tester) async {
    await tester.pumpWidget(_wrap(AutoBackupScreen(
      store: store,
      now: () => now,
      restorer: _ThrowingRestorer(),
    )));
    await _settle(tester);

    await tester.tap(find.byKey(
        const ValueKey('auto_backup_restore_auto_backup_20261003.json')));
    await _settle(tester);
    await tester.tap(find.text('復元する'));
    await _settle(tester);

    expect(find.textContaining('復元に失敗しました'), findsOneWidget);
  });

  testWidgets('共有ボタンで read した JSON を渡す', (tester) async {
    final sharer = _FakeSharer();
    await tester.pumpWidget(_wrap(AutoBackupScreen(
      store: store,
      now: () => now,
      sharer: sharer,
    )));
    await _settle(tester);

    await tester.tap(find
        .byKey(const ValueKey('auto_backup_share_auto_backup_20261003.json')));
    await _settle(tester);

    expect(sharer.sharedNames, ['auto_backup_20261003.json']);
    expect(sharer.sharedBodies, ['{"day":3}']);
  });

  testWidgets('onBackupNow があれば実行後に一覧を再読込する', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_wrap(AutoBackupScreen(
      store: store,
      now: () => now,
      onBackupNow: () async {
        calls++;
        await store.write('auto_backup_20261009.json', '{"day":9}');
      },
    )));
    await _settle(tester);

    expect(
        find.byKey(const ValueKey('auto_backup_backup_now')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('auto_backup_backup_now')));
    await _settle(tester);

    expect(calls, 1);
    expect(
        find.byKey(const ValueKey('auto_backup_row_auto_backup_20261009.json')),
        findsOneWidget);
  });

  testWidgets('onBackupNow 未注入ならボタンを出さない', (tester) async {
    await tester
        .pumpWidget(_wrap(AutoBackupScreen(store: store, now: () => now)));
    await _settle(tester);

    expect(find.byKey(const ValueKey('auto_backup_backup_now')), findsNothing);
  });

  testWidgets('保持世代ラベルを表示する', (tester) async {
    await tester.pumpWidget(_wrap(AutoBackupScreen(
      store: store,
      policy: const AutoBackupPolicy(keep: 5),
      now: () => now,
    )));
    await _settle(tester);

    expect(find.text('保持 5世代中 3件'), findsOneWidget);
  });
}

/// 常に例外を投げる復元役
class _ThrowingRestorer implements AutoBackupRestorer {
  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async =>
      throw StateError('boom');
}
