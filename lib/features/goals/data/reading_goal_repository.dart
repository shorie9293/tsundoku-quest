/// 読書目標の永続化リポジトリ
///
/// Hive box に JSON 文字列で単一オブジェクト保存する。破損時は未設定へフォールバック。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal.dart';

abstract class ReadingGoalRepository {
  Future<ReadingGoal> load();

  Future<void> save(ReadingGoal goal);
}

/// Hive 実装（'reading_goal_box' に 'goal' キーで JSON 文字列保存）
class HiveReadingGoalRepository implements ReadingGoalRepository {
  HiveReadingGoalRepository(this._boxManager);

  final BoxManagerInterface _boxManager;

  /// 保存キー
  static const String goalKey = 'goal';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await _boxManager.getBox<String>(BoxNames.readingGoal);
    return _box!;
  }

  @override
  Future<ReadingGoal> load() async {
    try {
      final box = await _getBox();
      final raw = box.get(goalKey);
      if (raw == null || raw.isEmpty) return const ReadingGoal.empty();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const ReadingGoal.empty();
      return ReadingGoal.fromJson(decoded);
    } catch (e) {
      debugPrint('[ReadingGoalRepo] load failed: $e');
      return const ReadingGoal.empty();
    }
  }

  @override
  Future<void> save(ReadingGoal goal) async {
    final box = await _getBox();
    await box.put(goalKey, jsonEncode(goal.toJson()));
    await box.flush();
  }
}

/// テスト・オフライン用のインメモリ実装
class InMemoryReadingGoalRepository implements ReadingGoalRepository {
  InMemoryReadingGoalRepository({ReadingGoal? initial})
      : _goal = initial ?? const ReadingGoal.empty();

  ReadingGoal _goal;

  /// 現在保持している目標（検証用）
  ReadingGoal get current => _goal;

  @override
  Future<ReadingGoal> load() async => _goal;

  @override
  Future<void> save(ReadingGoal goal) async {
    _goal = goal;
  }
}
