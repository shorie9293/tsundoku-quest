import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'about_app_keys.dart';
import '../domain/about_info.dart';

/// アプリについて画面。
///
/// - アプリ名＋バージョン表示
/// - OSSライセンス: showLicensePage（追加依存なし）
/// - プライバシーポリシー: ダイアログでURL表示＋コピー（url_launcher不使用）
/// - 問い合わせ: メール表示＋コピー
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.info = kAboutInfo});

  /// 表示する情報（既定は kAboutInfo。試練から注入可能）。
  final AboutInfo info;

  Future<void> _copy(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('コピーしました')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('コピーに失敗しました')),
        );
      }
    }
  }

  void _showCopyDialog(BuildContext context, String title, String value) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SelectableText(value),
          actions: [
            TextButton(
              key: AboutAppKeys.copyButton,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _copy(context, value);
              },
              child: const Text('コピー'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AboutAppKeys.aboutScreen,
      appBar: AppBar(title: const Text('アプリについて')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: Text(
              info.appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Center(
            child: Text(
              'v${info.version}',
              key: AboutAppKeys.versionLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Center(
            child: Text(
              info.tagline,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          ListTile(
            key: AboutAppKeys.licenseTile,
            leading: const Icon(Icons.description_outlined),
            title: const Text('OSSライセンス'),
            subtitle: const Text('このアプリが利用しているライブラリ'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: info.appName,
              applicationVersion: info.version,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            key: AboutAppKeys.privacyTile,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            subtitle: const Text('URLを確認・コピーする'),
            onTap: () => _showCopyDialog(
              context,
              'プライバシーポリシー',
              info.privacyPolicyUrl,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            key: AboutAppKeys.contactTile,
            leading: const Icon(Icons.mail_outline),
            title: const Text('問い合わせ'),
            subtitle: const Text('メールアドレスを確認・コピーする'),
            onTap: () => _showCopyDialog(context, '問い合わせ', info.contactEmail),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
