import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_book_event_exporter.dart';

void main() {
  late Directory tempDir;
  late String filePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tsundoku_test_');
    filePath = '${tempDir.path}/tsundoku_book_events.json';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('TsundokuBookEventExporter', () {
    test('constructor uses default filePath', () {
      const exporter = TsundokuBookEventExporter();
      expect(exporter.filePath,
          '/data/local/tmp/takamagahara_shared/tsundoku_book_events.json');
    });

    test('exportBookAdded creates JSON file with correct fields', () async {
      final exporter = TsundokuBookEventExporter(filePath: filePath);
      await exporter.exportBookAdded(
        bookTitle: 'Dartプログラミング入門',
        bookAuthor: '山田太郎',
        timestamp: '2026-05-21T21:28:00Z',
      );

      expect(File(filePath).existsSync(), isTrue);

      final content = await File(filePath).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      expect(json['event'], 'book_added');
      expect(json['bookTitle'], 'Dartプログラミング入門');
      expect(json['bookAuthor'], '山田太郎');
      expect(json['timestamp'], '2026-05-21T21:28:00Z');
    });

    test('exportBookAdded handles null bookAuthor (defaults to empty string)',
        () async {
      final exporter = TsundokuBookEventExporter(filePath: filePath);
      await exporter.exportBookAdded(
        bookTitle: 'テスト本',
        timestamp: '2026-05-21T21:30:00Z',
      );

      expect(File(filePath).existsSync(), isTrue);

      final content = await File(filePath).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      expect(json['bookAuthor'], '');
    });

    test('exportBookAdded creates parent directory if not exists', () async {
      // Use a deeply nested path where the directory doesn't exist
      final nestedPath = '${tempDir.path}/deeply/nested/tsundoku_book_events.json';
      final exporter = TsundokuBookEventExporter(filePath: nestedPath);

      // Directory should not exist before export
      expect(Directory('${tempDir.path}/deeply/nested').existsSync(), isFalse);

      await exporter.exportBookAdded(
        bookTitle: 'Nested Book',
        timestamp: '2026-05-21T21:32:00Z',
      );

      // Directory and file should exist after export
      expect(Directory('${tempDir.path}/deeply/nested').existsSync(), isTrue);
      expect(File(nestedPath).existsSync(), isTrue);

      final content = await File(nestedPath).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json['bookTitle'], 'Nested Book');
    });
  });
}
