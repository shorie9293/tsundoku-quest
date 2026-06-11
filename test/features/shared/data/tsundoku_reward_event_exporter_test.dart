import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_reward_event_exporter.dart';

/// テスト用の一時JSONLファイルパスを生成
String _testFilePath(String suffix) =>
    '${Directory.systemTemp.path}/test_reward_events_$suffix.jsonl';

/// ファイルからJSONL行を読み取り、Mapのリストとして返す
Future<List<Map<String, dynamic>>> _readJsonlLines(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return [];
  final content = await file.readAsString();
  return content
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, dynamic>)
      .toList();
}

void main() {
  late String filePath;
  late TsundokuRewardEventExporter exporter;

  setUp(() {
    filePath = _testFilePath('default');
    exporter = TsundokuRewardEventExporter(
      filePath: filePath,
      userId: 'test-user-123',
    );
  });

  tearDown(() async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cleanup best-effort
    }
  });

  // ──────────────────────────────────────────
  //  Constructor & Configuration (5 tests)
  // ──────────────────────────────────────────

  group('constructor', () {
    test('should use default filePath when not specified', () {
      final e = TsundokuRewardEventExporter(userId: 'u1');
      expect(
        e.filePath,
        '/data/local/tmp/takamagahara_shared/tsundoku_reward_events.jsonl',
      );
    });

    test('should use custom filePath when specified', () {
      const customPath = '/tmp/custom_events.jsonl';
      final e = TsundokuRewardEventExporter(
        filePath: customPath,
        userId: 'u1',
      );
      expect(e.filePath, customPath);
    });

    test('should default userId to empty string', () {
      final e = TsundokuRewardEventExporter();
      expect(e.userId, '');
    });

    test('should set userId via constructor', () {
      expect(exporter.userId, 'test-user-123');
    });

    test('should update userId via setter', () {
      exporter.userId = 'new-user-456';
      expect(exporter.userId, 'new-user-456');
    });
  });

  // ──────────────────────────────────────────
  //  Event Type: level_up (2 tests)
  // ──────────────────────────────────────────

  group('exportLevelUp', () {
    test('should write level_up event with all fields', () async {
      await exporter.exportLevelUp(newLevel: 5, title: '見習い冒険者');

      final lines = await _readJsonlLines(filePath);
      expect(lines.length, 1);
      expect(lines[0]['event_type'], 'level_up');
      expect(lines[0]['user_id'], 'test-user-123');
      expect(lines[0]['new_level'], 5);
      expect(lines[0]['title'], '見習い冒険者');
      expect(lines[0]['event_id'], isA<String>());
      expect(lines[0]['timestamp'], isA<String>());
    });

    test('should accept custom timestamp', () async {
      const customTs = '2026-06-12T10:00:00.000Z';
      await exporter.exportLevelUp(
        newLevel: 10,
        title: '熟練冒険者',
        timestamp: customTs,
      );

      final lines = await _readJsonlLines(filePath);
      expect(lines[0]['timestamp'], customTs);
    });
  });

  // ──────────────────────────────────────────
  //  Event Type: xp_milestone (2 tests)
  // ──────────────────────────────────────────

  group('exportXpMilestone', () {
    test('should write xp_milestone event with milestone and total_xp',
        () async {
      await exporter.exportXpMilestone(milestone: 100, totalXp: 1500);

      final lines = await _readJsonlLines(filePath);
      expect(lines[0]['event_type'], 'xp_milestone');
      expect(lines[0]['milestone'], 100);
      expect(lines[0]['total_xp'], 1500);
    });

    test('should accept custom timestamp', () async {
      const customTs = '2026-06-12T11:00:00.000Z';
      await exporter.exportXpMilestone(
        milestone: 500,
        totalXp: 5000,
        timestamp: customTs,
      );

      final lines = await _readJsonlLines(filePath);
      expect(lines[0]['timestamp'], customTs);
    });
  });

  // ──────────────────────────────────────────
  //  Event Type: daily_mission_complete (1 test)
  // ──────────────────────────────────────────

  group('exportDailyMissionComplete', () {
    test('should write daily_mission_complete event', () async {
      await exporter.exportDailyMissionComplete(
        date: '2026-06-12',
        completedCount: 5,
        totalCount: 5,
      );

      final lines = await _readJsonlLines(filePath);
      expect(lines[0]['event_type'], 'daily_mission_complete');
      expect(lines[0]['date'], '2026-06-12');
      expect(lines[0]['completed_count'], 5);
      expect(lines[0]['total_count'], 5);
    });
  });

  // ──────────────────────────────────────────
  //  Event Type: trophy_written (1 test)
  // ──────────────────────────────────────────

  group('exportTrophyWritten', () {
    test('should write trophy_written event with learning count', () async {
      await exporter.exportTrophyWritten(
        trophyId: 'trophy-001',
        userBookId: 'ub-42',
        learningCount: 3,
      );

      final lines = await _readJsonlLines(filePath);
      expect(lines[0]['event_type'], 'trophy_written');
      expect(lines[0]['trophy_id'], 'trophy-001');
      expect(lines[0]['user_book_id'], 'ub-42');
      expect(lines[0]['learning_count'], 3);
    });
  });

  // ──────────────────────────────────────────
  //  Event Type: book_completed (2 tests)
  // ──────────────────────────────────────────

  group('exportBookCompleted', () {
    test('should write book_completed event with title', () async {
      await exporter.exportBookCompleted(
        bookId: 'book-001',
        bookTitle: '走れメロス',
      );

      final lines = await _readJsonlLines(filePath);
      expect(lines[0]['event_type'], 'book_completed');
      expect(lines[0]['book_id'], 'book-001');
      expect(lines[0]['book_title'], '走れメロス');
    });

    test('should handle null bookTitle gracefully', () async {
      await exporter.exportBookCompleted(
        bookId: 'book-002',
        bookTitle: null,
      );

      final lines = await _readJsonlLines(filePath);
      expect(lines[0]['event_type'], 'book_completed');
      expect(lines[0]['book_title'], '');
    });
  });

  // ──────────────────────────────────────────
  //  Event Type: pages_milestone (1 test)
  // ──────────────────────────────────────────

  group('exportPagesMilestone', () {
    test('should write pages_milestone event', () async {
      await exporter.exportPagesMilestone(
        milestone: 1000,
        totalPages: 5000,
      );

      final lines = await _readJsonlLines(filePath);
      expect(lines[0]['event_type'], 'pages_milestone');
      expect(lines[0]['milestone'], 1000);
      expect(lines[0]['total_pages'], 5000);
    });
  });

  // ──────────────────────────────────────────
  //  Event Type: reading_streak (1 test)
  // ──────────────────────────────────────────

  group('exportReadingStreak', () {
    test('should write reading_streak event', () async {
      await exporter.exportReadingStreak(streak: 30);

      final lines = await _readJsonlLines(filePath);
      expect(lines[0]['event_type'], 'reading_streak');
      expect(lines[0]['streak'], 30);
    });
  });

  // ──────────────────────────────────────────
  //  Idempotency & Multi-Event (3 tests)
  // ──────────────────────────────────────────

  group('idempotency and multi-event', () {
    test('should generate unique event_id for each event', () async {
      await exporter.exportLevelUp(newLevel: 1, title: 't');
      await exporter.exportLevelUp(newLevel: 2, title: 't');
      await exporter.exportXpMilestone(milestone: 100, totalXp: 100);

      final lines = await _readJsonlLines(filePath);
      expect(lines.length, 3);
      final ids = lines.map((l) => l['event_id']).toSet();
      expect(ids.length, 3); // All unique
    });

    test('should append events to the same file (JSONL format)', () async {
      await exporter.exportLevelUp(newLevel: 3, title: 'test');
      await exporter.exportBookCompleted(bookId: 'b1', bookTitle: 't');
      await exporter.exportReadingStreak(streak: 7);

      final lines = await _readJsonlLines(filePath);
      expect(lines.length, 3);
      for (final line in lines) {
        expect(line['event_id'], isA<String>());
        expect(line['timestamp'], isA<String>());
      }
    });

    test('should not corrupt file across multiple writes', () async {
      for (int i = 0; i < 10; i++) {
        await exporter.exportXpMilestone(
            milestone: i * 100, totalXp: i * 1000);
      }

      final lines = await _readJsonlLines(filePath);
      expect(lines.length, 10);
      expect(lines[0]['milestone'], 0);
      expect(lines[9]['milestone'], 900);
    });
  });

  // ──────────────────────────────────────────
  //  Error Resilience (3 tests)
  // ──────────────────────────────────────────

  group('error resilience', () {
    test('should not throw when writing to an unwritable path', () async {
      final badExporter = TsundokuRewardEventExporter(
        filePath: '/root/invalid/test_events.jsonl',
        userId: 'u1',
      );

      // Should complete without throwing (best-effort export)
      await expectLater(
        badExporter.exportLevelUp(newLevel: 1, title: 'test'),
        completes,
      );
    });

    test('should create parent directories automatically', () async {
      final nestedPath =
          '${Directory.systemTemp.path}/nested/deep/dir/events.jsonl';
      final nestedExporter = TsundokuRewardEventExporter(
        filePath: nestedPath,
        userId: 'u1',
      );

      await nestedExporter.exportLevelUp(newLevel: 1, title: 'test');

      final file = File(nestedPath);
      expect(await file.exists(), isTrue);

      // Cleanup
      try {
        await file.parent.parent.parent.parent.delete(recursive: true);
      } catch (_) {}
    });

    test('should produce valid JSON even with special characters', () async {
      await exporter.exportLevelUp(
        newLevel: 1,
        title: '特殊文字: "<テスト>" & \'ok\'',
      );

      final lines = await _readJsonlLines(filePath);
      expect(lines[0]['title'], '特殊文字: "<テスト>" & \'ok\'');
    });
  });

  // ──────────────────────────────────────────
  //  Timestamp (1 test)
  // ──────────────────────────────────────────

  group('timestamp format', () {
    test('should generate ISO 8601 UTC timestamps by default', () async {
      await exporter.exportLevelUp(newLevel: 1, title: 't');

      final lines = await _readJsonlLines(filePath);
      final ts = lines[0]['timestamp'] as String;

      // ISO 8601 format check: YYYY-MM-DDThh:mm:ss
      expect(ts, matches(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'));
      expect(ts, endsWith('Z')); // UTC marker
    });
  });
}
