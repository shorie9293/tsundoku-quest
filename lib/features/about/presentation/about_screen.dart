import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'about_app_keys.dart';
import '../domain/about_info.dart';
import '../domain/external_url_opener.dart';
import 'external_url_launcher.dart';

/// アプリについて画面。
///
/// - アプリ名＋バージョン表示
/// - OSSライセンス: showLicensePage（追加依存なし）
/// - プライバシーポリシー / 問い合わせ: タップで外部アプリ（ブラウザ・メール）へ渡し、
///   開けなかった場合は従来のコピー導線（ダイアログ）へ退避する
class AboutScreen extends StatelessWidget {
  const AboutScreen({
    super.key,
    this.info = kAboutInfo,
    this.clipboardWriter = _defaultClipboardWriter,
    this.urlOpener = launchExternalUrl,
  });

  /// 表示する情報（既定は kAboutInfo。試練から注入可能）。
  final AboutInfo info;

  /// クリップボード書き込み口（試練ではインメモリ実装を注入する）。
  final Future<void> Function(String value) clipboardWriter;

  /// 外部URLを開く口（試練ではフェイクを注入する）。
  final ExternalUrlOpener urlOpener;

  static Future<void> _defaultClipboardWriter(String value) {
    return Clipboard.setData(ClipboardData(text: value));
  }

  Future<void> _copy(BuildContext context, String text) async {
    try {
      await clipboardWriter(text);
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

  /// 外部アプリで開く。開けなければ（false・例外）コピー導線へ退避する。
  Future<void> _openOrCopy(
    BuildContext context, {
    required Uri? uri,
    required String title,
    required String value,
  }) async {
    var opened = false;
    if (uri != null) {
      try {
        opened = await urlOpener(uri);
      } catch (_) {
        opened = false;
      }
    }
    if (opened || !context.mounted) return;
    await _showCopyDialog(context, title, value);
  }

  Future<void> _showCopyDialog(
    BuildContext context,
    String title,
    String value,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('外部アプリで開けませんでした。以下をコピーしてご利用ください。'),
              const SizedBox(height: 8),
              SelectableText(value),
            ],
          ),
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
            subtitle: const Text('ブラウザで開く（開けない場合はコピー）'),
            onTap: () => _openOrCopy(
              context,
              uri: externalUri(info.privacyPolicyUrl),
              title: 'プライバシーポリシー',
              value: info.privacyPolicyUrl,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            key: AboutAppKeys.contactTile,
            leading: const Icon(Icons.mail_outline),
            title: const Text('問い合わせ'),
            subtitle: const Text('メールで送る（開けない場合はコピー）'),
            onTap: () => _openOrCopy(
              context,
              uri: mailtoUri(info.contactEmail),
              title: '問い合わせ',
              value: info.contactEmail,
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
