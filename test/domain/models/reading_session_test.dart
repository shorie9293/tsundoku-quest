import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';

void main() {
  group('ReadingSession', () {
    const sampleSession = ReadingSession(
      id: 'session-1',
      userBookId: 'ub-1',
      startedAt: '2025-05-21T10:00:00Z',
      endedAt: '2025-05-21T11:30:00Z',
      startPage: 1,
      endPage: 50,
      durationMinutes: 90,
      createdAt: '2025-05-21T10:00:00Z',
    );

    test('constructorTest: 全必須フィールドが正しく設定される', () {
      expect(sampleSession.id, 'session-1');
      expect(sampleSession.userBookId, 'ub-1');
      expect(sampleSession.startedAt, '2025-05-21T10:00:00Z');
      expect(sampleSession.endedAt, '2025-05-21T11:30:00Z');
      expect(sampleSession.startPage, 1);
      expect(sampleSession.endPage, 50);
      expect(sampleSession.durationMinutes, 90);
      expect(sampleSession.createdAt, '2025-05-21T10:00:00Z');
    });

    test('optionalFieldsNullTest: endedAt/endPage/durationMinutes がnullでも正しく構築', () {
      const session = ReadingSession(
        id: 'session-2',
        userBookId: 'ub-2',
        startedAt: '2025-05-21T12:00:00Z',
        startPage: 10,
        createdAt: '2025-05-21T12:00:00Z',
      );

      expect(session.id, 'session-2');
      expect(session.userBookId, 'ub-2');
      expect(session.startedAt, '2025-05-21T12:00:00Z');
      expect(session.startPage, 10);
      expect(session.createdAt, '2025-05-21T12:00:00Z');
      expect(session.endedAt, isNull);
      expect(session.endPage, isNull);
      expect(session.durationMinutes, isNull);
    });

    group('fromJson', () {
      test('fromJsonTest: camelCaseキーから正しくデシリアライズ', () {
        final json = {
          'id': 'session-3',
          'userBookId': 'ub-3',
          'startedAt': '2025-05-21T08:00:00Z',
          'endedAt': '2025-05-21T09:00:00Z',
          'startPage': 5,
          'endPage': 30,
          'durationMinutes': 60,
          'createdAt': '2025-05-21T08:00:00Z',
        };

        final session = ReadingSession.fromJson(json);

        expect(session.id, 'session-3');
        expect(session.userBookId, 'ub-3');
        expect(session.startedAt, '2025-05-21T08:00:00Z');
        expect(session.endedAt, '2025-05-21T09:00:00Z');
        expect(session.startPage, 5);
        expect(session.endPage, 30);
        expect(session.durationMinutes, 60);
        expect(session.createdAt, '2025-05-21T08:00:00Z');
      });

      test('fromJsonTest: オプショナルフィールドがnullでも正しくデシリアライズ', () {
        final json = {
          'id': 'session-4',
          'userBookId': 'ub-4',
          'startedAt': '2025-05-21T08:00:00Z',
          'startPage': 5,
          'createdAt': '2025-05-21T08:00:00Z',
        };

        final session = ReadingSession.fromJson(json);

        expect(session.id, 'session-4');
        expect(session.endedAt, isNull);
        expect(session.endPage, isNull);
        expect(session.durationMinutes, isNull);
      });
    });

    group('toJson', () {
      test('toJsonTest: 正しいcamelCaseキーのMapを返す', () {
        final json = sampleSession.toJson();

        expect(json['id'], 'session-1');
        expect(json['userBookId'], 'ub-1');
        expect(json['startedAt'], '2025-05-21T10:00:00Z');
        expect(json['endedAt'], '2025-05-21T11:30:00Z');
        expect(json['startPage'], 1);
        expect(json['endPage'], 50);
        expect(json['durationMinutes'], 90);
        expect(json['createdAt'], '2025-05-21T10:00:00Z');
      });

      test('toJsonTest: オプショナルフィールドがnullの場合も正しくMap化', () {
        const session = ReadingSession(
          id: 'session-5',
          userBookId: 'ub-5',
          startedAt: '2025-05-21T08:00:00Z',
          startPage: 1,
          createdAt: '2025-05-21T08:00:00Z',
        );

        final json = session.toJson();

        expect(json['id'], 'session-5');
        expect(json['endedAt'], isNull);
        expect(json['endPage'], isNull);
        expect(json['durationMinutes'], isNull);
      });
    });

    group('fromSupabase', () {
      test('fromSupabaseTest: snake_caseキーから正しくデシリアライズ', () {
        final json = {
          'id': 'session-10',
          'user_book_id': 'ub-10',
          'started_at': '2025-05-21T14:00:00Z',
          'ended_at': '2025-05-21T15:00:00Z',
          'start_page': 20,
          'end_page': 80,
          'duration_minutes': 60,
          'created_at': '2025-05-21T14:00:00Z',
        };

        final session = ReadingSession.fromSupabase(json);

        expect(session.id, 'session-10');
        expect(session.userBookId, 'ub-10');
        expect(session.startedAt, '2025-05-21T14:00:00Z');
        expect(session.endedAt, '2025-05-21T15:00:00Z');
        expect(session.startPage, 20);
        expect(session.endPage, 80);
        expect(session.durationMinutes, 60);
        expect(session.createdAt, '2025-05-21T14:00:00Z');
      });

      test('fromSupabaseTest: オプショナルフィールドがnullでも正しくデシリアライズ', () {
        final json = {
          'id': 'session-11',
          'user_book_id': 'ub-11',
          'started_at': '2025-05-21T14:00:00Z',
          'start_page': 20,
          'created_at': '2025-05-21T14:00:00Z',
        };

        final session = ReadingSession.fromSupabase(json);

        expect(session.id, 'session-11');
        expect(session.endedAt, isNull);
        expect(session.endPage, isNull);
        expect(session.durationMinutes, isNull);
      });
    });

    group('toSupabase', () {
      test('toSupabaseTest: 正しいsnake_caseキーのMapを返す', () {
        final json = sampleSession.toSupabase();

        expect(json['id'], 'session-1');
        expect(json['user_book_id'], 'ub-1');
        expect(json['started_at'], '2025-05-21T10:00:00Z');
        expect(json['ended_at'], '2025-05-21T11:30:00Z');
        expect(json['start_page'], 1);
        expect(json['end_page'], 50);
        expect(json['duration_minutes'], 90);
        expect(json['created_at'], '2025-05-21T10:00:00Z');
      });

      test('toSupabaseTest: オプショナルフィールドがnullの場合も正しくMap化', () {
        const session = ReadingSession(
          id: 'session-12',
          userBookId: 'ub-12',
          startedAt: '2025-05-21T08:00:00Z',
          startPage: 1,
          createdAt: '2025-05-21T08:00:00Z',
        );

        final json = session.toSupabase();

        expect(json['id'], 'session-12');
        expect(json['ended_at'], isNull);
        expect(json['end_page'], isNull);
        expect(json['duration_minutes'], isNull);
      });
    });

    group('roundTrip', () {
      test('roundTripTest: toJson→fromJson で元の値が復元される', () {
        const original = ReadingSession(
          id: 'rt-1',
          userBookId: 'ub-rt',
          startedAt: '2025-06-01T00:00:00Z',
          endedAt: '2025-06-01T02:00:00Z',
          startPage: 10,
          endPage: 100,
          durationMinutes: 120,
          createdAt: '2025-06-01T00:00:00Z',
        );

        final json = original.toJson();
        final restored = ReadingSession.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.userBookId, original.userBookId);
        expect(restored.startedAt, original.startedAt);
        expect(restored.endedAt, original.endedAt);
        expect(restored.startPage, original.startPage);
        expect(restored.endPage, original.endPage);
        expect(restored.durationMinutes, original.durationMinutes);
        expect(restored.createdAt, original.createdAt);
      });

      test('roundTripTest: オプショナルフィールドがnullでも復元される', () {
        const original = ReadingSession(
          id: 'rt-2',
          userBookId: 'ub-rt2',
          startedAt: '2025-06-01T00:00:00Z',
          startPage: 10,
          createdAt: '2025-06-01T00:00:00Z',
        );

        final json = original.toJson();
        final restored = ReadingSession.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.endedAt, isNull);
        expect(restored.endPage, isNull);
        expect(restored.durationMinutes, isNull);
      });

      test('supabaseRoundTripTest: toSupabase→fromSupabase で元の値が復元される', () {
        const original = ReadingSession(
          id: 'srt-1',
          userBookId: 'ub-srt',
          startedAt: '2025-06-01T00:00:00Z',
          endedAt: '2025-06-01T02:00:00Z',
          startPage: 10,
          endPage: 100,
          durationMinutes: 120,
          createdAt: '2025-06-01T00:00:00Z',
        );

        final json = original.toSupabase();
        final restored = ReadingSession.fromSupabase(json);

        expect(restored.id, original.id);
        expect(restored.userBookId, original.userBookId);
        expect(restored.startedAt, original.startedAt);
        expect(restored.endedAt, original.endedAt);
        expect(restored.startPage, original.startPage);
        expect(restored.endPage, original.endPage);
        expect(restored.durationMinutes, original.durationMinutes);
        expect(restored.createdAt, original.createdAt);
      });

      test('supabaseRoundTripTest: オプショナルフィールドがnullでも復元される', () {
        const original = ReadingSession(
          id: 'srt-2',
          userBookId: 'ub-srt2',
          startedAt: '2025-06-01T00:00:00Z',
          startPage: 10,
          createdAt: '2025-06-01T00:00:00Z',
        );

        final json = original.toSupabase();
        final restored = ReadingSession.fromSupabase(json);

        expect(restored.id, original.id);
        expect(restored.endedAt, isNull);
        expect(restored.endPage, isNull);
        expect(restored.durationMinutes, isNull);
      });
    });
  });
}
