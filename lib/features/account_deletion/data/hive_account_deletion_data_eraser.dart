import 'package:hive_flutter/hive_flutter.dart';

import 'package:tsundoku_quest/core/infrastructure/hive/hive_initializer.dart';
import 'package:tsundoku_quest/features/account_deletion/domain/account_deletion_policy.dart';

/// 本番のローカルデータ削除（退会）。
///
/// [AccountDeletionPolicy.targetBoxNames] の Box を開いているものだけ clear し、
/// 最後に `Hive.deleteFromDisk()` で box ファイルごと消す。
///
/// Hive 未初期化（widget 試練など）では何もしない — `openBox` を呼ぶと
/// zone 汚染で flutter_test が落ちるため（hive_initializer.dart の注記参照）。
class HiveAccountDeletionDataEraser {
  const HiveAccountDeletionDataEraser();

  Future<void> call() async {
    if (!hiveInitialized) return;

    for (final name in AccountDeletionPolicy.targetBoxNames) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box<dynamic>(name).clear();
      }
    }

    // 未 open の Box も含め、ディスク上の全 box ファイルを削除する。
    await Hive.deleteFromDisk();
  }
}
