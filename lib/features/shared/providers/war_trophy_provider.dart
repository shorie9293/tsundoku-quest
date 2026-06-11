import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/repositories/war_trophy_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/war_trophy_repository_provider.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_reward_event_exporter.dart';

/// 戦利品を管理するStateNotifier
///
/// 透過型ハイブリッド:
/// - Repository あり → Supabase に永続化 + インメモリ即時反映
/// - Repository なし → インメモリのみ（テスト／オフライン用）
class WarTrophyNotifier extends StateNotifier<List<WarTrophy>> {
  final WarTrophyRepository? _repository;
  final TsundokuRewardEventExporter? _rewardExporter;

  /// [repository] が null の場合はインメモリモード、
  /// 指定時は Supabase 透過永続化モードで動作する。
  /// [rewardExporter] が指定された場合、新規戦利品追加時に
  /// イベントを共有ストレージに書き出す。
  WarTrophyNotifier([this._repository, TsundokuRewardEventExporter? rewardExporter])
      : _rewardExporter = rewardExporter,
        super(const []);

  // ═══════════════════════════════════════════
  //  Supabase 連携
  // ═══════════════════════════════════════════

  /// Supabase から戦利品一覧を取得して state を更新する
  Future<void> fetchTrophies() async {
    if (_repository == null) {
      debugPrint('🏆 [WarTrophy] fetchTrophies: リポジトリなし');
      return;
    }
    try {
      debugPrint('🏆 [WarTrophy] fetchTrophies: Supabaseから取得開始...');
      final trophies = await _repository.getMyTrophies();
      debugPrint('🏆 [WarTrophy] fetchTrophies: ${trophies.length}件取得');
      state = trophies;
    } catch (e, stack) {
      debugPrint('🏆 [WarTrophy] fetchTrophies 失敗: $e\n$stack');
    }
  }

  // ═══════════════════════════════════════════
  //  WarTrophy 操作（透過型: Supabaseあり→両方 / なし→メモリのみ）
  // ═══════════════════════════════════════════

  /// 戦利品を追加。Supabase連携時は裏で非同期保存。
  void addTrophy(WarTrophy trophy) {
    // 既存トロフィーの置き換えか判定（先にチェック）
    final existingIndex = state.indexWhere((t) => t.id == trophy.id);
    final isNew = existingIndex < 0;

    // 1. 即時UI反映（インメモリ）
    final updated = state.toList();
    if (existingIndex >= 0) {
      updated[existingIndex] = trophy;
    } else {
      updated.add(trophy);
    }
    state = updated;

    // 2. 新規戦利品の場合のみ報酬イベント発火（replaceはスキップ）
    if (isNew && _rewardExporter != null) {
      _rewardExporter!.exportTrophyWritten(
        trophyId: trophy.id,
        userBookId: trophy.userBookId,
        learningCount: trophy.learnings.length,
      );
    }

    // 3. 裏でSupabase保存（失敗してもUIは崩さない）
    _syncToSupabase(trophy);
  }

  /// 戦利品をIDで取得（インメモリ検索）
  WarTrophy? getTrophy(String id) {
    try {
      return state.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Supabaseに同期する（既存→更新 / 新規→作成）
  Future<void> _syncToSupabase(WarTrophy trophy) async {
    if (_repository == null) return;
    try {
      final isExisting = state.any((t) => t.id == trophy.id);
      if (isExisting) {
        await _repository.updateTrophy(trophy);
      } else {
        await _repository.createTrophy(trophy);
      }
    } catch (e) {
      debugPrint('🏆 [WarTrophy] Supabase同期失敗: $e');
    }
  }
}

/// Riverpod プロバイダ
///
/// Supabase未初期化（テスト環境）ではリポジトリなしで動作。
final warTrophyProvider =
    StateNotifierProvider<WarTrophyNotifier, List<WarTrophy>>((ref) {
  WarTrophyRepository? repository;
  try {
    repository = ref.read(warTrophyRepositoryProvider);
  } catch (_) {
    // Supabase未初期化（テスト環境）→ リポジトリなしで動作
  }
  return WarTrophyNotifier(repository);
});
