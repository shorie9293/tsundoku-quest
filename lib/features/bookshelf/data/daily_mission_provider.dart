import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_reward_event_exporter.dart';
import '../domain/daily_mission.dart';

/// デイリーミッション状態
class DailyMissionState {
  final List<DailyMission> missions;
  final DateTime date; // このミッションの日付

  const DailyMissionState({
    required this.missions,
    required this.date,
  });

  bool get allCompleted => missions.every((m) => m.isCompleted);
  int get completedCount => missions.where((m) => m.isCompleted).length;
  int get totalCount => missions.length;
}

/// デイリーミッションを管理するStateNotifier
///
/// Hive + SharedPreferences の二段階永続化:
///   - Hive BoxManager が利用可能 → バイナリ永続化（高速）
///   - Hive 利用不可 → SharedPreferences + JSON にフォールバック
class DailyMissionNotifier extends StateNotifier<DailyMissionState> {
  static const _prefsKey = 'daily_missions_state';
  static const _prefsKeyDate = 'daily_missions_date';
  static const _hiveBoxName = 'settings_box';
  static const _hiveDateKey = 'daily_missions_date';
  static const int _hiveMissionsKey = 100; // index key for missions list

  final TsundokuRewardEventExporter? _rewardExporter;
  final BoxManagerInterface? _boxManager;
  bool _dailyMissionCompleteEmitted = false;

  /// [boxManager] が指定された場合は Hive 永続化、
  /// null の場合は SharedPreferences 永続化を使用する。
  DailyMissionNotifier({TsundokuRewardEventExporter? rewardExporter, BoxManagerInterface? boxManager})
      : _rewardExporter = rewardExporter,
        _boxManager = boxManager,
        super(DailyMissionState(
            missions: [], date: DateTime.fromMillisecondsSinceEpoch(0))) {
    _loadOrGenerate();
  }

