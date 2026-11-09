/// 設定つきバックアップの往復試練（実 Hive + mock SharedPreferences）
///
/// 控え JSON に設定を載せ、復元で戻ることを実測する。
/// 秘密（app_lock）が控えに漏れないこと、includeSettings:false で
/// 設定を触らないこと、設定なしの旧控えが従来どおり成功することも固定する。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/book_adapters.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/reading_reminder_adapter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/reading_session_adapter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/features/backup/data/backup_repository.dart';
import 'package:tsundoku_quest/features/backup/data/backup_settings_store.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_settings_spec.dart';
import 'package:tsundoku_quest/features/reminders/data/hive_quiet_hours_repository.dart';
import 'package:tsundoku_quest/features/reminders/data/hive_reminder_settings_repository.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_settings.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';

/// 実 Hive を temp ディレクトリで使う最小の BoxManager。
class _TestBoxManager implements BoxManagerInterface {
  @override
  Future<Box<T>> getBox<T>(String name) async => await Hive.openBox<T>(name);

  @override
  Future<void> openAllBoxes() async {}

  @override
  Future<void> closeBox(String name) async {
    if (Hive.isBoxOpen(name)) await Hive.box(name).close();
  }

  @override
  Future<void> closeAllBoxes() async => await Hive.close();

  @override
  Future<void> clearBox(String name) async {
    final box = await getBox<dynamic>(name);
    await box.clear();
  }
}

bool _adaptersRegistered = false;

void _registerAdapters() {
  if (_adaptersRegistered) return;
  Hive.registerAdapter(BookSourceAdapter());
  Hive.registerAdapter(BookAdapter());
  Hive.registerAdapter(BookStatusAdapter());
  Hive.registerAdapter(BookMediumAdapter());
  Hive.registerAdapter(UserBookAdapter());
  Hive.registerAdapter(ReadingSessionAdapter());
  Hive.registerAdapter(ReadingReminderAdapter());
  _adaptersRegistered = true;
}

/// 復元先の設定を「既定」に戻す（復元で戻ることを確かめるため）。
Future<void> _resetSettings(_TestBoxManager boxManager) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await HiveQuietHoursRepository(boxManager)
      .save(QuietHoursSettings.defaults());
  await HiveReminderSettingsRepository(boxManager)
      .save(const ReadingReminderSettings());
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('tutorial_lore_seen', false);
  await prefs.setBool('tutorial_operation_seen', false);
}

