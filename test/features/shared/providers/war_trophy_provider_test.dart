import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/repositories/war_trophy_repository.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';

class MockWarTrophyRepository extends Mock implements WarTrophyRepository {}

WarTrophy _testTrophy(String id) => WarTrophy(
      id: id, userBookId: 'ub-1', userId: 'user-1',
      learnings: ['学び1', '学び2', '学び3'], action: 'アクション',
      createdAt: '2026-05-04T10:00:00Z');

void main() {
  setUpAll(() {
    registerFallbackValue(_testTrophy('fb'));
  });

  group('WarTrophyNotifier (in-memory mode)', () {
    test('initial state is empty', () {
      final notifier = WarTrophyNotifier();
      expect(notifier.state, isEmpty);
    });

    test('addTrophy should add to state', () {
      final notifier = WarTrophyNotifier();
      notifier.addTrophy(_testTrophy('wt-1'));
      expect(notifier.state.length, 1);
      expect(notifier.state[0].id, 'wt-1');
    });

    test('addTrophy should replace existing trophy with same id', () {
      final notifier = WarTrophyNotifier();
      notifier.addTrophy(_testTrophy('wt-1'));
      notifier.addTrophy(WarTrophy(
        id: 'wt-1', userBookId: 'ub-1', userId: 'user-1',
        learnings: ['新しい学び'], action: '新しいアクション',
        createdAt: '2026-05-05T10:00:00Z'));
      expect(notifier.state.length, 1);
      expect(notifier.state[0].learnings, ['新しい学び']);
    });

    test('getTrophy should return trophy by id', () {
      final notifier = WarTrophyNotifier();
      notifier.addTrophy(_testTrophy('wt-1'));
      expect(notifier.getTrophy('wt-1')!.id, 'wt-1');
    });

    test('getTrophy should return null for unknown id', () {
      expect(WarTrophyNotifier().getTrophy('unknown'), isNull);
    });

    test('fetchTrophies should do nothing when no repository', () async {
      final notifier = WarTrophyNotifier();
      await notifier.fetchTrophies();
      expect(notifier.state, isEmpty);
    });
  });

  group('WarTrophyNotifier (with repository)', () {
    late MockWarTrophyRepository mockRepo;
    late WarTrophyNotifier notifier;

    setUp(() {
      mockRepo = MockWarTrophyRepository();
      notifier = WarTrophyNotifier(mockRepo);
    });

    test('initial state is empty', () {
      expect(notifier.state, isEmpty);
    });

    test('fetchTrophies should load from repository', () async {
      final trophies = [_testTrophy('wt-1'), _testTrophy('wt-2')];
      when(() => mockRepo.getMyTrophies()).thenAnswer((_) async => trophies);
      await notifier.fetchTrophies();
      expect(notifier.state.length, 2);
      verify(() => mockRepo.getMyTrophies()).called(1);
    });

    test('addTrophy syncs via updateTrophy (state already has it)', () async {
      // _syncToSupabase checks state AFTER in-memory update,
      // so the trophy is always "existing" → updateTrophy is called
      final trophy = _testTrophy('wt-1');
      when(() => mockRepo.updateTrophy(any())).thenAnswer((_) async => trophy);
      notifier.addTrophy(trophy);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.length, 1);
      expect(notifier.state[0].id, 'wt-1');
      verify(() => mockRepo.updateTrophy(any())).called(1);
      verifyNever(() => mockRepo.createTrophy(any()));
    });

    test('addTrophy twice syncs both via updateTrophy', () async {
      final trophy1 = _testTrophy('wt-1');
      final trophy2 = WarTrophy(
        id: 'wt-1', userBookId: 'ub-1', userId: 'user-1',
        learnings: ['新しい学び'], action: '新しいアクション',
        createdAt: '2026-05-05T10:00:00Z');
      when(() => mockRepo.updateTrophy(any())).thenAnswer((_) async => trophy2);
      notifier.addTrophy(trophy1);
      notifier.addTrophy(trophy2);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.length, 1);
      expect(notifier.state[0].learnings, ['新しい学び']);
      verify(() => mockRepo.updateTrophy(any())).called(2);
    });
  });
}
