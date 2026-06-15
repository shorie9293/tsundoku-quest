import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/infrastructure/supabase/supabase_client_provider.dart';
import '../../core/infrastructure/supabase/supabase_storage_service.dart';
import '../../domain/models/enemy.dart';

/// 敵一覧（Supabase Storage から取得）
final enemyListProvider = FutureProvider<List<Enemy>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final storage = SupabaseStorageService(client);
  return storage.fetchEnemyList();
});

/// ランダムに敵を1体選出する
/// [playerLevel] が指定された場合、そのレベル以下のランクから抽選
class EnemySelector {
  final Random _random;

  EnemySelector({Random? random}) : _random = random ?? Random();

  /// 敵リストからランダムに1体選ぶ
  Enemy? selectRandom(List<Enemy> enemies, {int? playerLevel}) {
    if (enemies.isEmpty) return null;

    final candidates = playerLevel != null
        ? enemies.where((e) => _isRankAvailable(e.rank, playerLevel)).toList()
        : enemies;

    if (candidates.isEmpty) return null;

    // 低ランクほど出現率が高くなる重み付け
    final weighted = <Enemy>[];
    for (final enemy in candidates) {
      final weight = 6 - enemy.rank; // rank 1→5, rank 5→1
      for (int i = 0; i < weight; i++) {
        weighted.add(enemy);
      }
    }
    return weighted[_random.nextInt(weighted.length)];
  }

  /// 指定ランクがプレイヤーレベルに対して出現可能か
  bool _isRankAvailable(int rank, int playerLevel) {
    if (playerLevel <= 3) return rank <= 2;
    if (playerLevel <= 7) return rank <= 3;
    if (playerLevel <= 15) return rank <= 4;
    return true;
  }
}
