/// Hive implementation of UserBookRepository
///
/// Uses the 'books_box' Hive box for UserBook persistence.
/// Books (the catalog entries) are stored alongside UserBooks.
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/user_book_repository.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';

class HiveUserBookRepository implements UserBookRepository {
  final BoxManagerInterface _boxManager;

  HiveUserBookRepository(this._boxManager);

  Box<UserBook>? _box;

  Future<Box<UserBook>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await _boxManager.getBox<UserBook>(BoxNames.books);
    return _box!;
  }

  // ── Read operations ──

  @override
  Future<List<UserBook>> getMyBooks() async {
    try {
      final box = await _getBox();
      return BoxHelper.loadCollection(box);
    } catch (e) {
      debugPrint('[HiveUserBookRepo] getMyBooks failed: $e');
      return [];
    }
  }

  @override
  Future<List<UserBook>> getByStatus(BookStatus status) async {
    try {
      final box = await _getBox();
      final all = BoxHelper.loadCollection(box);
      return all.where((ub) => ub.status == status).toList();
    } catch (e) {
      debugPrint('[HiveUserBookRepo] getByStatus failed: $e');
      return [];
    }
  }

  @override
  Future<UserBook?> getById(String id) async {
    try {
      final box = await _getBox();
      return box.get(id);
    } catch (e) {
      debugPrint('[HiveUserBookRepo] getById failed: $e');
      return null;
    }
  }

  // ── Write operations ──

  @override
  Future<UserBook> addBook(UserBook userBook) async {
    final box = await _getBox();
    await box.put(userBook.id, userBook);
    await box.flush();
    return userBook;
  }

  @override
  Future<UserBook> updateBook(UserBook userBook) async {
    final box = await _getBox();
    await box.put(userBook.id, userBook);
    await box.flush();
    return userBook;
  }

  @override
  Future<void> deleteBook(String id) async {
    final box = await _getBox();
    await box.delete(id);
    await box.flush();
  }

  /// Close the underlying box
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
