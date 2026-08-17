/// Hive implementation of ReminderSettingsRepository
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import 'reminder_settings_repository.dart';

class HiveReminderSettingsRepository implements ReminderSettingsRepository {
  final BoxManagerInterface _boxManager;

  HiveReminderSettingsRepository(this._boxManager);

  Box<ReadingReminderSettings>? _box;

  Future<Box<ReadingReminderSettings>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box =
        await _boxManager.getBox<ReadingReminderSettings>(BoxNames.reminder);
    return _box!;
  }

  @override
  Future<ReadingReminderSettings> load() async {
    try {
      final box = await _getBox();
      return BoxHelper.loadSingle(box) ?? const ReadingReminderSettings();
    } catch (e) {
      debugPrint('[ReminderRepo] load failed: $e');
      return const ReadingReminderSettings();
    }
  }

  @override
  Future<void> save(ReadingReminderSettings settings) async {
    try {
      final box = await _getBox();
      await BoxHelper.saveSingle(box, settings);
    } catch (e) {
      debugPrint('[ReminderRepo] save failed: $e');
    }
  }
}
