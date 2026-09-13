/// 読書目標（月間・年間の読了冊数目標）
///
/// 令和八年長月十三日 具現化（改善提案#43）
/// `0` は「未設定」を意味する。負値・非数値は読み込み時に 0 へ丸める
/// （破損 JSON でも例外を投げない）。
library;

/// 不変の読書目標モデル
class ReadingGoal {
  /// 月間の読了目標冊数（0 = 未設定）
  final int monthlyTarget;

  /// 年間の読了目標冊数（0 = 未設定）
  final int yearlyTarget;

  /// 最終更新日時（ISO8601。未設定時は空文字）
  final String updatedAt;

  const ReadingGoal({
    this.monthlyTarget = 0,
    this.yearlyTarget = 0,
    this.updatedAt = '',
  });

  /// 未設定の目標
  const ReadingGoal.empty()
      : monthlyTarget = 0,
        yearlyTarget = 0,
        updatedAt = '';

  bool get isMonthlySet => monthlyTarget > 0;

  bool get isYearlySet => yearlyTarget > 0;

  /// どちらか一方でも設定済みか
  bool get isConfigured => isMonthlySet || isYearlySet;

  ReadingGoal copyWith({
    int? monthlyTarget,
    int? yearlyTarget,
    String? updatedAt,
  }) {
    return ReadingGoal(
      monthlyTarget: monthlyTarget ?? this.monthlyTarget,
      yearlyTarget: yearlyTarget ?? this.yearlyTarget,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'monthlyTarget': monthlyTarget,
        'yearlyTarget': yearlyTarget,
        'updatedAt': updatedAt,
      };

  /// 破損に強い復元（非数値・負値は 0 へ）
  factory ReadingGoal.fromJson(Map<String, dynamic> json) {
    return ReadingGoal(
      monthlyTarget: _safeCount(json['monthlyTarget']),
      yearlyTarget: _safeCount(json['yearlyTarget']),
      updatedAt: (json['updatedAt'] as String?) ?? '',
    );
  }

  static int _safeCount(Object? raw) {
    final value = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}') ?? 0;
    return value < 0 ? 0 : value;
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingGoal &&
      other.monthlyTarget == monthlyTarget &&
      other.yearlyTarget == yearlyTarget &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(monthlyTarget, yearlyTarget, updatedAt);
}

/// 目標達成の段階バッジ
enum ReadingGoalBadge {
  notSet('未設定', '🎯'),
  notStarted('挑戦開始', '🧭'),
  started('挑戦中', '📖'),
  halfway('折り返し', '⚔️'),
  almost('あと少し', '🔥'),
  achieved('目標達成', '🏆');

  final String label;
  final String icon;
  const ReadingGoalBadge(this.label, this.icon);
}

/// 目標に対する進捗の値オブジェクト
class ReadingGoalProgress {
  /// 目標冊数（0 = 未設定）
  final int target;

  /// 達成冊数（読了数）
  final int achieved;

  const ReadingGoalProgress({required this.target, required this.achieved});

  bool get isSet => target > 0;

  /// 残り冊数（超過時は 0）
  int get remaining {
    final rest = target - achieved;
    return rest > 0 ? rest : 0;
  }

  bool get isAchieved => isSet && achieved >= target;

  /// 進捗率（0.0〜1.0）
  double get ratio {
    if (!isSet) return 0;
    final value = achieved / target;
    return value > 1 ? 1 : value;
  }

  /// 進捗率（パーセント整数）
  int get percent => (ratio * 100).round();

  ReadingGoalBadge get badge {
    if (!isSet) return ReadingGoalBadge.notSet;
    if (isAchieved) return ReadingGoalBadge.achieved;
    if (achieved == 0) return ReadingGoalBadge.notStarted;
    if (ratio >= 0.8) return ReadingGoalBadge.almost;
    if (ratio >= 0.5) return ReadingGoalBadge.halfway;
    return ReadingGoalBadge.started;
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingGoalProgress &&
      other.target == target &&
      other.achieved == achieved;

  @override
  int get hashCode => Object.hash(target, achieved);
}
