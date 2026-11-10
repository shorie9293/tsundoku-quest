/// 復元確認ダイアログの内訳プレビュー（配線）の試練
///
/// 受入: ①内訳（件数＋先頭サンプル）表示 ②0件/取得失敗で非表示・throw なし
/// ③狭幅 360x640 で overflow しない ④確認/キャンセル導線は不変
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:tsundoku_quest/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:tsundoku_quest/features/backup/data/backup_repository.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_settings_spec.dart';
import 'package:tsundoku_quest/features/backup/presentation/backup_keys.dart';
import 'package:tsundoku_quest/features/backup/presentation/backup_screen.dart';

UserBook _ub(String id, {String title = '本'}) => UserBook(
      id: id,
      userId: 'u1',
      bookId: 'book-$id',
      book: Book(
        id: 'book-$id',
        title: title,
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      ),
      status: BookStatus.tsundoku,
      medium: BookMedium.physical,
      createdAt: '2026-01-02T00:00:00Z',
    );

BackupData _data({
  List<UserBook> books = const [],
  Map<String, Object?>? settings,
}) =>
    BackupData(
      exportedAt: '2026-10-01T00:00:00Z',
      books: books,
      settings:
          settings == null ? null : BackupSettingsBundle(values: settings),
    );

String _json(BackupData data) => jsonEncode(data.toJson());

