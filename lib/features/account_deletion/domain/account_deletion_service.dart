/// アカウント削除（退会）の実行サービス。
///
/// 副作用（Hive の削除・サインアウト）は注入された関数に委ね、
/// 失敗は必ず [AccountDeletionResult] へ変換する（例外を画面へ漏らさない）。
library;

/// 退会実行の結果。
class AccountDeletionResult {
  const AccountDeletionResult._({required this.success, required this.message});

  /// 成功結果。
  factory AccountDeletionResult.success({String? message}) =>
      AccountDeletionResult._(
        success: true,
        message: message ?? '端末内のデータを削除し、サインアウトしました。ご利用ありがとうございました。',
      );

  /// 失敗結果（[message] は画面にそのまま出せる日本語）。
  factory AccountDeletionResult.failure({required String message}) =>
      AccountDeletionResult._(success: false, message: message);

  final bool success;
  final String message;
}

/// 退会の実行。
///
/// 順序は「ローカルデータ削除 → サインアウト」。ローカル削除に失敗した
/// 場合はサインアウトしない（アカウントだけ消えてデータが残る事態を避ける）。
class AccountDeletionService {
  const AccountDeletionService({
    required this.signOut,
    required this.clearLocalData,
  });

  /// 認証基盤からのサインアウト。
  final Future<void> Function() signOut;

  /// 端末内データの全削除。
  final Future<void> Function() clearLocalData;

  /// 退会を実行する。
  ///
  /// [confirmed] が false のときは何もせず失敗を返す（二重の安全弁）。
  Future<AccountDeletionResult> execute({required bool confirmed}) async {
    if (!confirmed) {
      return AccountDeletionResult.failure(
        message: '確認が完了していないため削除を実行しませんでした。',
      );
    }

    try {
      await clearLocalData();
    } catch (_) {
      return AccountDeletionResult.failure(
        message: '端末内データの削除に失敗しました。時間をおいて再試行してください。',
      );
    }

    try {
      await signOut();
    } catch (_) {
      return AccountDeletionResult.failure(
        message: 'サインアウトに失敗しました。通信状況を確認して再試行してください。',
      );
    }

    return AccountDeletionResult.success();
  }
}
