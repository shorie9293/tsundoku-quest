import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tsundoku_quest/features/settings/data/text_scale_repository.dart';
import 'package:tsundoku_quest/features/settings/domain/text_scale_setting.dart';

/// 文字サイズリポジトリのプロバイダ
final textScaleRepositoryProvider = Provider<TextScaleRepository>(
  (ref) => const TextScaleRepository(),
);

/// アプリ全体の文字スケール倍率を管理するコントローラ
class TextScaleController extends Notifier<double> {
  @override
  double build() => TextScaleSetting.normalScale;

  /// 保存済みの設定を読み込む（未保存/不正値は1.0に正規化）。
  Future<void> load() async {
    final repository = ref.read(textScaleRepositoryProvider);
    final saved = await repository.loadScale();
    state = TextScaleSetting.normalized(saved);
  }

  /// 文字サイズを変更して永続化する。
  ///
  /// 許可外の値は ArgumentError を投げ、state は変更しない。
  /// 正常値は state 更新後に永続化する。
  Future<void> setScale(double scale) async {
    if (!TextScaleSetting.isAllowed(scale)) {
      throw ArgumentError.value(scale, 'scale', '許可されていない文字サイズ倍率');
    }
    state = scale;
    await ref.read(textScaleRepositoryProvider).saveScale(scale);
  }
}

/// アプリ全体の文字スケール倍率プロバイダ
final textScaleProvider =
    NotifierProvider<TextScaleController, double>(TextScaleController.new);
