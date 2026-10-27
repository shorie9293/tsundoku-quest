/// 本番既定の [QuietHoursGuard] 生成点
///
/// スケジューラの `guard` を省略した場合は必ずここを通るため、
/// 設定画面（[HiveQuietHoursRepository]）で保存した静穏時間設定が
/// 本番の通知経路へ自動的に反映される。
///
/// 試練では [repositoryFactory] を差し替えることで、
/// **既定生成経路のまま**任意のリポジトリを注入できる
/// （Hive に触れずに既定結線を検証するための差し替えシーム）。
library;

import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_service.dart';

import 'hive_quiet_hours_repository.dart';
import 'quiet_hours_repository.dart';

abstract final class QuietHoursGuardWiring {
  /// 既定リポジトリの生成関数。null なら本番の [HiveQuietHoursRepository]。
  ///
  /// Hive の BoxManager を持たない経路（試練・バックグラウンド分離）でも
  /// 例外にせず既定設定（無効）へ落とすため、[boxManager] を省略できる。
  static QuietHoursRepository Function()? repositoryFactory;

  /// 差し替えを既定へ戻す（試練の tearDown で呼ぶ）。
  static void reset() => repositoryFactory = null;

  /// 明示指定が無いときに使うガードを生成する。
  ///
  /// [boxManager] 省略時は `BoxManagerInterface` を持たないため
  /// [NoopQuietHoursRepository]（＝静穏時間なし＝従来通り）に落ちる。
  /// これにより Hive 未初期化の通知経路でも例外もハングも起きない。
  static QuietHoursGuard create({BoxManagerInterface? boxManager}) {
    final factory = repositoryFactory;
    final QuietHoursRepository repository = factory != null
        ? factory()
        : boxManager != null
            ? HiveQuietHoursRepository(boxManager, openIfMissing: false)
            : NoopQuietHoursRepository();
    return QuietHoursRepositoryGuard(repository);
  }
}
