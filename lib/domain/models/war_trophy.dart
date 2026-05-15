/// 戦利品カード（読了後メモ）
class WarTrophy {
  final String id;
  final String userBookId;
  final String userId;
  final List<String> learnings; // 3つの学び
  final String action; // 1つの行動
  final String? favoriteQuote;
  final String createdAt;

  const WarTrophy({
    required this.id,
    required this.userBookId,
    required this.userId,
    required this.learnings,
    required this.action,
    this.favoriteQuote,
    required this.createdAt,
  });

  factory WarTrophy.fromJson(Map<String, dynamic> json) {
    return WarTrophy(
      id: json['id'] as String,
      userBookId: json['userBookId'] as String,
      userId: json['userId'] as String,
      learnings:
          (json['learnings'] as List<dynamic>).map((e) => e as String).toList(),
      action: json['action'] as String,
      favoriteQuote: json['favoriteQuote'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userBookId': userBookId,
      'userId': userId,
      'learnings': learnings,
      'action': action,
      'favoriteQuote': favoriteQuote,
      'createdAt': createdAt,
    };
  }
}
