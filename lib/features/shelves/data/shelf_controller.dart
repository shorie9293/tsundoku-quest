import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/domain/models/book_shelf.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';
import 'package:tsundoku_quest/features/shelves/data/shelf_repository_provider.dart';

/// 自作棚の状態を管理する StateNotifier
///
/// 読み込みは load() で非同期に行い、以降の操作は Repository 永続化＋
/// インメモリ即時反映の透過型で行う。
class ShelfController extends StateNotifier<List<BookShelf>> {
  final ShelfRepository _repository;

  ShelfController(this._repository) : super(const []);

  bool _loaded = false;

  /// Repository から棚一覧を読み込む（初回のみ）
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    state = await _repository.listShelves();
  }

  /// 棚を新規作成し、新棚を返す
  Future<BookShelf> createShelf(String name, {int colorValue = 0}) async {
    final shelf = await _repository.createShelf(name, colorValue: colorValue);
    state = [...state, shelf];
    return shelf;
  }

  /// 棚名を変更する
  Future<void> renameShelf(String id, String newName) async {
    final updated = await _repository.renameShelf(id, newName);
    state = [
      for (final s in state) s.id == id ? updated : s,
    ];
  }

  /// 棚を削除する
  Future<void> deleteShelf(String id) async {
    await _repository.deleteShelf(id);
    state = state.where((s) => s.id != id).toList();
  }

  /// 蔵書を棚に追加する
  Future<void> addBook(String shelfId, String userBookId) async {
    final updated = await _repository.addBookToShelf(shelfId, userBookId);
    state = [
      for (final s in state) s.id == shelfId ? updated : s,
    ];
  }

  /// 蔵書を棚から取り除く
  Future<void> removeBook(String shelfId, String userBookId) async {
    final updated =
        await _repository.removeBookFromShelf(shelfId, userBookId);
    state = [
      for (final s in state) s.id == shelfId ? updated : s,
    ];
  }
}

/// ShelfController の Provider
final shelfControllerProvider =
    StateNotifierProvider<ShelfController, List<BookShelf>>((ref) {
  return ShelfController(ref.watch(shelfRepositoryProvider));
});
