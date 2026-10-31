import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 読み込み失敗の共通表示。
///
/// 「0件」([LoadEmptyView]) とは別ウィジェット・別文言にして、
/// 通信断を「見つかりません」と誤表示しない。
class LoadErrorView extends StatelessWidget {
  /// 失敗の説明文（例: 読み込みに失敗しました）。
  final String message;

  /// null のときは再試行ボタンを表示しない。
  final VoidCallback? onRetry;

  const LoadErrorView({
    super.key = const ValueKey('load_error_view'),
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off,
                size: 40, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const ValueKey('load_retry_button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('再試行'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 0件の共通表示。[LoadErrorView] とは別文言。
class LoadEmptyView extends StatelessWidget {
  /// 0件の説明文（例: 書籍が見つかりません）。
  final String message;

  const LoadEmptyView({
    super.key = const ValueKey('load_empty_view'),
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off,
              size: 40,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
