import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
/// shared_preferences を使って日付を跨いだ状態を永続化する。
class DailyMissionNotifier extends StateNotifier<DailyMissionState> {
  static const _prefsKey = 'daily_missions_state';
  static const _prefsKeyDate = 'daily_missions_date';

  DailyMissionNotifier() : super(DailyMissionState(missions: [], date: DateTime.fromMillisecondsSinceEpoch(0))) {
    _loadOrGenerate();
  }

  /// 保存されているミッションを読み込むか、新規生成する
  Future<void> _loadOrGenerate() async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDateStr = prefs.getString(_prefsKeyDate);
      final savedDate = savedDateStr != null ? DateTime.tryParse(savedDateStr) : null;

      // 同じ日付なら復元
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
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [DailyMission] 読み込み失敗: $e');
    }

    // 新規生成
    final missions = DailyMission.generateDailyMissions(todayDate);
    state = DailyMissionState(missions: missions, date: todayDate);
    await _save();
  }

  /// shared_preferences に保存
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final missionsJson = jsonEncode(state.missions.map((m) => m.toJson()).toList());
      await prefs.setString(_prefsKey, missionsJson);
      await prefs.setString(_prefsKeyDate, state.date.toIso8601String());
    } catch (e) {
      debugPrint('⚠️ [DailyMission] 保存失敗: $e');
    }
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
    }
    return totalXpReward;
  }
}

/// Riverpod プロバイダ
final dailyMissionProvider =
    StateNotifierProvider<DailyMissionNotifier, DailyMissionState>((ref) {
  return DailyMissionNotifier();
});
