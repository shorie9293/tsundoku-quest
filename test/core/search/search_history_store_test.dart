import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/search/search_history.dart';
import 'package:tsundoku_quest/core/search/search_history_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesSearchHistoryStore', () {
    test('キーは library_search_history_v1 固定', () {
      expect(SharedPreferencesSearchHistoryStore.key, 'library_search_history_v1');
    });

    test('未保存なら空の履歴を返す', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const store = SharedPreferencesSearchHistoryStore();
      expect((await store.load()).entries, isEmpty);
    });

    test('save した内容を load で復元できる（往復）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const store = SharedPreferencesSearchHistoryStore();
      final history = SearchHistory(entries: ['犬', '猫']);
      await store.save(history);

      final loaded = await store.load();
      expect(loaded.entries, ['犬', '猫']);
    });

    test('壊れた保存値は空の履歴へフォールバックする', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesSearchHistoryStore.key: '{broken',
      });
      const store = SharedPreferencesSearchHistoryStore();
      expect((await store.load()).entries, isEmpty);
    });

    test('別キー（検索条件）の値には干渉しない', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const store = SharedPreferencesSearchHistoryStore();
      await store.save(SearchHistory(entries: ['猫']));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SharedPreferencesSearchHistoryStore.key), isNotNull);
      expect(prefs.getString('library_search_query_v1'), isNull);
    });
  });
}
