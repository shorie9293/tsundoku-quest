import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/user_book_repository.dart';

/// テスト用のMockUserBookRepository — インメモリで動作
class MockUserBookRepository implements UserBookRepository {
  final List<UserBook> _store = [];
  bool shouldThrow = false;

  void seed(List<UserBook> books) => _store.addAll(books);
  void reset() => _store.clear();

  @override
  Future<List<UserBook>> getMyBooks() async {
    if (shouldThrow) throw Exception('Mock error');
    return List.unmodifiable(_store);
  }

  @override
  Future<List<UserBook>> getByStatus(BookStatus status) async {
    return _store.where((b) => b.status == status).toList();
  }

  @override
  Future<UserBook?> getById(String id) async {
    try {
      return _store.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserBook> addBook(UserBook userBook) async {
    _store.add(userBook);
    return userBook;
  }

  @override
  Future<UserBook> updateBook(UserBook userBook) async {
    final idx = _store.indexWhere((b) => b.id == userBook.id);
    if (idx >= 0) _store[idx] = userBook;
    return userBook;
  }

  @override
  Future<void> deleteBook(String id) async {
    _store.removeWhere((b) => b.id == id);
  }
}
