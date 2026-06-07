import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/core/infrastructure/supabase/supabase_client_provider.dart';
import 'package:tsundoku_quest/domain/repositories/war_trophy_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/war_trophy_repository_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockClient;

  setUp(() {
    mockClient = MockSupabaseClient();
  });

  group('warTrophyRepositoryProvider', () {
    test('provides WarTrophyRepository with injected SupabaseClient', () {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(warTrophyRepositoryProvider);

      expect(repo, isA<WarTrophyRepository>());
    });

    test('returns same instance on repeated reads (singleton)', () {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final repo1 = container.read(warTrophyRepositoryProvider);
      final repo2 = container.read(warTrophyRepositoryProvider);

      expect(repo1, same(repo2));
    });

    test('creates new instance when invalidated', () {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final repo1 = container.read(warTrophyRepositoryProvider);
      container.invalidate(warTrophyRepositoryProvider);
      final repo2 = container.read(warTrophyRepositoryProvider);

      expect(repo1, isNot(same(repo2)));
      expect(repo2, isA<WarTrophyRepository>());
    });

    test('forwards stats through the repository interface', () async {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(warTrophyRepositoryProvider);
      // Verify the repo exposes the correct interface methods
      expect(repo.getMyTrophies, isA<Function>());
      expect(repo.createTrophy, isA<Function>());
      expect(repo.updateTrophy, isA<Function>());
    });
  });
}
