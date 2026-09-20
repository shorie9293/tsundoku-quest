/// バックアップの復元（merge）ロジック — 純粋関数
///
/// 道標 #69 / Kanban t_4d1829a9
/// id 重複は既存優先でスキップ。入力の並び順は保持する。
library;

import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';

/// 復元結果の要約（不変）
class BackupMergeResult {
  final int addedBooks;
  final int skippedBooks;
  final int addedSessions;
  final int skippedSessions;

  /// 復元対象（新規追加のみ・既存は含まない）
  final List<UserBook> newBooks;
  final List<ReadingSession> newSessions;

  BackupMergeResult({
    required this.addedBooks,
    required this.skippedBooks,
    required this.addedSessions,
    required this.skippedSessions,
    List<UserBook>? newBooks,
    List<ReadingSession>? newSessions,
  })  : newBooks = newBooks ?? [],
        newSessions = newSessions ?? [];

  bool get isEmpty => addedBooks == 0 && addedSessions == 0;
}

/// incoming のうち既存に無い id のエントリのみを返す。
/// 既存・incoming 双方の順序は保持（incoming 順）。
BackupMergeResult mergeBackup({
  required BackupData incoming,
  required List<UserBook> existingBooks,
  required List<ReadingSession> existingSessions,
}) {
  final existingBookIds = existingBooks.map((b) => b.id).toSet();
  final existingSessionIds = existingSessions.map((s) => s.id).toSet();

  final addedBooks = <UserBook>[];
  var skippedBooks = 0;
  for (final b in incoming.books) {
    if (existingBookIds.contains(b.id)) {
      skippedBooks++;
    } else {
      addedBooks.add(b);
      existingBookIds.add(b.id);
    }
  }

  final addedSessions = <ReadingSession>[];
  var skippedSessions = 0;
  for (final s in incoming.sessions) {
    if (existingSessionIds.contains(s.id)) {
      skippedSessions++;
    } else {
      addedSessions.add(s);
      existingSessionIds.add(s.id);
    }
  }

  return BackupMergeResult(
    addedBooks: addedBooks.length,
    skippedBooks: skippedBooks,
    addedSessions: addedSessions.length,
    skippedSessions: skippedSessions,
    newBooks: addedBooks,
    newSessions: addedSessions,
  );
}
