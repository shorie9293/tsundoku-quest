import 'package:flutter/material.dart';

import 'crash_log_service.dart';

/// [ErrorBoundary] 用の試練キー。
class CrashKeys {
  CrashKeys._();

  static const Key errorBoundaryFallback = Key('view_error_boundary_fallback');
  static const Key errorBoundaryReload = Key('btn_error_boundary_reload');
  static const Key crashLogScreen = Key('screen_crash_log');
  static const Key crashLogSummary = Key('txt_crash_log_summary');
  static const Key crashLogList = Key('list_crash_log');
  static const Key crashLogCopy = Key('btn_crash_log_copy');
  static const Key crashLogEmpty = Key('view_crash_log_empty');
}

/// 表示中（build中）例外の受け皿。
///
/// - `initState` で [ErrorWidget.builder] を差し替え、子孫の build 例外時に
///   日本語の復帰画面（再読み込み）を出す。
/// - 再読み込みで generation を進め、[child] を作り直す。
/// - `dispose` で元の builder に戻す（既存 MaterialApp の設定を壊さない）。
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.onReload,
    this.logger,
  });

  final Widget child;

  /// 再読み込み時に呼ばれる追加処理（任意）。
  final VoidCallback? onReload;

  /// 記録先（既定は端末内ファイル）。
  final CrashLogger? logger;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  late final ErrorWidgetBuilder _previousBuilder;
  late final ErrorWidgetBuilder _ownBuilder;
  late final CrashLogger _logger;

  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _logger = widget.logger ?? CrashLogger();
    _previousBuilder = ErrorWidget.builder;
    _ownBuilder = _buildFallback;
    ErrorWidget.builder = _ownBuilder;
  }

  @override
  void dispose() {
    // 自分が差し替えた場合のみ戻す（後から別の境界が差し替えていたら触らない）
    if (identical(ErrorWidget.builder, _ownBuilder)) {
      ErrorWidget.builder = _previousBuilder;
    }
    super.dispose();
  }

  Widget _buildFallback(FlutterErrorDetails details) {
    _logger.record(details.exception, details.stack, kind: 'widget');
    return _BoundaryFallback(onReload: _reload);
  }

  void _reload() {
    try {
      widget.onReload?.call();
    } catch (_) {
      // onReload の失敗で復帰操作を止めない
    }
    if (!mounted) return;
    setState(() {
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<int>(_generation),
      child: widget.child,
    );
  }
}

class _BoundaryFallback extends StatelessWidget {
  const _BoundaryFallback({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: CrashKeys.errorBoundaryFallback,
      color: theme.colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '表示中に問題が発生しました',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'ご迷惑をおかけしています。再読み込みで復帰できます。',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: CrashKeys.errorBoundaryReload,
                onPressed: onReload,
                icon: const Icon(Icons.refresh),
                label: const Text('再読み込み'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