/// 復元呼び出しを記録するフェイク
class _FakeRestorer implements AutoBackupRestorer {
  final List<String> restored = [];

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    restored.add(fileName);
    return const AutoBackupRestoreResult(ok: true, message: '復元しました');
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _wrap(Widget child) => MaterialApp(home: child);

/// 狭幅（360x640）に固定する
void _narrow(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('自動バックアップ画面の復元確認', () {
    late InMemoryAutoBackupStore store;
    final now = DateTime(2026, 10, 29, 9, 30);

    setUp(() async {
      store = InMemoryAutoBackupStore(now: () => now);
    });

    testWidgets('内訳（件数＋上書きサンプル）を表示する', (tester) async {
      await store.write(
        'auto_backup_20261003.json',
        _json(_data(books: [
          _ub('a'),
          _ub('b', title: '新刊')
        ], settings: {
          'tsundoku_theme_mode': 'light',
        })),
      );

      await tester.pumpWidget(_wrap(AutoBackupScreen(
        store: store,
        now: () => now,
        restorer: _FakeRestorer(),
        collectCurrent: () async => _data(
          books: [_ub('a')],
          settings: {'tsundoku_theme_mode': 'dark'},
        ),
      )));
      await _settle(tester);

      await tester.tap(find.byKey(
          const ValueKey('auto_backup_restore_auto_backup_20261003.json')));
      await _settle(tester);

      final summary = tester
          .widget<Text>(find.byKey(AppKeys.autoBackupRestorePreviewSummary));
      expect(summary.data, '新規 1件 / 上書き 1件 / 変更なし 1件');

      final samples = tester
          .widget<Text>(find.byKey(AppKeys.autoBackupRestorePreviewSamples));
      expect(samples.data, contains('上書きされるキー'));
      expect(samples.data, contains('設定「テーマ」'));

      // 既存の本文・スイッチ・ボタンは不変
      expect(
        find.text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('auto_backup_restore_include_settings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('auto_backup_restore_cancel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('auto_backup_restore_confirm')),
        findsOneWidget,
      );
    });

    testWidgets('0件ならプレビューを出さず従来表示のまま', (tester) async {
      await store.write(
        'auto_backup_20261004.json',
        '{"tsundoku_quest_backup":true,"version":1,'
            '"books":[],"readingSessions":[]}',
      );

      await tester.pumpWidget(_wrap(AutoBackupScreen(
        store: store,
        now: () => now,
        restorer: _FakeRestorer(),
        collectCurrent: () async => _data(),
      )));
      await _settle(tester);

      await tester.tap(find.byKey(
          const ValueKey('auto_backup_restore_auto_backup_20261004.json')));
      await _settle(tester);

      expect(find.byKey(AppKeys.autoBackupRestorePreviewSummary), findsNothing);
      expect(find.byKey(AppKeys.autoBackupRestorePreviewSamples), findsNothing);
      expect(
        find.text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('取得失敗（collectCurrent 例外）でもダイアログは出る', (tester) async {
      await store.write(
        'auto_backup_20261005.json',
        _json(_data(books: [_ub('a')])),
      );

      await tester.pumpWidget(_wrap(AutoBackupScreen(
        store: store,
        now: () => now,
        restorer: _FakeRestorer(),
        collectCurrent: () async => throw StateError('boom'),
      )));
      await _settle(tester);

      await tester.tap(find.byKey(
          const ValueKey('auto_backup_restore_auto_backup_20261005.json')));
      await _settle(tester);

      expect(find.byKey(AppKeys.autoBackupRestorePreviewSummary), findsNothing);
      expect(
        find.byKey(const ValueKey('auto_backup_restore_confirm')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('狭幅 360x640 でも内訳つきダイアログが overflow しない', (tester) async {
      _narrow(tester);
      await store.write(
        'auto_backup_20261006.json',
        _json(_data(
          books: [for (var i = 0; i < 40; i++) _ub('id$i')],
          settings: {
            for (final spec in kBackupSettingSpecs)
              if (!spec.isSecret) spec.key: 'incoming',
          },
        )),
      );

      await tester.pumpWidget(_wrap(AutoBackupScreen(
        store: store,
        now: () => now,
        restorer: _FakeRestorer(),
        collectCurrent: () async => _data(settings: {
          for (final spec in kBackupSettingSpecs)
            if (!spec.isSecret) spec.key: 'current',
        }),
      )));
      await _settle(tester);

      await tester.tap(find.byKey(
          const ValueKey('auto_backup_restore_auto_backup_20261006.json')));
      await _settle(tester);

      expect(
          find.byKey(AppKeys.autoBackupRestorePreviewSummary), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('確認で復元・キャンセルで復元しない（導線不変）', (tester) async {
      await store.write(
        'auto_backup_20261007.json',
        _json(_data(books: [_ub('a')])),
      );
      final restorer = _FakeRestorer();

      await tester.pumpWidget(_wrap(AutoBackupScreen(
        store: store,
        now: () => now,
        restorer: restorer,
        collectCurrent: () async => _data(),
      )));
      await _settle(tester);

      await tester.tap(find.byKey(
          const ValueKey('auto_backup_restore_auto_backup_20261007.json')));
      await _settle(tester);
      await tester
          .tap(find.byKey(const ValueKey('auto_backup_restore_cancel')));
      await _settle(tester);
      expect(restorer.restored, isEmpty);

      await tester.tap(find.byKey(
          const ValueKey('auto_backup_restore_auto_backup_20261007.json')));
      await _settle(tester);
      await tester
          .tap(find.byKey(const ValueKey('auto_backup_restore_confirm')));
      await _settle(tester);

      expect(restorer.restored, ['auto_backup_20261007.json']);
    });
  });

  group('手動リストア画面', () {
    testWidgets('取り込み後の結果に内訳を添える', (tester) async {
      final repo = InMemoryBackupRepository(books: [_ub('a')]);
      await tester.pumpWidget(_wrap(BackupScreen(repository: repo)));
      await tester.pumpAndSettle();

      final payload = _json(_data(books: [_ub('a'), _ub('b')]));
      await tester.enterText(find.byKey(BackupKeys.importField), payload);
      await tester.tap(find.byKey(BackupKeys.importButton));
      await tester.pumpAndSettle();

      final message =
          tester.widget<Text>(find.byKey(BackupKeys.resultMessage)).data!;
      expect(message, contains('復元しました'));
      expect(message, contains('新規 1件 / 上書き 0件 / 変更なし 1件'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('0件なら内訳を添えない（本文は従来どおり）', (tester) async {
      final repo = InMemoryBackupRepository(books: [_ub('a')]);
      await tester.pumpWidget(_wrap(BackupScreen(repository: repo)));
      await tester.pumpAndSettle();

      final payload = _json(_data());
      await tester.enterText(find.byKey(BackupKeys.importField), payload);
      await tester.tap(find.byKey(BackupKeys.importButton));
      await tester.pumpAndSettle();

      final message =
          tester.widget<Text>(find.byKey(BackupKeys.resultMessage)).data!;
      expect(message, contains('復元しました'));
      expect(message, isNot(contains('新規 0件')));
      expect(tester.takeException(), isNull);
    });
  });
}
