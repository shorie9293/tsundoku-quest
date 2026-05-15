import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/adventurer_repository.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/domain/repositories/user_book_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/supabase_adventurer_repository.dart';

class MockReadingSessionRepository extends Mock
    implements ReadingSessionRepository {}

class MockUserBookRepository extends Mock implements UserBookRepository {}

/// Helper: create a UserBook for testing
UserBook ub(String id, BookStatus status, {int currentPage = 0}) {
  return UserBook(
    id: id,
    userId: 'user-1',
    bookId: 'book-$id',
    status: status,
    medium: BookMedium.physical,
    currentPage: currentPage,
    totalReadingMinutes: 0,
    createdAt: '2026-05-01T00:00:00Z',
  );
}

void allStubs(MockReadingSessionRepository repo) {
  when(() => repo.getTotalReadingMinutesAll()).thenAnswer((_) async => 0);
  when(() => repo.getTotalPagesReadAll()).thenAnswer((_) async => 0);
  when(() => repo.getAllReadingDates()).thenAnswer((_) async => []);
  when(() => repo.getCurrentStreak()).thenAnswer((_) async => 0);
  when(() => repo.getLongestStreak()).thenAnswer((_) async => 0);
}

void main() {
  late MockReadingSessionRepository mockSessionRepo;
  late MockUserBookRepository mockUserBookRepo;
  late SupabaseAdventurerRepository repo;

  setUp(() {
    resetMocktailState();
    mockSessionRepo = MockReadingSessionRepository();
    mockUserBookRepo = MockUserBookRepository();
    repo = SupabaseAdventurerRepository(mockSessionRepo, mockUserBookRepo);
  });

  test('implements AdventurerRepository', () {
    expect(repo, isA<AdventurerRepository>());
  });

  group('stats()', () {
    test('computes comprehensive stats from repositories', () async {
      when(() => mockSessionRepo.getTotalReadingMinutesAll())
          .thenAnswer((_) async => 150);
      when(() => mockSessionRepo.getTotalPagesReadAll())
          .thenAnswer((_) async => 500);
      when(() => mockSessionRepo.getAllReadingDates())
          .thenAnswer((_) async => ['2026-05-09', '2026-05-08', '2026-05-07']);
      when(() => mockSessionRepo.getCurrentStreak())
          .thenAnswer((_) async => 3);
      when(() => mockSessionRepo.getLongestStreak())
          .thenAnswer((_) async => 5);
      when(() => mockUserBookRepo.getMyBooks())
          .thenAnswer((_) async => []);

      final stats = await repo.stats();

      expect(stats.totalReadingMinutes, 150);
      expect(stats.totalPagesRead, 500);
      expect(stats.currentStreak, 3);
      expect(stats.longestStreak, 5);
      expect(stats.readingDates, ['2026-05-09', '2026-05-08', '2026-05-07']);
    });

    test('computes totalBooksRegistered and totalBooksCompleted', () async {
      allStubs(mockSessionRepo);
      when(() => mockUserBookRepo.getMyBooks())
          .thenAnswer((_) async => [
            ub('1', BookStatus.reading),
            ub('2', BookStatus.completed),
            ub('3', BookStatus.completed),
            ub('4', BookStatus.tsundoku),
          ]);

      final stats = await repo.stats();

      expect(stats.totalBooksRegistered, 4);
      expect(stats.totalBooksCompleted, 2);
    });

    test('computes totalPagesRead from reading sessions', () async {
      when(() => mockSessionRepo.getTotalReadingMinutesAll())
          .thenAnswer((_) async => 0);
      when(() => mockSessionRepo.getTotalPagesReadAll())
          .thenAnswer((_) async => 600);
      when(() => mockSessionRepo.getAllReadingDates())
          .thenAnswer((_) async => []);
      when(() => mockSessionRepo.getCurrentStreak())
          .thenAnswer((_) async => 0);
      when(() => mockSessionRepo.getLongestStreak())
          .thenAnswer((_) async => 0);
      when(() => mockUserBookRepo.getMyBooks())
          .thenAnswer((_) async => []);

      final stats = await repo.stats();

      expect(stats.totalPagesRead, 600);
    });

    test('returns default stats when both repos return empty', () async {
      allStubs(mockSessionRepo);
      when(() => mockUserBookRepo.getMyBooks())
          .thenAnswer((_) async => []);

      final stats = await repo.stats();

      expect(stats.totalReadingMinutes, 0);
      expect(stats.totalBooksRegistered, 0);
      expect(stats.totalBooksCompleted, 0);
      expect(stats.totalPagesRead, 0);
    });
  });
}
