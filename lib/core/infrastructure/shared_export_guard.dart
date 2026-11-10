import 'package:tsundoku_quest/core/logging/app_logger.dart';

/// 連携エクスポート（投げっぱなし呼出）を安全に起動する。
///
/// SAF の共有フォルダが未選択のとき、[SharedFileStore] 経由の書込は
/// `SharedStorageException` で失敗する。呼出元の本処理（UI 反映・Hive /
/// Supabase 保存）は止めず、**かつ無音にもしない**ため、ここで観測して
/// ログに1行残す。
///
/// これが無いと、`runZonedGuarded` の未捕捉例外経路に流れて
/// CrashLogger（Crashlytics）に「アプリのエラー」として記録されてしまう。
/// 連携は機能停止であってクラッシュではないため、ここで堰き止める。
void guardSharedExport(Future<void> future, {required String label}) {
  future.then<void>(
    (_) {},
    onError: (Object error) {
      appLog.warn('共有ストレージ書込失敗（$label）: 連携は停止中か共有フォルダ未選択');
      appLog.debug('共有ストレージ書込失敗の詳細（$label）: $error');
    },
  );
}
