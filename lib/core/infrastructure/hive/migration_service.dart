/// ツンドクエスト Hive データ移行サービス
///
/// 初回起動時に Supabase + SharedPreferences から Hive Box への
/// データ移行を一度だけ実行する。
///
/// 移行対象:
///   1. Supabase user_books → books_box (UserBook 型)
///   2. Supabase reading_sessions → reading_sessions_box (ReadingSession 型)
///   3. SharedPreferences tutorial state → tutorial_box
///
/// 移行不要なもの:
///   - DailyMission: DailyMissionNotifier が既に Hive + SharedPreferences
///     二段階永続化を実装済みのため。
///   - AdventurerStats: UserBook と ReadingSession の集計から計算されるため、
///     上記2つの移行が完了すれば自動的に再計算される。
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';

/// 移行結果
///
/// 各フィールドで移行の成否・スキップ状態を追跡する。
class MigrationResult {
  /// 既に移行完了済みでスキップされた
  bool skipped = false;

  /// 移行が正常に完了した
  bool completed = false;

  /// 移行全体のエラー（致命的）
  String? error;

  /// 移行した UserBook 数
  int booksMigrated = 0;

  /// UserBook 移行をスキップした（既存データあり）
  bool booksSkipped = false;

  /// UserBook 移行エラー
  String? booksError;

  /// 移行した ReadingSession 数
  int sessionsMigrated = 0;

  /// ReadingSession 移行をスキップした（既存データあり）
  bool sessionsSkipped = false;

  /// ReadingSession 移行エラー
  String? sessionsError;

  /// Tutorial 状態の移行が完了した
  bool tutorialMigrated = false;
}

/// Hive データ移行サービス
///
/// 使い方:
/// ```dart
/// final migrationService = HiveMigrationService(
///   boxManager: hiveBoxManager,
///   onFetchUserBooks: () async => supabaseBookRepo.getMyBooks(),
///   onFetchReadingSessions: () async => supabaseSessionRepo.getRecentSessions(limit: 1000),
/// );
/// final result = await migrationService.migrate();
/// ```
class HiveMigrationService {
  /// SharedPreferences の移行完了フラグキー
  static const _migrationCompletedKey = 'hive_migration_completed_v1';

  /// Tutorial の SharedPreferences キー
  static const _tutorialLoreSeenKey = 'tutorial_lore_seen';
  static const _tutorialOperationSeenKey = 'tutorial_operation_seen';

  final BoxManagerInterface _boxManager;

  /// Supabase から UserBook 一覧を取得するコールバック
  final Future<List<UserBook>> Function()? _onFetchUserBooks;

  /// Supabase から ReadingSession 一覧を取得するコールバック
  final Future<List<ReadingSession>> Function()? _onFetchReadingSessions;

  HiveMigrationService({
    required BoxManagerInterface boxManager,
    Future<List<UserBook>> Function()? onFetchUserBooks,
    Future<List<ReadingSession>> Function()? onFetchReadingSessions,
  }) : _boxManager = boxManager,
       _onFetchUserBooks = onFetchUserBooks,
       _onFetchReadingSessions = onFetchReadingSessions;

