/// バックアップの組み立て・JSON書き出し（純粋ロジック）
///
/// 道標 #69 / Kanban t_4d1829a9
/// 全依存を関数注入（loader）とし、Hive 等に触れないため
/// テストはフェイクなしで完結する。ローダ失敗は握りつぶさない。
library;

import 'dart:convert';

import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';

/// バックアップ組み立て・書き出し
class BackupExporter {
  final Future<List<UserBook>> Function() booksLoader;
  final Future<List<ReadingSession>> Function() sessionsLoader;
  final Future<ReadingGoalSnapshot> Function() goalLoader;
  final DateTime Function() now;

  const BackupExporter({
    required this.booksLoader,
    required this.sessionsLoader,
    required this.goalLoader,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  /// 現状態からスナップショットを組み立てる
  Future<BackupData> buildData() async {
    final books = await booksLoader();
    final sessions = await sessionsLoader();
    final goalRaw = await goalLoader();
    final goal = goalRaw.isConfigured ? goalRaw : null;
    return BackupData(
      exportedAt: now().toUtc().toIso8601String(),
      books: books,
      sessions: sessions,
      goal: goal,
    );
  }

  /// JSON 文字列へ書き出す
  Future<String> exportJson() async {
    final data = await buildData();
    return const JsonEncoder.withIndent('  ').convert(data.toJson());
  }
}

/// JSON 文字列の復号（破損時は FormatException を上位へ）
Object? backupJsonDecode(String source) => jsonDecode(source);
