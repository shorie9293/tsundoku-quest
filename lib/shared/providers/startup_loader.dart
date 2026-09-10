import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';

/// アプリ起動時に Supabase から表示用データをロードする。
///
/// 足跡画面の読書感想（戦利品）は warTrophyProvider 由来だが、
/// fetchTrophies() が起動時に呼ばれておらず、再起動後に感想が
/// 表示されない禍津があったため、本ローダーで起動時取得を担う。
Future<void> loadStartupData(ProviderContainer container) async {
  try {
    await container.read(warTrophyProvider.notifier).fetchTrophies();
  } catch (e) {
    // 起動を妨げない。オフライン時はインメモリデータで動作する。
    assert(() {
      // ignore: avoid_print
      print('⚠️ [Startup] 戦利品ロード失敗: $e');
      return true;
    }());
  }
}
