import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/goals/domain/daily_reading_goal.dart';
import 'package:tsundoku_quest/features/goals/domain/daily_reading_goal_service.dart';

ReadingSession session({
  required String id,
  required String startedAt,
  int? minutes,
}) {
  return ReadingSession(
    id: id,
    userBookId: 'b1',
    startedAt: startedAt,
    startPage: 0,
    durationMinutes: minutes,
    createdAt: startedAt,
  );
}

void main() {
  final now = DateTime(2026, 10, 9, 15, 0);

  group('dateKey', () {
    test('ローカル日付をゼロ埋め YYYY-MM-DD にする', () {
      expect(DailyReadingGoalService.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(DailyReadingGoalService.dateKey(DateTime(2026, 12, 31)), '2026-12-31');
      expect(DailyReadingGoalService.dateKey(DateTime(999, 3, 7)), '0999-03-07');
    });
  });

  group('minutesByDate', () {
    test('同一日の分を合算する', () {
      final map = DailyReadingGoalService.minutesByDate([
        session(id: '1', startedAt: '2026-10-09T08:00:00', minutes: 20),
        session(id: '2', startedAt: '2026-10-09T22:00:00', minutes: 15),
      ]);
      expect(map['2026-10-09'], 35);
    });

    test('異なる日は別キーになる', () {
      final map = DailyReadingGoalService.minutesByDate([
        session(id: '1', startedAt: '2026-10-08T10:00:00', minutes: 10),
        session(id: '2', startedAt: '2026-10-09T10:00:00', minutes: 5),
      ]);
      expect(map.keys.length, 2);
      expect(map['2026-10-08'], 10);
      expect(map['2026-10-09'], 5);
    });

    test('UTC の startedAt はローカル日付へ変換される', () {
      // 2026-10-09T20:00:00Z = JST 2026-10-10T05:00:00
      final map = DailyReadingGoalService.minutesByDate([
        session(id: '1', startedAt: '2026-10-09T20:00:00Z', minutes: 30),
      ]);
      expect(map['2026-10-10'], 30);
    });

    test('durationMinutes が null は 0 分として日付キーを作る', () {
      final map = DailyReadingGoalService.minutesByDate([
        session(id: '1', startedAt: '2026-10-09T10:00:00'),
      ]);
      expect(map['2026-10-09'], 0);
    });

    test('durationMinutes が 0 以下は 0 分として加算する', () {
      final map = DailyReadingGoalService.minutesByDate([
        session(id: '1', startedAt: '2026-10-09T10:00:00', minutes: -5),
        session(id: '2', startedAt: '2026-10-09T11:00:00', minutes: 12),
      ]);
      expect(map['2026-10-09'], 12);
    });

    test('解釈不能な startedAt は黙って無視する', () {
      final map = DailyReadingGoalService.minutesByDate([
        session(id: '1', startedAt: '', minutes: 10),
        session(id: '2', startedAt: 'not-a-date', minutes: 10),
        session(id: '3', startedAt: '2026-10-09T09:00:00', minutes: 7),
      ]);
      expect(map.keys.length, 1);
      expect(map['2026-10-09'], 7);
    });

    test('空リストは空 map', () {
      expect(DailyReadingGoalService.minutesByDate([]), isEmpty);
    });
  });

  group('build', () {
    test('lastSevenDays は常に7件・昇順', () {
      final progress = DailyReadingGoalService.build(
        sessions: [],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.lastSevenDays.length, 7);
      expect(progress.lastSevenDays.first.date, '2026-10-03');
      expect(progress.lastSevenDays.last.date, '2026-10-09');
      for (var i = 1; i < 7; i++) {
        expect(
          progress.lastSevenDays[i].date.compareTo(progress.lastSevenDays[i - 1].date),
          greaterThan(0),
        );
      }
    });

    test('lastSevenDays の minutes は map から、無ければ 0', () {
      final progress = DailyReadingGoalService.build(
        sessions: [session(id: '1', startedAt: '2026-10-05T10:00:00', minutes: 40)],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      final day5 = progress.lastSevenDays.firstWhere((d) => d.date == '2026-10-05');
      expect(day5.minutes, 40);
      expect(day5.isAchieved, isTrue);
      final day6 = progress.lastSevenDays.firstWhere((d) => d.date == '2026-10-06');
      expect(day6.minutes, 0);
    });

    test('todayMinutes は今日の合算', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-09T08:00:00', minutes: 20),
          session(id: '2', startedAt: '2026-10-09T20:00:00', minutes: 10),
        ],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.todayMinutes, 30);
      expect(progress.todayAchieved, isTrue);
    });

    test('todayMinutes は負値にならない', () {
      final progress = DailyReadingGoalService.build(
        sessions: [],
        goal: const DailyReadingGoal.empty(),
        now: now,
      );
      expect(progress.todayMinutes, 0);
    });

    test('currentStreak: 今日達成なら今日から遡る', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-07T10:00:00', minutes: 30),
          session(id: '2', startedAt: '2026-10-08T10:00:00', minutes: 30),
          session(id: '3', startedAt: '2026-10-09T10:00:00', minutes: 30),
        ],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.currentStreak, 3);
    });

    test('currentStreak: 今日未達成でも昨日まで達成なら途切れ扱いしない', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-07T10:00:00', minutes: 30),
          session(id: '2', startedAt: '2026-10-08T10:00:00', minutes: 30),
        ],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.todayAchieved, isFalse);
      expect(progress.currentStreak, 2);
    });

    test('currentStreak: 昨日も未達成なら 0', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-06T10:00:00', minutes: 30),
        ],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.currentStreak, 0);
    });

    test('currentStreak: 未設定（target==0）なら 0', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-09T10:00:00', minutes: 100),
        ],
        goal: const DailyReadingGoal.empty(),
        now: now,
      );
      expect(progress.currentStreak, 0);
      expect(progress.longestStreak, 0);
      expect(progress.isSet, isFalse);
    });

    test('longestStreak: 連続達成を数える', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-03T10:00:00', minutes: 30),
          session(id: '2', startedAt: '2026-10-04T10:00:00', minutes: 30),
          session(id: '3', startedAt: '2026-10-05T10:00:00', minutes: 30),
        ],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.longestStreak, 3);
    });

    test('longestStreak: 断絶があると連続はリセットされる', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-03T10:00:00', minutes: 30),
          session(id: '2', startedAt: '2026-10-04T10:00:00', minutes: 30),
          session(id: '3', startedAt: '2026-10-06T10:00:00', minutes: 30),
          session(id: '4', startedAt: '2026-10-07T10:00:00', minutes: 30),
        ],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.longestStreak, 2);
    });

    test('longestStreak: 未達成分は無視する', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-03T10:00:00', minutes: 10),
          session(id: '2', startedAt: '2026-10-04T10:00:00', minutes: 30),
          session(id: '3', startedAt: '2026-10-05T10:00:00', minutes: 30),
        ],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.longestStreak, 2);
    });

    test('longestStreak: ウィンドウ外の過去日も集計対象になる', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-09-20T10:00:00', minutes: 30),
          session(id: '2', startedAt: '2026-09-21T10:00:00', minutes: 30),
        ],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.longestStreak, 2);
    });

    test('todayRatio: 部分達成', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-09T10:00:00', minutes: 15),
        ],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.todayRatio, closeTo(0.5, 0.0001));
    });

    test('todayRatio: 超過は 1.0 にクランプ', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-09T10:00:00', minutes: 90),
        ],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.todayRatio, 1.0);
    });

    test('todayRatio: 未設定は 0', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-09T10:00:00', minutes: 90),
        ],
        goal: const DailyReadingGoal.empty(),
        now: now,
      );
      expect(progress.todayRatio, 0);
    });

    test('todayRatio: 0分なら 0', () {
      final progress = DailyReadingGoalService.build(
        sessions: [],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.todayRatio, 0);
    });

    test('achievedDaysInWindow: 直近7日中の達成日数', () {
      final progress = DailyReadingGoalService.build(
        sessions: [
          session(id: '1', startedAt: '2026-10-04T10:00:00', minutes: 30),
          session(id: '2', startedAt: '2026-10-05T10:00:00', minutes: 15),
          session(id: '3', startedAt: '2026-10-08T10:00:00', minutes: 35),
          session(id: '4', startedAt: '2026-10-01T10:00:00', minutes: 30),
        ],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: now,
      );
      expect(progress.achievedDaysInWindow, 2);
    });

    test('日をまたぐ月替わりでも昇順7件が保たれる', () {
      final nowOct = DateTime(2026, 10, 2, 12);
      final progress = DailyReadingGoalService.build(
        sessions: [],
        goal: const DailyReadingGoal(targetMinutes: 30),
        now: nowOct,
      );
      expect(progress.lastSevenDays.first.date, '2026-09-26');
      expect(progress.lastSevenDays.last.date, '2026-10-02');
    });
  });
}