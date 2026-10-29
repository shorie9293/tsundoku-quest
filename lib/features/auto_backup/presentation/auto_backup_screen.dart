/// 自動バックアップの閲覧・復元・共有画面
///
/// Kanban t_db8484e0 / 改善提案 #188 続編。
/// 依存は全て注入可能。復元役・共有役が未注入なら導線自体を出さない
/// （本番は設定ハブから実装を注入する）。
library;

import 'package:flutter/material.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_sharer.dart';

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

  /// 現在時刻（試練で固定する）
  final DateTime Function()? now;

  const AutoBackupScreen({
    super.key,
    required this.store,
    this.policy = const AutoBackupPolicy(),
    this.restorer,
    this.sharer,
    this.onBackupNow,
    this.now,
  });

  @override
  State<AutoBackupScreen> createState() => _AutoBackupScreenState();
}

class _AutoBackupScreenState extends State<AutoBackupScreen> {
  List<AutoBackupRow>? _rows;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
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
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _rows = const [];
        _error = '$e';
      });
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(AutoBackupRow row) async {
    final restorer = widget.restorer;
    if (restorer == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('復元の確認'),
        content: const Text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
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
    );
    if (confirmed != true) return;

    String message;
    try {
      final result = await restorer.restore(row.entry.fileName);
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('auto_backup_loading')),
      );
    }
    final rows = _rows ?? const <AutoBackupRow>[];
    if (rows.isEmpty) {
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
    return ListTile(
      key: ValueKey('auto_backup_row_$fileName'),
      title: Text(row.displayLabel),
      subtitle: Text(fileName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.restorer != null && row.restorable)
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
