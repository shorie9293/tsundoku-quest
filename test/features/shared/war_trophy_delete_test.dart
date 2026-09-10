import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/repositories/war_trophy_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/war_trophy_repository_provider.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';

/// 禍津③: 本削除時に該当本の戦利品（感想）も削除されることを検証する。
class _FakeRepository implements WarTrophyRepository {
  final List<WarTrophy> trophies;
  final List<String> deletedIds = [];
  _FakeRepository(this.trophies);

  @override
  Future<List<WarTrophy>> getMyTrophies() async => trophies;

  @override
  Future<WarTrophy> createTrophy(WarTrophy trophy) async => trophy;

  @override
  Future<WarTrophy> updateTrophy(WarTrophy trophy) async => trophy;

  @override
  Future<void> deleteTrophiesByUserBook(String userBookId) async {
    deletedIds.add(userBookId);
    trophies.removeWhere((t) => t.userBookId == userBookId);
  }
}

WarTrophy _trophy(String id, String userBookId) => WarTrophy(
      id: id,
      userBookId: userBookId,
      userId: 'u1',
      learnings: const ['学び'],
      action: '',
      favoriteQuote: null,
      createdAt: '2026-09-10T00:00:00.000Z',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('removeTrophiesByUserBook が state から該当戦利品を除去しリポジトリにも通知する', () async {
    final repo = _FakeRepository([_trophy('t1', 'ub1'), _trophy('t2', 'ub2')]);
    final container = ProviderContainer(overrides: [
      warTrophyRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    // 事前ロード
    await container.read(warTrophyProvider.notifier).fetchTrophies();
    expect(container.read(warTrophyProvider).length, 2);

    await container
        .read(warTrophyProvider.notifier)
        .removeTrophiesByUserBook('ub1');

    expect(container.read(warTrophyProvider).length, 1,
        reason: 'ub1 の戦利品は state から除去されるべき');
    expect(repo.deletedIds, ['ub1'],
        reason: 'リポジトリ（Supabase）側にも削除が伝播するべき');
  });
}
