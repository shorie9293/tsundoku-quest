import 'package:tsundoku_quest/domain/models/war_trophy.dart';

/// 戦利品リポジトリの抽象インターフェース
abstract class WarTrophyRepository {
  /// 自分の戦利品を全件取得
  Future<List<WarTrophy>> getMyTrophies();

  /// 戦利品を作成
  Future<WarTrophy> createTrophy(WarTrophy trophy);

  /// 戦利品を更新
  Future<WarTrophy> updateTrophy(WarTrophy trophy);
}
