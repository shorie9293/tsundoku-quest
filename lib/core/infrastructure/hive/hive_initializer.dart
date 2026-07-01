/// ツンドクエスト Hive 初期化モジュール
///
/// アプリ起動時に Hive を初期化し、全 TypeAdapter を登録する。
/// main.dart の `runApp()` 前に呼び出すこと。
///
/// 参照: 高天原神書 hive-persistence-blueprint §2.3
library;

import 'package:hive_flutter/hive_flutter.dart';

/// Hive の初期化と全 TypeAdapter の登録を行う。
///
/// 呼出順序:
///   1. Hive.initFlutter() — Flutter 用パス設定
///   2. registerAdapters() — 全型アダプター登録
///
/// [registerAdaptersCallback] は各モデルの TypeAdapter を登録する
/// コールバック。新モデル追加時はここに追記する。
Future<void> initializeHive({
  void Function()? registerAdaptersCallback,
}) async {
  // 1. Flutter 用に Hive を初期化（プラットフォーム固有パス設定）
  await Hive.initFlutter();

  // 2. TypeAdapter を登録（モデルが増えたら追記）
  if (registerAdaptersCallback != null) {
    registerAdaptersCallback();
  }

  // 注: Box の open は BoxManager 側で遅延実行する。
  //     ここで openBox() すると Hive が Widget より先に起動し、
  //     testWidgets でハングする原因になる。
  //     → 実運用では BoxManager.openAllBoxes() を runApp 後に呼ぶ。
}
