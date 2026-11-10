/// 自動バックアップの閲覧・復元・共有画面
///
/// Kanban t_db8484e0 / 改善提案 #188 続編。
/// 依存は全て注入可能。復元役・共有役が未注入なら導線自体を出さない
/// （本番は設定ハブから実装を注入する）。
library;

import 'package:flutter/material.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_sharer.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_status.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/restore_preview.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_exporter.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';

/// 自動バックアップ一覧
class AutoBackupScreen extends StatefulWidget {
  /// 保管庫
  final AutoBackupStore store;

  /// 保持世代数（表示用）
  final AutoBackupPolicy policy;

  /// 復元役（null なら復元導線を出さない）
  final AutoBackupRestorer? restorer;

  /// 共有役（null なら共有導線を出さない）
  final AutoBackupSharer? sharer;

  /// 「今すぐバックアップ」の実行（null ならボタンを出さない）
  final Future<void> Function()? onBackupNow;

  /// 自動バックアップの状態の読み出し元（null なら状態表示を出さない）
  final AutoBackupStatusStore? statusStore;

  /// 現状データの収集（null なら内訳プレビューを出さない）
  final Future<BackupData> Function()? collectCurrent;

  /// 現在時刻（試練で固定する）
  final DateTime Function()? now;

  const AutoBackupScreen({
    super.key,
    required this.store,
    this.policy = const AutoBackupPolicy(),
    this.restorer,
    this.sharer,
    this.onBackupNow,
    this.statusStore,
    this.collectCurrent,
    this.now,
  });

  @override
  State<AutoBackupScreen> createState() => _AutoBackupScreenState();
}

