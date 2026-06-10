import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/repositories/war_trophy_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/supabase_war_trophy_repository.dart';

/// SupabaseClient の最小限モック（全メソッドはサブクラスで上書きするため未使用）
class _MockClient extends Mock implements SupabaseClient {}

WarTrophy _t(String id) => WarTrophy(
    id: id, userBookId: 'ub-1', userId: 'user-1',
    learnings: ['学1','学2','学3'], action: 'act',
    favoriteQuote: 'q', createdAt: '2026-05-04T10:00:00Z');

/// テスト用サブクラス — Supabase 依存メソッドを上書き
class _TestableWarTrophyRepo extends SupabaseWarTrophyRepository {
  _TestableWarTrophyRepo() : super(_MockClient());

  final List<WarTrophy> _trophies = [];
  final Map<String, WarTrophy> _byId = {};

  void seedTrophies(List<WarTrophy> trophies) {
    _trophies
      ..clear()
      ..addAll(trophies);
    _byId.clear();
    for (final t in trophies) {
      _byId[t.id] = t;
    }
  }

  @override
  Future<List<WarTrophy>> getMyTrophies() async => List.from(_trophies);

  @override
  Future<WarTrophy> createTrophy(WarTrophy trophy) async {
    _byId[trophy.id] = trophy;
    _trophies.insert(0, trophy);
    return trophy;
  }

  @override
  Future<WarTrophy> updateTrophy(WarTrophy trophy) async {
    _byId[trophy.id] = trophy;
    final idx = _trophies.indexWhere((t) => t.id == trophy.id);
    if (idx >= 0) _trophies[idx] = trophy;
    return trophy;
  }
}

void main() {
  late _TestableWarTrophyRepo repo;

  setUp(() {
    repo = _TestableWarTrophyRepo();
  });

  test('implements WarTrophyRepository', () {
    expect(repo, isA<WarTrophyRepository>());
  });

  group('getMyTrophies', () {
    test('returns list', () async {
      repo.seedTrophies([_t('wt-1'), _t('wt-2')]);
      final r = await repo.getMyTrophies();
      expect(r.length, 2);
    });

    test('returns empty', () async {
      repo.seedTrophies([]);
      expect(await repo.getMyTrophies(), isEmpty);
    });
  });

  group('createTrophy', () {
    test('creates and returns', () async {
      final r = await repo.createTrophy(_t('new-id'));
      expect(r.id, 'new-id');
      expect(r.learnings, ['学1','学2','学3']);
    });
  });

  group('updateTrophy', () {
    test('updates and returns', () async {
      repo.seedTrophies([_t('wt-1')]);
      const updated = WarTrophy(
        id: 'wt-1', userBookId: 'ub-1', userId: 'user-1',
        learnings: ['更新'], action: 'new-act',
        favoriteQuote: 'new-q', createdAt: '2026-05-05T10:00:00Z',
      );
      final r = await repo.updateTrophy(updated);
      expect(r.id, 'wt-1');
      expect(r.learnings, ['更新']);
      expect(r.action, 'new-act');
    });
  });
}
