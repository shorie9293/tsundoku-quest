/// 設定つき復元（AutoBackupRestorerWithOptions）と復元確認ダイアログの試練
///
/// 改善提案: 自動バックアップが設定も運び、復元時に「設定も戻すか」を選べる。
/// 既存の AutoBackupRestorer だけを実装するフェイクは従来経路のまま動くこと。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:tsundoku_quest/features/auto_backup/presentation/auto_backup_screen.dart';

/// 設定の有無を記録する復元役（旧インタフェースのみ）
class _LegacyRestorer implements AutoBackupRestorer {
  final List<String> restored = [];

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    restored.add(fileName);
    return const AutoBackupRestoreResult(ok: true, message: '復元しました');
  }
}

/// 設定の有無を記録する復元役（新インタフェース）
class _OptionsRestorer implements AutoBackupRestorerWithOptions {
  final List<String> restored = [];
  final List<bool> includeSettings = [];

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    restored.add(fileName);
    return const AutoBackupRestoreResult(ok: true, message: '復元しました');
  }

  @override
  Future<AutoBackupRestoreResult> restoreWithOptions(
    String fileName, {
    bool includeSettings = true,
  }) async {
    restored.add(fileName);
    this.includeSettings.add(includeSettings);
    return const AutoBackupRestoreResult(ok: true, message: '復元しました');
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('AutoBackupRestorerImpl.restoreWithOptions', () {
    late InMemoryAutoBackupStore store;
    late List<String> applied;
    late List<bool> includeFlags;
    late int rescheduleCount;

    setUp(() async {
      store = InMemoryAutoBackupStore(now: () => DateTime(2026, 11, 9, 9));
      await store.write('auto_backup_20261108.json', '{"day":8}');
      applied = [];
      includeFlags = [];
      rescheduleCount = 0;
    });

    AutoBackupRestorerImpl build({
      bool withOptions = true,
      bool rescheduleThrows = false,
    }) =>
        AutoBackupRestorerImpl(
          store: store,
          now: () => DateTime(2026, 11, 9, 9),
          buildCurrentJson: () async => '{"current":true}',
          applyBackup: (json) async {
            applied.add(json);
          },
          applyBackupWithOptions: withOptions
              ? (json, includeSettings) async {
                  applied.add(json);
                  includeFlags.add(includeSettings);
                }
              : null,
          onSettingsRestored: () async {
            rescheduleCount++;
            if (rescheduleThrows) throw StateError('reschedule failed');
          },
        );

    test('restoreWithOptions は includeSettings を下流へ渡す', () async {
      final result = await build().restoreWithOptions(
          'auto_backup_20261108.json',
          includeSettings: false);

      expect(result.ok, isTrue);
      expect(includeFlags, [false]);
      expect(applied, ['{"day":8}']);
    });

    test('既定は設定も戻す（includeSettings:true）', () async {
      final result =
          await build().restoreWithOptions('auto_backup_20261108.json');

      expect(result.ok, isTrue);
      expect(includeFlags, [true]);
    });

    test('設定適用後に通知の再予約を呼ぶ', () async {
      await build().restoreWithOptions('auto_backup_20261108.json');
      await Future<void>.delayed(Duration.zero);

      expect(rescheduleCount, 1);
    });

    test('includeSettings:false なら再予約を呼ばない', () async {
      await build().restoreWithOptions('auto_backup_20261108.json',
          includeSettings: false);
      await Future<void>.delayed(Duration.zero);

      expect(rescheduleCount, 0);
    });

    test('再予約が例外を投げても復元結果は ok のまま（例外非波及）', () async {
      final result = await build(rescheduleThrows: true)
          .restoreWithOptions('auto_backup_20261108.json');
      await Future<void>.delayed(Duration.zero);

      expect(result.ok, isTrue);
      expect(rescheduleCount, 1);
    });

    test('従来 restore も新経路を既定値で通る（後方互換）', () async {
      final result = await build().restore('auto_backup_20261108.json');

      expect(result.ok, isTrue);
      expect(includeFlags, [true]);
    });

    test('applyBackupWithOptions 未注入なら従来の applyBackup に落ちる', () async {
      final result = await build(withOptions: false)
          .restoreWithOptions('auto_backup_20261108.json');

      expect(result.ok, isTrue);
      expect(applied, ['{"day":8}']);
      expect(includeFlags, isEmpty);
    });
  });

  group('AutoBackupScreen 復元確認ダイアログ', () {
    late InMemoryAutoBackupStore store;
    final now = DateTime(2026, 11, 9, 9, 30);

    setUp(() async {
      store = InMemoryAutoBackupStore(now: () => now);
      await store.write('auto_backup_20261108.json', '{"day":8}');
    });

    Future<void> openDialog(
        WidgetTester tester, AutoBackupRestorer restorer) async {
      await tester.pumpWidget(_wrap(AutoBackupScreen(
        store: store,
        now: () => now,
        restorer: restorer,
      )));
      await _settle(tester);
      await tester.tap(find.byKey(
          const ValueKey('auto_backup_restore_auto_backup_20261108.json')));
      await _settle(tester);
    }

    testWidgets('チェックボックスは既定ONで、そのまま復元すると設定も戻す', (tester) async {
      final restorer = _OptionsRestorer();
      await openDialog(tester, restorer);

      final checkbox = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('auto_backup_restore_include_settings')),
      );
      expect(checkbox.value, isTrue);
      expect(
        find.text('設定も戻す（テーマ・文字サイズ・静穏時間・リマインダー）'),
        findsOneWidget,
      );

      await tester.tap(find.text('復元する'));
      await _settle(tester);

      expect(restorer.restored, ['auto_backup_20261108.json']);
      expect(restorer.includeSettings, [true]);
    });

    testWidgets('チェックを外すと includeSettings:false で復元する', (tester) async {
      final restorer = _OptionsRestorer();
      await openDialog(tester, restorer);

      await tester.tap(
          find.byKey(const ValueKey('auto_backup_restore_include_settings')));
      await _settle(tester);

      await tester.tap(find.text('復元する'));
      await _settle(tester);

      expect(restorer.includeSettings, [false]);
    });

    testWidgets('旧インタフェースの復元役には従来 restore を呼ぶ', (tester) async {
      final restorer = _LegacyRestorer();
      await openDialog(tester, restorer);

      await tester.tap(find.text('復元する'));
      await _settle(tester);

      expect(restorer.restored, ['auto_backup_20261108.json']);
      expect(find.text('復元しました'), findsOneWidget);
    });

    testWidgets('キャンセルならチェック状態に関わらず復元しない', (tester) async {
      final restorer = _OptionsRestorer();
      await openDialog(tester, restorer);

      await tester.tap(find.text('キャンセル'));
      await _settle(tester);

      expect(restorer.restored, isEmpty);
    });
  });
}
