/// Hive TypeAdapter for WarTrophy model
library;

import 'package:hive/hive.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';

class WarTrophyAdapter extends TypeAdapter<WarTrophy> {
  @override
  final int typeId = 18;

  @override
  WarTrophy read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return WarTrophy(
      id: fields[0] as String,
      userBookId: fields[1] as String,
      userId: fields[2] as String,
      learnings: (fields[3] as List).cast<String>(),
      action: fields[4] as String,
      favoriteQuote: fields[5] as String?,
      createdAt: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WarTrophy obj) {
    writer.writeByte(7);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.userBookId);
    writer.writeByte(2);
    writer.write(obj.userId);
    writer.writeByte(3);
    writer.write(obj.learnings);
    writer.writeByte(4);
    writer.write(obj.action);
    writer.writeByte(5);
    writer.write(obj.favoriteQuote);
    writer.writeByte(6);
    writer.write(obj.createdAt);
  }
}
