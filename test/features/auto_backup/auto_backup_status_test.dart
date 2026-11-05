/// 自動バックアップ失敗の可視化に関する試練。
///
/// 改善提案 #188 続編（book-review-app の実装を現世へ写経）。
/// ①失敗記録 ②成功で復帰 ③未試行 ④失敗表示 ⑤最終成功表示
/// ⑥now 注入 ⑦既存 policy 挙動不変 ⑧負の失敗回数 ⑨JSON 往復・破損耐性
/// ⑩File store 往復・一覧非表示 ⑪service の記録 ⑫設定ハブのバッジ
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_service.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_status.dart';
import 'package:tsundoku_quest/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:tsundoku_quest/features/settings/presentation/settings_hub_screen.dart';

void main() {
  final now = DateTime(2026, 11, 5, 9, 30);

  group('AutoBackupStatus', () {
    test('失敗を記録すると回数が増え理由が残る', () {
      final status = AutoBackupStatus.initial
          .recordFailure(now, StateError('容量不足'))
          .recordFailure(
            now.add(const Duration(hours: 1)),
            StateError('権限なし'),
          );

      expect(status.consecutiveFailures, 2);
      expect(status.lastError, contains('権限なし'));
      expect(status.lastAttemptAt, now.add(const Duration(hours: 1)));
      expect(status.lastSuccessAt, isNull);
      expect(status.hasFailed, isTrue);
      expect(status.hasAttempted, isTrue);
    });

    test('成功で回数が0に戻り最終成功が更新される', () {
      final failed = AutoBackupStatus.initial.recordFailure(now, 'boom');
      final ok = failed.recordSuccess(now.add(const Duration(days: 1)));

      expect(ok.consecutiveFailures, 0);
      expect(ok.lastError, isNull);
      expect(ok.lastSuccessAt, now.add(const Duration(days: 1)));
      expect(ok.lastAttemptAt, now.add(const Duration(days: 1)));
      expect(ok.hasFailed, isFalse);
    });

    test('成功後も最終成功時刻は失敗記録で保持される', () {
      final ok = AutoBackupStatus.initial.recordSuccess(now);
      final failed = ok.recordFailure(now.add(const Duration(days: 1)), 'x');

      expect(failed.lastSuccessAt, now);
      expect(failed.consecutiveFailures, 1);
    });

    test('連続失敗が閾値に達すると劣化とみなす', () {
      var status = AutoBackupStatus.initial;
      for (var i = 0; i < AutoBackupStatus.degradedThreshold; i++) {
        status = status.recordFailure(now, 'x');
      }
      expect(status.isDegraded, isTrue);
      expect(
        AutoBackupStatus.initial.recordFailure(now, 'x').isDegraded,
        isFalse,
      );
    });

    test('未試行は hasAttempted が false で初期状態のまま', () {
      final status = AutoBackupStatus.initial;
      expect(status.hasAttempted, isFalse);
      expect(status.hasFailed, isFalse);
      expect(status.lastSuccessAt, isNull);
      expect(status.lastAttemptAt, isNull);
      expect(status.lastError, isNull);
    });

    test('負の失敗回数は ArgumentError（assert ではない）', () {
      expect(
        () => AutoBackupStatus(consecutiveFailures: -1),
        throwsArgumentError,
      );
    });

    test('失敗回数があるのに理由が無い状態は ArgumentError', () {
      expect(
        () => AutoBackupStatus(consecutiveFailures: 1),
        throwsArgumentError,
      );
    });

    test('JSON 往復で値が保たれる', () {
      final status = AutoBackupStatus.initial
          .recordSuccess(now)
          .recordFailure(now.add(const Duration(hours: 2)), 'disk full');
      final restored = AutoBackupStatus.fromJson(status.toJson());

      expect(restored.lastSuccessAt, status.lastSuccessAt);
      expect(restored.lastAttemptAt, status.lastAttemptAt);
      expect(restored.lastError, status.lastError);
      expect(restored.consecutiveFailures, status.consecutiveFailures);
    });

    test('壊れた JSON は初期状態へ落ちて例外を投げない', () {
      final restored = AutoBackupStatus.fromJson(<String, Object?>{
        'lastSuccessAt': 'not-a-date',
        'consecutiveFailures': 'x',
      });
      expect(restored.consecutiveFailures, 0);
      expect(restored.lastSuccessAt, isNull);
      expect(restored.lastError, isNull);
    });

    test('長すぎる失敗理由は1行に切り詰める', () {
      final long = 'a' * 500;
      final status = AutoBackupStatus.initial.recordFailure(now, long);
      expect(status.lastError!.length, lessThanOrEqualTo(121));
      expect(status.lastError, isNot(contains('\n')));
    });
  });

  group('AutoBackupStatusStore', () {
    late Directory dir;

    setUp(() {
      dir = Directory('${Directory.current.path}/.dart_tool/status_test')
        ..createSync(recursive: true);
      for (final entity in dir.listSync()) {
        entity.deleteSync(recursive: true);
      }
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('ファイルへ保存して読み戻せる', () async {
      final store =
          FileAutoBackupStatusStore(directoryResolver: () async => dir);
      expect(await store.load(), isNull);

      await store.save(AutoBackupStatus.initial.recordFailure(now, 'boom'));
      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.consecutiveFailures, 1);
      expect(loaded.lastError, contains('boom'));
      expect(loaded.lastAttemptAt, now);
    });

    test('状態ファイルは自動バックアップ一覧に現れない', () async {
      final statusStore =
          FileAutoBackupStatusStore(directoryResolver: () async => dir);
      await statusStore.save(AutoBackupStatus.initial.recordSuccess(now));

      final backupStore =
          FileAutoBackupStore(directoryResolver: () async => dir);
      expect(await backupStore.list(), isEmpty);
    });

    test('壊れた状態ファイルは null として扱う', () async {
      File('${dir.path}/${FileAutoBackupStatusStore.fileName}')
          .writeAsStringSync('not json');
      final store =
          FileAutoBackupStatusStore(directoryResolver: () async => dir);
      expect(await store.load(), isNull);
    });
  });

  group('AutoBackupService の状態記録', () {
    test('成功で最終成功が記録される', () async {
      final statusStore = InMemoryAutoBackupStatusStore();
      final service = AutoBackupService(
        store: InMemoryAutoBackupStore(now: () => now),
        statusStore: statusStore,
        now: () => now,
      );

      final result = await service.run(() async => '{"books":[]}');
      final status = await statusStore.load();

      expect(result.ran, isTrue);
      expect(status!.lastSuccessAt, now);
      expect(status.consecutiveFailures, 0);
    });

    test('失敗で連続失敗が増え、例外は外へ出ない', () async {
      final statusStore = InMemoryAutoBackupStatusStore();
      final service = AutoBackupService(
        store: InMemoryAutoBackupStore(now: () => now),
        statusStore: statusStore,
        now: () => now,
      );

      final result = await service.run(() async => throw StateError('boom'));
      final status = await statusStore.load();

      expect(result.error, isNotNull);
      expect(status!.consecutiveFailures, 1);
      expect(status.lastError, contains('boom'));
      expect(status.lastSuccessAt, isNull);
    });

    test('記録先が無くても従来どおり動く（後方互換）', () async {
      final service = AutoBackupService(
        store: InMemoryAutoBackupStore(now: () => now),
        now: () => now,
      );
      final result = await service.run(() async => '{"books":[]}');
      expect(result.ran, isTrue);
      expect(await service.loadStatus(), isNull);
    });

    test('スキップ（24時間未経過）では状態を書き換えない', () async {
      final statusStore = InMemoryAutoBackupStatusStore();
      final store = InMemoryAutoBackupStore(now: () => now);
      await store.write('auto_backup_20261105.json', '{"books":[]}');

      final service = AutoBackupService(
        store: store,
        statusStore: statusStore,
        now: () => now,
      );
      final result = await service.run(() async => '{"books":[]}');

      expect(result.ran, isFalse);
      expect(result.error, isNull);
      expect(await statusStore.load(), isNull);
    });
  });

  group('既存 policy の挙動不変', () {
    test('同日は再実行しない（冪等）・翌日は実行する', () {
      const policy = AutoBackupPolicy();
      expect(policy.shouldRun(lastAt: now, now: now), isFalse);
      expect(
        policy.shouldRun(lastAt: now, now: now.add(const Duration(days: 1))),
        isTrue,
      );
      expect(policy.shouldRun(lastAt: null, now: now), isTrue);
      expect(AutoBackupPolicy.fileNameFor(now), 'auto_backup_20261105.json');
    });
  });

  group('AutoBackupScreen の状態表示', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required AutoBackupStatusStore statusStore,
      InMemoryAutoBackupStore? store,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AutoBackupScreen(
            store: store ?? InMemoryAutoBackupStore(now: () => now),
            statusStore: statusStore,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('一度も試行が無ければ「まだありません」', (tester) async {
      await pumpScreen(tester, statusStore: InMemoryAutoBackupStatusStore());

      expect(find.byKey(const ValueKey('auto_backup_empty')), findsOneWidget);
      expect(find.text('バックアップはまだありません'), findsOneWidget);
      expect(find.byKey(AppKeys.autoBackupFailureBanner), findsNothing);
      expect(find.byKey(AppKeys.autoBackupLastSuccess), findsNothing);
    });

    testWidgets('失敗ありは失敗文言と最終試行時刻を出す', (tester) async {
      final statusStore = InMemoryAutoBackupStatusStore(
        AutoBackupStatus.initial.recordFailure(now, '容量不足'),
      );
      await pumpScreen(tester, statusStore: statusStore);

      expect(find.byKey(AppKeys.autoBackupFailureBanner), findsOneWidget);
      expect(find.textContaining('自動バックアップに失敗しています'), findsOneWidget);
      expect(find.textContaining('2026-11-05 09:30'), findsOneWidget);
      expect(find.textContaining('容量不足'), findsOneWidget);
      // 未実行の文言は出さない（未実行と失敗を同じ見た目にしない）。
      expect(find.text('バックアップはまだありません'), findsNothing);
    });

    testWidgets('失敗バナーに再試行ボタンを出す（onBackupNow 注入時）', (tester) async {
      var called = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AutoBackupScreen(
            store: InMemoryAutoBackupStore(now: () => now),
            statusStore: InMemoryAutoBackupStatusStore(
              AutoBackupStatus.initial.recordFailure(now, 'x'),
            ),
            onBackupNow: () async {
              called++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.autoBackupRetry));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets('成功ありは最終成功時刻を出す', (tester) async {
      final statusStore = InMemoryAutoBackupStatusStore(
        AutoBackupStatus.initial.recordSuccess(now),
      );
      await pumpScreen(tester, statusStore: statusStore);

      expect(find.byKey(AppKeys.autoBackupLastSuccess), findsOneWidget);
      expect(find.textContaining('最終成功 2026-11-05 09:30'), findsOneWidget);
      expect(find.byKey(AppKeys.autoBackupFailureBanner), findsNothing);
    });

    testWidgets('状態の読み出し元が無ければ従来表示のまま', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AutoBackupScreen(
            store: InMemoryAutoBackupStore(now: () => now),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('バックアップはまだありません'), findsOneWidget);
      expect(find.byKey(AppKeys.autoBackupFailureBanner), findsNothing);
      expect(find.byKey(AppKeys.autoBackupLastSuccess), findsNothing);
    });
  });

  group('設定ハブの警告バッジ', () {
    testWidgets('連続失敗が閾値以上なら警告文言を出す', (tester) async {
      var status = AutoBackupStatus.initial;
      for (var i = 0; i < AutoBackupStatus.degradedThreshold; i++) {
        status = status.recordFailure(now, 'x');
      }
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsHubScreen(
            autoBackupStatusStore: InMemoryAutoBackupStatusStore(status),
            autoBackupBuilder: (_) => const Scaffold(body: Text('body')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final entry = find.byKey(AppKeys.settingsHubItem('auto_backup'));
      await tester.scrollUntilVisible(
        entry,
        80,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('自動バックアップに失敗しています'), findsOneWidget);
      expect(
        find.textContaining('（${AutoBackupStatus.degradedThreshold}回連続）'),
        findsOneWidget,
      );
    });

    testWidgets('健全なら通常の説明文のまま（警告は出さない）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsHubScreen(
            autoBackupStatusStore: InMemoryAutoBackupStatusStore(
              AutoBackupStatus.initial.recordSuccess(now),
            ),
            autoBackupBuilder: (_) => const Scaffold(body: Text('body')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.settingsHubItem('auto_backup')), findsOneWidget);
      expect(find.textContaining('自動バックアップに失敗しています'), findsNothing);
    });
  });
}
