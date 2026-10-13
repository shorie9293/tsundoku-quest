import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/features/badges/data/badge_record_repository.dart';

/// BoxManagerInterface のフェイク（テスト用 Hive box をメモリで代弁）
class _FakeBoxManager implements BoxManagerInterface {
  final Map<String, Box> _boxes = {};

  @override
  Future<Box<T>> getBox<T>(String name) async {
    return _boxes.putIfAbsent(name, () => _FakeBox(name)) as Box<T>;
  }

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
    await _boxes[name]?.clear();
  }
}

class _FakeBox implements Box<String> {
  _FakeBox(this._name);

  final String _name;
  final Map<dynamic, String> _data = {};

  @override
  String? get(dynamic key, {String? defaultValue}) =>
      _data[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> flush() async {}

  @override
  bool get isOpen => true;

  @override
  String get name => _name;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BadgeRecordSet', () {
    test('recordAll は既存を上書きせず新規のみ追加する', () {
      final base = BadgeRecordSet({
        'books_1': '2026-10-01T00:00:00.000Z',
      });
      final now = DateTime(2026, 10, 13, 9);
      final next = base.recordAll(['books_1', 'streak_3'], now: now);

      // 既存の獲得日時は保持
      expect(next.earnedAtById['books_1'], '2026-10-01T00:00:00.000Z');
      // 新規のみ now の UTC ISO8601
      expect(next.earnedAtById['streak_3'], now.toUtc().toIso8601String());
      // 元は不変
      expect(base.earnedAtById.length, 1);
      expect(next.ids, containsAll(['books_1', 'streak_3']));
      expect(next.isEmpty, false);
    });

    test('earnedAtOf は未登録・解釈不能で null', () {
      const set = BadgeRecordSet({
        'books_1': '2026-10-01T12:30:00.000Z',
        'bad': 'not-a-date',
      });
      expect(set.earnedAtOf('books_1'), DateTime.parse('2026-10-01T12:30:00Z'));
      expect(set.earnedAtOf('bad'), isNull);
      expect(set.earnedAtOf('missing'), isNull);
    });

    test('toJson → fromJson 往復', () {
      final set = BadgeRecordSet({
        'books_1': '2026-10-01T00:00:00.000Z',
        'streak_3': '2026-10-13T09:00:00.000Z',
      });
      final restored = BadgeRecordSet.fromJson(set.toJson());
      expect(restored, set);
      expect(restored.hashCode, set.hashCode);
    });

    test('破損JSON（非String値・非Map）は無視して空集合へフォールバック', () {
      final restored = BadgeRecordSet.fromJson({
        'books_1': '2026-10-01T00:00:00.000Z', // 有効
        'bad_int': 123, // 非String → 無視
        'bad_list': ['a'], // 非String → 無視
        'bad_null': null, // 非String → 無視
      });
      expect(restored.ids, ['books_1']);
    });

    test('値等価の == と hashCode', () {
      const a = BadgeRecordSet({'x': '1', 'y': '2'});
      const b = BadgeRecordSet({'y': '2', 'x': '1'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const BadgeRecordSet({'x': '1'})));
    });

    test('既定コンストラクタは空集合', () {
      const set = BadgeRecordSet();
      expect(set.isEmpty, true);
      expect(set.ids, isEmpty);
      expect(set.earnedAtOf('anything'), isNull);
    });
  });

  group('InMemoryBadgeRecordRepository', () {
    test('load は初期値を返し、save で置き換わる', () async {
      final repo = InMemoryBadgeRecordRepository(
        initial: const BadgeRecordSet({'a': '2026-01-01T00:00:00.000Z'}),
      );
      expect((await repo.load()).ids, ['a']);

      final next = (await repo.load())
          .recordAll(['b'], now: DateTime(2026, 10, 13));
      await repo.save(next);

      expect(repo.current, next);
      expect((await repo.load()), next);
    });
  });

  group('HiveBadgeRecordRepository', () {
    test('save → load 往復（' + BoxNames.readingGoal + ' box）', () async {
      final fake = _FakeBoxManager();
      final repo = HiveBadgeRecordRepository(fake);

      final set = BadgeRecordSet({'books_1': '2026-10-01T00:00:00.000Z'})
          .recordAll(['streak_3'], now: DateTime(2026, 10, 13, 9));
      await repo.save(set);

      final loaded = await HiveBadgeRecordRepository(fake).load();
      expect(loaded, set);
      expect(loaded.earnedAtOf('streak_3'), isNotNull);
    });

    test('空boxは空集合を返す', () async {
      final repo = HiveBadgeRecordRepository(_FakeBoxManager());
      expect(await repo.load(), const BadgeRecordSet());
    });

    test('破損JSONは空集合へフォールバック', () async {
      final fake = _FakeBoxManager();
      final box = await fake.getBox<String>(BoxNames.readingGoal);
      await box.put(HiveBadgeRecordRepository.recordKey, '{{{not json');
      final repo = HiveBadgeRecordRepository(fake);
      expect(await repo.load(), const BadgeRecordSet());
    });

    test('非MapのJSONは空集合へフォールバック', () async {
      final fake = _FakeBoxManager();
      final box = await fake.getBox<String>(BoxNames.readingGoal);
      await box.put(HiveBadgeRecordRepository.recordKey, '[1,2,3]');
      final repo = HiveBadgeRecordRepository(fake);
      expect(await repo.load(), const BadgeRecordSet());
    });
  });
}
