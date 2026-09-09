/// Hive implementation of ShelfRepository
///
/// 棚データは 'shelves_box' Hive box に JSON 文字列（shelfId → json）で保存する。
/// JSON 文字列保存により TypeAdapter 登録・マイグレーションが不要で堅牢。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/book_shelf.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';

class HiveShelfRepository implements ShelfRepository {
  final BoxManagerInterface _boxManager;

  HiveShelfRepository(this._boxManager);

  Box<String>? _box;

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await _boxManager.getBox<String>(BoxNames.shelves);
    return _box!;
  }

  @override
  Future<List<BookShelf>> listShelves() async {
    try {
      final box = await _getBox();
      final shelves = box.values
          .map((raw) => BookShelf.fromJson(jsonDecode(raw) as Map<String, dynamic>))
          .toList();
      shelves.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return shelves;
    } catch (e) {
      debugPrint('[HiveShelfRepo] listShelves failed: $e');
      return [];
    }
  }

  Future<void> _put(BookShelf shelf) async {
    final box = await _getBox();
    await box.put(shelf.id, jsonEncode(shelf.toJson()));
    await box.flush();
  }

  @override
  Future<BookShelf> createShelf(String name, {int colorValue = 0}) async {
    final shelf = BookShelf.create(name: name, colorValue: colorValue);
    await _put(shelf);
    return shelf;
  }

  @override
  Future<BookShelf> renameShelf(String id, String newName) async {
    final shelf = await _find(id);
    final updated = shelf.copyWith(name: newName);
    await _put(updated);
    return updated;
  }

  @override
  Future<void> deleteShelf(String id) async {
    final box = await _getBox();
    await box.delete(id);
    await box.flush();
  }

  @override
  Future<BookShelf> addBookToShelf(String shelfId, String userBookId) async {
    final shelf = await _find(shelfId);
    if (shelf.userBookIds.contains(userBookId)) return shelf;
    final updated =
        shelf.copyWith(userBookIds: [...shelf.userBookIds, userBookId]);
    await _put(updated);
    return updated;
  }

  @override
  Future<BookShelf> removeBookFromShelf(
      String shelfId, String userBookId) async {
    final shelf = await _find(shelfId);
    final updated = shelf.copyWith(
      userBookIds: shelf.userBookIds.where((b) => b != userBookId).toList(),
    );
    await _put(updated);
    return updated;
  }

  Future<BookShelf> _find(String id) async {
    final box = await _getBox();
    final raw = box.get(id);
    if (raw == null) throw StateError('Shelf not found: $id');
    return BookShelf.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
