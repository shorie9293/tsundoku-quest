import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/models/reading_session.dart';
import '../../../domain/repositories/reading_session_repository.dart';

/// Supabaseをデータストアに使用したReadingSessionRepositoryの具象実装
class SupabaseReadingSessionRepository implements ReadingSessionRepository {
  final SupabaseClient _client;

  SupabaseReadingSessionRepository(this._client);

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _client
        .from('reading_sessions')
        .insert({
          'user_book_id': userBookId,
          'started_at': now,
          'start_page': startPage,
        })
        .select()
        .single();
    return ReadingSession.fromSupabase(response);
  }

  @override
  Future<ReadingSession> endSession(
    String sessionId,
    int endPage,
    int durationMinutes,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await _client
        .from('reading_sessions')
        .update({
          'ended_at': now,
          'end_page': endPage,
          'duration_minutes': durationMinutes,
        })
        .eq('id', sessionId)
        .select()
        .single();
    return ReadingSession.fromSupabase(response);
  }

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) async {
    final response = await _client
        .from('reading_sessions')
        .select()
        .eq('user_book_id', userBookId)
        .order('started_at', ascending: false);
    return (response)
        .map((json) => ReadingSession.fromSupabase(json))
        .toList();
  }

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async {
    final response = await _client
        .from('reading_sessions')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (response)
        .map((json) => ReadingSession.fromSupabase(json))
        .toList();
  }

  @override
  Future<List<String>> getAllReadingDates() async {
    final response = await _client
        .from('reading_sessions')
        .select('started_at') as List<dynamic>;
    // Extract unique dates from started_at timestamps
    final dateSet = <String>{};
    for (final row in response) {
      if (row is Map<String, dynamic> && row['started_at'] is String) {
        final dateStr = row['started_at'] as String;
        // Extract YYYY-MM-DD from ISO 8601 timestamp
        final dateOnly = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
        dateSet.add(dateOnly);
      }
    }
    final result = dateSet.toList()..sort((a, b) => b.compareTo(a));
    return result;
  }

  @override
  Future<int> getTotalReadingMinutes(String userBookId) async {
    final response = await _client
        .from('reading_sessions')
        .select('duration_minutes')
        .eq('user_book_id', userBookId)
        .not('duration_minutes', 'is', null) as List<dynamic>;
    int total = 0;
    for (final row in response) {
      if (row is Map<String, dynamic> && row['duration_minutes'] is int) {
        total += row['duration_minutes'] as int;
      }
    }
    return total;
  }

  // ━━━ Phase 3: 戦歴・統計の集計メソッド ━━━

  @override
  Future<int> getTotalReadingMinutesAll() async {
    final response = await _client
        .from('reading_sessions')
        .select('duration_minutes')
        .not('duration_minutes', 'is', null) as List<dynamic>;
    int total = 0;
    for (final row in response) {
      if (row is Map<String, dynamic> && row['duration_minutes'] is int) {
        total += row['duration_minutes'] as int;
      }
    }
    return total;
  }

  @override
  Future<int> getTotalPagesReadAll() async {
    final response = await _client
        .from('reading_sessions')
        .select('start_page,end_page')
        .not('end_page', 'is', null) as List<dynamic>;
    int total = 0;
    for (final row in response) {
      if (row is Map<String, dynamic> &&
          row['start_page'] is int &&
          row['end_page'] is int) {
        final pages = (row['end_page'] as int) - (row['start_page'] as int);
        if (pages > 0) total += pages;
      }
    }
    return total;
  }

  @override
  Future<List<int>> getWeeklyReadingMinutes() async {
    final now = DateTime.now().toUtc();
    final weekStart = now.subtract(const Duration(days: 6));
    final weekStartStr = weekStart.toIso8601String();

    final response = await _client
        .from('reading_sessions')
        .select('started_at,duration_minutes')
        .gte('started_at', weekStartStr)
        .not('duration_minutes', 'is', null) as List<dynamic>;

    // Initialize 7 days with 0 minutes
    final dailyMinutes = List.filled(7, 0);
    for (final row in response) {
      if (row is Map<String, dynamic> &&
          row['started_at'] is String &&
          row['duration_minutes'] is int) {
        final ts = row['started_at'] as String;
        final duration = row['duration_minutes'] as int;
        final dateStr = ts.length >= 10 ? ts.substring(0, 10) : ts;
        // Calculate day index from weekStart
        final date = DateTime.parse(dateStr);
        final diff = date.difference(weekStart).inDays;
        if (diff >= 0 && diff < 7) {
          dailyMinutes[diff] += duration;
        }
      }
    }
    return dailyMinutes;
  }

  @override
  Future<int> getCurrentStreak() async {
    final dates = await getAllReadingDates();
    if (dates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final yesterday =
        today.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    // Streak must include today or yesterday
    if (dates[0] != todayStr && dates[0] != yesterdayStr) return 0;

    int streak = 1;
    for (int i = 1; i < dates.length; i++) {
      final current = DateTime.parse(dates[i - 1]);
      final prev = DateTime.parse(dates[i]);
      final diff = current.difference(prev).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Future<int> getLongestStreak() async {
    final dates = await getAllReadingDates();
    if (dates.isEmpty) return 0;

    int longest = 1;
    int current = 1;
    for (int i = 1; i < dates.length; i++) {
      final prev = DateTime.parse(dates[i - 1]);
      final curr = DateTime.parse(dates[i]);
      final diff = prev.difference(curr).inDays;
      if (diff == 1) {
        current++;
      } else {
        if (current > longest) longest = current;
        current = 1;
      }
    }
    if (current > longest) longest = current;
    return longest;
  }
}
