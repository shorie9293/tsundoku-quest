/// バックアップ画面
///
/// 道標 #69 / Kanban t_4d1829a9
/// エクスポート（JSON/CSV を share_plus で共有）と
/// インポート（貼付テキストからの復元）を提供する。
/// 依存はすべて注入可能（テストはフェイク注入・Hive 未初期化で走る）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:tsundoku_quest/features/backup/data/backup_repository.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_csv.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_exporter.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';
import 'package:tsundoku_quest/features/backup/presentation/backup_keys.dart';

/// 共有ゲートウェイ（試練ではフェイク注入）
abstract class BackupShareGateway {
  Future<void> shareFile({
    required String fileName,
    required String mimeType,
    required String body,
  });
}

/// share_plus 実装
class SharePlusBackupGateway implements BackupShareGateway {
  const SharePlusBackupGateway();

  @override
  Future<void> shareFile({
    required String fileName,
    required String mimeType,
    required String body,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(body.codeUnits),
            mimeType: mimeType,
            name: fileName,
          ),
        ],
      ),
    );
  }
}

/// バックアップ画面
class BackupScreen extends ConsumerStatefulWidget {
  final BackupRepository? repository;
  final BackupShareGateway? shareGateway;
  final BackupExporter? exporter;

  const BackupScreen({super.key, this.repository, this.shareGateway, this.exporter});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _importController = TextEditingController();
  BackupData? _lastCollected;
  String? _resultMessage;

  BackupRepository get _repository =>
      widget.repository ?? ref.read(backupRepositoryProvider);

  BackupShareGateway get _shareGateway =>
      widget.shareGateway ?? const SharePlusBackupGateway();

  Future<void> _export({required bool asCsv}) async {
    try {
      final data = await _repository.collect();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      if (asCsv) {
        await _shareGateway.shareFile(
          fileName: 'tsundoku_books_$stamp.csv',
          mimeType: 'text/csv',
          body: backupBooksToCsv(data.books),
        );
      } else {
        final json = jsonEncode(data.toJson());
        await _shareGateway.shareFile(
          fileName: 'tsundoku_backup_$stamp.json',
          mimeType: 'application/json',
          body: json,
        );
        setState(() {
          _lastCollected = data;
          _resultMessage =
              '書き出しました（蔵書${data.bookCount}冊・セッション${data.sessionCount}回）';
        });
      }
    } catch (e) {
      setState(() => _resultMessage = '書き出しに失敗しました: $e');
    }
  }

  Future<void> _import() async {
    final raw = _importController.text.trim();
    if (raw.isEmpty) {
      setState(() => _resultMessage = 'バックアップJSONを貼り付けてください');
      return;
    }
    try {
      final decoded = backupJsonDecode(raw);
      final data = BackupData.tryFromJson(decoded);
      if (data == null) {
        setState(() => _resultMessage = 'バックアップJSONの形式が正しくありません');
        return;
      }
      final result = await _repository.restore(data);
      setState(() {
        _resultMessage =
            '復元しました（追加 蔵書${result.addedBooks}冊・セッション${result.addedSessions}回／スキップ 蔵書${result.skippedBooks}冊・セッション${result.skippedSessions}回）';
        _importController.clear();
      });
    } catch (e) {
      setState(() => _resultMessage = '復元に失敗しました: $e');
    }
  }

  Future<void> _collectSummary() async {
    try {
      final data = await _repository.collect();
      setState(() {
        _lastCollected = data;
        _resultMessage = null;
      });
    } catch (_) {
      // サマリ取得失敗は静かに無視（初回フレームで Hive 未初期化の可能性）
    }
  }

  @override
  void initState() {
    super.initState();
    _collectSummary();
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _lastCollected;
    return Scaffold(
      key: const ValueKey('backup_scaffold'),
      appBar: AppBar(title: const Text('バックアップ')),
      body: ListView(
        key: BackupKeys.screen,
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data == null
                        ? '読み込み中…'
                        : '蔵書 ${data.bookCount} 冊・読書セッション ${data.sessionCount} 回'
                            '${data.goal != null ? '・読書目標あり' : ''}',
                    key: BackupKeys.summary,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        key: BackupKeys.exportJsonButton,
                        onPressed: () => _export(asCsv: false),
                        child: const Text('JSONで書き出す'),
                      ),
                      OutlinedButton(
                        key: BackupKeys.exportCsvButton,
                        onPressed: () => _export(asCsv: true),
                        child: const Text('CSVで書き出す'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('復元（インポート）'),
                  const SizedBox(height: 8),
                  const Text('別端末で書き出したバックアップJSONを貼り付けてください。'),
                  const SizedBox(height: 8),
                  TextField(
                    key: BackupKeys.importField,
                    controller: _importController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '{"tsundoku_quest_backup": true, ...}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: BackupKeys.importButton,
                    onPressed: _import,
                    child: const Text('取り込む'),
                  ),
                ],
              ),
            ),
          ),
          if (_resultMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _resultMessage!,
                key: BackupKeys.resultMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
