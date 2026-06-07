import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/core/infrastructure/supabase/supabase_client_provider.dart';
import 'package:tsundoku_quest/domain/repositories/adventurer_repository.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/domain/repositories/user_book_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/user_book_repository_provider.dart';
import 'package:tsundoku_quest/features/reading/data/reading_session_repository_provider.dart';
import 'package:tsundoku_quest/features/shared/data/adventurer_repository_provider.dart';

class MockReadingSessionRepository extends Mock
    implements ReadingSessionRepository {}

class MockUserBookRepository extends Mock implements UserBookRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockReadingSessionRepository mockSessionRepo;
  late MockUserBookRepository mockUserBookRepo;
  late MockSupabaseClient mockClient;

  setUp(() {
    mockSessionRepo = MockReadingSessionRepository();
    mockUserBookRepo = MockUserBookRepository();
    mockClient = MockSupabaseClient();
  });

  group('adventurerRepositoryProvider', () {
    test('provides AdventurerRepository with injected repositories', () {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockClient),
          readingSessionRepositoryProvider
              .overrideWithValue(mockSessionRepo),
          userBookRepositoryProvider.overrideWithValue(mockUserBookRepo),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(adventurerRepositoryProvider);

      expect(repo, isA<AdventurerRepository>());
      // The provider should create a concrete instance, not return the mock directly
      expect(repo, isNot(same(mockSessionRepo)));
      expect(repo, isNot(same(mockUserBookRepo)));
    });

    test('returns same instance on repeated reads (singleton behavior)', () {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockClient),
          readingSessionRepositoryProvider
              .overrideWithValue(mockSessionRepo),
          userBookRepositoryProvider.overrideWithValue(mockUserBookRepo),
        ],
      );
      addTearDown(container.dispose);

      final repo1 = container.read(adventurerRepositoryProvider);
      final repo2 = container.read(adventurerRepositoryProvider);

      expect(repo1, same(repo2));
    });
  });
}
