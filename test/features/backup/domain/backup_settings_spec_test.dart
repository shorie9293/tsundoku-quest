/// バックアップに載せる設定の許可リスト／純粋変換の試練
///
/// 改善提案: 自動バックアップが設定（テーマ・文字サイズ・静穏時間・
/// リマインダー・チュートリアル既読）も運ぶ。
/// 秘密（app_lock・トークン・Supabase セッション）は絶対に載せない。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_settings_spec.dart';

void main() {
  group('kBackupSettingSpecs', () {
    test('設定とチュートリアルの両カテゴリが許可リストに載っている', () {
      final categories = kBackupSettingSpecs.map((s) => s.category).toSet();
      expect(categories, containsAll(BackupSettingCategory.values));
    });

    test('キーは重複しない（last-wins の事故を防ぐ）', () {
      final keys = kBackupSettingSpecs.map((s) => s.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('主要な設定キーが許可リストに載っている', () {
      final keys = kBackupSettingSpecs.map((s) => s.key).toSet();
      expect(
        keys,
        containsAll(<String>[
          'tsundoku_theme_mode',
          'tsundoku_text_scale',
          'tsundoku_reduce_motion',
          'quiet_hours_settings',
          'reminder_settings',
          'tutorial_lore_seen',
          'tutorial_operation_seen',
        ]),
      );
    });

    test('secretKeys に app_lock 系が列挙される（控えに入れない対象）', () {
      expect(secretKeys, contains('app_lock.enabled'));
      expect(secretKeys, contains('app_lock.passcode_hash'));
      // 許可リスト側に isSecret として実在する（＝除外根拠が明示されている）
      final appLock =
          kBackupSettingSpecs.where((s) => s.key == 'app_lock.passcode_hash');
      expect(appLock.single.isSecret, isTrue);
    });

    test('label は空でない（UI・将来の説明に使える）', () {
      for (final spec in kBackupSettingSpecs) {
        expect(spec.label, isNotEmpty, reason: spec.key);
      }
    });
  });

  group('selectForBackup', () {
    test('許可リストのキーだけ通す（未知キーは落とす）', () {
      final out = selectForBackup(<String, Object?>{
        'tsundoku_theme_mode': 'dark',
        'tsundoku_text_scale': 1.25,
        'unknown_key': 'x',
        'evil': 'y',
      });

      expect(
        out.keys.toSet(),
        <String>{'tsundoku_theme_mode', 'tsundoku_text_scale'},
      );
      expect(out['tsundoku_theme_mode'], 'dark');
      expect(out['tsundoku_text_scale'], 1.25);
    });

    test('プレフィックス一括取得はしない（近似キーは落とす）', () {
      final out = selectForBackup(<String, Object?>{
        'tsundoku_theme_mode': 'light',
        'tsundoku_theme_mode_extra': 'dark',
        'tsundoku_text_scale_backup': 2.0,
        'quiet_hours_settings_copy': '{}',
      });

      expect(out.keys.toSet(), <String>{'tsundoku_theme_mode'});
    });

    test('秘密キーは生データに在っても必ず落ちる', () {
      final raw = <String, Object?>{
        'app_lock.enabled': true,
        'app_lock.passcode_hash': 'v2:120000:aa:bb',
        'app_lock.method': 'passcode',
        'app_lock.relock_grace_seconds': 30,
        'supabase.auth.token': '{"access_token":"secret"}',
        'auth.access_token': 'secret',
        'refresh_token': 'secret',
        'tsundoku_theme_mode': 'dark',
      };

      final out = selectForBackup(raw);

      expect(out.keys.toSet(), <String>{'tsundoku_theme_mode'});
      for (final key in secretKeys) {
        expect(out.containsKey(key), isFalse, reason: key);
      }
    });

    test('複雑型（Map/List）と巨大文字列は載せない（例外なし）', () {
      final out = selectForBackup(<String, Object?>{
        'tsundoku_theme_mode': <String, Object?>{'nested': true},
        'quiet_hours_settings': 'x' * (kMaxBackupSettingValueLength + 1),
        'reminder_settings': <Object?>[1, 2, 3],
        'tutorial_lore_seen': true,
      });

      expect(out.keys.toSet(), <String>{'tutorial_lore_seen'});
    });

    test('巨大入力（1万キー）でも例外を投げず、許可分だけ返す', () {
      final raw = <String, Object?>{
        for (var i = 0; i < 10000; i++) 'junk_$i': i,
        'tutorial_operation_seen': false,
      };

      final out = selectForBackup(raw);

      expect(out.keys.toSet(), <String>{'tutorial_operation_seen'});
    });

    test('空 Map・null 値は安全に扱う', () {
      expect(selectForBackup(<String, Object?>{}), isEmpty);
      expect(selectForBackup(<String, Object?>{'tutorial_lore_seen': null}),
          isEmpty);
    });
  });

  group('isAcceptableSettingValue', () {
    test('既知キーの期待型を受け入れる', () {
      expect(isAcceptableSettingValue('tsundoku_theme_mode', 'dark'), isTrue);
      expect(isAcceptableSettingValue('tsundoku_text_scale', 1.25), isTrue);
      expect(isAcceptableSettingValue('tsundoku_text_scale', 1), isTrue);
      expect(isAcceptableSettingValue('quiet_hours_settings', '{}'), isTrue);
      expect(isAcceptableSettingValue('tutorial_lore_seen', true), isTrue);
    });

    test('型不一致・未知キー・秘密キーは拒否する', () {
      expect(isAcceptableSettingValue('tsundoku_text_scale', 'big'), isFalse);
      expect(isAcceptableSettingValue('tsundoku_theme_mode', 3), isFalse);
      expect(isAcceptableSettingValue('tutorial_lore_seen', 'true'), isFalse);
      expect(isAcceptableSettingValue('unknown_key', 'x'), isFalse);
      expect(isAcceptableSettingValue('app_lock.enabled', true), isFalse);
    });
  });

  group('BackupSettingsBundle', () {
    test('toJson → tryFromJson で往復する', () {
      const bundle = BackupSettingsBundle(values: <String, Object?>{
        'tsundoku_theme_mode': 'dark',
        'tutorial_lore_seen': true,
      });

      final restored = BackupSettingsBundle.tryFromJson(bundle.toJson());

      expect(restored, isNotNull);
      expect(restored!.schemaVersion, bundle.schemaVersion);
      expect(restored.values, bundle.values);
    });

    test('非 Map は null（例外を投げない）', () {
      expect(BackupSettingsBundle.tryFromJson(null), isNull);
      expect(BackupSettingsBundle.tryFromJson('settings'), isNull);
      expect(BackupSettingsBundle.tryFromJson(<Object?>[]), isNull);
      expect(BackupSettingsBundle.tryFromJson(42), isNull);
    });

    test('values が非 Map・欠落・破損なら null（例外を投げない）', () {
      expect(
        BackupSettingsBundle.tryFromJson(<String, Object?>{'values': 'x'}),
        isNull,
      );
      expect(
        BackupSettingsBundle.tryFromJson(<String, Object?>{'schemaVersion': 1}),
        isNull,
      );
      expect(
        BackupSettingsBundle.tryFromJson(<String, Object?>{
          'schemaVersion': 1,
          'values': <Object?>[1, 2, 3],
        }),
        isNull,
      );
    });

    test('schemaVersion が壊れていても 1 に落として読む', () {
      final restored = BackupSettingsBundle.tryFromJson(<String, Object?>{
        'schemaVersion': 'v1',
        'values': <String, Object?>{'tutorial_lore_seen': true},
      });

      expect(restored, isNotNull);
      expect(restored!.schemaVersion, 1);
      expect(restored.values['tutorial_lore_seen'], isTrue);
    });

    test('読み込み時に秘密キー・未知キー・複雑型を落とす', () {
      final restored = BackupSettingsBundle.tryFromJson(<String, Object?>{
        'schemaVersion': 1,
        'values': <String, Object?>{
          'tsundoku_theme_mode': 'dark',
          'app_lock.enabled': true,
          'unknown_key': 'x',
          'reminder_settings': <String, Object?>{'enabled': true},
        },
      });

      expect(restored, isNotNull);
      expect(restored!.values.keys.toSet(), <String>{'tsundoku_theme_mode'});
    });

    test('巨大・深い JSON でも例外を投げない', () {
      Object? deep = 'leaf';
      for (var i = 0; i < 200; i++) {
        deep = <String, Object?>{'n': deep};
      }
      final huge = <String, Object?>{
        'schemaVersion': 1,
        'values': <String, Object?>{
          'tsundoku_theme_mode': deep,
          for (var i = 0; i < 10000; i++) 'junk_$i': i,
        },
      };

      final restored = BackupSettingsBundle.tryFromJson(huge);

      expect(restored, isNotNull);
      expect(restored!.values, isEmpty);
    });

    test('fromRaw は許可リスト通過後の束を返す', () {
      final bundle = BackupSettingsBundle.fromRaw(<String, Object?>{
        'tsundoku_theme_mode': 'light',
        'app_lock.enabled': true,
      });

      expect(bundle.values.keys.toSet(), <String>{'tsundoku_theme_mode'});
    });
  });
}
