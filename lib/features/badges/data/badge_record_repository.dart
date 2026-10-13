/// 読書達成バッジ獲得記録の永続化リポジトリ
///
/// Hive box（'reading_goal_box' の 'badge_records' キー）に
/// JSON 文字列で保存する。破損時は空集合へフォールバック。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';

/// バッジ獲得記録の集合（id → 獲得日時 ISO8601 文字列）
class BadgeRecordSet {
  final Map<String, String> earnedAtById;

  const BadgeRecordSet([this.earnedAtById = const {}]);

  bool get isEmpty => earnedAtById.isEmpty;

  /// 登録済みバッジid一覧（挿入順）
  List<String> get ids => earnedAtById.keys.toList();

  /// 指定idの獲得日時（未登録・解釈不能なら null）
  DateTime? earnedAtOf(String id) {
    final raw = earnedAtById[id];
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// 既存は保持し、未登録idのみ [now] を獲得日時として追加する
  BadgeRecordSet recordAll(Iterable<String> ids, {required DateTime now}) {
    final next = Map<String, String>.of(earnedAtById);
    final stamp = now.toUtc().toIso8601String();
    for (final id in ids) {
      next.putIfAbsent(id, () => stamp);
    }
    return BadgeRecordSet(next);
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.of(earnedAtById);

  /// 破損耐性：非Map値・非String値は黙って無視する
  factory BadgeRecordSet.fromJson(Map<String, dynamic> json) {
    final map = <String, String>{};
    json.forEach((key, value) {
      if (value is String) {
        map[key] = value;
      }
    });
    return BadgeRecordSet(map);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BadgeRecordSet &&
        _mapEquals(other.earnedAtById, earnedAtById);
  }

  @override
  int get hashCode => Object.hashAllUnordered(
        earnedAtById.entries.map((e) => Object.hash(e.key, e.value)),
      );
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

/// バッジ獲得記録リポジトリの抽象
abstract class BadgeRecordRepository {
  Future<BadgeRecordSet> load();

  Future<void> save(BadgeRecordSet set);
}

/// Hive 実装（'reading_goal_box' に 'badge_records' キーで JSON 文字列保存）
class HiveBadgeRecordRepository implements BadgeRecordRepository {
  HiveBadgeRecordRepository(this._boxManager);

  final BoxManagerInterface _boxManager;

  /// 保存キー（'goal' / 'daily_goal' と別の名前空間）
  static const String recordKey = 'badge_records';

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await _boxManager.getBox<String>(BoxNames.readingGoal);
    return _box!;
  }

  @override
  Future<BadgeRecordSet> load() async {
    try {
      final box = await _getBox();
      final raw = box.get(recordKey);
      if (raw == null || raw.isEmpty) return const BadgeRecordSet();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const BadgeRecordSet();
      }
      return BadgeRecordSet.fromJson(decoded);
    } catch (e) {
      debugPrint('[BadgeRecordRepo] load failed: $e');
      return const BadgeRecordSet();
    }
  }

  @override
  Future<void> save(BadgeRecordSet set) async {
    final box = await _getBox();
    await box.put(recordKey, jsonEncode(set.toJson()));
    await box.flush();
  }
}

/// テスト・オフライン用のインメモリ実装
class InMemoryBadgeRecordRepository implements BadgeRecordRepository {
  InMemoryBadgeRecordRepository({BadgeRecordSet? initial})
      : _set = initial ?? const BadgeRecordSet();

  BadgeRecordSet _set;

  /// 現在保持している記録（検証用）
  BadgeRecordSet get current => _set;

  @override
  Future<BadgeRecordSet> load() async => _set;

  @override
  Future<void> save(BadgeRecordSet set) async {
    _set = set;
  }
}
