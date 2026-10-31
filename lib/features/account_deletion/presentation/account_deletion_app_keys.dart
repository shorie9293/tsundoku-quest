import 'package:flutter/foundation.dart';

/// 退会画面の試練用 Key（画面内で完結するため AppKeys とは分離）。
class AccountDeletionAppKeys {
  const AccountDeletionAppKeys._();

  static const Key screen = Key('screen_account_deletion');
  static const Key proceedButton = Key('btn_account_deletion_proceed');
  static const Key confirmField = Key('field_account_deletion_confirm');
  static const Key confirmSubmit = Key('btn_account_deletion_confirm');
  static const Key confirmError = Key('text_account_deletion_confirm_error');
  static const Key retryButton = Key('btn_account_deletion_retry');
  static const Key successMessage = Key('text_account_deletion_success');
  static const Key errorMessage = Key('text_account_deletion_error');
}
