/// XP 獲得量の計算。database.ts の calculateXp / calculateLevel からの移植。
int calculateXp({
  required String type,
  int? pages,
  int? minutes,
}) {
  switch (type) {
    case 'daily_quest':
      return 50;
    case 'complete_book':
      return 200 + (pages ?? 0);
    case 'reading_session':
      return (minutes ?? 0) * 2;
    case 'write_trophy':
      return 100;
    default:
      return 0;
  }
}

/// レベル計算の結果
class LevelResult {
  final int level;
  final int xp;
  final int xpToNextLevel;
  final String title;

  const LevelResult({
    required this.level,
    required this.xp,
    required this.xpToNextLevel,
    required this.title,
  });
}

/// 称号の定義（レベル閾値 → 称号）
const Map<int, String> _titles = {
  1: '書庫の見習い',
  5: '本の探検家',
  10: '知の航海者',
  20: '書庫の賢者',
  30: '千巻の守護者',
  50: '万巻の覇王',
};

/// 総XPからレベル・称号を計算（database.ts の calculateLevel 移植）
/// レベル = floor(sqrt(totalXp / 100)) + 1
LevelResult calculateLevel(int totalXp) {
  final level = (totalXp / 100).toDouble();
  final sqrtLevel = _sqrt(level);
  final calculatedLevel = sqrtLevel.toInt() + 1;

  final xpForCurrentLevel =
      ((calculatedLevel - 1) * (calculatedLevel - 1)) * 100;
  final xpForNextLevel = (calculatedLevel * calculatedLevel) * 100;
  final xp = totalXp - xpForCurrentLevel;
  final xpToNextLevel = xpForNextLevel - xpForCurrentLevel;

  // 称号を決定
  String title = '書庫の見習い';
  for (final entry in _titles.entries) {
    if (calculatedLevel >= entry.key) {
      title = entry.value;
    }
  }

  return LevelResult(
    level: calculatedLevel,
    xp: xp,
    xpToNextLevel: xpToNextLevel,
    title: title,
  );
}

/// 簡易 sqrt（整数演算で近似、doubleに変換してから math.sqrt 相当）
double _sqrt(double x) {
  if (x <= 0) return 0;
  double guess = x / 2;
  for (int i = 0; i < 20; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}
