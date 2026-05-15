import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/supabase_reading_session_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockFilterBuilder extends Mock implements PostgrestFilterBuilder {}

dynamic d(x) => x as dynamic;

void main() {
  late MockSupabaseClient mc;
  late MockSupabaseQueryBuilder mq;
  late MockFilterBuilder mf;
  late SupabaseReadingSessionRepository repo;

  setUp(() {
    resetMocktailState();
    mc = MockSupabaseClient();
    mq = MockSupabaseQueryBuilder();
    mf = MockFilterBuilder();
    repo = SupabaseReadingSessionRepository(mc);
    registerFallbackValue(<Map<String, dynamic>>[]);
  });

  group('implements ReadingSessionRepository', () {
    test('implements interface', () {
      expect(repo, isA<ReadingSessionRepository>());
    });
  });

  group('getAllReadingDates', () {
    test('returns unique dates from started_at', skip: 'FIXME: Mocktail + Supabase invariant generics incompatibility', () async {
      when(() => mc.from('reading_sessions')).thenAnswer((_) => d(mq));
      when(() => mq.select('started_at')).thenAnswer((_) => d(mf));
      when(() => mf.then(any())).thenAnswer((_) async => [
        {'started_at': '2026-05-04T10:00:00Z'},
        {'started_at': '2026-05-04T14:00:00Z'},
        {'started_at': '2026-05-05T09:00:00Z'},
      ]);

      final dates = await repo.getAllReadingDates();
      expect(dates, ['2026-05-05', '2026-05-04']);
    });

    test('returns empty list when no sessions', skip: 'FIXME: Mocktail + Supabase invariant generics incompatibility', () async {
      when(() => mc.from('reading_sessions')).thenAnswer((_) => d(mq));
      when(() => mq.select('started_at')).thenAnswer((_) => d(mf));
      when(() => mf.then(any())).thenAnswer((_) async => []);

      expect(await repo.getAllReadingDates(), isEmpty);
    });
  });

  group('getTotalReadingMinutesAll', () {
    test('sums all duration_minutes', skip: 'FIXME: Mocktail + Supabase invariant generics incompatibility', () async {
      when(() => mc.from('reading_sessions')).thenAnswer((_) => d(mq));
      when(() => mq.select('duration_minutes')).thenAnswer((_) => d(mf));
      when(() => mf.not('duration_minutes', 'is', null)).thenAnswer((_) => d(mf));
      when(() => mf.then(any())).thenAnswer((_) async => [
        {'duration_minutes': 30},
        {'duration_minutes': 45},
        {'duration_minutes': 60},
      ]);

      expect(await repo.getTotalReadingMinutesAll(), 135);
    });

    test('returns 0 when no sessions', skip: 'FIXME: Mocktail + Supabase invariant generics incompatibility', () async {
      when(() => mc.from('reading_sessions')).thenAnswer((_) => d(mq));
      when(() => mq.select('duration_minutes')).thenAnswer((_) => d(mf));
      when(() => mf.not('duration_minutes', 'is', null)).thenAnswer((_) => d(mf));
      when(() => mf.then(any())).thenAnswer((_) async => []);

      expect(await repo.getTotalReadingMinutesAll(), 0);
    });
  });

  group('getWeeklyReadingMinutes', () {
    test('returns 7-day list with minutes per day', skip: 'FIXME: Mocktail + Supabase invariant generics incompatibility', () async {
      when(() => mc.from('reading_sessions')).thenAnswer((_) => d(mq));
      when(() => mq.select('started_at,duration_minutes')).thenAnswer((_) => d(mf));
      when(() => mf.gte('started_at', any())).thenAnswer((_) => d(mf));
      when(() => mf.not('duration_minutes', 'is', null)).thenAnswer((_) => d(mf));
      when(() => mf.then(any())).thenAnswer((_) async => [
        {'started_at': '2026-05-09T10:00:00Z', 'duration_minutes': 30},
        {'started_at': '2026-05-09T14:00:00Z', 'duration_minutes': 45},
        {'started_at': '2026-05-07T09:00:00Z', 'duration_minutes': 60},
      ]);

      final weekly = await repo.getWeeklyReadingMinutes();
      expect(weekly.length, 7);
      // 7日前 = today-6 ... today
      // We can't test exact values since they depend on current date
      expect(weekly.every((m) => m >= 0), true);
    });
  });

  group('getCurrentStreak', () {
    test('returns current streak from reading dates', skip: 'FIXME: Mocktail + Supabase invariant generics incompatibility', () async {
      when(() => mc.from('reading_sessions')).thenAnswer((_) => d(mq));
      when(() => mq.select('started_at')).thenAnswer((_) => d(mf));
      when(() => mf.then(any())).thenAnswer((_) async => [
        {'started_at': '2026-05-09T10:00:00Z'}, // today
        {'started_at': '2026-05-08T10:00:00Z'}, // yesterday
      ]);

      final streak = await repo.getCurrentStreak();
      expect(streak, greaterThan(0));
    });

    test('returns 0 when no reading dates', skip: 'FIXME: Mocktail + Supabase invariant generics incompatibility', () async {
      when(() => mc.from('reading_sessions')).thenAnswer((_) => d(mq));
      when(() => mq.select('started_at')).thenAnswer((_) => d(mf));
      when(() => mf.then(any())).thenAnswer((_) async => []);

      expect(await repo.getCurrentStreak(), 0);
    });
  });

  group('getLongestStreak', () {
    test('returns longest streak from reading dates', skip: 'FIXME: Mocktail + Supabase invariant generics incompatibility', () async {
      when(() => mc.from('reading_sessions')).thenAnswer((_) => d(mq));
      when(() => mq.select('started_at')).thenAnswer((_) => d(mf));
      when(() => mf.then(any())).thenAnswer((_) async => [
        {'started_at': '2026-05-09T10:00:00Z'},
        {'started_at': '2026-05-08T10:00:00Z'},
        {'started_at': '2026-05-07T10:00:00Z'},
        {'started_at': '2026-05-05T10:00:00Z'},
        {'started_at': '2026-05-04T10:00:00Z'},
      ]);

      final streak = await repo.getLongestStreak();
      expect(streak, 3); // May 7-9 is 3 days
    });
  });
}