  /// 移行が必要かどうかを判定する
  ///
  /// SharedPreferences の移行完了フラグが true なら移行不要。
  Future<bool> isMigrationNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_migrationCompletedKey) != true;
    } catch (_) {
      // SharedPreferences が読めない場合は移行を試行
      return true;
    }
  }

  /// 全移行を実行する
  ///
  /// 各ステップは冪等（idempotent）:
  /// - 該当 Hive Box に既存データがあればスキップ
  /// - 個別ステップの失敗は後続に影響しない
  Future<MigrationResult> migrate() async {
    final result = MigrationResult();

    try {
      // 0. 既に完了済みならスキップ
      if (!await isMigrationNeeded()) {
        debugPrint('[HiveMigration] 移行済みフラグ検出 → スキップ');
        result.skipped = true;
        result.completed = true;
        return result;
      }

      debugPrint('[HiveMigration] === データ移行を開始 ===');

      // 1. BoxManager が Box を開いていることを保証
      try {
        await _boxManager.openAllBoxes();
      } catch (e) {
        debugPrint('[HiveMigration] Box open 失敗: $e');
      }

      // 2. Supabase → Hive: UserBook
      await _migrateUserBooks(result);

      // 3. Supabase → Hive: ReadingSession
      await _migrateReadingSessions(result);

      // 4. SharedPreferences → Hive: Tutorial state
      await _migrateTutorialState(result);

      // 5. 移行完了フラグを設定
      await _markComplete();
      result.completed = true;

      debugPrint(
        '[HiveMigration] === 移行完了: '
        'books=${result.booksMigrated}(${result.booksSkipped ? "skip" : "ok"}), '
        'sessions=${result.sessionsMigrated}(${result.sessionsSkipped ? "skip" : "ok"}), '
        'tutorial=${result.tutorialMigrated ? "ok" : "skip"} ===',
      );
    } catch (e, stack) {
      debugPrint('[HiveMigration] 移行全体で致命的エラー: $e\n$stack');
      result.error = e.toString();
    }

    return result;
  }

  // ════════════════════════════════════════════
  //  個別移行ステップ
  // ════════════════════════════════════════════

  /// UserBook を Supabase → Hive に移行
  Future<void> _migrateUserBooks(MigrationResult result) async {
    if (_onFetchUserBooks == null) {
      debugPrint('[HiveMigration] UserBook fetch callback なし → スキップ');
      result.booksSkipped = true;
      return;
    }

    try {
      final box = await _boxManager.getBox<UserBook>(BoxNames.books);

      // 既存データチェック（冪等性）
      if (box.isNotEmpty) {
        debugPrint('[HiveMigration] books_box 既存データあり → スキップ');
        result.booksSkipped = true;
        return;
      }

      debugPrint('[HiveMigration] Supabase → Hive: UserBook 移行中...');
      final books = await _onFetchUserBooks();
      debugPrint('[HiveMigration] Supabase から ${books.length} 件の UserBook を取得');

      int migrated = 0;
      for (final book in books) {
        try {
          await box.put(book.id, book);
          migrated++;
        } catch (e) {
          debugPrint('[HiveMigration] UserBook put 失敗 (id=${book.id}): $e');
        }
      }
      await box.flush();
      result.booksMigrated = migrated;
      debugPrint('[HiveMigration] UserBook: $migrated 件を Hive に保存');
    } catch (e) {
      debugPrint('[HiveMigration] UserBook 移行失敗: $e');
      result.booksError = e.toString();
    }
  }

  /// ReadingSession を Supabase → Hive に移行
  Future<void> _migrateReadingSessions(MigrationResult result) async {
    if (_onFetchReadingSessions == null) {
      debugPrint('[HiveMigration] ReadingSession fetch callback なし → スキップ');
      result.sessionsSkipped = true;
      return;
    }

    try {
      final box = await _boxManager.getBox<ReadingSession>(BoxNames.readingSessions);

      // 既存データチェック（冪等性）
      if (box.isNotEmpty) {
        debugPrint('[HiveMigration] reading_sessions_box 既存データあり → スキップ');
        result.sessionsSkipped = true;
        return;
      }

      debugPrint('[HiveMigration] Supabase → Hive: ReadingSession 移行中...');
      final sessions = await _onFetchReadingSessions();
      debugPrint('[HiveMigration] Supabase から ${sessions.length} 件の ReadingSession を取得');

      int migrated = 0;
      for (final session in sessions) {
        try {
          await box.put(session.id, session);
          migrated++;
        } catch (e) {
          debugPrint('[HiveMigration] ReadingSession put 失敗 (id=${session.id}): $e');
        }
      }
      await box.flush();
      result.sessionsMigrated = migrated;
      debugPrint('[HiveMigration] ReadingSession: $migrated 件を Hive に保存');
    } catch (e) {
      debugPrint('[HiveMigration] ReadingSession 移行失敗: $e');
      result.sessionsError = e.toString();
    }
  }

  /// Tutorial 状態を SharedPreferences → Hive に移行
  Future<void> _migrateTutorialState(MigrationResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final loreSeen = prefs.getBool(_tutorialLoreSeenKey) ?? false;
      final operationSeen = prefs.getBool(_tutorialOperationSeenKey) ?? false;

      final box = await _boxManager.getBox(BoxNames.tutorial);
      if (box.isEmpty) {
        await box.put('lore_seen', loreSeen);
        await box.put('operation_seen', operationSeen);
        await box.flush();
        result.tutorialMigrated = true;
        debugPrint('[HiveMigration] Tutorial 状態を移行: lore=$loreSeen, op=$operationSeen');
      } else {
        debugPrint('[HiveMigration] tutorial_box 既存データあり → スキップ');
      }
    } catch (e) {
      debugPrint('[HiveMigration] Tutorial 移行失敗: $e');
    }
  }

  /// 移行完了フラグを SharedPreferences に設定
  Future<void> _markComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationCompletedKey, true);
      debugPrint('[HiveMigration] 完了フラグを設定');
    } catch (e) {
      debugPrint('[HiveMigration] 完了フラグ設定失敗: $e');
    }
  }
}
