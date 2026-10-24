import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_reward_event_exporter.dart';

/// クロスアプリ報酬イベント書き出しの単一インスタンス。
///
/// 書き出し先 JSONL は rpg-task (Kozuchi) が読む共有ストレージ上のファイル。
/// userId は [RewardEventUserLinker] が認証状態に追随して設定する。
/// 複数の Notifier が同じインスタンスを共有することで、
/// 「サインイン時に設定した userId」が全書き出し経路に反映される。
final tsundokuRewardEventExporterProvider =
    Provider<TsundokuRewardEventExporter>((ref) {
  return TsundokuRewardEventExporter();
});
