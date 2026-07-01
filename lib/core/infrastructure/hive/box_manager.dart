/// ツンドクエスト Hive Box 管理システム
///
/// 全 Hive Box の open/close/get を一元管理する。
/// Riverpod Provider 経由でアクセスし、テスト時は Mock で置換可能。
///
/// 参照: 高天原神書 hive-persistence-blueprint §4 (Repository 実装パターン)
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

// ════════════════════════════════════════════
// Box 名定数 — 全 Box の名前空間管理
// ════════════════════════════════════════════

/// 定義済み Hive Box 名の一覧
class BoxNames {
  BoxNames._();

  /// 冒険者ステータス（単一オブジェクト、index 0 保存）
  static const String adventurer = 'adventurer_box';

  /// 登録書籍データ（Book / UserBook）
  static const String books = 'books_box';

  /// 読書セッション履歴（ReadingSession）
  static const String readingSessions = 'reading_sessions_box';

  /// アプリ設定（SharedPreferences の補完的永続化）
  static const String settings = 'settings_box';

  /// チュートリアル表示状態
  static const String tutorial = 'tutorial_box';

  /// 全 Box 名のリスト（openAllBoxes 用）
  static const List<String> all = [
    adventurer,
    books,
    readingSessions,
    settings,
    tutorial,
  ];
}

// ════════════════════════════════════════════
// 抽象インターフェース（テスト可能にするため）
// ════════════════════════════════════════════

/// Box 管理の抽象インターフェース
///
/// テスト時は MockBoxManager で置換し、実 Hive を起動しない。
abstract class BoxManagerInterface {
  /// 指定された Box を取得（未 open なら open する）
  Future<Box<T>> getBox<T>(String name);

  /// 全定義済み Box を一括 open
  Future<void> openAllBoxes();

  /// 指定された Box を close
  Future<void> closeBox(String name);

  /// 全 Box を close
  Future<void> closeAllBoxes();

  /// 指定された Box のデータを全削除
  Future<void> clearBox(String name);
}

// ════════════════════════════════════════════
// Hive 実装
// ════════════════════════════════════════════

/// Hive による Box 管理の具象実装
///
/// Riverpod の Provider 経由でシングルトンとして利用する。
class HiveBoxManager implements BoxManagerInterface {
  /// Box キャッシュ — name → Box のマップ
  final Map<String, Box> _boxes = {};

  /// 破損フラグ（Box 名 → 破損状態）
  final Map<String, bool> _corruptionFlags = {};

  /// 指定された Box 名の破損状態を返す
  bool isCorrupted(String name) => _corruptionFlags[name] ?? false;

  // ── _getBox パターン（§4.1）: キャッシュ付き遅延 open ──

  @override
  Future<Box<T>> getBox<T>(String name) async {
    // キャッシュヒット: 既に開いている Box を返す
    if (_boxes.containsKey(name)) {
      final cachedBox = _boxes[name];
      if (cachedBox != null && cachedBox.isOpen) {
        return cachedBox as Box<T>;
      }
    }

    try {
      final box = await Hive.openBox<T>(name);
      _boxes[name] = box;
      _corruptionFlags[name] = false;
      return box;
    } catch (e) {
      // 型不一致等で open に失敗 → 破損フラグを立て raw データ退避を試行
      debugPrint('[HiveBoxManager] Box "$name" open failed: $e');
      _corruptionFlags[name] = true;

      // ★ 型なし Box で開き直し、raw データ読出しを試行（§4.2）
      try {
        final rawBox = await Hive.openBox<dynamic>(name);
        _boxes[name] = rawBox;
        debugPrint('[HiveBoxManager] Box "$name" opened as raw (untyped)');
        return rawBox as Box<T>;
      } catch (e2) {
        debugPrint('[HiveBoxManager] Box "$name" raw open also failed: $e2');
        rethrow;
      }
    }
  }

  // ── 一括操作 ──

  @override
  Future<void> openAllBoxes() async {
    for (final name in BoxNames.all) {
      try {
        await getBox(name);
      } catch (e) {
        debugPrint('[HiveBoxManager] Failed to open box "$name": $e');
        // 1つの Box の失敗で全停止しない
      }
    }
  }

  @override
  Future<void> closeBox(String name) async {
    if (_boxes.containsKey(name)) {
      final box = _boxes[name];
      if (box != null && box.isOpen) {
        await box.close();
      }
      _boxes.remove(name);
    }
  }

  @override
  Future<void> closeAllBoxes() async {
    for (final name in _boxes.keys.toList()) {
      await closeBox(name);
    }
  }

  @override
  Future<void> clearBox(String name) async {
    try {
      final box = await getBox(name);
      await box.clear();
      await box.flush();
    } catch (e) {
      debugPrint('[HiveBoxManager] Failed to clear box "$name": $e');
      rethrow;
    }
  }
}

// ════════════════════════════════════════════
// ヘルパー: Box 操作ユーティリティ
// ════════════════════════════════════════════

/// Box 操作のヘルパー拡張
///
/// 全 Repository 実装で共通利用する安全な read/write 操作を提供。
class BoxHelper {
  BoxHelper._();

  /// 単一オブジェクトの安全な保存（§4.2 パターン）
  ///
  /// [box] に対象オブジェクトを index 0 に保存し、即座に flush する。
  static Future<void> saveSingle<T>(Box<T> box, T object) async {
    await box.put(0, object);
    await box.flush(); // ★ OS kill 耐性（§4.3）
  }

  /// 単一オブジェクトの安全な読み取り
  ///
  /// 空 Box の場合は null を返す。型不一致時は例外を投げる。
  static T? loadSingle<T>(Box<T> box) {
    if (box.isEmpty) return null;
    try {
      return box.getAt(0);
    } catch (e) {
      debugPrint('[BoxHelper] loadSingle failed: $e');
      rethrow;
    }
  }

  /// コレクションの安全な保存（upsert + delete の2段階）
  ///
  /// [box] に [items] を key → value で upsert し、
  /// [items] に含まれないキーは削除する。
  static Future<void> saveCollection<T>(
    Box<T> box,
    Map<String, T> items,
  ) async {
    if (items.isEmpty) {
      await box.clear();
      await box.flush();
      return;
    }

    // upsert
    await box.putAll(items);

    // 不要キー削除
    final currentKeys = items.keys.toSet();
    final keysToDelete = box.keys
        .where((k) => k is String && !currentKeys.contains(k))
        .toList();
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }

    await box.flush(); // ★ OS kill 耐性
  }

  /// コレクションの安全な読み取り（全件）
  static List<T> loadCollection<T>(Box<T> box) {
    return box.values.toList();
  }
}
