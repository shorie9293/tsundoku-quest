/// 読書達成バッジコレクションの計算サービス（純粋関数のみ）
library;

import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/badges/domain/badge_definition.dart';

/// バッジ定義・進捗計算の static 専用クラス
class BadgeCollectionService {
  BadgeCollectionService._();

  /// 全バッジ定義（24件・宣言順がそのまま表示順）
  static const List<BadgeDefinition> kBadgeDefinitions = [
    // ── 読了冊数 ──
    BadgeDefinition.def(
      id: 'books_1',
      name: 'はじめての一冊',
      description: '最初の1冊を読みきろう',
      icon: '📖',
      category: BadgeCategory.completedBooks,
      tier: 1,
      threshold: 1,
      metricKey: 'completedBooks',
    ),
    BadgeDefinition.def(
      id: 'books_5',
      name: '読書の輪',
      description: '5冊を読みきろう',
      icon: '📚',
      category: BadgeCategory.completedBooks,
      tier: 1,
      threshold: 5,
      metricKey: 'completedBooks',
    ),
    BadgeDefinition.def(
      id: 'books_10',
      name: '書架の架け橋',
      description: '10冊を読みきろう',
      icon: '📚',
      category: BadgeCategory.completedBooks,
      tier: 2,
      threshold: 10,
      metricKey: 'completedBooks',
    ),
    BadgeDefinition.def(
      id: 'books_25',
      name: '読書家への道',
      description: '25冊を読みきろう',
      icon: '📚',
      category: BadgeCategory.completedBooks,
      tier: 3,
      threshold: 25,
      metricKey: 'completedBooks',
    ),
    BadgeDefinition.def(
      id: 'books_50',
      name: '蔵書の達人',
      description: '50冊を読みきろう',
      icon: '👑',
      category: BadgeCategory.completedBooks,
      tier: 4,
      threshold: 50,
      metricKey: 'completedBooks',
    ),
    // ── 連続記録 ──
    BadgeDefinition.def(
      id: 'streak_3',
      name: '三連の燈',
      description: '3日連続で読書しよう',
      icon: '🔥',
      category: BadgeCategory.streak,
      tier: 1,
      threshold: 3,
      metricKey: 'currentStreak',
    ),
    BadgeDefinition.def(
      id: 'streak_7',
      name: '一週間の誓い',
      description: '7日連続で読書しよう',
      icon: '🔥',
      category: BadgeCategory.streak,
      tier: 2,
      threshold: 7,
      metricKey: 'currentStreak',
    ),
    BadgeDefinition.def(
      id: 'streak_14',
      name: '二週間の修練',
      description: '14日連続で読書しよう',
      icon: '🔥',
      category: BadgeCategory.streak,
      tier: 3,
      threshold: 14,
      metricKey: 'currentStreak',
    ),
    BadgeDefinition.def(
      id: 'streak_30',
      name: '月をめぐる習慣',
      description: '30日連続で読書しよう',
      icon: '🏆',
      category: BadgeCategory.streak,
      tier: 4,
      threshold: 30,
      metricKey: 'currentStreak',
    ),
    // ── 読書時間 ──
    BadgeDefinition.def(
      id: 'minutes_60',
      name: '最初の1時間',
      description: '合計60分読書しよう',
      icon: '⏱️',
      category: BadgeCategory.readingTime,
      tier: 1,
      threshold: 60,
      metricKey: 'readingMinutes',
    ),
    BadgeDefinition.def(
      id: 'minutes_300',
      name: '5時間の航路',
      description: '合計300分読書しよう',
      icon: '⏱️',
      category: BadgeCategory.readingTime,
      tier: 1,
      threshold: 300,
      metricKey: 'readingMinutes',
    ),
    BadgeDefinition.def(
      id: 'minutes_1000',
      name: '千分の修行',
      description: '合計1000分読書しよう',
      icon: '⏱️',
      category: BadgeCategory.readingTime,
      tier: 2,
      threshold: 1000,
      metricKey: 'readingMinutes',
    ),
    BadgeDefinition.def(
      id: 'minutes_3000',
      name: '五十時間の塔',
      description: '合計3000分読書しよう',
      icon: '⏱️',
      category: BadgeCategory.readingTime,
      tier: 3,
      threshold: 3000,
      metricKey: 'readingMinutes',
    ),
    BadgeDefinition.def(
      id: 'minutes_10000',
      name: '読書の賢者',
      description: '合計10000分読書しよう',
      icon: '🧙',
      category: BadgeCategory.readingTime,
      tier: 4,
      threshold: 10000,
      metricKey: 'readingMinutes',
    ),
    // ── 読了ページ ──
    BadgeDefinition.def(
      id: 'pages_100',
      name: '百ページの扉',
      description: '合計100ページ読もう',
      icon: '📄',
      category: BadgeCategory.pagesTotal,
      tier: 1,
      threshold: 100,
      metricKey: 'pagesTotal',
    ),
    BadgeDefinition.def(
      id: 'pages_500',
      name: '五百頁の海',
      description: '合計500ページ読もう',
      icon: '📄',
      category: BadgeCategory.pagesTotal,
      tier: 2,
      threshold: 500,
      metricKey: 'pagesTotal',
    ),
    BadgeDefinition.def(
      id: 'pages_2000',
      name: '二千頁の山',
      description: '合計2000ページ読もう',
      icon: '📄',
      category: BadgeCategory.pagesTotal,
      tier: 3,
      threshold: 2000,
      metricKey: 'pagesTotal',
    ),
    BadgeDefinition.def(
      id: 'pages_10000',
      name: '万頁の彼方',
      description: '合計10000ページ読もう',
      icon: '🏔️',
      category: BadgeCategory.pagesTotal,
      tier: 4,
      threshold: 10000,
      metricKey: 'pagesTotal',
    ),
    // ── 読書の時間帯: 早朝 ──
    BadgeDefinition.def(
      id: 'morning_1',
      name: '朝読の一滴',
      description: '早朝（5〜7時）に1回読書しよう',
      icon: '🌅',
      category: BadgeCategory.timeOfDay,
      tier: 1,
      threshold: 1,
      metricKey: 'earlyMorningSessions',
    ),
    BadgeDefinition.def(
      id: 'morning_5',
      name: '朝読の習慣',
      description: '早朝（5〜7時）に5回読書しよう',
      icon: '🌅',
      category: BadgeCategory.timeOfDay,
      tier: 2,
      threshold: 5,
      metricKey: 'earlyMorningSessions',
    ),
    BadgeDefinition.def(
      id: 'morning_20',
      name: '暁の読書家',
      description: '早朝（5〜7時）に20回読書しよう',
      icon: '☀️',
      category: BadgeCategory.timeOfDay,
      tier: 3,
      threshold: 20,
      metricKey: 'earlyMorningSessions',
    ),
    // ── 読書の時間帯: 夜 ──
    BadgeDefinition.def(
      id: 'night_1',
      name: '夜読の一滴',
      description: '夜（22時〜4時）に1回読書しよう',
      icon: '🌙',
      category: BadgeCategory.timeOfDay,
      tier: 1,
      threshold: 1,
      metricKey: 'nightSessions',
    ),
    BadgeDefinition.def(
      id: 'night_5',
      name: '夜読の習慣',
      description: '夜（22時〜4時）に5回読書しよう',
      icon: '🌙',
      category: BadgeCategory.timeOfDay,
      tier: 2,
      threshold: 5,
      metricKey: 'nightSessions',
    ),
    BadgeDefinition.def(
      id: 'night_20',
      name: '静寂の読書家',
      description: '夜（22時〜4時）に20回読書しよう',
      icon: '🌌',
      category: BadgeCategory.timeOfDay,
      tier: 3,
      threshold: 20,
      metricKey: 'nightSessions',
    ),
  ];

