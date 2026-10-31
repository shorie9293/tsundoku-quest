import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

import 'crash_log_entry.dart';
import 'crash_log_repository.dart';
import 'crash_log_service.dart';
import 'error_boundary.dart';

/// 端末内クラッシュログの閲覧画面。
///
/// サマリー1行＋直近一覧＋クリップボードコピー＋空状態。
class CrashLogScreen extends StatefulWidget {
  const CrashLogScreen({super.key, this.repository});

  /// 保管先（試練から注入可能）。既定は端末内ファイル。
  final CrashLogRepository? repository;

  @override
  State<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<CrashLogScreen> {
  late final CrashLogRepository _repository;
  List<CrashLogEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FileCrashLogRepository();
    _load();
  }

  Future<void> _load() async {
    final entries = await _repository.loadAll();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _copy() async {
    final text = formatCrashLogsForClipboard(_entries);
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('クリップボードへコピーしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = summarize(_entries);
    return Scaffold(
      key: CrashKeys.crashLogScreen,
      appBar: AppBar(
        title: const Text('不具合の報告'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              key: CrashKeys.crashLogCopy,
              tooltip: 'クリップボードへコピー',
              onPressed: _copy,
              icon: const Icon(Icons.copy_all_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const _EmptyView()
              : ListView(
                  key: CrashKeys.crashLogList,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text(
                        summary!,
                        key: CrashKeys.crashLogSummary,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    for (final entry in recent(_entries, limit: 20))
                      _EntryTile(entry: entry),
                  ],
                ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: CrashKeys.crashLogEmpty,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: TakamagaharaColors.deepPurple,
            ),
            SizedBox(height: 12),
            Text('記録された不具合はありません'),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final CrashLogEntry entry;

  String get _when {
    final t = entry.timestamp;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.bug_report_outlined),
      title: Text(
        entry.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('$_when ・ ${entry.kind}'),
    );
  }
}
