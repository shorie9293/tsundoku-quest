import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/models/reading_session.dart';
import '../../../domain/repositories/reading_session_repository.dart';
import '../domain/weekly_reading_buckets.dart';
import '../domain/reading_date_key.dart';

/// Supabaseをデータストアに使用したReadingSessionRepositoryの具象実装
class SupabaseReadingSessionRepository implements ReadingSessionRepository {
  final SupabaseClient _client;
  final DateTime Function() _clock;

  SupabaseReadingSessionRepository(
    this._client, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

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
  Future<ReadingSession> createSession(ReadingSession session) async {
    final response = await _client
        .from('reading_sessions')
        .insert(session.toSupabase())
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
  Future<void> updateSession(ReadingSession session) async {
    await _client
        .from('reading_sessions')
        .update(session.toSupabase())
        .eq('id', session.id);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _client.from('reading_sessions').delete().eq('id', sessionId);
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
    // 日付キーはローカル暦（UTC の先頭10文字切り出しでは JST 早朝が前日になる）。
    return ReadingDateKey.uniqueSortedDescending(
      response
          .whereType<Map<String, dynamic>>()
          .map((row) => row['started_at'])
          .whereType<String>(),
    );
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
    final now = _clock();
    // 下限は「ローカル週初め 0 時」を UTC 化した ISO。
    // 時刻付き UTC インスタントを引くとローカル最古の日が落ちる。
    final weekStartStr = WeeklyReadingBuckets.weekStartIso(now);

    final response = await _client
        .from('reading_sessions')
        .select('started_at,duration_minutes')
        .gte('started_at', weekStartStr)
        .not('duration_minutes', 'is', null) as List<dynamic>;

    // 集計は純粋モジュールに一任（index 6 = 今日、ローカル暦）。
    final samples = <ReadingSample>[];
    for (final row in response) {
      if (row is Map<String, dynamic> &&
          row['started_at'] is String &&
          row['duration_minutes'] is int) {
        samples.add((
          startedAt: row['started_at'] as String,
          durationMinutes: row['duration_minutes'] as int,
        ));
      }
    }
    return WeeklyReadingBuckets.build(samples, now: now);
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