  /// 保存されているミッションを読み込むか、新規生成する
  Future<void> _loadOrGenerate() async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Hive 読み込みを試行
    if (_boxManager != null) {
      try {
        final box = await _boxManager.getBox<dynamic>(_hiveBoxName);
        final savedDateStr = box.get(_hiveDateKey) as String?;

        if (savedDateStr != null) {
          final savedDate = DateTime.tryParse(savedDateStr);
          if (savedDate != null &&
              savedDate.year == todayDate.year &&
              savedDate.month == todayDate.month &&
              savedDate.day == todayDate.day) {
            final savedMissions = box.get(_hiveMissionsKey);
            if (savedMissions != null && savedMissions is List) {
              final missions = savedMissions.cast<DailyMission>();
              state = DailyMissionState(missions: missions, date: todayDate);
              _dailyMissionCompleteEmitted = missions.every((m) => m.isCompleted);
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [DailyMission] Hive 読み込み失敗: $e');
      }
    }

    // SharedPreferences フォールバック
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDateStr = prefs.getString(_prefsKeyDate);
      final savedDate = savedDateStr != null ? DateTime.tryParse(savedDateStr) : null;

      if (savedDate != null &&
          savedDate.year == todayDate.year &&
          savedDate.month == todayDate.month &&
          savedDate.day == todayDate.day) {
        final savedMissionsJson = prefs.getString(_prefsKey);
        if (savedMissionsJson != null) {
          final list = jsonDecode(savedMissionsJson) as List<dynamic>;
          final missions = list
              .map((e) => DailyMission.fromJson(e as Map<String, dynamic>))
              .toList();
          state = DailyMissionState(missions: missions, date: todayDate);
          _dailyMissionCompleteEmitted = missions.every((m) => m.isCompleted);
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [DailyMission] SharedPreferences 読み込み失敗: $e');
    }

    // 新規生成（日付が変わったらフラグリセット）
    final missions = DailyMission.generateDailyMissions(todayDate);
    state = DailyMissionState(missions: missions, date: todayDate);
    _dailyMissionCompleteEmitted = false;
    await _save();
  }

  /// Hive + SharedPreferences の両方に保存
  Future<void> _save() async {
    // Hive 保存
    if (_boxManager != null) {
      try {
        final box = await _boxManager.getBox<dynamic>(_hiveBoxName);
        await box.put(_hiveDateKey, state.date.toIso8601String());
        await box.put(_hiveMissionsKey, state.missions);
        await box.flush();
      } catch (e) {
        debugPrint('⚠️ [DailyMission] Hive 保存失敗: $e');
      }
    }

    // SharedPreferences 保存（フォールバック兼デバッグ用）
    try {
      final prefs = await SharedPreferences.getInstance();
      final missionsJson = jsonEncode(state.missions.map((m) => m.toJson()).toList());
      await prefs.setString(_prefsKey, missionsJson);
      await prefs.setString(_prefsKeyDate, state.date.toIso8601String());
    } catch (e) {
      debugPrint('⚠️ [DailyMission] SharedPreferences 保存失敗: $e');
    }
  }

  /// 全ミッション達成時に報酬イベントを発火
  void _emitDailyMissionCompleteIfNeeded() {
    if (_rewardExporter == null) return;
    if (_dailyMissionCompleteEmitted) return;
    if (!state.allCompleted) return;

    _dailyMissionCompleteEmitted = true;
    _rewardExporter.exportDailyMissionComplete(
      date: state.date.toIso8601String().substring(0, 10),
      completedCount: state.completedCount,
      totalCount: state.totalCount,
    );
  }

  /// 読書時間（分）の進捗を加算
  /// 達成したミッションのXP報酬の合計を返す
  Future<int> addReadingMinutes(int minutes) async {
    int totalXpReward = 0;
    final updatedMissions = state.missions.map((m) {
      if (m.type == DailyMissionType.readTime && !m.isCompleted) {
        final mission = DailyMission(
          id: m.id,
          type: m.type,
          target: m.target,
          xpReward: m.xpReward,
          title: m.title,
          description: m.description,
          icon: m.icon,
          isCompleted: m.isCompleted,
          currentProgress: m.currentProgress,
        );
        final completed = mission.addProgress(minutes);
        if (completed) {
          totalXpReward += mission.xpReward;
        }
        return mission;
      }
      return m;
    }).toList();

    if (totalXpReward > 0) {
      state = DailyMissionState(missions: updatedMissions, date: state.date);
      await _save();
      _emitDailyMissionCompleteIfNeeded();
    }
    return totalXpReward;
  }

  /// 読了の進捗を加算
  Future<int> addBookCompleted() async {
    int totalXpReward = 0;
    final updatedMissions = state.missions.map((m) {
      if (m.type == DailyMissionType.completeBook && !m.isCompleted) {
        final mission = DailyMission(
          id: m.id,
          type: m.type,
          target: m.target,
          xpReward: m.xpReward,
          title: m.title,
          description: m.description,
          icon: m.icon,
          isCompleted: m.isCompleted,
          currentProgress: m.currentProgress,
        );
        final completed = mission.addProgress(1);
        if (completed) {
          totalXpReward += mission.xpReward;
        }
        return mission;
      }
      return m;
    }).toList();

    if (totalXpReward > 0) {
      state = DailyMissionState(missions: updatedMissions, date: state.date);
      await _save();
      _emitDailyMissionCompleteIfNeeded();
    }
    return totalXpReward;
  }

  /// 読書ページ数の進捗を加算
  Future<int> addReadingPages(int pages) async {
    int totalXpReward = 0;
    final updatedMissions = state.missions.map((m) {
      if (m.type == DailyMissionType.readPages && !m.isCompleted) {
        final mission = DailyMission(
          id: m.id,
          type: m.type,
          target: m.target,
          xpReward: m.xpReward,
          title: m.title,
          description: m.description,
          icon: m.icon,
          isCompleted: m.isCompleted,
          currentProgress: m.currentProgress,
        );
        final completed = mission.addProgress(pages);
        if (completed) {
          totalXpReward += mission.xpReward;
        }
        return mission;
      }
      return m;
    }).toList();

    if (totalXpReward > 0) {
      state = DailyMissionState(missions: updatedMissions, date: state.date);
      await _save();
      _emitDailyMissionCompleteIfNeeded();
    }
    return totalXpReward;
  }
}

/// Riverpod プロバイダ
final dailyMissionProvider =
    StateNotifierProvider<DailyMissionNotifier, DailyMissionState>((ref) {
  return DailyMissionNotifier();
});
