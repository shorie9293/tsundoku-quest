import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';

void main() {
  group('InMemoryShelfRepository', () {
    test('createShelf → listShelves で作成順に返る', () async {
      final repo = InMemoryShelfRepository();
      await repo.createShelf('A');
      await repo.createShelf('B');
      final shelves = await repo.listShelves();
      expect(shelves.map((s) => s.name), ['A', 'B']);
    });

    test('renameShelf は名前を変更する', () async {
      final repo = InMemoryShelfRepository();
      final s = await repo.createShelf('A');
      final updated = await repo.renameShelf(s.id, '新名');
      expect(updated.name, '新名');
      final shelves = await repo.listShelves();
      expect(shelves.single.name, '新名');
    });

    test('deleteShelf は棚を消す', () async {
      final repo = InMemoryShelfRepository();
      final s = await repo.createShelf('A');
      await repo.deleteShelf(s.id);
      expect(await repo.listShelves(), isEmpty);
    });

    test('addBookToShelf は重複を許さない / removeBookFromShelf で外せる',
        () async {
      final repo = InMemoryShelfRepository();
      final s = await repo.createShelf('A');
      await repo.addBookToShelf(s.id, 'ub1');
      await repo.addBookToShelf(s.id, 'ub1'); // 重複は無視
      await repo.addBookToShelf(s.id, 'ub2');
      expect((await repo.listShelves()).single.userBookIds, ['ub1', 'ub2']);
      await repo.removeBookFromShelf(s.id, 'ub1');
      expect((await repo.listShelves()).single.userBookIds, ['ub2']);
    });

    test('存在しない棚への操作は StateError', () async {
      final repo = InMemoryShelfRepository();
      expect(() => repo.renameShelf('none', 'x'), throwsStateError);
    });
  });
}
