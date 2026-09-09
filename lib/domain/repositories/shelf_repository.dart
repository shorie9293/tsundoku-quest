import 'package:tsundoku_quest/domain/models/book_shelf.dart';

/// 自作棚の永続化リポジトリ抽象
///
/// テスト時は InMemoryShelfRepository で置換し、実 Hive を起動しない。
abstract class ShelfRepository {
  /// 全棚を返す（作成順）
  Future<List<BookShelf>> listShelves();

  /// 棚を新規作成する
  Future<BookShelf> createShelf(String name, {int colorValue = 0});

  /// 棚名を変更する
  Future<BookShelf> renameShelf(String id, String newName);

  /// 棚を削除する
  Future<void> deleteShelf(String id);

  /// 蔵書を棚へ追加する（重複時は何もしない）
  Future<BookShelf> addBookToShelf(String shelfId, String userBookId);

  /// 蔵書を棚から取り除く
  Future<BookShelf> removeBookFromShelf(String shelfId, String userBookId);
}

/// インメモリ実装（テスト用）
class InMemoryShelfRepository implements ShelfRepository {
  final Map<String, BookShelf> _shelves = {};

  InMemoryShelfRepository([List<BookShelf>? initial]) {
    if (initial != null) {
      for (final s in initial) {
        _shelves[s.id] = s;
      }
    }
  }

  List<BookShelf> _ordered() {
    final list = _shelves.values.toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<List<BookShelf>> listShelves() async => _ordered();

  @override
  Future<BookShelf> createShelf(String name, {int colorValue = 0}) async {
    final shelf = BookShelf.create(name: name, colorValue: colorValue);
    _shelves[shelf.id] = shelf;
    return shelf;
  }

  @override
  Future<BookShelf> renameShelf(String id, String newName) async {
    final cur = _shelves[id];
    if (cur == null) throw StateError('Shelf not found: $id');
    final updated = cur.copyWith(name: newName);
    _shelves[id] = updated;
    return updated;
  }

  @override
  Future<void> deleteShelf(String id) async {
    _shelves.remove(id);
  }

  @override
  Future<BookShelf> addBookToShelf(String shelfId, String userBookId) async {
    final cur = _shelves[shelfId];
    if (cur == null) throw StateError('Shelf not found: $shelfId');
    if (cur.userBookIds.contains(userBookId)) return cur;
    final updated =
        cur.copyWith(userBookIds: [...cur.userBookIds, userBookId]);
    _shelves[shelfId] = updated;
    return updated;
  }

  @override
  Future<BookShelf> removeBookFromShelf(
      String shelfId, String userBookId) async {
    final cur = _shelves[shelfId];
    if (cur == null) throw StateError('Shelf not found: $shelfId');
    final updated = cur.copyWith(
      userBookIds: cur.userBookIds.where((b) => b != userBookId).toList(),
    );
    _shelves[shelfId] = updated;
    return updated;
  }
}
