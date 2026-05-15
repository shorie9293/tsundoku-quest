/// 冒険者のステータス
class AdventurerStats {
  final int level;
  final int xp;
  final int xpToNextLevel;
  final String title;
  final int totalBooksRegistered;
  final int totalBooksCompleted;
  final int totalReadingMinutes;
  final int totalPagesRead;
  final int currentStreak;
  final int longestStreak;
  final List<String> readingDates;

  const AdventurerStats({
    required this.level,
    required this.xp,
    required this.xpToNextLevel,
    required this.title,
    required this.totalBooksRegistered,
    required this.totalBooksCompleted,
    required this.totalReadingMinutes,
    required this.totalPagesRead,
    required this.currentStreak,
    required this.longestStreak,
    required this.readingDates,
  });

  /// 駆け出し冒険者の初期ステータス
  factory AdventurerStats.beginner() {
    return const AdventurerStats(
      level: 1,
      xp: 0,
      xpToNextLevel: 100,
      title: '書庫の見習い',
      totalBooksRegistered: 0,
      totalBooksCompleted: 0,
      totalReadingMinutes: 0,
      totalPagesRead: 0,
      currentStreak: 0,
      longestStreak: 0,
      readingDates: [],
    );
  }
}
