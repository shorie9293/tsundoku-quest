import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_reward_event_exporter.dart';

/// 認証状態の変化を [TsundokuRewardEventExporter.userId] へ反映する薄い部品。
///
/// 背景: rpg-task 側の `CrossAppRewardEvent.fromJson` は user_id が空だと
/// FormatException を投げて行ごと破棄する（=報酬ゼロ）。そのため書き出し前に
/// userId が入っている必要があり、サインイン/サインアウトに追随させる。
///
/// 実網なしで試練を撃てるよう、購読するストリームは注入可能にしてある。
/// `Stream<String?>` の要素は「サインイン中の userId」、null はサインアウト相当。
class RewardEventUserLinker {
  final TsundokuRewardEventExporter exporter;

  StreamSubscription<String?>? _subscription;

  RewardEventUserLinker({required this.exporter});

  /// 購読中なら true
  bool get isLinked => _subscription != null;

  /// [userIdChanges] を購読し、userId を追随させる。
  /// null を渡した場合は何もしない（Supabase 未初期化時のフォールバック）。
  /// 購読開始に失敗しても例外は投げない（best-effort）。
  void bind(Stream<String?>? userIdChanges) {
    unbind();
    if (userIdChanges == null) return;
    try {
      _subscription = userIdChanges.listen(
        (userId) {
          // サインアウト（null / 空）は空文字へ戻す
          exporter.userId = (userId == null || userId.trim().isEmpty)
              ? ''
              : userId;
        },
        onError: (Object e) {
          // 認証ストリームのエラーでアプリを落とさない
          debugPrint('⚠️ [RewardEventUserLinker] 認証ストリームのエラー: $e');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('⚠️ [RewardEventUserLinker] 購読開始失敗: $e');
      _subscription = null;
    }
  }

  /// Supabase の AuthState ストリームを購読する。
  void bindSupabaseAuthStates(Stream<AuthState> states) {
    bind(userIdChangesFromAuthStates(states));
  }

  /// Supabase の AuthState ストリームを `Stream<String?>` に変換する。
  /// サインアウト時は session が null になるため null が流れる。
  static Stream<String?> userIdChangesFromAuthStates(
    Stream<AuthState> states,
  ) {
    return states.map((state) => state.session?.user.id);
  }

  /// 購読を解除する
  Future<void> unbind() async {
    final sub = _subscription;
    _subscription = null;
    if (sub == null) return;
    try {
      await sub.cancel();
    } catch (_) {
      // 解除失敗は無視（best-effort）
    }
  }

  /// Supabase が利用可能なら認証状態に接続した linker を返す。
  /// 未初期化（テスト環境・オフライン）なら静かに null を返し、例外は投げない。
  ///
  /// 参照: lib/features/shared/data/supabase_auth_repository.dart の
  /// `authStateChanges`（= `client.auth.onAuthStateChange`）と同じストリーム。
  static RewardEventUserLinker? tryCreateForSupabase(
    TsundokuRewardEventExporter exporter,
  ) {
    try {
      final client = Supabase.instance.client;
      // 既にサインイン済みなら即座に反映
      final currentUser = client.auth.currentUser;
      if (currentUser != null) exporter.userId = currentUser.id;

      final linker = RewardEventUserLinker(exporter: exporter);
      linker.bindSupabaseAuthStates(client.auth.onAuthStateChange);
      return linker;
    } catch (e) {
      // Supabase 未初期化 — 何もしない
      debugPrint('ℹ️ [RewardEventUserLinker] Supabase未初期化のため未接続: $e');
      return null;
    }
  }
}
