import 'dart:math';

/// デイリーミッションの種別
enum DailyMissionType {
  /// N分間読書する
  readTime,

  /// 本を1冊読了する
  completeBook,

  /// Nページ読む
  readPages,
}

/// デイリーミッション1件
class DailyMission {
  final String id;
  final DailyMissionType type;
  final int target; // 目標値（分、ページ数、冊数）
  final int xpReward; // 達成報酬XP
  final String title;
  final String description;
  final String icon; // 絵文字アイコン
  bool isCompleted;
  int currentProgress; // 現在の進捗

  DailyMission({
    required this.id,
    required this.type,
    required this.target,
    required this.xpReward,
    required this.title,
    required this.description,
    required this.icon,
    this.isCompleted = false,
    this.currentProgress = 0,
  });

  double get progress => target > 0 ? (currentProgress / target).clamp(0.0, 1.0) : 0.0;

  /// 進捗を加算し、達成したらtrueを返す
  bool addProgress(int amount) {
    if (isCompleted) return false;
    currentProgress = (currentProgress + amount).clamp(0, target);
    if (currentProgress >= target) {
      isCompleted = true;
      currentProgress = target;
      return true;
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'target': target,
        'xpReward': xpReward,
        'title': title,
        'isCompleted': isCompleted,
        'currentProgress': currentProgress,
      };

  factory DailyMission.fromJson(Map<String, dynamic> json) {
    return DailyMission(
      id: json['id'] as String,
      type: DailyMissionType.values.byName(json['type'] as String),
      target: json['target'] as int,
      xpReward: json['xpReward'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '📖',
      isCompleted: json['isCompleted'] as bool? ?? false,
      currentProgress: json['currentProgress'] as int? ?? 0,
    );
  }

  /// 今日のミッション候補プール
  static final List<DailyMission> _missionPool = [
    DailyMission(
      id: 'read_15min',
      type: DailyMissionType.readTime,
      target: 15,
      xpReward: 50,
      title: '📖 15分間の読書をしよう',
      description: 'どの本でもOK。1ページでも冒険は始まる！',
      icon: '📖',
    ),
    DailyMission(
      id: 'read_30min',
      type: DailyMissionType.readTime,
      target: 30,
      xpReward: 100,
      title: '⏰ 30分間の読書をしよう',
      description: '少し長めの読書タイム。コーヒーと一緒にどうぞ。',
      icon: '⏰',
    ),
    DailyMission(
      id: 'read_60min',
      type: DailyMissionType.readTime,
      target: 60,
      xpReward: 200,
      title: '🔥 1時間の集中読書！',
      description: '今日は気合を入れて1時間！達成感が違う。',
      icon: '🔥',
    ),
    DailyMission(
      id: 'complete_book',
      type: DailyMissionType.completeBook,
      target: 1,
      xpReward: 150,
      title: '⚔️ 本を1冊討伐しよう',
      description: '戦利品カードを書いて冒険を完了！',
      icon: '⚔️',
    ),
    DailyMission(
      id: 'read_20pages',
      type: DailyMissionType.readPages,
      target: 20,
      xpReward: 60,
      title: '📄 20ページ読もう',
      description: 'ページを進めるのも立派な冒険。',
      icon: '📄',
    ),
    DailyMission(
      id: 'read_50pages',
      type: DailyMissionType.readPages,
      target: 50,
      xpReward: 120,
      title: '📚 50ページ読もう',
      description: '一気に読み進めよう！ダンジョン深部へ！',
      icon: '📚',
    ),
  ];

  /// 今日のミッションをランダムに最大3つ選出（seedは日付）
  static List<DailyMission> generateDailyMissions(DateTime date) {
    final rng = Random(date.hashCode);
    final pool = List<DailyMission>.from(_missionPool);
    pool.shuffle(rng);
    // 最大3つ、かつ同タイプは1つまで
    final selected = <DailyMission>[];
    final usedTypes = <DailyMissionType>{};
    for (final mission in pool) {
      if (selected.length >= 3) break;
      if (usedTypes.contains(mission.type)) continue;
      usedTypes.add(mission.type);
      // 新しいインスタンスとして返す（進捗リセット）
      selected.add(DailyMission(
        id: mission.id,
        type: mission.type,
        target: mission.target,
        xpReward: mission.xpReward,
        title: mission.title,
        description: mission.description,
        icon: mission.icon,
      ));
    }
    return selected;
  }
}
