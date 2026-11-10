/// 復元前プレビュー（純粋層）の試練
///
/// 受入: ①内訳（件数＋先頭サンプル） ②0件/破損/空/巨大で throw しない
/// ③意味論が適用側（mergeBackup / restore）と一致する
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/restore_preview.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_settings_spec.dart';

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

ReadingSession _session(String id) => ReadingSession(
      id: id,
      userBookId: 'ub-$id',
      startedAt: '2026-01-03T00:00:00Z',
      startPage: 0,
      createdAt: '2026-01-03T00:00:00Z',
    );

BackupData _data({
  List<UserBook> books = const [],
  List<ReadingSession> sessions = const [],
  ReadingGoalSnapshot? goal,
  Map<String, Object?>? settings,
}) =>
    BackupData(
      exportedAt: '2026-10-01T00:00:00Z',
      books: books,
      sessions: sessions,
      goal: goal,
      settings:
          settings == null ? null : BackupSettingsBundle(values: settings),
    );

void main() {
  group('diffBackup は適用側と同じ意味論', () {
    test('既存 id の蔵書は上書きされず「変更なし」になる', () {
      final diff = diffBackup(
        incoming: _data(books: [_ub('a', title: '吾輩は猫である'), _ub('b')]),
        existing: _data(books: [_ub('a', title: '別名')]),
      );

      expect(diff.created, 1);
      expect(diff.restored, 0);
      expect(diff.unchanged, 1);
    });

    test('設定は差分キーだけが上書き・未所持キーは新規', () {
      final diff = diffBackup(
        incoming: _data(settings: {
          'tsundoku_theme_mode': 'light',
          'tsundoku_text_scale': 1.2,
        }),
        existing: _data(settings: {'tsundoku_theme_mode': 'dark'}),
      );

      expect(diff.created, 1);
      expect(diff.restored, 1);
      expect(diff.unchanged, 0);
      expect(diff.toOverwrite.keys.single, '設定「テーマ」');
      expect(diff.toCreate.keys.single, '設定「文字サイズ」');
    });

    test('同値の設定は変更なし', () {
      final diff = diffBackup(
        incoming: _data(settings: {'tsundoku_theme_mode': 'dark'}),
        existing: _data(settings: {'tsundoku_theme_mode': 'dark'}),
      );

      expect(diff.created, 0);
      expect(diff.restored, 0);
      expect(diff.unchanged, 1);
    });

    test('読書目標は新規エントリがある時だけ上書き扱い', () {
      final incoming = _data(
        books: [_ub('a')],
        goal: const ReadingGoalSnapshot(monthlyTarget: 5, yearlyTarget: 50),
      );
      final existing = _data(
        goal: const ReadingGoalSnapshot(monthlyTarget: 3, yearlyTarget: 30),
      );

      final diff = diffBackup(incoming: incoming, existing: existing);
      expect(diff.toOverwrite.containsKey('読書目標'), isTrue);
      expect(diff.toOverwrite['読書目標'], isNotNull);
    });

    test('新規エントリが無ければ読書目標は計上しない（適用側の条件）', () {
      final diff = diffBackup(
        incoming: _data(
          goal: const ReadingGoalSnapshot(monthlyTarget: 5),
        ),
        existing: _data(
          goal: const ReadingGoalSnapshot(monthlyTarget: 3),
        ),
      );

      expect(diff.isEmpty, isTrue);
      expect(diff.unchanged, 0);
    });
  });

  group('RestorePreview', () {
    test('許可リスト外の設定キーも表示ラベル付きで数える', () {
      final diff = diffBackup(
        incoming: _data(settings: {'unknown_key': 'x'}),
        existing: _data(),
      );

      final preview = RestorePreview.build(diff);
      expect(preview.created, 1);
      expect(preview.total, 1);
      expect(preview.overwriteSampleKeys, isEmpty);
    });

    test('8件の上書きは先頭5件＋ほか3件', () {
      final diff = diffBackup(
        incoming: _data(settings: {
          for (var i = 0; i < kBackupSettingSpecs.length; i++)
            if (!kBackupSettingSpecs[i].isSecret)
              kBackupSettingSpecs[i].key: 'v$i',
        }),
        existing: _data(settings: {
          for (var i = 0; i < kBackupSettingSpecs.length; i++)
            if (!kBackupSettingSpecs[i].isSecret)
              kBackupSettingSpecs[i].key: 'old',
        }),
      );

      final preview = RestorePreview.build(diff);
      expect(preview.overwritten, greaterThan(5));
      expect(preview.overwriteSampleKeys, hasLength(5));
      expect(preview.hiddenOverwriteCount,
          preview.overwritten - preview.overwriteSampleKeys.length);
      expect(preview.samplesText, contains('ほか'));
    });

    test('上書き0件なら samplesText は null', () {
      final diff = diffBackup(
        incoming: _data(books: [_ub('a')]),
        existing: _data(),
      );
      final preview = RestorePreview.build(diff);

      expect(preview.summary, '新規 1件 / 上書き 0件 / 変更なし 0件');
      expect(preview.samplesText, isNull);
      expect(preview.message, '既存データは上書きされません（新規データのみ追加されます）');
    });

    test('0件は「復元対象のデータはありません」', () {
      final preview = RestorePreview.build(
        diffBackup(incoming: _data(), existing: _data()),
      );

      expect(preview.total, 0);
      expect(preview.hasChanges, isFalse);
      expect(preview.message, '復元対象のデータはありません');
    });

    test('sampleLimit が 0 以下でも throw せず既定に丸める', () {
      final preview = RestorePreview.build(
        diffBackup(
          incoming: _data(settings: {'tsundoku_theme_mode': 'light'}),
          existing: _data(settings: {'tsundoku_theme_mode': 'dark'}),
        ),
        sampleLimit: 0,
      );

      expect(preview.overwriteSampleKeys, hasLength(1));
    });

    test('巨大入力でも throw せず全件数える', () {
      final books = <UserBook>[for (var i = 0; i < 3000; i++) _ub('id$i')];

      final preview = compose(
        incoming: _data(books: books),
        existing: _data(),
      );

      expect(preview, isNotNull);
      expect(preview!.created, 3000);
      expect(preview.overwriteSampleKeys, isEmpty);
    });

    test('壊れた設定値でも compose は throw しない', () {
      final preview = compose(
        incoming: _data(settings: {
          'tsundoku_theme_mode': <String, Object?>{
            'nested': [1, 2, 3]
          },
        }),
        existing: _data(settings: {'tsundoku_theme_mode': 'dark'}),
      );

      expect(preview, isNotNull);
      expect(preview!.overwritten, 1);
    });

    test('空の束でも compose は null を返さず0件になる', () {
      final preview = compose(
        incoming: _data(),
        existing: _data(sessions: [_session('s1')]),
      );

      expect(preview, isNotNull);
      expect(preview!.total, 0);
    });
  });
}
