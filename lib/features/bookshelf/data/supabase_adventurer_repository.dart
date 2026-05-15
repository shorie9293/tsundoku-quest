import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/adventurer_repository.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/domain/repositories/user_book_repository.dart';

/// Supabaseをデータストアに使用したAdventurerRepositoryの具象実装
///
/// 読書セッション（reading_sessions）と蔵書（user_books）のデータから
/// 冒険者ステータスを計算する。
///
/// 注意: XP・レベル計算は AdventurerNotifier (クライアントサイド) が担当。
/// 本リポジトリは統計の生データをSupabaseから収集する責務のみを持つ。
class SupabaseAdventurerRepository implements AdventurerRepository {
  final ReadingSessionRepository _sessionRepo;
  final UserBookRepository _userBookRepo;

  SupabaseAdventurerRepository(this._sessionRepo, this._userBookRepo);

  @override
  Future<AdventurerStats> stats() async {
    final totalReadingMinutes = await _sessionRepo.getTotalReadingMinutesAll();
    final totalPagesRead = await _sessionRepo.getTotalPagesReadAll();
    final readingDates = await _sessionRepo.getAllReadingDates();
    final currentStreak = await _sessionRepo.getCurrentStreak();
    final longestStreak = await _sessionRepo.getLongestStreak();

    // Get user books for registration/completion counts
    List<UserBook> userBooks;
    try {
      userBooks = await _userBookRepo.getMyBooks();
    } catch (_) {
      userBooks = [];
    }

    final totalBooksRegistered = userBooks.length;
    final totalBooksCompleted =
        userBooks.where((ub) => ub.status == BookStatus.completed).length;

    // Return stats with level 1 default (Notifier handles level calculation)
    return AdventurerStats(
      level: 1,
      xp: 0,
      xpToNextLevel: 100,
      title: '書庫の見習い',
      totalBooksRegistered: totalBooksRegistered,
      totalBooksCompleted: totalBooksCompleted,
      totalReadingMinutes: totalReadingMinutes,
      totalPagesRead: totalPagesRead,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      readingDates: readingDates,
    );
  }

  @override
  Future<void> addXp(int amount) async {
    // XP is managed client-side in AdventurerNotifier
  }

  @override
  Future<void> updateReadingStats(int pagesRead, int minutesRead) async {
    // Reading stats are captured through reading_sessions table
  }

  @override
  Future<void> incrementBooksRegistered() async {
    // Handled by UserBookRepository when book is added
  }

  @override
  Future<void> incrementBooksCompleted() async {
    // Handled by UserBookRepository when book status changes
  }

  @override
  Future<void> updateStreak() async {
    // Streak is computed from reading_sessions data
  }
}
