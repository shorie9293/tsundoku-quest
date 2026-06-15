class Enemy {
  final String id;
  final String name;
  final int rank; // 1-5
  final int hp;
  final int attack;
  final int defense;
  final int xpReward;
  final String spriteUrl; // Supabase Storage public URL

  const Enemy({
    required this.id,
    required this.name,
    required this.rank,
    required this.hp,
    required this.attack,
    required this.defense,
    required this.xpReward,
    required this.spriteUrl,
  });

  /// JSONからEnemyを生成
  factory Enemy.fromJson(Map<String, dynamic> json) => Enemy(
        id: json['id'] as String,
        name: json['name'] as String,
        rank: json['rank'] as int,
        hp: json['hp'] as int,
        attack: json['attack'] as int,
        defense: json['defense'] as int,
        xpReward: json['xp_reward'] as int,
        spriteUrl: json['sprite_url'] as String,
      );

  /// EnemyをJSONに変換
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rank': rank,
        'hp': hp,
        'attack': attack,
        'defense': defense,
        'xp_reward': xpReward,
        'sprite_url': spriteUrl,
      };
}