class _AutoBackupScreenState extends State<AutoBackupScreen> {
  List<AutoBackupRow>? _rows;
  AutoBackupStatus? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    AutoBackupStatus? status;
    final statusStore = widget.statusStore;
    if (statusStore != null) {
      try {
        status = await statusStore.load();
      } catch (_) {
        status = null;
      }
    }
    try {
      final entries = await widget.store.list();
      final contents = <String, String?>{};
      for (final entry in entries) {
        if (!AutoBackupPolicy.isAutoBackupFile(entry.fileName)) continue;
        try {
          contents[entry.fileName] = await widget.store.read(entry.fileName);
        } catch (_) {
          contents[entry.fileName] = null;
        }
      }
      final rows = AutoBackupPresenter(keep: widget.policy.keep)
          .buildRows(entries: entries, contents: contents);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _status = status;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _rows = const [];
        _status = status;
        _error = '$e';
      });
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// 復元前プレビューを組み立てる。取得失敗時は null（従来表示のまま）。
  Future<RestorePreview?> _buildPreview(String fileName) async {
    final collect = widget.collectCurrent;
    if (collect == null) return null;
    try {
      final json = await widget.store.read(fileName);
      if (json == null) return null;
      final incoming = BackupData.tryFromJson(backupJsonDecode(json));
      if (incoming == null) return null;
      final existing = await collect();
      return compose(incoming: incoming, existing: existing);
    } catch (_) {
      return null;
    }
  }

  Future<void> _restore(AutoBackupRow row) async {
    final restorer = widget.restorer;
    if (restorer == null) return;

    // 既定ON: 機種変更・再インストール後は設定も戻したいのが本筋。
    var includeSettings = true;

    final preview = await _buildPreview(row.entry.fileName);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('復元の確認'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
                if (preview != null && preview.total > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview.summary,
                          key: AppKeys.autoBackupRestorePreviewSummary,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(preview.message),
                        ),
                        if (preview.samplesText case final samples?)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              samples,
                              key: AppKeys.autoBackupRestorePreviewSamples,
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const ValueKey('auto_backup_restore_include_settings'),
                  value: includeSettings,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) =>
                      setDialogState(() => includeSettings = value ?? false),
                  title: const Text('設定も戻す（テーマ・文字サイズ・静穏時間・リマインダー）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('auto_backup_restore_cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const ValueKey('auto_backup_restore_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('復元する'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    String message;
    try {
      final fileName = row.entry.fileName;
      // 新インタフェースを持つ実装だけ「設定も戻す」を選べる。
      // 旧実装（フェイク等）は従来どおりの restore に落とす。
      final result = restorer is AutoBackupRestorerWithOptions
          ? await restorer.restoreWithOptions(
              fileName,
              includeSettings: includeSettings,
            )
          : await restorer.restore(fileName);
      message = result.message ?? (result.ok ? '復元しました' : '復元できませんでした');
    } catch (e) {
      message = '復元に失敗しました: $e';
    }
    _notify(message);
    await _load();
  }

  Future<void> _share(AutoBackupRow row) async {
    final sharer = widget.sharer;
    if (sharer == null) return;
    try {
      final json = await widget.store.read(row.entry.fileName);
      if (json == null) {
        _notify('バックアップの内容を読み込めませんでした');
        return;
      }
      await sharer.share(row.entry.fileName, json);
    } catch (e) {
      _notify('共有に失敗しました: $e');
    }
  }

  Future<void> _backupNow() async {
    final action = widget.onBackupNow;
    if (action == null) return;
    try {
      await action();
    } catch (e) {
      _notify('バックアップに失敗しました: $e');
    }
    await _load();
  }

  /// 失敗の警告バナー（未実行と毎回失敗を同じ見た目にしない）。
  Widget _failureBanner(AutoBackupStatus status) {
    final attemptedAt = status.lastAttemptAt;
    final when = attemptedAt == null
        ? ''
        : '（最終試行 ${AutoBackupPresenter.formatDate(attemptedAt)}）';
    final reason = status.lastError;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        key: AppKeys.autoBackupFailureBanner,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '自動バックアップに失敗しています$when',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  reason,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            if (widget.onBackupNow != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: AppKeys.autoBackupRetry,
                  onPressed: _backupNow,
                  child: const Text('今すぐ実行'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 最終成功の控えめな表示（状態が未読なら何も出さない）。
  Widget? _lastSuccessLine() {
    final success = _status?.lastSuccessAt;
    if (success == null) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text(
        '最終成功 ${AutoBackupPresenter.formatDate(success)}',
        key: AppKeys.autoBackupLastSuccess,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('auto_backup_loading')),
      );
    }
    final rows = _rows ?? const <AutoBackupRow>[];
    final status = _status;
    if (rows.isEmpty && status?.hasAttempted != true) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'バックアップはまだありません',
                key: ValueKey('auto_backup_empty'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_lastSuccessLine() case final line?) line,
        if (status?.hasFailed == true) _failureBanner(status!),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AutoBackupPresenter(keep: widget.policy.keep)
                      .retentionLabel(rows.length),
                  key: const ValueKey('auto_backup_retention'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (widget.onBackupNow != null)
                FilledButton.icon(
                  key: const ValueKey('auto_backup_backup_now'),
                  onPressed: _backupNow,
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('今すぐバックアップ'),
                ),
            ],
          ),
        ),
        for (final row in rows) _buildRow(row),
      ],
    );
  }

  Widget _buildRow(AutoBackupRow row) {
    final fileName = row.entry.fileName;
    final showReason = widget.restorer != null && !row.restorability.isRestorable;
    return ListTile(
      key: ValueKey('auto_backup_row_$fileName'),
      title: Text(row.displayLabel),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fileName),
          if (showReason)
            Text(
              row.restorability.label,
              key: ValueKey('auto_backup_restore_reason_$fileName'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.restorer != null && row.restorability.isRestorable)
            IconButton(
              key: ValueKey('auto_backup_restore_$fileName'),
              tooltip: '復元',
              icon: const Icon(Icons.restore),
              onPressed: () => _restore(row),
            ),
          if (widget.sharer != null)
            IconButton(
              key: ValueKey('auto_backup_share_$fileName'),
              tooltip: '共有',
              icon: const Icon(Icons.ios_share),
              onPressed: () => _share(row),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('auto_backup_screen'),
      appBar: AppBar(title: const Text('自動バックアップ')),
      body: _buildBody(),
    );
  }
}
