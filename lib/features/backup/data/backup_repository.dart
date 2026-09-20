/// バックアップの収集・復元リポジトリ
///
/// 道標 #69 / Kanban t_4d1829a9
/// collect は Hive の books_box / reading_sessions_box と
/// ReadingGoalRepository から現状態を集める。
/// restore は mergeBackup の新規エントリのみを書き戻す
/// （既存 id は上書きしない）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_merge.dart';
import 'package:tsundoku_quest/features/goals/data/reading_goal_repository.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal.dart';

/// バックアップ収集・復元の抽象
abstract class BackupRepository {
  Future<BackupData> collect();

  /// 復元を実行し要約を返す。ローダ系の例外は握りつぶさない。
  Future<BackupMergeResult> restore(BackupData data);
}

/// Hive 実装
class HiveBackupRepository implements BackupRepository {
  final BoxManagerInterface _boxManager;
  final ReadingGoalRepository? _goalRepository;

  HiveBackupRepository(this._boxManager, {ReadingGoalRepository? goalRepository})
      : _goalRepository = goalRepository;

  Future<Box<UserBook>> _getBooksBox() =>
      _boxManager.getBox<UserBook>(BoxNames.books);

  Future<Box<ReadingSession>> _getSessionsBox() =>
      _boxManager.getBox<ReadingSession>(BoxNames.readingSessions);

  @override
  Future<BackupData> collect() async {
    final booksBox = await _getBooksBox();
    final sessionsBox = await _getSessionsBox();
    final books = BoxHelper.loadCollection(booksBox);
    final sessions = BoxHelper.loadCollection(sessionsBox);

    ReadingGoalSnapshot? goal;
    final goalRepo = _goalRepository;
    if (goalRepo != null) {
      try {
        final g = await goalRepo.load();
        if (g.isConfigured) {
          goal = ReadingGoalSnapshot(
            monthlyTarget: g.monthlyTarget,
            yearlyTarget: g.yearlyTarget,
            updatedAt: g.updatedAt,
          );
        }
      } catch (e) {
        debugPrint('[BackupRepo] goal load failed (skipped): $e');
      }
    }

    return BackupData(
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      books: books,
      sessions: sessions,
      goal: goal,
    );
  }

  @override
  Future<BackupMergeResult> restore(BackupData data) async {
    final booksBox = await _getBooksBox();
    final sessionsBox = await _getSessionsBox();
    final existingBooks = BoxHelper.loadCollection(booksBox);
    final existingSessions = BoxHelper.loadCollection(sessionsBox);

    final result = mergeBackup(
      incoming: data,
      existingBooks: existingBooks,
      existingSessions: existingSessions,
    );

    for (final b in result.newBooks) {
      await booksBox.put(b.id, b);
    }
    for (final s in result.newSessions) {
      await sessionsBox.put(s.id, s);
    }

    final goal = data.goal;
    final goalRepo = _goalRepository;
    if (goal != null && goalRepo != null && !result.isEmpty) {
      await goalRepo.save(ReadingGoal(
        monthlyTarget: goal.monthlyTarget,
        yearlyTarget: goal.yearlyTarget,
        updatedAt: goal.updatedAt,
      ));
    }

    return result;
  }
}

/// テスト用インメモリ実装
class InMemoryBackupRepository implements BackupRepository {
  List<UserBook> books;
  List<ReadingSession> sessions;
  ReadingGoalSnapshot? goal;

  InMemoryBackupRepository({
    List<UserBook>? books,
    List<ReadingSession>? sessions,
    this.goal,
  })  : books = books ?? [],
        sessions = sessions ?? [];

  @override
  Future<BackupData> collect() async {
    return BackupData(
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      books: List.of(books),
      sessions: List.of(sessions),
      goal: goal,
    );
  }

  @override
  Future<BackupMergeResult> restore(BackupData data) async {
    final result = mergeBackup(
      incoming: data,
      existingBooks: books,
      existingSessions: sessions,
    );
    books = [...books, ...result.newBooks];
    sessions = [...sessions, ...result.newSessions];
    if (data.goal != null) goal = data.goal;
    return result;
  }
}

/// DI プロバイダー（既存 provider 慣習踏襲）
final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  final boxManager = ref.read(hiveBoxManagerProvider);
  // 目標リポジトリは Hive 実装を直接組み立てる（循環 DI 回避）
  final goalRepo = HiveReadingGoalRepository(boxManager);
  return HiveBackupRepository(boxManager, goalRepository: goalRepo);
});
