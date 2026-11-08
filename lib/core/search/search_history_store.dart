import 'package:shared_preferences/shared_preferences.dart';

import 'search_history.dart';

/// 検索語履歴の保存先（試練では差し替え可能）。
abstract class SearchHistoryStore {
  Future<SearchHistory> load();

  Future<void> save(SearchHistory history);
}

/// SharedPreferences 実装。プラグイン不在・IO 失敗は握りつぶす
/// （履歴が残らないだけで、検索画面は操作可能でなければならない）。
class SharedPreferencesSearchHistoryStore implements SearchHistoryStore {
  static const String key = 'library_search_history_v1';

  const SharedPreferencesSearchHistoryStore();

  @override
  Future<SearchHistory> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SearchHistory.decode(prefs.getString(key));
    } catch (_) {
      return SearchHistory.empty();
    }
  }

  @override
  Future<void> save(SearchHistory history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, history.encode());
    } catch (_) {
      // 永続化失敗は無音（検索操作を妨げない）
    }
  }
}
