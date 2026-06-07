import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/core/infrastructure/supabase/supabase_client_provider.dart';
import 'package:tsundoku_quest/domain/repositories/user_book_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/user_book_repository_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockSupabaseClient mockClient;

  setUp(() {
    mockClient = MockSupabaseClient();
  });

  group('userBookRepositoryProvider', () {
    test('provides UserBookRepository with injected SupabaseClient', () {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(userBookRepositoryProvider);

      expect(repo, isA<UserBookRepository>());
    });

    test('returns same instance on repeated reads (singleton behavior)', () {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final repo1 = container.read(userBookRepositoryProvider);
      final repo2 = container.read(userBookRepositoryProvider);

      expect(repo1, same(repo2));
    });

    test('creates a different instance when provider is refreshed', () {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final repo1 = container.read(userBookRepositoryProvider);
      container.invalidate(userBookRepositoryProvider);
      final repo2 = container.read(userBookRepositoryProvider);

      // After invalidation, a new instance should be created
      expect(repo1, isNot(same(repo2)));
      expect(repo2, isA<UserBookRepository>());
    });
  });
}
