/// Hive TypeAdapter for ReadingSession
///
/// 読書セッションの永続化用アダプター
library;

import 'package:hive/hive.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';

/// ReadingSession Adapter (typeId: 15)
class ReadingSessionAdapter extends TypeAdapter<ReadingSession> {
  @override
  final int typeId = 15;

  @override
  ReadingSession read(BinaryReader reader) {
    return ReadingSession(
      id: reader.read(),
      userBookId: reader.read(),
      startedAt: reader.read(),
      endedAt: reader.read(),
      startPage: reader.read(),
      endPage: reader.read(),
      durationMinutes: reader.read(),
      createdAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, ReadingSession obj) {
    writer.write(obj.id);
    writer.write(obj.userBookId);
    writer.write(obj.startedAt);
    writer.write(obj.endedAt);
    writer.write(obj.startPage);
    writer.write(obj.endPage);
    writer.write(obj.durationMinutes);
    writer.write(obj.createdAt);
  }
}
