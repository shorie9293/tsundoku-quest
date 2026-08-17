/// Hive TypeAdapter for ReadingReminderSettings
library;

import 'package:hive/hive.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';

/// ReadingReminderSettings Adapter (typeId: 18)
///
/// targetStatus は登録済みの BookStatusAdapter (typeId 12) により解決される。
class ReadingReminderAdapter extends TypeAdapter<ReadingReminderSettings> {
  @override
  final int typeId = 18;

  @override
  ReadingReminderSettings read(BinaryReader reader) {
    return ReadingReminderSettings(
      enabled: reader.read(),
      hour: reader.read(),
      minute: reader.read(),
      targetStatus: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, ReadingReminderSettings obj) {
    writer.write(obj.enabled);
    writer.write(obj.hour);
    writer.write(obj.minute);
    writer.write(obj.targetStatus);
  }
}
