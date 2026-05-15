import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';

/// 冒険者リポジトリの抽象インターフェース
abstract class AdventurerRepository {
  /// 冒険者のステータスを取得
  Future<AdventurerStats> stats();

  /// 経験値を追加
  Future<void> addXp(int amount);

  /// 読書統計を更新
  Future<void> updateReadingStats(int pagesRead, int minutesRead);

  /// 登録書籍数をインクリメント
  Future<void> incrementBooksRegistered();

  /// 完了書籍数をインクリメント
  Future<void> incrementBooksCompleted();

  /// 連続読書日数を更新
  Future<void> updateStreak();
}
