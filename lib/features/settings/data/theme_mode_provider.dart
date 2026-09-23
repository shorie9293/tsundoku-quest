import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tsundoku_quest/features/settings/data/theme_mode_repository.dart';
import 'package:tsundoku_quest/features/settings/domain/theme_mode_setting.dart';

/// テーマモードリポジトリのプロバイダ
final themeModeRepositoryProvider = Provider<ThemeModeRepository>(
  (ref) => const ThemeModeRepository(),
);

/// アプリ全体のテーマモード（ライト/ダーク/システム）を管理するコントローラ
class ThemeModeController extends Notifier<ThemeModeSetting> {
  @override
  ThemeModeSetting build() => ThemeModeSetting.system;

  /// 保存済みの設定を読み込む（未保存/不正値は system にフォールバック）。
  Future<void> load() async {
    final repository = ref.read(themeModeRepositoryProvider);
    final saved = await repository.loadThemeMode();
    state = saved ?? ThemeModeSetting.system;
  }

  /// テーマモードを変更して永続化する。
  ///
  /// state 更新後に永続化する。
  Future<void> setMode(ThemeModeSetting mode) async {
    state = mode;
    await ref.read(themeModeRepositoryProvider).saveThemeMode(mode);
  }
}

/// アプリ全体のテーマモードプロバイダ
final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeModeSetting>(
  ThemeModeController.new,
);
