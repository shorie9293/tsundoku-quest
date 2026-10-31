import 'package:flutter/material.dart';

import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

import 'package:tsundoku_quest/features/account_deletion/domain/account_deletion_policy.dart';
import 'package:tsundoku_quest/features/account_deletion/domain/account_deletion_service.dart';
import 'package:tsundoku_quest/features/account_deletion/presentation/account_deletion_app_keys.dart';

/// アカウント削除（退会）画面 — 2段階確認。
///
/// 1段目: 削除対象（端末内 Box・サーバ上のアカウント）を列挙して見せる。
/// 2段目: 確認文字（[AccountDeletionPolicy.confirmationPhrase]）の入力を要求し、
///        一致したときだけ [AccountDeletionService.execute] を1回呼ぶ。
///
/// 失敗時は成功文言を出さず、エラー文言と再試行だけを出す。
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key, required this.service});

  final AccountDeletionService service;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  bool _busy = false;
  AccountDeletionResult? _result;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.service.execute(confirmed: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  Future<void> _openConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmationDialog(),
    );
    if (confirmed == true) {
      await _run();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final succeeded = result?.success ?? false;
    final message = result?.message ?? '';

    return Scaffold(
      key: AccountDeletionAppKeys.screen,
      appBar: AppBar(title: const Text('アカウント削除（退会）')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                Text(
                  AccountDeletionPolicy.summary(
                    hasActiveSession: true,
                    isAnonymous: false,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text('削除されるデータ', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final boxName in AccountDeletionPolicy.targetBoxNames)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline, size: 20),
                    title: Text(boxName),
                  ),
                const Divider(),
                Text(
                  'この画面で削除されるのは端末内のデータのみです。'
                  'サーバ上のアカウント（メールアドレス・同期データ）は残ります'
                  '（サーバ側の削除は現在準備中です）。',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (result != null && !succeeded) ...[
                  Text(
                    message,
                    key: AccountDeletionAppKeys.errorMessage,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                ],
                if (succeeded) ...[
                  Text(
                    message,
                    key: AccountDeletionAppKeys.successMessage,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_busy)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (succeeded)
                  FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('閉じる'),
                  )
                else if (result != null)
                  SemanticHelper.interactive(
                    testId: 'btn_account_deletion_retry',
                    label: '再試行する',
                    child: FilledButton(
                      key: AccountDeletionAppKeys.retryButton,
                      onPressed: _run,
                      child: const Text('再試行する'),
                    ),
                  )
                else
                  SemanticHelper.interactive(
                    testId: 'btn_account_deletion_proceed',
                    label: '削除手続きへ進む',
                    child: FilledButton.tonal(
                      key: AccountDeletionAppKeys.proceedButton,
                      onPressed: _openConfirmation,
                      child: const Text('削除手続きへ進む'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 確認文字の入力ダイアログ。一致したときだけ true で閉じる。
class _ConfirmationDialog extends StatefulWidget {
  const _ConfirmationDialog();

  @override
  State<_ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<_ConfirmationDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final ok = AccountDeletionPolicy.isConfirmationSatisfied(
      input: _controller.text,
      expected: AccountDeletionPolicy.confirmationPhrase,
    );
    if (!ok) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    const phrase = AccountDeletionPolicy.confirmationPhrase;
    return AlertDialog(
      title: const Text('最終確認'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('続行するには「$phrase」と入力してください。'),
          const SizedBox(height: 12),
          TextField(
            key: AccountDeletionAppKeys.confirmField,
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: '確認文字',
              errorText: _showError ? '「$phrase」と完全に一致する必要があります' : null,
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_showError) ...[
            const SizedBox(height: 8),
            Text(
              '入力が一致しません。削除は実行されていません。',
              key: AccountDeletionAppKeys.confirmError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: AccountDeletionAppKeys.confirmSubmit,
          onPressed: _submit,
          child: const Text('削除する'),
        ),
      ],
    );
  }
}
