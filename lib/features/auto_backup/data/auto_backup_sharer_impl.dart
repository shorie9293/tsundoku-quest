/// 自動バックアップの共有実装
///
/// Kanban t_db8484e0 / 改善提案 #188 続編。
/// アプリ専用領域の JSON を一時ファイルへ写し、share_plus で共有する。
/// 既存 `features/backup` の SharePlusBackupGateway と同じ流儀。
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_sharer.dart';

/// 一時ファイル経由の共有
class FileAutoBackupSharer implements AutoBackupSharer {
  final Future<Directory> Function() _directoryResolver;

  FileAutoBackupSharer({Future<Directory> Function()? directoryResolver})
      : _directoryResolver = directoryResolver ?? getTemporaryDirectory;

  @override
  Future<void> share(String fileName, String json) async {
    final dir = await _directoryResolver();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(json, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        subject: fileName,
        files: [XFile(file.path, mimeType: 'application/json', name: fileName)],
      ),
    );
  }
}
