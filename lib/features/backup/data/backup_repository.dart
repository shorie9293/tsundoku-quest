/// バックアップの収集・復元リポジトリ
///
/// 道標 #69 / Kanban t_4d1829a9
/// collect は Hive の books_box / reading_sessions_box と
/// ReadingGoalRepository から現状態を集める。
/// restore は mergeBackup の新規エントリのみを書き戻す
/// （既存 id は上書きしない）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_merge.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_settings_spec.dart';
import 'package:tsundoku_quest/features/backup/data/backup_settings_store.dart';
import 'package:tsundoku_quest/features/goals/data/reading_goal_repository.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal.dart';
import 'package:tsundoku_quest/core/logging/app_logger.dart';

/// バックアップ収集・復元の抽象
abstract class BackupRepository {
  Future<BackupData> collect();

  /// 復元を実行し要約を返す。ローダ系の例外は握りつぶさない。
  ///
  /// [includeSettings] が false なら設定（テーマ・文字サイズ・静穏時間・
  /// リマインダー等）には一切触れない（記録だけ戻す）。
  Future<BackupMergeResult> restore(
    BackupData data, {
    bool includeSettings = true,
  });
}

/// Hive 実装
class HiveBackupRepository implements BackupRepository {
  final BoxManagerInterface _boxManager;
  final ReadingGoalRepository? _goalRepository;

  /// 設定の読み書き（null なら設定は控えに載せない＝従来どおり）
  final BackupSettingsStore? _settingsStore;

  HiveBackupRepository(
    this._boxManager, {
    ReadingGoalRepository? goalRepository,
    BackupSettingsStore? settingsStore,
  })  : _goalRepository = goalRepository,
        _settingsStore = settingsStore;

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
        appLog.warn('[BackupRepo] goal load failed (skipped): $e');
      }
    }

    return BackupData(
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      books: books,
      sessions: sessions,
      goal: goal,
      settings: await _collectSettings(),
    );
  }

  /// 設定を許可リスト通過の上で束ねる。読めなければ null（＝従来どおり）。
  Future<BackupSettingsBundle?> _collectSettings() async {
    final store = _settingsStore;
    if (store == null) return null;
    try {
      final raw = await store.readRaw();
      return BackupSettingsBundle.fromRaw(raw);
    } catch (e) {
      appLog.warn('[BackupRepo] settings collect failed (skipped): $e');
      return null;
    }
  }

  @override
  Future<BackupMergeResult> restore(
    BackupData data, {
    bool includeSettings = true,
  }) async {
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

    if (includeSettings) {
      await _applySettings(data.settings);
    }

    return result;
  }

  /// 設定を1キーずつ適用する。未知キー・型不一致・破損は個別に握って
  /// スキップし、復元全体は落とさない。
  Future<void> _applySettings(BackupSettingsBundle? bundle) async {
    final store = _settingsStore;
    if (store == null || bundle == null) return;

    // 復元側でも許可リストと秘密除外を通す（改竄された控え対策）。
    final values = selectForBackup(bundle.values);
    for (final entry in values.entries) {
      if (!isAcceptableSettingValue(entry.key, entry.value)) {
        appLog
            .warn('[BackupRepo] setting skipped (type mismatch): ${entry.key}');
        continue;
      }
      try {
        await store.writeValue(entry.key, entry.value);
      } catch (e) {
        appLog.warn('[BackupRepo] setting skipped (${entry.key}): $e');
      }
    }
  }
}

/// テスト用インメモリ実装
class InMemoryBackupRepository implements BackupRepository {
  List<UserBook> books;
  List<ReadingSession> sessions;
  ReadingGoalSnapshot? goal;

  /// 設定の生読み書き（null なら設定を扱わない）
  final BackupSettingsStore? settingsStore;

  InMemoryBackupRepository({
    List<UserBook>? books,
    List<ReadingSession>? sessions,
    this.goal,
    this.settingsStore,
  })  : books = books ?? [],
        sessions = sessions ?? [];

  @override
  Future<BackupData> collect() async {
    BackupSettingsBundle? settings;
    final store = settingsStore;
    if (store != null) {
      try {
        settings = BackupSettingsBundle.fromRaw(await store.readRaw());
      } catch (_) {
        settings = null;
      }
    }
    return BackupData(
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      books: List.of(books),
      sessions: List.of(sessions),
      goal: goal,
      settings: settings,
    );
  }

  @override
  Future<BackupMergeResult> restore(
    BackupData data, {
    bool includeSettings = true,
  }) async {
    final result = mergeBackup(
      incoming: data,
      existingBooks: books,
      existingSessions: sessions,
    );
    books = [...books, ...result.newBooks];
    sessions = [...sessions, ...result.newSessions];
    if (data.goal != null) goal = data.goal;
    final store = settingsStore;
    final bundle = data.settings;
    if (includeSettings && store != null && bundle != null) {
      for (final entry in selectForBackup(bundle.values).entries) {
        if (!isAcceptableSettingValue(entry.key, entry.value)) continue;
        try {
          await store.writeValue(entry.key, entry.value);
        } catch (_) {
          // 1キーの失敗で復元全体を落とさない
        }
      }
    }
    return result;
  }
}

/// DI プロバイダー（既存 provider 慣習踏襲）
final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  final boxManager = ref.read(hiveBoxManagerProvider);
  // 目標リポジトリは Hive 実装を直接組み立てる（循環 DI 回避）
  final goalRepo = HiveReadingGoalRepository(boxManager);
  return HiveBackupRepository(
    boxManager,
    goalRepository: goalRepo,
    settingsStore: HiveBackupSettingsStore(boxManager),
  );
});