  /// セッション・蔵書から集計メトリクスを算出する（純粋）
  static Map<String, int> metrics({
    required List<ReadingSession> sessions,
    required List<UserBook> userBooks,
    required DateTime now,
  }) {
    var completedBooks = 0;
    for (final book in userBooks) {
      if (book.status == BookStatus.completed) completedBooks++;
    }

    var readingMinutes = 0;
    var pagesTotal = 0;
    var earlyMorning = 0;
    var night = 0;
    final daySet = <DateTime>{};

    for (final s in sessions) {
      final started = DateTime.tryParse(s.startedAt)?.toLocal();
      if (started == null) continue;

      final dm = s.durationMinutes;
      if (dm != null && dm > 0) readingMinutes += dm;

      final sp = s.startPage;
      final ep = s.endPage;
      if (ep != null) {
        final diff = ep - sp;
        if (diff > 0) pagesTotal += diff;
      }

      daySet.add(_dayOf(started));

      final h = started.hour;
      if (h >= 5 && h <= 7) earlyMorning++;
      if (h >= 22 || h <= 4) night++;
    }

    return {
      'completedBooks': completedBooks,
      'readingMinutes': readingMinutes,
      'pagesTotal': pagesTotal,
      'currentStreak': _currentStreak(daySet, _dayOf(now)),
      'longestStreak': _longestStreak(daySet),
      'earlyMorningSessions': earlyMorning,
      'nightSessions': night,
    };
  }

  /// メトリクスからバッジコレクションを構築する（宣言順を厳守）
  static BadgeCollection build({
    required List<ReadingSession> sessions,
    required List<UserBook> userBooks,
    required DateTime now,
  }) {
    final m = metrics(sessions: sessions, userBooks: userBooks, now: now);
    final badges = kBadgeDefinitions.map((def) {
      final current = m[def.metricKey] ?? 0;
      return BadgeProgress(
        definition: def,
        current: current,
        isEarned: current >= def.threshold,
      );
    }).toList();
    return BadgeCollection(badges);
  }

  /// バッジid → 獲得日時を既存コレクションに紐付ける（純粋）
  static BadgeCollection attachEarnedAt(
    BadgeCollection collection,
    Map<String, DateTime> earnedAtById,
  ) {
    final badges = collection.badges.map((b) {
      if (!b.isEarned) return b;
      final at = earnedAtById[b.definition.id];
      if (at == null) return b;
      return b.copyWith(earnedAt: at);
    }).toList();
    return BadgeCollection(badges);
  }

  // ── 内部ヘルパ ──

  /// ローカル日付（時刻を切り捨て）へ正規化
  static DateTime _dayOf(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  /// [days] が [anchorDay]（またはその1日前）に連結している場合のみ
  /// そこから遡る連続日数を返す
  static int _currentStreak(Set<DateTime> days, DateTime anchorDay) {
    var day = anchorDay;
    if (!days.contains(day)) {
      day = day.subtract(const Duration(days: 1));
      if (!days.contains(day)) return 0;
    }
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 日付集合内の最大連続日数（空なら 0）
  static int _longestStreak(Set<DateTime> days) {
    if (days.isEmpty) return 0;
    final sorted = days.toList()..sort();
    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]) == const Duration(days: 1)) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }
    return longest;
  }
}
