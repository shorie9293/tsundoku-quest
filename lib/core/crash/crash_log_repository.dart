import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'crash_log_entry.dart';

/// クラッシュログの保管先（試練で差し替え可能な抽象）。
abstract class CrashLogRepository {
  /// 保存済みの全件（古い順）。
  Future<List<CrashLogEntry>> loadAll();

  /// 1件追記する。直近 [maxEntries] 件を超えた分は古い順に捨てる。
  Future<void> append(CrashLogEntry entry);

  /// 全消去。
  Future<void> clear();
}

/// 保持する最大件数。これを超えたら古い順にローテートする。
const int kCrashLogMaxEntries = 50;

/// 追記後のリストを直近 [kCrashLogMaxEntries] 件に丸める。
List<CrashLogEntry> rotateCrashLogs(List<CrashLogEntry> entries) {
  if (entries.length <= kCrashLogMaxEntries) return List.of(entries);
  return entries.sublist(entries.length - kCrashLogMaxEntries);
}

/// ファイル保存実装（documents 配下 `crash_log.jsonl`・1行1JSON）。
///
/// 壊れた行は読み飛ばす。書き込み失敗は握る（記録の失敗でアプリを止めない）。
class FileCrashLogRepository implements CrashLogRepository {
  FileCrashLogRepository({
    File? file,
    Future<Directory> Function()? documentsDirectory,
  })  : _file = file,
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  static const String fileName = 'crash_log.jsonl';

  final File? _file;
  final Future<Directory> Function() _documentsDirectory;

  Future<File> _resolveFile() async {
    final injected = _file;
    if (injected != null) return injected;
    final dir = await _documentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<List<CrashLogEntry>> loadAll() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return const [];
      final lines = await file.readAsLines();
      final entries = <CrashLogEntry>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final entry = CrashLogEntry.tryDecode(line);
        // 壊れた行は読み飛ばす
        if (entry != null) entries.add(entry);
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> append(CrashLogEntry entry) async {
    try {
      final file = await _resolveFile();
      final entries = rotateCrashLogs([...await loadAll(), entry]);
      final buffer = StringBuffer();
      for (final e in entries) {
        buffer.writeln(e.toJsonLine());
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(buffer.toString(), flush: true);
    } catch (_) {
      // 書き込み失敗は握る
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _resolveFile();
      if (await file.exists()) {
        await file.writeAsString('', flush: true);
      }
    } catch (_) {
      // 消去失敗も握る
    }
  }
}

/// 試練・メモリ内利用向け実装（ローテート規則はファイル実装と同一）。
class InMemoryCrashLogRepository implements CrashLogRepository {
  InMemoryCrashLogRepository([List<CrashLogEntry>? initial])
      : _entries = List.of(initial ?? const <CrashLogEntry>[]);

  List<CrashLogEntry> _entries;

  List<CrashLogEntry> get entries => List.unmodifiable(_entries);

  @override
  Future<List<CrashLogEntry>> loadAll() async => List.of(_entries);

  @override
  Future<void> append(CrashLogEntry entry) async {
    _entries = rotateCrashLogs([..._entries, entry]);
  }

  @override
  Future<void> clear() async {
    _entries = [];
  }
}
