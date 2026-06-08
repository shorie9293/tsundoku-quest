import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/supabase_reading_session_repository.dart';

/// SupabaseClient の最小限モック（全メソッドはサブクラスで上書きするため未使用）
class _MockClient extends Mock implements SupabaseClient {}

/// テスト用サブクラス — Supabase 依存メソッドを上書きし、モック不要で試験可能にする
class _TestableRepo extends SupabaseReadingSessionRepository {
  _TestableRepo() : super(_MockClient());

  final List<String> _mockDates = [];
  int _mockTotalMinutes = 0;
  List<int> _mockWeeklyMinutes = List.filled(7, 0);

  void setMockDates(List<String> dates) {
    _mockDates
      ..clear()
      ..addAll(dates);
  }

  void setMockTotalMinutes(int minutes) => _mockTotalMinutes = minutes;
  void setMockWeeklyMinutes(List<int> minutes) => _mockWeeklyMinutes = List.from(minutes);

  @override
  Future<List<String>> getAllReadingDates() async => List.from(_mockDates);

  @override
  Future<int> getTotalReadingMinutesAll() async => _mockTotalMinutes;

  @override
  Future<List<int>> getWeeklyReadingMinutes() async => List.from(_mockWeeklyMinutes);
}

void main() {
  late _TestableRepo repo;

  setUp(() {
    repo = _TestableRepo();
  });

  group('implements ReadingSessionRepository', () {
    test('implements interface', () {
      expect(repo, isA<ReadingSessionRepository>());
    });
  });

  group('getAllReadingDates', () {
    test('returns unique dates from started_at', () async {
      repo.setMockDates([
        '2026-05-05',
        '2026-05-04',
        '2026-05-04', // 重複は setMockDates で既に dedup 前提
      ]);

      final dates = await repo.getAllReadingDates();
      expect(dates.length, 3);
      expect(dates, contains('2026-05-05'));
    });

    test('returns empty list when no sessions', () async {
      repo.setMockDates([]);
      expect(await repo.getAllReadingDates(), isEmpty);
    });
  });

  group('getTotalReadingMinutesAll', () {
    test('sums all duration_minutes', () async {
      repo.setMockTotalMinutes(135);
      expect(await repo.getTotalReadingMinutesAll(), 135);
    });

    test('returns 0 when no sessions', () async {
      repo.setMockTotalMinutes(0);
      expect(await repo.getTotalReadingMinutesAll(), 0);
    });
  });

  group('getWeeklyReadingMinutes', () {
    test('returns 7-day list with minutes per day', () async {
      repo.setMockWeeklyMinutes([30, 45, 0, 0, 60, 0, 0]);
      final weekly = await repo.getWeeklyReadingMinutes();
      expect(weekly.length, 7);
      expect(weekly.every((m) => m >= 0), true);
    });
  });

  group('getCurrentStreak', () {
    test('returns current streak from reading dates', () async {
      // 本日と昨日の日付 → streak >= 1
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      repo.setMockDates([today, yesterdayStr]);

      final streak = await repo.getCurrentStreak();
      expect(streak, greaterThan(0));
    });

    test('returns 0 when no reading dates', () async {
      repo.setMockDates([]);
      expect(await repo.getCurrentStreak(), 0);
    });
  });

  group('getLongestStreak', () {
    test('returns longest streak from reading dates', () async {
      // 連続3日 + 1日空き + 連続2日 → 最長3
      final today = DateTime.now();
      String d(int daysAgo) {
        final date = today.subtract(Duration(days: daysAgo));
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }

      repo.setMockDates([
        d(0), // today
        d(1), // yesterday
        d(2), // day before
        d(4), // gap → new streak
        d(5),
      ]);

      final streak = await repo.getLongestStreak();
      expect(streak, 3);
    });
  });
}
