/// Hive TypeAdapters for DailyMission and DailyMissionType
///
/// デイリーミッションの永続化用アダプター
library;

import 'package:hive/hive.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/daily_mission.dart';

// ════════════════════════════════════════════
// DailyMissionType Adapter (typeId: 16)
// ════════════════════════════════════════════

class DailyMissionTypeAdapter extends TypeAdapter<DailyMissionType> {
  @override
  final int typeId = 16;

  @override
  DailyMissionType read(BinaryReader reader) {
    final ordinal = reader.readByte();
    if (ordinal >= DailyMissionType.values.length) {
      return DailyMissionType.readTime;
    }
    return DailyMissionType.values[ordinal];
  }

  @override
  void write(BinaryWriter writer, DailyMissionType obj) {
    writer.writeByte(obj.index);
  }
}

// ════════════════════════════════════════════
// DailyMission Adapter (typeId: 17)
// ════════════════════════════════════════════

class DailyMissionAdapter extends TypeAdapter<DailyMission> {
  @override
  final int typeId = 17;

  @override
  DailyMission read(BinaryReader reader) {
    return DailyMission(
      id: reader.read(),
      type: reader.read(),
      target: reader.read(),
      xpReward: reader.read(),
      title: reader.read(),
      description: reader.read(),
      icon: reader.read(),
      isCompleted: reader.read(),
      currentProgress: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, DailyMission obj) {
    writer.write(obj.id);
    writer.write(obj.type);
    writer.write(obj.target);
    writer.write(obj.xpReward);
    writer.write(obj.title);
    writer.write(obj.description);
    writer.write(obj.icon);
    writer.write(obj.isCompleted);
    writer.write(obj.currentProgress);
  }
}
