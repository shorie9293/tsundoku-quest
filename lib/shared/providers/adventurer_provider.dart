import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';
import 'package:tsundoku_quest/domain/repositories/adventurer_repository.dart';
import 'xp_calculator.dart';

/// 冒険者ステータスを管理するStateNotifier
class AdventurerNotifier extends StateNotifier<AdventurerStats> {
  AdventurerNotifier() : super(AdventurerStats.beginner());

  /// Supabase から冒険者ステータスを読み込んで state を更新する
  void loadFromRepository(AdventurerRepository repository) {
    repository.stats().then((stats) {
      // level/XP はクライアントサイド管理だが stats() は常に level=1 から始まるため
      // そのまま上書きして問題ない（XP永続化は未実装）
      state = stats;
    }).catchError((_) {
      // Supabase が使えない場合は初期状態のまま
    });
  }

  // ━━━ XP操作 ━━━

  void addXp(int amount) {
    final newTotalXp = _computeTotalXpFromLevel(state.level, state.xp) + amount;
    final levelResult = calculateLevel(newTotalXp);
    state = AdventurerStats(
      level: levelResult.level,
      xp: levelResult.xp,
      xpToNextLevel: levelResult.xpToNextLevel,
      title: levelResult.title,
      totalBooksRegistered: state.totalBooksRegistered,
      totalBooksCompleted: state.totalBooksCompleted,
      totalReadingMinutes: state.totalReadingMinutes,
      totalPagesRead: state.totalPagesRead,
      currentStreak: state.currentStreak,
      longestStreak: state.longestStreak,
      readingDates: state.readingDates,
    );
  }

  /// 現在のレベルとXPから総XPを逆算
  int _computeTotalXpFromLevel(int level, int xp) {
    return ((level - 1) * (level - 1)) * 100 + xp;
  }

  // ━━━ カウント操作 ━━━

  void incrementBooksRegistered() {
    state = _copyWith(totalBooksRegistered: state.totalBooksRegistered + 1);
  }

  void incrementBooksCompleted() {
    state = _copyWith(totalBooksCompleted: state.totalBooksCompleted + 1);
  }

  // ━━━ 読書統計 ━━━

  void updateReadingStats({required int minutes, required int pages}) {
    state = _copyWith(
      totalReadingMinutes: state.totalReadingMinutes + minutes,
      totalPagesRead: state.totalPagesRead + pages,
    );
  }

  // ━━━ ストリーク ━━━

  void updateStreak({required int current, required int longest}) {
    state = _copyWith(
      currentStreak: current,
      longestStreak:
          longest > state.longestStreak ? longest : state.longestStreak,
    );
  }

  AdventurerStats _copyWith({
    int? level,
    int? xp,
    int? xpToNextLevel,
    String? title,
    int? totalBooksRegistered,
    int? totalBooksCompleted,
    int? totalReadingMinutes,
    int? totalPagesRead,
    int? currentStreak,
    int? longestStreak,
    List<String>? readingDates,
  }) {
    return AdventurerStats(
      level: level ?? state.level,
      xp: xp ?? state.xp,
      xpToNextLevel: xpToNextLevel ?? state.xpToNextLevel,
      title: title ?? state.title,
      totalBooksRegistered: totalBooksRegistered ?? state.totalBooksRegistered,
      totalBooksCompleted: totalBooksCompleted ?? state.totalBooksCompleted,
      totalReadingMinutes: totalReadingMinutes ?? state.totalReadingMinutes,
      totalPagesRead: totalPagesRead ?? state.totalPagesRead,
      currentStreak: currentStreak ?? state.currentStreak,
      longestStreak: longestStreak ?? state.longestStreak,
      readingDates: readingDates ?? state.readingDates,
    );
  }

  // ━━━ 読書日付操作 ━━━

  void addReadingDate(String date) {
    final dateStr = date.length >= 10 ? date.substring(0, 10) : date;
    if (!state.readingDates.contains(dateStr)) {
      state = _copyWith(
        readingDates: [...state.readingDates, dateStr],
      );
    }
  }
}

/// Riverpod プロバイダ
final adventurerProvider =
    StateNotifierProvider<AdventurerNotifier, AdventurerStats>((ref) {
  return AdventurerNotifier();
});
