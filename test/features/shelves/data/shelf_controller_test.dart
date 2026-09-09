import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';
import 'package:tsundoku_quest/features/shelves/data/shelf_controller.dart';

void main() {
  group('ShelfController', () {
    test('load はリポジトリの棚を読み込む', () async {
      final repo = InMemoryShelfRepository();
      final c = ShelfController(repo);
      expect(c.state, isEmpty);
      await c.load();
      expect(c.state, isEmpty);

      await c.createShelf('A');
      final c2 = ShelfController(repo);
      await c2.load();
      expect(c2.state.single.name, 'A');
    });

    test('createShelf で棚が増える', () async {
      final c = ShelfController(InMemoryShelfRepository());
      await c.createShelf('積ん読の山');
      expect(c.state.single.name, '積ん読の山');
    });

    test('renameShelf / deleteShelf が状態に反映される', () async {
      final c = ShelfController(InMemoryShelfRepository());
      await c.createShelf('A');
      final shelf = c.state.single;
      await c.renameShelf(shelf.id, 'B');
      expect(c.state.single.name, 'B');

      await c.deleteShelf(shelf.id);
      expect(c.state, isEmpty);
    });

    test('addBook / removeBook が蔵書メンバーを更新する', () async {
      final c = ShelfController(InMemoryShelfRepository());
      await c.createShelf('A');
      final shelf = c.state.single;

      await c.addBook(shelf.id, 'ub1');
      await c.addBook(shelf.id, 'ub2');
      expect(c.state.single.userBookIds, ['ub1', 'ub2']);

      await c.removeBook(shelf.id, 'ub1');
      expect(c.state.single.userBookIds, ['ub2']);
    });
  });
}
