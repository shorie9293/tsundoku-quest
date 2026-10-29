/// 自動バックアップ保管庫
///
/// Kanban t_db8484e0 / 改善提案 #188 — 全現世共通仕様
/// `auto_backups/` 配下に `auto_backup_yyyyMMdd.json` を置く。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';

/// 保管庫の抽象（試練では InMemory 実装で置換する）
abstract interface class AutoBackupStore {
  /// 保管庫内の全エントリ
  Future<List<AutoBackupEntry>> list();

  /// [fileName] で書き込む（同日同名は上書き＝冪等）
  Future<void> write(String fileName, String contents);

  /// [fileName] の内容（存在しなければ null）
  Future<String?> read(String fileName);

  /// [fileName] を削除する
  Future<void> delete(String fileName);
}

/// 試練・メモリ用の保管庫
class InMemoryAutoBackupStore implements AutoBackupStore {
  final DateTime Function() _now;
  final Map<String, String> _contents = {};
  final Map<String, DateTime> _createdAt = {};

  InMemoryAutoBackupStore({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// 書き込み済みファイル名（昇順）
  List<String> get fileNames => _contents.keys.toList()..sort();

  /// 内容の参照（試練用）
  String? contentOf(String fileName) => _contents[fileName];

  @override
  Future<List<AutoBackupEntry>> list() async => [
        for (final name in _contents.keys)
          AutoBackupEntry(fileName: name, createdAt: _createdAt[name]!),
      ];

  @override
  Future<void> write(String fileName, String contents) async {
    _contents[fileName] = contents;
    _createdAt[fileName] = _now();
  }

  @override
  Future<String?> read(String fileName) async => _contents[fileName];

  @override
  Future<void> delete(String fileName) async {
    _contents.remove(fileName);
    _createdAt.remove(fileName);
  }
}

/// 実機用の保管庫（アプリ書類ディレクトリ/auto_backups/）
class FileAutoBackupStore implements AutoBackupStore {
  /// 直下に掘るサブディレクトリ名
  static const String subdirectory = 'auto_backups';

  final Future<Directory> Function() _directoryResolver;

  FileAutoBackupStore({Future<Directory> Function()? directoryResolver})
      : _directoryResolver =
            directoryResolver ?? getApplicationDocumentsDirectory;

  Future<Directory> _ensureDir() async {
    final base = await _directoryResolver();
    final dir = Directory('${base.path}${Platform.pathSeparator}$subdirectory');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<List<AutoBackupEntry>> list() async {
    final dir = await _ensureDir();
    final entries = <AutoBackupEntry>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!AutoBackupPolicy.isAutoBackupFile(name)) continue;
      DateTime createdAt;
      try {
        createdAt = (await entity.stat()).modified;
      } catch (e) {
        debugPrint('[AutoBackup] stat failed ($name): $e');
        createdAt = DateTime.fromMillisecondsSinceEpoch(0);
      }
      entries.add(AutoBackupEntry(fileName: name, createdAt: createdAt));
    }
    return entries;
  }

  @override
  Future<void> write(String fileName, String contents) async {
    final dir = await _ensureDir();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(contents, flush: true);
  }

  @override
  Future<String?> read(String fileName) async {
    final dir = await _ensureDir();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    try {
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      debugPrint('[AutoBackup] read failed ($fileName): $e');
      return null;
    }
  }

  @override
  Future<void> delete(String fileName) async {
    final dir = await _ensureDir();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
