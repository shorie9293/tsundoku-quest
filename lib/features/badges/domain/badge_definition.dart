/// 読書達成バッジの定義モデル（ドメイン層・純粋Dart）
library;

/// バッジのカテゴリ
enum BadgeCategory {
  completedBooks('読了冊数', '📚'),
  streak('連続記録', '🔥'),
  readingTime('読書時間', '⏱️'),
  pagesTotal('読了ページ', '📄'),
  timeOfDay('読書の時間帯', '🌅');

  final String label;
  final String icon;

  const BadgeCategory(this.label, this.icon);
}

/// バッジの定義（id・名前・閾値など不変情報）
class BadgeDefinition {
  final String id;
  final String name;
  final String description;
  final String icon;
  final BadgeCategory category;

  /// 階級（1..4）
  final int tier;

  /// 目標値
  final int threshold;

  /// 達成判定に使うメトリクスのキー
  final String metricKey;

  /// 定義リスト構築用の const コンストラクタ（検証なし・信頼済み入力専用）
  const BadgeDefinition.def({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.tier,
    required this.threshold,
    required this.metricKey,
  });

  /// threshold <= 0 は不正値として ArgumentError を投げる
  factory BadgeDefinition({
    required String id,
    required String name,
    required String description,
    required String icon,
    required BadgeCategory category,
    required int tier,
    required int threshold,
    required String metricKey,
  }) {
    if (threshold <= 0) {
      throw ArgumentError.value(threshold, 'threshold', 'must be positive');
    }
    return BadgeDefinition.def(
      id: id,
      name: name,
      description: description,
      icon: icon,
      category: category,
      tier: tier,
      threshold: threshold,
      metricKey: metricKey,
    );
  }
}

/// バッジの進捗スナップショット
class BadgeProgress {
  final BadgeDefinition definition;
  final int current;
  final bool isEarned;
  final DateTime? earnedAt;

  const BadgeProgress({
    required this.definition,
    required this.current,
    required this.isEarned,
    this.earnedAt,
  });

  int get required => definition.threshold;

  /// 進捗率（0.0〜1.0 にクランプ）
  double get ratio {
    if (required <= 0) return 0.0;
    final r = current / required;
    if (r < 0.0) return 0.0;
    if (r > 1.0) return 1.0;
    return r;
  }

  int get percent => (ratio * 100).round();

  /// 目標までの残り（0 未満にならない）
  int get remaining {
    final r = required - current;
    return r < 0 ? 0 : r;
  }

  /// '3 / 7' 形式の進捗ラベル
  String get progressLabel {
    final c = current < required ? current : required;
    return '$c / $required';
  }

  /// earnedAt のみ差し替えた副本を返す
  BadgeProgress copyWith({DateTime? earnedAt}) {
    return BadgeProgress(
      definition: definition,
      current: current,
      isEarned: isEarned,
      earnedAt: earnedAt,
    );
  }
}

/// バッジコレクション（進捗の集合）
class BadgeCollection {
  final List<BadgeProgress> badges;

  const BadgeCollection(this.badges);

  bool get isEmpty => badges.isEmpty;

  int get total => badges.length;

  int get earnedCount =>
      badges.where((b) => b.isEarned).length;

  /// 獲得率（0.0〜1.0、空なら 0.0）
  double get completionRatio =>
      total == 0 ? 0.0 : earnedCount / total;

  /// '獲得 3 / 24' 形式のサマリ
  String get summaryLabel => '獲得 $earnedCount / $total';

  List<BadgeProgress> get earned =>
      badges.where((b) => b.isEarned).toList();

  List<BadgeProgress> get locked =>
      badges.where((b) => !b.isEarned).toList();

  /// 指定カテゴリのバッジのみ抽出（宣言順を維持）
  List<BadgeProgress> badgesOf(BadgeCategory category) =>
      badges.where((b) => b.definition.category == category).toList();
}

/// 階級の表示ラベル（1..4 以外はブロンズ）
String badgeTierLabel(int tier) {
  switch (tier) {
    case 1:
      return 'ブロンズ';
    case 2:
      return 'シルバー';
    case 3:
      return 'ゴールド';
    case 4:
      return '伝説';
    default:
      return 'ブロンズ';
  }
}
