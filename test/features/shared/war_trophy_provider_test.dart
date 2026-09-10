import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/repositories/war_trophy_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/war_trophy_repository_provider.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';

/// 削除/読了と足跡画面の連携テスト
///
/// 禍津①: fetchTrophies がどこからも呼ばれず、再起動後に感想が消える問題
class _FakeRepository implements WarTrophyRepository {
  final List<WarTrophy> trophies;
  _FakeRepository(this.trophies);

  @override
  Future<List<WarTrophy>> getMyTrophies() async => trophies;

  @override
  Future<WarTrophy> createTrophy(WarTrophy trophy) async => trophy;

  @override
  Future<WarTrophy> updateTrophy(WarTrophy trophy) async => trophy;

  @override
  Future<void> deleteTrophiesByUserBook(String userBookId) async {}
}

WarTrophy _trophy(String id, String userBookId) => WarTrophy(
      id: id,
      userBookId: userBookId,
      userId: 'test-user',
      learnings: ['学び1'],
      action: '行動',
      favoriteQuote: null,
      createdAt: '2026-09-10T00:00:00.000Z',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WarTrophyNotifier.fetchTrophies', () {
    test('リポジトリから戦利品を読み込み state に反映する', () async {
      final container = ProviderContainer(overrides: [
        warTrophyRepositoryProvider.overrideWithValue(
          _FakeRepository([_trophy('t1', 'ub1')]),
        ),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(warTrophyProvider.notifier);
      await notifier.fetchTrophies();

      expect(container.read(warTrophyProvider).length, 1);
    });
  });
}
