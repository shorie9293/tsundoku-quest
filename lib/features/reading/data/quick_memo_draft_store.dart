/// クイックメモ下書きの保存先（端末ローカル）
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/features/reading/domain/quick_memo.dart';

/// 下書きストアの抽象（試練では InMemory 実装を注入する）
abstract class QuickMemoDraftStore {
  Future<QuickMemoDraft?> load(String userBookId);

  Future<void> save(String userBookId, QuickMemoDraft draft);

  Future<void> clear(String userBookId);
}

/// SharedPreferences 実装（本番経路）
class SharedPreferencesQuickMemoDraftStore implements QuickMemoDraftStore {
  static const String keyPrefix = 'quick_memo_draft_';

  static String keyFor(String userBookId) => '$keyPrefix$userBookId';

  @override
  Future<QuickMemoDraft?> load(String userBookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(userBookId));
      if (raw == null) return null;
      return QuickMemoDraft.fromJson(jsonDecode(raw));
    } catch (_) {
      // 破損した下書きは無視する（起動を妨げない）
      return null;
    }
  }

  @override
  Future<void> save(String userBookId, QuickMemoDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(userBookId), jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clear(String userBookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(userBookId));
  }
}

/// 試練用のインメモリ実装。書き込み・消去の履歴も観測できる。
class InMemoryQuickMemoDraftStore implements QuickMemoDraftStore {
  final Map<String, QuickMemoDraft> _drafts = {};
  final List<String> saveCalls = [];
  final List<String> clearCalls = [];

  @override
  Future<QuickMemoDraft?> load(String userBookId) async => _drafts[userBookId];

  @override
  Future<void> save(String userBookId, QuickMemoDraft draft) async {
    saveCalls.add(userBookId);
    _drafts[userBookId] = draft;
  }

  @override
  Future<void> clear(String userBookId) async {
    clearCalls.add(userBookId);
    _drafts.remove(userBookId);
  }
}
