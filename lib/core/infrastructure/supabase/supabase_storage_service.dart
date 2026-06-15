import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/models/game_avatar.dart';
import '../../../domain/models/enemy.dart';

class SupabaseStorageService {
  final SupabaseClient _client;
  static const String bucketName = 'game-assets';

  const SupabaseStorageService(this._client);

  /// Returns a StorageFileApi bound to the game-assets bucket
  StorageFileApi get _bucket => _client.storage.from(bucketName);

  /// アバターの全角度スプライト公開URLを取得する
  /// [avatarId] 例: 'default' → 'avatars/default/front.png'
  Future<Map<AvatarAngle, String>> fetchAvatarSprites(String avatarId) async {
    final urls = <AvatarAngle, String>{};
    for (final angle in AvatarAngle.values) {
      final path = 'avatars/$avatarId/${angle.name}.png';
      urls[angle] = _bucket.getPublicUrl(path);
    }
    return urls;
  }

  /// 敵スプライトの公開URLを取得する
  String fetchEnemySpriteUrl(String enemyId) {
    final path = 'enemies/$enemyId.png';
    return _bucket.getPublicUrl(path);
  }

  /// 敵一覧JSONをSupabase Storageから取得する
  /// 'enemies/enemies.json' をダウンロードしてパース
  /// JSON形式:
  ///   - 配列: [{"id": "...", ...}, ...]
  ///   - オブジェクト: {"enemies": [{"id": "...", ...}, ...]}
  Future<List<Enemy>> fetchEnemyList() async {
    try {
      final data = await _bucket.download('enemies/enemies.json');
      final jsonStr = utf8.decode(data);
      final decoded = jsonDecode(jsonStr);
      List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map<String, dynamic>) {
        list = (decoded['enemies'] as List<dynamic>?) ?? [];
      } else {
        return [];
      }
      return list
          .map((e) => Enemy.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 公開URLを構築
  String getPublicUrl(String path) {
    return _bucket.getPublicUrl(path);
  }
}
