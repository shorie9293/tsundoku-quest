import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_repository.dart';

/// 実 Hive を開かないフェイク Box（テスト用の禍祓い）。
class _FakeBox implements Box<String> {
  final String _name;
  final Map<dynamic, String> _store = {};

  _FakeBox(this._name);

  @override
  String get name => _name;
  @override
  bool get isOpen => true;
  @override
  String? get path => null;
  @override
  bool get lazy => false;
  @override
  Iterable<dynamic> get keys => _store.keys.toList();
  @override
  int get length => _store.length;
  @override
  bool get isEmpty => _store.isEmpty;
  @override
  bool get isNotEmpty => _store.isNotEmpty;
  @override
  Iterable<String> get values => _store.values.toList();

  @override
  String? get(dynamic key, {String? defaultValue}) =>
      _store[key] ?? defaultValue;
  @override
  String? getAt(int index) => values.isEmpty ? null : values.elementAt(index);
  @override
  dynamic keyAt(int index) => keys.isEmpty ? null : keys.elementAt(index);
  @override
  bool containsKey(dynamic key) => _store.containsKey(key);

  @override
  Future<void> put(dynamic key, String value) async => _store[key] = value;
  @override
  Future<void> putAt(int index, String value) async =>
      _store[keys.elementAt(index)] = value;
  @override
  Future<void> putAll(Map<dynamic, String> entries) async =>
      _store.addAll(entries);
  @override
  Future<int> add(String value) async {
    _store[length] = value;
    return length - 1;
  }

  @override
  Future<Iterable<int>> addAll(Iterable<String> values) async {
    for (final v in values) {
      await add(v);
    }
    return [for (var i = 0; i < values.length; i++) i];
  }

  @override
  Future<void> delete(dynamic key) async => _store.remove(key);
  @override
  Future<void> deleteAt(int index) async =>
      _store.remove(keys.elementAt(index));
  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    for (final k in keys) {
      _store.remove(k);
    }
  }

  @override
  Future<int> clear() async {
    final n = _store.length;
    _store.clear();
    return n;
  }

  @override
  Future<void> compact() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> deleteFromDisk() async => _store.clear();
  @override
  Future<void> flush() async {}
  @override
  Stream<BoxEvent> watch({dynamic key}) => const Stream.empty();
  @override
  Iterable<String> valuesBetween({dynamic startKey, dynamic endKey}) =>
      values;
  @override
  Map<dynamic, String> toMap() => Map.of(_store);
}

/// 実 Hive を開かないフェイク BoxManager（テスト用の禍祓い）。
///
/// Hive 未初期化で実 Box を開くと zone 汚染でテストが落ちる既知の禍津のため、
/// Hive 実リポジトリの試練は必ずフェイクで行う。
class _FakeBoxManager implements BoxManagerInterface {
  final Map<String, Box<String>> _boxes = {};

  /// テストから生の Box を取り出す（破損データ投入用）。
  Box<String> peekBox(String name) =>
      _boxes.putIfAbsent(name, () => _FakeBox(name));

  @override
  Future<Box<T>> getBox<T>(String name) async =>
      peekBox(name) as Box<T>;

  @override
  Future<void> openAllBoxes() async {}

  @override
  Future<void> closeBox(String name) async {
    _boxes.remove(name);
  }

  @override
  Future<void> closeAllBoxes() async {
    _boxes.clear();
  }

  @override
  Future<void> clearBox(String name) async {
    await peekBox(name).clear();
  }
}

void main() {
  group('InMemoryReadingQueueRepository', () {
    test('save → load の往復', () async {
      final repo = InMemoryReadingQueueRepository();
      await repo.saveEntries([
        ReadingQueueEntry(
          userBookId: 'a',
          position: 1,
          addedAt: DateTime(2026, 9, 21),
        ),
        ReadingQueueEntry(
          userBookId: 'b',
          position: 2,
          addedAt: DateTime(2026, 9, 22),
        ),
      ]);
      final loaded = await repo.loadEntries();
      expect(loaded.map((e) => e.userBookId).toList(), ['a', 'b']);
      expect(loaded.map((e) => e.position).toList(), [1, 2]);
    });

    test('load 直後は空', () async {
      final repo = InMemoryReadingQueueRepository();
      expect(await repo.loadEntries(), isEmpty);
    });
  });

  group('HiveReadingQueueRepository', () {
    late _FakeBoxManager boxManager;
    late HiveReadingQueueRepository repo;

    setUp(() {
      boxManager = _FakeBoxManager();
      repo = HiveReadingQueueRepository(boxManager);
    });

    test('save → load の往復', () async {
      await repo.saveEntries([
        ReadingQueueEntry(
          userBookId: 'a',
          position: 1,
          addedAt: DateTime(2026, 9, 21, 10),
        ),
        ReadingQueueEntry(
          userBookId: 'b',
          position: 2,
          addedAt: DateTime(2026, 9, 22, 10),
        ),
      ]);
      final loaded = await repo.loadEntries();
      expect(loaded.map((e) => e.userBookId).toList(), ['a', 'b']);
      expect(loaded.map((e) => e.position).toList(), [1, 2]);
    });

    test('キー=userBookId で JSON 文字列保存されている', () async {
      final entry = ReadingQueueEntry(
        userBookId: 'ub-9',
        position: 1,
        addedAt: DateTime(2026, 9, 21),
      );
      await repo.saveEntries([entry]);
      final box = boxManager.peekBox(BoxNames.readingQueue);
      expect(box.get('ub-9'), isNotNull);
      final map = jsonDecode(box.get('ub-9')!) as Map<String, dynamic>;
      expect(map['userBookId'], 'ub-9');
      expect(map['position'], 1);
      expect(map['addedAt'], isA<String>());
    });

    test('破損エントリは読み飛ばす', () async {
      await repo.saveEntries([
        ReadingQueueEntry(
          userBookId: 'a',
          position: 1,
          addedAt: DateTime(2026, 9, 21),
        ),
      ]);
      final box = boxManager.peekBox(BoxNames.readingQueue);
      await box.put('broken', '{not json');
      await box.put(
        'wrong-type',
        jsonEncode({'position': 'one', 'addedAt': '2026-01-01'}),
      );
      final loaded = await repo.loadEntries();
      expect(loaded.map((e) => e.userBookId).toList(), ['a']);
    });

    test('削除済みエントリは load に現れない', () async {
      await repo.saveEntries([
        ReadingQueueEntry(
          userBookId: 'a',
          position: 1,
          addedAt: DateTime(2026, 9, 21),
        ),
      ]);
      await repo.saveEntries([
        ReadingQueueEntry(
          userBookId: 'b',
          position: 1,
          addedAt: DateTime(2026, 9, 22),
        ),
      ]);
      final loaded = await repo.loadEntries();
      expect(loaded.map((e) => e.userBookId).toList(), ['b']);
    });
  });

  group('NoopReadingQueueRepository', () {
    test('loadEntries は空リスト・saveEntries は無害', () async {
      final repo = NoopReadingQueueRepository();
      expect(await repo.loadEntries(), isEmpty);
      await repo.saveEntries([
        ReadingQueueEntry(
          userBookId: 'a',
          position: 1,
          addedAt: DateTime(2026, 9, 21),
        ),
      ]);
      expect(await repo.loadEntries(), isEmpty);
    });
  });
}
