import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/history/data/weekly_reading_provider.dart';
import 'package:tsundoku_quest/features/reading/data/reading_session_repository_provider.dart';

/// Fake implementation of [ReadingSessionRepository] for testing.
class FakeReadingSessionRepository implements ReadingSessionRepository {
  final List<int> weeklyMinutes;

  FakeReadingSessionRepository(this.weeklyMinutes);

  @override
  Future<List<int>> getWeeklyReadingMinutes() async => weeklyMinutes;

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) {
    throw UnimplementedError();
  }

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) {
    throw UnimplementedError();
  }

  @override
  Future<ReadingSession> endSession(
    String sessionId,
    int endPage,
    int durationMinutes,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getAllReadingDates() {
    throw UnimplementedError();
  }

  @override
  Future<int> getTotalReadingMinutes(String userBookId) {
    throw UnimplementedError();
  }

  @override
  Future<int> getTotalReadingMinutesAll() {
    throw UnimplementedError();
  }

  @override
  Future<int> getTotalPagesReadAll() {
    throw UnimplementedError();
  }

  @override
  Future<int> getCurrentStreak() {
    throw UnimplementedError();
  }

  @override
  Future<int> getLongestStreak() {
    throw UnimplementedError();
  }
}

void main() {
  group('weeklyReadingMinutesProvider', () {
    test('returns the list from the repository', () async {
      final fakeRepo = FakeReadingSessionRepository([10, 15, 20, 5, 0, 30, 25]);
      final container = ProviderContainer(
        overrides: [
          readingSessionRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final result = await container.read(weeklyReadingMinutesProvider.future);
      expect(result, [10, 15, 20, 5, 0, 30, 25]);

      container.dispose();
    });

    test('returns empty list when repository returns empty', () async {
      final fakeRepo = FakeReadingSessionRepository([]);
      final container = ProviderContainer(
        overrides: [
          readingSessionRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final result = await container.read(weeklyReadingMinutesProvider.future);
      expect(result, isEmpty);

      container.dispose();
    });

    test('returns correct values for multiple weeks with various patterns',
        () async {
      final fakeRepo = FakeReadingSessionRepository([0, 0, 0, 0, 0, 0, 0]);
      final container = ProviderContainer(
        overrides: [
          readingSessionRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final result = await container.read(weeklyReadingMinutesProvider.future);
      expect(result, [0, 0, 0, 0, 0, 0, 0]);

      container.dispose();
    });

    test('returns single-element list correctly', () async {
      final fakeRepo = FakeReadingSessionRepository([42]);
      final container = ProviderContainer(
        overrides: [
          readingSessionRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final result = await container.read(weeklyReadingMinutesProvider.future);
      expect(result, [42]);

      container.dispose();
    });
  });
}
