import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tsundoku_quest/features/settings/data/reduce_motion_repository.dart';
import 'package:tsundoku_quest/features/settings/domain/reduce_motion_setting.dart';

/// 動きを減らす設定リポジトリのプロバイダ
final reduceMotionRepositoryProvider = Provider<ReduceMotionRepository>(
  (ref) => const ReduceMotionRepository(),
);

/// アプリ全体の「動きを減らす」設定を管理するコントローラ
class ReduceMotionController extends StateNotifier<ReduceMotionSetting> {
  ReduceMotionController(this._repository)
      : super(ReduceMotionSetting.system);

  final ReduceMotionRepository _repository;

  /// 保存済みの設定を読み込む（未保存/不正値は system にフォールバック）。
  Future<void> load() async {
    final saved = await _repository.loadReduceMotion();
    state = saved ?? ReduceMotionSetting.system;
  }

  /// 設定を変更して永続化する。
  ///
  /// 永続化に成功してから state を更新する（保存失敗時は表示を変えない）。
  Future<void> setSetting(ReduceMotionSetting setting) async {
    await _repository.saveReduceMotion(setting);
    state = setting;
  }
}

/// アプリ全体の「動きを減らす」設定プロバイダ
final reduceMotionProvider =
    StateNotifierProvider<ReduceMotionController, ReduceMotionSetting>(
  (ref) => ReduceMotionController(ref.watch(reduceMotionRepositoryProvider)),
);
