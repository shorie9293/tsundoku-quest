/// 日次読書目標の永続化リポジトリ
///
/// Hive box（'reading_goal_box'、既存 'goal' キーと別の 'daily_goal' キー）に
/// JSON 文字列で保存する。破損時は未設定へフォールバック。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/features/goals/domain/daily_reading_goal.dart';

abstract class DailyReadingGoalRepository {
  Future<DailyReadingGoal> load();

  Future<void> save(DailyReadingGoal goal);
}

/// Hive 実装（'reading_goal_box' に 'daily_goal' キーで JSON 文字列保存）
class HiveDailyReadingGoalRepository implements DailyReadingGoalRepository {
  HiveDailyReadingGoalRepository(this._boxManager);

  final BoxManagerInterface _boxManager;

  /// 保存キー（既存 'goal' キーと衝突しない）
  static const String goalKey = 'daily_goal';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await _boxManager.getBox<String>(BoxNames.readingGoal);
    return _box!;
  }

  @override
  Future<DailyReadingGoal> load() async {
    try {
      final box = await _getBox();
      final raw = box.get(goalKey);
      if (raw == null || raw.isEmpty) return const DailyReadingGoal.empty();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const DailyReadingGoal.empty();
      }
      return DailyReadingGoal.fromJson(decoded);
    } catch (e) {
      debugPrint('[DailyReadingGoalRepo] load failed: $e');
      return const DailyReadingGoal.empty();
    }
  }

  @override
  Future<void> save(DailyReadingGoal goal) async {
    final box = await _getBox();
    await box.put(goalKey, jsonEncode(goal.toJson()));
    await box.flush();
  }
}

/// テスト・オフライン用のインメモリ実装
class InMemoryDailyReadingGoalRepository implements DailyReadingGoalRepository {
  InMemoryDailyReadingGoalRepository({DailyReadingGoal? initial})
      : _goal = initial ?? const DailyReadingGoal.empty();

  DailyReadingGoal _goal;

  /// 現在保持している目標（検証用）
  DailyReadingGoal get current => _goal;

  @override
  Future<DailyReadingGoal> load() async => _goal;

  @override
  Future<void> save(DailyReadingGoal goal) async {
    _goal = goal;
  }
}