void main() {
  late Directory tempDir;
  late _TestBoxManager boxManager;
  late HiveBackupSettingsStore settingsStore;
  late HiveBackupRepository repository;

  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = Directory.systemTemp.createTempSync('tsundoku_backup_settings_');
    Hive.init(tempDir.path);
    _registerAdapters();
    boxManager = _TestBoxManager();
    settingsStore = HiveBackupSettingsStore(boxManager);
    repository = HiveBackupRepository(
      boxManager,
      settingsStore: settingsStore,
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// 設定を「利用者が選んだ値」に変える。
  Future<void> seedCustomSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tsundoku_theme_mode', 'dark');
    await prefs.setDouble('tsundoku_text_scale', 1.25);
    await prefs.setString('tsundoku_reduce_motion', 'on');
    // 秘密（控えに載ってはいけない）
    await prefs.setBool('app_lock.enabled', true);
    await prefs.setString('app_lock.passcode_hash', 'v2:120000:aabb:ccdd');

    await HiveQuietHoursRepository(boxManager).save(QuietHoursSettings(
      enabled: true,
      startHour: 23,
      startMinute: 30,
      endHour: 6,
      endMinute: 45,
      policy: QuietHoursPolicy.skip,
    ));
    await HiveReminderSettingsRepository(boxManager).save(
      const ReadingReminderSettings(
        enabled: true,
        hour: 7,
        minute: 15,
        targetStatus: BookStatus.reading,
      ),
    );
    await prefs.setBool('tutorial_lore_seen', true);
    await prefs.setBool('tutorial_operation_seen', false);
  }

  group('HiveBackupSettingsStore', () {
    test('readRaw が設定を読み、秘密は読まない', () async {
      await seedCustomSettings();

      final raw = await settingsStore.readRaw();

      expect(raw['tsundoku_theme_mode'], 'dark');
      expect(raw['tsundoku_text_scale'], 1.25);
      expect(raw['tsundoku_reduce_motion'], 'on');
      expect(raw['tutorial_lore_seen'], isTrue);
      expect(raw['tutorial_operation_seen'], isFalse);
      expect(raw['quiet_hours_settings'], isA<String>());
      expect(raw['reminder_settings'], isA<String>());
      for (final key in secretKeys) {
        expect(raw.containsKey(key), isFalse, reason: key);
      }
    });

    test('writeValue で設定が保存され、readRaw が同じ値を返す', () async {
      await seedCustomSettings();
      final raw = await settingsStore.readRaw();

      await _resetSettings(boxManager);
      for (final entry in raw.entries) {
        await settingsStore.writeValue(entry.key, entry.value);
      }

      final again = await settingsStore.readRaw();
      expect(again['tsundoku_theme_mode'], 'dark');
      expect(again['tsundoku_text_scale'], 1.25);
      expect(again['tsundoku_reduce_motion'], 'on');
      expect(again['quiet_hours_settings'], raw['quiet_hours_settings']);
      expect(again['reminder_settings'], raw['reminder_settings']);
      expect(again['tutorial_lore_seen'], isTrue);
    });

    test('型不一致・不正値の writeValue は例外（呼び側が個別に握る）', () async {
      await expectLater(
        settingsStore.writeValue('tsundoku_text_scale', 'big'),
        throwsA(anything),
      );
      await expectLater(
        settingsStore.writeValue('tsundoku_theme_mode', 3),
        throwsA(anything),
      );
      await expectLater(
        settingsStore.writeValue('quiet_hours_settings', 'not json'),
        throwsA(anything),
      );
    });
  });

  group('collect', () {
    test('collect が設定を束ねる（秘密は載らない）', () async {
      await seedCustomSettings();

      final data = await repository.collect();

      expect(data.settings, isNotNull);
      final values = data.settings!.values;
      expect(values['tsundoku_theme_mode'], 'dark');
      expect(values['tsundoku_text_scale'], 1.25);
      expect(values['tutorial_lore_seen'], isTrue);
      for (final key in secretKeys) {
        expect(values.containsKey(key), isFalse, reason: key);
      }
      // 生 JSON にも秘密の値が現れない
      final json = jsonEncode(data.toJson());
      expect(json.contains('app_lock'), isFalse);
      expect(json.contains('aabb:ccdd'), isFalse);
    });

    test('settingsStore 未注入なら settings は null（従来どおり）', () async {
      final legacy = HiveBackupRepository(boxManager);

      final data = await legacy.collect();

      expect(data.settings, isNull);
      expect(data.toJson().containsKey('settings'), isFalse);
    });

    test('控えに設定が無い場合でも壊れない', () async {
      // 何も seed しない（すべて未保存）
      final data = await repository.collect();

      expect(data.settings, isNotNull);
      expect(data.settings!.values, isEmpty);
      expect(data.toJson().containsKey('settings'), isTrue);
    });
  });

  group('restore', () {
    test('控え → 復元の往復で設定が戻る', () async {
      await seedCustomSettings();
      final collected = await repository.collect();
      final quietBefore = await HiveQuietHoursRepository(boxManager).load();
      final reminderBefore =
          await HiveReminderSettingsRepository(boxManager).load();
      final json = jsonDecode(jsonEncode(collected.toJson()));
      final incoming = BackupData.tryFromJson(json);
      expect(incoming, isNotNull);
      expect(incoming!.settings, isNotNull);

      await _resetSettings(boxManager);
      final afterReset = await SharedPreferences.getInstance();
      expect(afterReset.getString('tsundoku_theme_mode'), isNull);

      await repository.restore(incoming);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tsundoku_theme_mode'), 'dark');
      expect(prefs.getDouble('tsundoku_text_scale'), 1.25);
      expect(prefs.getString('tsundoku_reduce_motion'), 'on');
      expect(await HiveQuietHoursRepository(boxManager).load(), quietBefore);
      expect(
        jsonEncode(
            (await HiveReminderSettingsRepository(boxManager).load()).toJson()),
        jsonEncode(reminderBefore.toJson()),
      );
      expect(prefs.getBool('tutorial_lore_seen'), isTrue);
      expect(prefs.getBool('tutorial_operation_seen'), isFalse);
      // 秘密は復元されない（元の true へ戻らない）
      expect(prefs.getBool('app_lock.enabled'), isNull);
    });

    test('includeSettings:false なら設定を触らない', () async {
      await seedCustomSettings();
      final collected = await repository.collect();
      final incoming = BackupData.tryFromJson(collected.toJson())!;

      await _resetSettings(boxManager);
      final result = await repository.restore(incoming, includeSettings: false);

      expect(result, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tsundoku_theme_mode'), isNull);
      expect(
        await HiveQuietHoursRepository(boxManager).load(),
        QuietHoursSettings.defaults(),
      );
      expect(prefs.getBool('tutorial_lore_seen'), isFalse);
    });

    test('settings 無しの旧控えは成功する（現状維持）', () async {
      final legacyJson = <String, Object?>{
        'tsundoku_quest_backup': true,
        'version': 1,
        'exportedAt': '2026-11-01T00:00:00Z',
        'books': <Object?>[],
        'readingSessions': <Object?>[],
        'readingGoal': null,
      };
      final incoming = BackupData.tryFromJson(legacyJson);

      expect(incoming, isNotNull);
      expect(incoming!.settings, isNull);

      await seedCustomSettings();
      final result = await repository.restore(incoming);

      expect(result.addedBooks, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tsundoku_theme_mode'), 'dark');
    });

    test('壊れた settings は無視され、他は従来どおり復元される', () async {
      final broken = <String, Object?>{
        'tsundoku_quest_backup': true,
        'version': 1,
        'exportedAt': '2026-11-01T00:00:00Z',
        'books': <Object?>[],
        'readingSessions': <Object?>[],
        'settings': 'not a map',
      };

      final incoming = BackupData.tryFromJson(broken);

      expect(incoming, isNotNull);
      expect(incoming!.settings, isNull);
      final result = await repository.restore(incoming);
      expect(result.addedBooks, 0);
    });

    test('型不一致の設定は個別に握ってスキップし、他は適用する', () async {
      await _resetSettings(boxManager);
      final incoming = BackupData(
        exportedAt: '2026-11-01T00:00:00Z',
        books: const [],
        settings: const BackupSettingsBundle(values: <String, Object?>{
          'tsundoku_theme_mode': 'dark',
          'tsundoku_text_scale': 'huge', // 型不一致
          'quiet_hours_settings': 'not json', // 破損
          'tutorial_lore_seen': true,
        }),
      );

      final result = await repository.restore(incoming);

      expect(result, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tsundoku_theme_mode'), 'dark');
      expect(prefs.getDouble('tsundoku_text_scale'), isNull);
      expect(prefs.getBool('tutorial_lore_seen'), isTrue);
      expect(
        await HiveQuietHoursRepository(boxManager).load(),
        QuietHoursSettings.defaults(),
      );
    });

    test('未知キーを含む settings でも例外を投げない', () async {
      await _resetSettings(boxManager);
      final incoming = BackupData(
        exportedAt: '2026-11-01T00:00:00Z',
        books: const [],
        settings: const BackupSettingsBundle(values: <String, Object?>{
          'unknown_key': 'x',
          'app_lock.enabled': true,
        }),
      );

      await repository.restore(incoming);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app_lock.enabled'), isNull);
    });
  });
}
