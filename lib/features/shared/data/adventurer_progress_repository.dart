/// 冒険者ステータス（レベル・XP・称号・読書日）の永続化リポジトリ。
///
/// `adventurer_box`（BoxNames.adventurer）に 'stats' キーで JSON 文字列を保存する。
/// 破損時は駆け出し状態へフォールバックし、例外は投げない。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/hive_initializer.dart';
import 'package:tsundoku_quest/domain/models/adventurer_progress.dart';

abstract class AdventurerProgressRepository {
  Future<AdventurerProgress> load();

  Future<void> save(AdventurerProgress progress);
}

/// Hive 実装
///
/// Hive 未初期化（widget 試練等）では **box を開かず** に既定値を返す／保存を捨てる。
/// （Hive.openBox を未初期化状態で呼ぶと zone 汚染で flutter_test が必ず落ちる）
class HiveAdventurerProgressRepository implements AdventurerProgressRepository {
  HiveAdventurerProgressRepository(this._boxManager);

  final BoxManagerInterface _boxManager;

  /// 保存キー
  static const String statsKey = 'stats';

  Box<String>? _box;

  Future<Box<String>?> _getBox() async {
    if (_box != null && _box!.isOpen) return _box;
    // 未初期化（widget 試練等）では box を開かない — zone 汚染で試練が落ちる
    if (!hiveInitialized && !Hive.isBoxOpen(BoxNames.adventurer)) return null;
    try {
      _box = await _boxManager.getBox<String>(BoxNames.adventurer);
      return _box;
    } catch (e) {
      debugPrint('[AdventurerProgressRepo] box open failed: $e');
      return null;
    }
  }

  @override
  Future<AdventurerProgress> load() async {
    try {
      final box = await _getBox();
      if (box == null) return AdventurerProgress.beginner();
      final raw = box.get(statsKey);
      if (raw == null || raw.isEmpty) return AdventurerProgress.beginner();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return AdventurerProgress.beginner();
      }
      return AdventurerProgress.fromJson(decoded);
    } catch (e) {
      debugPrint('[AdventurerProgressRepo] load failed: $e');
      return AdventurerProgress.beginner();
    }
  }

  @override
  Future<void> save(AdventurerProgress progress) async {
    try {
      final box = await _getBox();
      if (box == null) return;
      await box.put(statsKey, jsonEncode(progress.toJson()));
      await box.flush();
    } catch (e) {
      debugPrint('[AdventurerProgressRepo] save failed: $e');
    }
  }
}

/// テスト・オフライン用のインメモリ実装
class InMemoryAdventurerProgressRepository
    implements AdventurerProgressRepository {
  InMemoryAdventurerProgressRepository({AdventurerProgress? initial})
      : _progress = initial ?? AdventurerProgress.beginner();

  AdventurerProgress _progress;

  /// 保存された件数（書き込み到達の検証用）
  int saveCount = 0;

  /// 現在保持している値（検証用）
  AdventurerProgress get current => _progress;

  @override
  Future<AdventurerProgress> load() async => _progress;

  @override
  Future<void> save(AdventurerProgress progress) async {
    _progress = progress;
    saveCount++;
  }
}
