import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/war_trophy_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/war_trophy_repository_provider.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';
import 'package:tsundoku_quest/shared/providers/derived_provider.dart';

/// テスト用の空リポジトリ（本物の Hive を触らせない）
class _FakeTrophyRepo implements WarTrophyRepository {
  @override
  Future<List<WarTrophy>> getMyTrophies() async => [];
  @override
  Future<WarTrophy> createTrophy(WarTrophy trophy) async => trophy;
  @override
  Future<WarTrophy> updateTrophy(WarTrophy trophy) async => trophy;
  @override
  Future<void> deleteTrophiesByUserBook(String userBookId) async {}
}

/// 禍津②: 足跡画面の「登録数」「読了数」が bookDataProvider から
/// リアルタイムに派生していることを検証する。
///
/// adventurerProvider はセッション内で増減が反映されないため、
/// 足跡画面のカウントは bookStatsProvider（リアルタイム計算）を使う。
UserBook _ub(String id, BookStatus status) => UserBook(
      id: id,
      userId: 'u1',
      bookId: 'b-$id',
      book: Book(
        id: 'b-$id',
        title: '本$id',
        source: BookSource.openbd,
        createdAt: '2026-09-10T00:00:00.000Z',
      ),
      status: status,
      medium: BookMedium.physical,
      createdAt: '2026-09-10T00:00:00.000Z',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('足跡画面カウント（bookStats リアルタイム派生）', () {
    test('読了に遷移すると completedCount が即座に増える', () {
      final container = ProviderContainer(overrides: [
        warTrophyRepositoryProvider.overrideWithValue(_FakeTrophyRepo()),
      ]);
      addTearDown(container.dispose);

      container.read(bookDataProvider.notifier).addUserBook(
            _ub('1', BookStatus.tsundoku),
          );
      container.read(bookDataProvider.notifier).addUserBook(
            _ub('2', BookStatus.tsundoku),
          );
      expect(container.read(bookStatsProvider).completedCount, 0);

      container.read(bookDataProvider.notifier).updateUserBook(
            id: '1',
            status: BookStatus.completed,
          );

      expect(container.read(bookStatsProvider).completedCount, 1);
      expect(container.read(bookStatsProvider).totalBooks, 2);
    });

    test('本を削除すると totalBooks が即座に減る', () {
      final container = ProviderContainer(overrides: [
        warTrophyRepositoryProvider.overrideWithValue(_FakeTrophyRepo()),
      ]);
      addTearDown(container.dispose);

      container.read(bookDataProvider.notifier).addUserBook(
            _ub('1', BookStatus.tsundoku),
          );
      expect(container.read(bookStatsProvider).totalBooks, 1);

      container.read(bookDataProvider.notifier).removeUserBook('1');

      expect(container.read(bookStatsProvider).totalBooks, 0);
    });
  });
}
