import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book_shelf.dart';

void main() {
  group('BookShelf model', () {
    test('toJson/fromJson ラウンドトリップ', () {
      final shelf = BookShelf(
        id: 's1',
        name: '積ん読の山',
        colorValue: 0xFF90CAF9,
        createdAt: '2026-09-09T10:00:00.000',
        userBookIds: const ['ub1', 'ub2'],
      );
      final decoded = BookShelf.fromJson(shelf.toJson());
      expect(decoded.id, 's1');
      expect(decoded.name, '積ん読の山');
      expect(decoded.colorValue, 0xFF90CAF9);
      expect(decoded.userBookIds, ['ub1', 'ub2']);
    });

    test('create は id/createdAt を採番し name を保持する', () {
      final now = DateTime(2026, 9, 9, 12, 0, 0);
      final shelf = BookShelf.create(name: '本棚', now: now);
      expect(shelf.name, '本棚');
      expect(shelf.id.isNotEmpty, isTrue);
      expect(shelf.createdAt, now.toIso8601String());
      expect(shelf.userBookIds, isEmpty);
    });

    test('copyWith で不変更新できる', () {
      final shelf = BookShelf.create(name: 'A', now: DateTime(2026, 1, 1));
      final renamed = shelf.copyWith(name: 'B');
      expect(renamed.name, 'B');
      expect(shelf.name, 'A', reason: '元のインスタンスは不変のまま');
    });

    test('fromJson は userBookIds 欠落時は空リスト', () {
      final shelf =
          BookShelf.fromJson({'id': 'x', 'name': 'n', 'createdAt': 't'});
      expect(shelf.userBookIds, isEmpty);
    });
  });
}
