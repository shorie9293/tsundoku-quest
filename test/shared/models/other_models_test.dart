import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';

void main() {
  // ━━━ AdventurerStats ━━━
  group('AdventurerStats', () {
    test('should create with all fields', () {
      final stats = AdventurerStats(
        level: 5,
        xp: 230,
        xpToNextLevel: 400,
        title: '本の探検家',
        totalBooksRegistered: 12,
        totalBooksCompleted: 3,
        totalReadingMinutes: 450,
        totalPagesRead: 890,
        currentStreak: 7,
        longestStreak: 14,
        readingDates: ['2026-05-01', '2026-05-02'],
      );

      expect(stats.level, 5);
      expect(stats.xp, 230);
      expect(stats.xpToNextLevel, 400);
      expect(stats.title, '本の探検家');
      expect(stats.totalBooksRegistered, 12);
      expect(stats.totalBooksCompleted, 3);
      expect(stats.totalReadingMinutes, 450);
      expect(stats.totalPagesRead, 890);
      expect(stats.currentStreak, 7);
      expect(stats.longestStreak, 14);
      expect(stats.readingDates, ['2026-05-01', '2026-05-02']);
    });

    test('should create with defaults (level 1 beginner)', () {
      final stats = AdventurerStats.beginner();

      expect(stats.level, 1);
      expect(stats.xp, 0);
      expect(stats.xpToNextLevel, 100);
      expect(stats.title, '書庫の見習い');
      expect(stats.totalBooksRegistered, 0);
      expect(stats.currentStreak, 0);
    });
  });

  // ━━━ WarTrophy ━━━
  group('WarTrophy', () {
    test('should create with all fields', () {
      final trophy = WarTrophy(
        id: 'wt-1',
        userBookId: 'ub-1',
        userId: 'user-1',
        learnings: ['学び1', '学び2', '学び3'],
        action: '毎日10分読書する',
        favoriteQuote: '為せば成る',
        createdAt: '2026-05-04T10:00:00Z',
      );

      expect(trophy.id, 'wt-1');
      expect(trophy.learnings.length, 3);
      expect(trophy.learnings[0], '学び1');
      expect(trophy.action, '毎日10分読書する');
      expect(trophy.favoriteQuote, '為せば成る');
    });

    test('fromJson should parse correctly', () {
      final json = {
        'id': 'wt-2',
        'userBookId': 'ub-2',
        'userId': 'user-1',
        'learnings': ['学びA', '学びB', '学びC'],
        'action': '週に1冊読む',
        'favoriteQuote': null,
        'createdAt': '2026-05-04T12:00:00Z',
      };

      final trophy = WarTrophy.fromJson(json);

      expect(trophy.id, 'wt-2');
      expect(trophy.learnings, ['学びA', '学びB', '学びC']);
      expect(trophy.action, '週に1冊読む');
      expect(trophy.favoriteQuote, isNull);
    });

    test('toJson should serialize correctly', () {
      final trophy = WarTrophy(
        id: 'wt-3',
        userBookId: 'ub-3',
        userId: 'user-1',
        learnings: ['A', 'B', 'C'],
        action: 'アクション',
        createdAt: '2026-05-04T12:00:00Z',
      );

      final json = trophy.toJson();

      expect(json['id'], 'wt-3');
      expect(json['learnings'], ['A', 'B', 'C']);
      expect(json['action'], 'アクション');
    });
  });

  // ━━━ ReadingSession ━━━
  group('ReadingSession', () {
    test('should create active session', () {
      final session = ReadingSession(
        id: 'rs-1',
        userBookId: 'ub-1',
        startedAt: '2026-05-04T10:00:00Z',
        startPage: 42,
        createdAt: '2026-05-04T10:00:00Z',
      );

      expect(session.id, 'rs-1');
      expect(session.userBookId, 'ub-1');
      expect(session.startedAt, '2026-05-04T10:00:00Z');
      expect(session.startPage, 42);
      expect(session.endedAt, isNull);
      expect(session.endPage, isNull);
      expect(session.durationMinutes, isNull);
    });

    test('should create completed session', () {
      final session = ReadingSession(
        id: 'rs-2',
        userBookId: 'ub-1',
        startedAt: '2026-05-04T10:00:00Z',
        endedAt: '2026-05-04T10:30:00Z',
        startPage: 42,
        endPage: 58,
        durationMinutes: 30,
        createdAt: '2026-05-04T10:00:00Z',
      );

      expect(session.endedAt, '2026-05-04T10:30:00Z');
      expect(session.endPage, 58);
      expect(session.durationMinutes, 30);
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'rs-3',
        'userBookId': 'ub-1',
        'startedAt': '2026-05-04T10:00:00Z',
        'endedAt': '2026-05-04T10:45:00Z',
        'startPage': 10,
        'endPage': 35,
        'durationMinutes': 45,
        'createdAt': '2026-05-04T10:00:00Z',
      };

      final session = ReadingSession.fromJson(json);
      final roundTripped = session.toJson();

      expect(roundTripped['id'], 'rs-3');
      expect(roundTripped['startPage'], 10);
      expect(roundTripped['endPage'], 35);
      expect(roundTripped['durationMinutes'], 45);
    });
  });
}
