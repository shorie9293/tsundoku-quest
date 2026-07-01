/// Hive implementation of WarTrophyRepository
///
/// Uses the 'war_trophies_box' Hive box for WarTrophy persistence.
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/repositories/war_trophy_repository.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';

class HiveWarTrophyRepository implements WarTrophyRepository {
  final BoxManagerInterface _boxManager;

  HiveWarTrophyRepository(this._boxManager);

  Box<WarTrophy>? _box;

  Future<Box<WarTrophy>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await _boxManager.getBox<WarTrophy>(BoxNames.warTrophies);
    return _box!;
  }

  @override
  Future<List<WarTrophy>> getMyTrophies() async {
    try {
      final box = await _getBox();
      final all = BoxHelper.loadCollection(box);
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    } catch (e) {
      debugPrint('[HiveWarTrophyRepo] getMyTrophies failed: $e');
      return [];
    }
  }

  @override
  Future<WarTrophy> createTrophy(WarTrophy trophy) async {
    final box = await _getBox();
    await box.put(trophy.id, trophy);
    await box.flush();
    return trophy;
  }

  @override
  Future<WarTrophy> updateTrophy(WarTrophy trophy) async {
    final box = await _getBox();
    await box.put(trophy.id, trophy);
    await box.flush();
    return trophy;
  }

  /// Close the underlying box
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
