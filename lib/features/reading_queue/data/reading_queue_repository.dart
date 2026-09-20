/// 「次に読む」読書キューの永続化リポジトリ
///
/// Hive box に JSON 文字列で保存する（TypeAdapter 不要）。
/// 破損エントリは読み飛ばし、他のエントリの読み取りを妨げない。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/features/reading_queue/domain/reading_queue_service.dart';

abstract class ReadingQueueRepository {
  Future<List<ReadingQueueEntry>> loadEntries();

  Future<void> saveEntries(List<ReadingQueueEntry> entries);
}

/// Hive 実装（BoxNames.readingQueue にキー=userBookId で JSON 文字列保存）
class HiveReadingQueueRepository implements ReadingQueueRepository {
  HiveReadingQueueRepository(this._boxManager);

  final BoxManagerInterface _boxManager;

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await _boxManager.getBox<String>(BoxNames.readingQueue);
    return _box!;
  }

  /// 破損エントリを読み飛ばして全件復元する
  List<ReadingQueueEntry> _readAll(Box<String> box) {
    final entries = <ReadingQueueEntry>[];
    for (final raw in box.values) {
      final entry = _decode(raw);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  ReadingQueueEntry? _decode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      return ReadingQueueEntry.fromJson(map);
    } catch (e) {
      debugPrint('[ReadingQueueRepo] skipping broken entry: $e');
      return null;
    }
  }

  @override
  Future<List<ReadingQueueEntry>> loadEntries() async {
    try {
      final box = await _getBox();
      return ReadingQueueService.normalize(_readAll(box));
    } catch (e) {
      debugPrint('[ReadingQueueRepo] load failed: $e');
      return const [];
    }
  }

  @override
  Future<void> saveEntries(List<ReadingQueueEntry> entries) async {
    final box = await _getBox();
    final normalized = ReadingQueueService.normalize(entries);
    await box.clear();
    for (final entry in normalized) {
      await box.put(entry.userBookId, jsonEncode(entry.toJson()));
    }
    await box.flush();
  }
}

/// テスト・オフライン用のインメモリ実装
class InMemoryReadingQueueRepository implements ReadingQueueRepository {
  final Map<String, ReadingQueueEntry> _store = {};

  /// 現在保持しているエントリ件数
  int get length => _store.length;

  @override
  Future<List<ReadingQueueEntry>> loadEntries() async {
    return ReadingQueueService.normalize(_store.values.toList());
  }

  @override
  Future<void> saveEntries(List<ReadingQueueEntry> entries) async {
    final normalized = ReadingQueueService.normalize(entries);
    _store
      ..clear()
      ..addEntries([for (final e in normalized) MapEntry(e.userBookId, e)]);
  }
}

/// 何もしない実装（プレビュー・フォールバック用）
class NoopReadingQueueRepository implements ReadingQueueRepository {
  @override
  Future<List<ReadingQueueEntry>> loadEntries() async => const [];

  @override
  Future<void> saveEntries(List<ReadingQueueEntry> entries) async {}
}
