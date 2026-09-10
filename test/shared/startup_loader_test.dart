import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/repositories/war_trophy_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/war_trophy_repository_provider.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';
import 'package:tsundoku_quest/shared/providers/startup_loader.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadStartupData', () {
    test('起動時に戦利品（読書感想）をロードする', () async {
      final container = ProviderContainer(overrides: [
        warTrophyRepositoryProvider.overrideWithValue(
          _FakeRepository([
            WarTrophy(
              id: 't1',
              userBookId: 'ub1',
              userId: 'test-user',
              learnings: ['学び'],
              action: '行動',
              favoriteQuote: null,
              createdAt: '2026-09-10T00:00:00.000Z',
            ),
          ]),
        ),
      ]);
      addTearDown(container.dispose);

      expect(container.read(warTrophyProvider), isEmpty);

      await loadStartupData(container);

      expect(container.read(warTrophyProvider).length, 1,
          reason: '起動時に戦利品がロードされ、足跡画面の感想が表示されるべき');
    });
  });
}
