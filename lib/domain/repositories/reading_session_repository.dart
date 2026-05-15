import 'package:tsundoku_quest/domain/models/reading_session.dart';

/// 読書セッションリポジトリの抽象インターフェース
abstract class ReadingSessionRepository {
  /// 特定の蔵書に関連する全セッションを取得
  Future<List<ReadingSession>> getByUserBook(String userBookId);

  /// 読書セッションを開始
  Future<ReadingSession> startSession(String userBookId, int startPage);

  /// 読書セッションを終了
  Future<ReadingSession> endSession(
    String sessionId,
    int endPage,
    int durationMinutes,
  );

  /// 最近の読書セッションを取得（直近N件）
  Future<List<ReadingSession>> getRecentSessions({int limit = 10});

  /// すべての読書日を重複なしで取得（並び順は降順）
  /// 各日付は "YYYY-MM-DD" 形式の文字列で返される
  Future<List<String>> getAllReadingDates();

  /// 特定の蔵書の総読書時間（分）を取得
  Future<int> getTotalReadingMinutes(String userBookId);

  // ━━━ Phase 3: 戦歴・統計の集計メソッド ━━━

  /// 全セッションの総読書時間（分）を取得
  Future<int> getTotalReadingMinutesAll();

  /// 全セッションから総読了ページ数を取得
  Future<int> getTotalPagesReadAll();

  /// 週間読書時間（直近7日間、日付昇順）を取得
  Future<List<int>> getWeeklyReadingMinutes();

  /// 現在の連続読書日数を取得
  Future<int> getCurrentStreak();

  /// 最長連続読書日数を取得
  Future<int> getLongestStreak();
}
