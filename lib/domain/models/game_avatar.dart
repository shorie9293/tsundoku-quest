enum AvatarAngle {
  front, frontRight, right, backRight, back, backLeft, left, frontLeft;

  AvatarAngle get next => AvatarAngle.values[(index + 1) % 8];
  AvatarAngle get prev => AvatarAngle.values[(index + 7) % 8];

  /// 正面方向（アイコン表示用）
  static const defaultAngle = AvatarAngle.front;
}

class GameAvatar {
  final String id;
  final String name;
  final Map<AvatarAngle, String> spriteUrls; // angle -> Supabase Storage public URL

  const GameAvatar({
    required this.id,
    required this.name,
    required this.spriteUrls,
  });

  /// 全角度のURLが揃っているか
  bool get isComplete => spriteUrls.length == AvatarAngle.values.length;

  /// 指定角度のURLを取得（なければfrontにフォールバック）
  String urlForAngle(AvatarAngle angle) =>
      spriteUrls[angle] ?? spriteUrls[AvatarAngle.defaultAngle]!;

  /// 空のプレースホルダーアバター
  factory GameAvatar.placeholder() => GameAvatar(
    id: 'placeholder',
    name: '見習い冒険者',
    spriteUrls: {AvatarAngle.defaultAngle: ''},
  );
}
