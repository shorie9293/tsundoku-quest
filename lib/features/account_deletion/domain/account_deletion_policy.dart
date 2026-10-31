/// アカウント削除（退会）の純粋ポリシー。
///
/// Flutter にも Hive にも依存しない。判定ロジックだけを置き、
/// 実行（削除・サインアウト）は [AccountDeletionService] に委ねる。
class AccountDeletionPolicy {
  const AccountDeletionPolicy._();

  /// 確認入力に求める語（完全一致）。
  static const String confirmationPhrase = '削除';

  /// 削除対象となる Hive Box 名の一覧。
  ///
  /// `lib/core/infrastructure/hive/box_manager.dart` の `BoxNames.all` を実測して
  /// 列挙したもの。追加・改名時は両者を同期させること（試練で一致を担保）。
  static const List<String> targetBoxNames = <String>[
    'adventurer_box',
    'books_box',
    'reading_sessions_box',
    'settings_box',
    'tutorial_box',
    'war_trophies_box',
    'reminder_box',
    'quiet_hours_box',
    'shelves_box',
    'reading_goal_box',
    'reading_queue_box',
  ];

  /// 退会してよいか。
  ///
  /// 削除対象は恒久アカウント（メール登録）のみ。匿名ゲストは
  /// サーバ側に復元可能な身元が無く、端末上のデータを消すだけなら
  /// 退会導線を出す必要がないため対象外とする。
  static bool canDelete({
    required bool hasActiveSession,
    required bool isAnonymous,
  }) =>
      hasActiveSession && !isAnonymous;

  /// 画面に出す説明文。
  static String summary({
    required bool hasActiveSession,
    required bool isAnonymous,
  }) {
    final count = targetBoxNames.length;
    if (!canDelete(
      hasActiveSession: hasActiveSession,
      isAnonymous: isAnonymous,
    )) {
      return hasActiveSession
          ? 'ゲスト利用中はアカウント削除を行えません。メールで登録すると退会できるようになります。'
          : 'ログインしていないため、削除できるアカウントがありません。';
    }
    return 'アカウントを削除すると、この端末の読書データ（Hive Box $count 件）と'
        'サーバ上のアカウントが削除されます。この操作は取り消せません。';
  }

  /// 確認入力が期待語と一致するか（前後空白を除いた完全一致）。
  static bool isConfirmationSatisfied({
    required String input,
    required String expected,
  }) =>
      input.trim() == expected.trim() && expected.trim().isNotEmpty;
}
