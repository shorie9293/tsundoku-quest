import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/reading/domain/reading_session_editor_service.dart';

void main() {
  group('validate', () {
    test('正常入力は valid', () {
      final v = ReadingSessionEditorService.validate(
        userBookId: 'ub1',
        durationMinutes: 30,
        startPage: 10,
        endPage: 20,
      );
      expect(v.isValid, isTrue);
      expect(v.error, isNull);
    });

    test('userBookId 空 → emptyBook', () {
      final v = ReadingSessionEditorService.validate(
        userBookId: '',
        durationMinutes: 30,
        startPage: 0,
      );
      expect(v.isValid, isFalse);
      expect(v.error, SessionEditError.emptyBook);
    });

    test('durationMinutes 0 → invalidDuration', () {
      final v = ReadingSessionEditorService.validate(
        userBookId: 'ub1',
        durationMinutes: 0,
        startPage: 0,
      );
      expect(v.error, SessionEditError.invalidDuration);
    });

    test('durationMinutes 負 → invalidDuration', () {
      final v = ReadingSessionEditorService.validate(
        userBookId: 'ub1',
        durationMinutes: -5,
        startPage: 0,
      );
      expect(v.error, SessionEditError.invalidDuration);
    });

    test('durationMinutes 上限超過 → durationTooLong', () {
      final v = ReadingSessionEditorService.validate(
        userBookId: 'ub1',
        durationMinutes: 24 * 60 + 1,
        startPage: 0,
      );
      expect(v.error, SessionEditError.durationTooLong);
    });

    test('durationMinutes 上限ちょうどは valid', () {
      final v = ReadingSessionEditorService.validate(
        userBookId: 'ub1',
        durationMinutes: 24 * 60,
        startPage: 0,
      );
      expect(v.isValid, isTrue);
    });

    test('startPage 負 → invalidPageRange', () {
      final v = ReadingSessionEditorService.validate(
        userBookId: 'ub1',
        durationMinutes: 30,
        startPage: -1,
      );
      expect(v.error, SessionEditError.invalidPageRange);
    });

    test('endPage < startPage → invalidPageRange', () {
      final v = ReadingSessionEditorService.validate(
        userBookId: 'ub1',
        durationMinutes: 30,
        startPage: 10,
        endPage: 9,
      );
      expect(v.error, SessionEditError.invalidPageRange);
    });

    test('endPage == startPage は valid', () {
      final v = ReadingSessionEditorService.validate(
        userBookId: 'ub1',
        durationMinutes: 30,
        startPage: 10,
        endPage: 10,
      );
      expect(v.isValid, isTrue);
    });

    test('invalid メッセージは日本語で非空', () {
      final v = ReadingSessionEditorService.validate(
        userBookId: 'ub1',
        durationMinutes: 0,
        startPage: 0,
      );
      expect(v.message, isNotEmpty);
    });
  });

  group('buildManual', () {
    test('startedAt は UTC ISO8601 文字列で格納される', () {
      final localStart = DateTime(2026, 10, 4, 12, 0);
      final s = ReadingSessionEditorService.buildManual(
        id: 's1',
        userBookId: 'ub1',
        startedAt: localStart,
        durationMinutes: 45,
        startPage: 1,
      );
      final parsed = DateTime.parse(s.startedAt);
      expect(s.startedAt.endsWith('Z'), isTrue,
          reason: 'UTC ISO8601 文字列であるべき');
      expect(parsed.toIso8601String(), s.startedAt);
      // 同一時点の UTC 値と一致する（TZ 依存の検証）
      expect(parsed.isUtc, isTrue);
      expect(DateTime.parse(s.startedAt).toUtc(), localStart.toUtc());
    });

    test('endedAt = startedAt + durationMinutes（UTC ISO）', () {
      final localStart = DateTime(2026, 10, 4, 12, 0);
      final s = ReadingSessionEditorService.buildManual(
        id: 's1',
        userBookId: 'ub1',
        startedAt: localStart,
        durationMinutes: 45,
        startPage: 1,
        endPage: 50,
      );
      expect(s.endedAt, isNotNull);
      expect(
        DateTime.parse(s.endedAt!),
        DateTime.parse(s.startedAt).add(const Duration(minutes: 45)),
      );
    });

    test('createdAt は指定があればその値（UTC ISO）', () {
      final createdAt = DateTime(2026, 10, 1, 9, 0);
      final s = ReadingSessionEditorService.buildManual(
        id: 's1',
        userBookId: 'ub1',
        startedAt: DateTime(2026, 10, 4, 12, 0),
        durationMinutes: 30,
        startPage: 0,
        createdAt: createdAt,
      );
      expect(DateTime.parse(s.createdAt), createdAt.toUtc());
    });

    test('createdAt 未指定なら now 注入時刻が使われる', () {
      final now = DateTime(2026, 10, 4, 18, 0);
      final s = ReadingSessionEditorService.buildManual(
        id: 's1',
        userBookId: 'ub1',
        startedAt: DateTime(2026, 10, 4, 12, 0),
        durationMinutes: 30,
        startPage: 0,
        createdAt: now,
      );
      expect(DateTime.parse(s.createdAt), now.toUtc());
    });

    test('id / userBookId / startPage / endPage / durationMinutes を保持', () {
      final s = ReadingSessionEditorService.buildManual(
        id: 'session-9',
        userBookId: 'ub-x',
        startedAt: DateTime(2026, 10, 4, 8, 0),
        durationMinutes: 60,
        startPage: 12,
        endPage: 30,
      );
      expect(s.id, 'session-9');
      expect(s.userBookId, 'ub-x');
      expect(s.startPage, 12);
      expect(s.endPage, 30);
      expect(s.durationMinutes, 60);
    });
  });

  group('durationFromTimes', () {
    test('45分差 → 45', () {
      final start = DateTime(2026, 10, 4, 10, 0);
      final end = DateTime(2026, 10, 4, 10, 45);
      expect(ReadingSessionEditorService.durationFromTimes(start, end), 45);
    });

    test('end が start 以前 → 0（負を返さない）', () {
      final start = DateTime(2026, 10, 4, 10, 0);
      final end = DateTime(2026, 10, 4, 9, 0);
      expect(ReadingSessionEditorService.durationFromTimes(start, end), 0);
    });

    test('同一時刻 → 0', () {
      final t = DateTime(2026, 10, 4, 10, 0);
      expect(ReadingSessionEditorService.durationFromTimes(t, t), 0);
    });

    test('90分差 → 90', () {
      final start = DateTime(2026, 10, 4, 22, 30);
      final end = DateTime(2026, 10, 5, 0, 0);
      expect(ReadingSessionEditorService.durationFromTimes(start, end), 90);
    });
  });

  group('formatDuration', () {
    test('45 → 45分', () {
      expect(ReadingSessionEditorService.formatDuration(45), '45分');
    });

    test('90 → 1時間30分', () {
      expect(ReadingSessionEditorService.formatDuration(90), '1時間30分');
    });

    test('120 → 2時間', () {
      expect(ReadingSessionEditorService.formatDuration(120), '2時間');
    });

    test('0 → 0分', () {
      expect(ReadingSessionEditorService.formatDuration(0), '0分');
    });

    test('60 → 1時間', () {
      expect(ReadingSessionEditorService.formatDuration(60), '1時間');
    });

    test('61 → 1時間1分', () {
      expect(ReadingSessionEditorService.formatDuration(61), '1時間1分');
    });
  });

  group('dateOnly', () {
    test('YYYY-MM-DD（ゼロ埋め）を返す', () {
      expect(
        ReadingSessionEditorService.dateOnly(DateTime(2026, 1, 4)),
        '2026-01-04',
      );
      expect(
        ReadingSessionEditorService.dateOnly(DateTime(2026, 12, 31)),
        '2026-12-31',
      );
    });
  });

  group('combineDateAndTime', () {
    test('正常な日付＋時刻でローカル DateTime を返す', () {
      final dt = ReadingSessionEditorService.combineDateAndTime(
          '2026-10-04', 13, 30);
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 10);
      expect(dt.day, 4);
      expect(dt.hour, 13);
      expect(dt.minute, 30);
      expect(dt.isUtc, isFalse, reason: 'ローカル DateTime であるべき');
    });

    test('存在しない日付（2月30日）→ null', () {
      expect(
        ReadingSessionEditorService.combineDateAndTime('2026-02-30', 10, 0),
        isNull,
      );
    });

    test('不正フォーマット → null', () {
      expect(
        ReadingSessionEditorService.combineDateAndTime('not-a-date', 10, 0),
        isNull,
      );
    });

    test('短い文字列 → null', () {
      expect(
        ReadingSessionEditorService.combineDateAndTime('2026/10/04', 10, 0),
        isNull,
      );
    });
  });
}