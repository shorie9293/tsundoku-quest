import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/crash/crash_log_entry.dart';

void main() {
  group('CrashLogEntry', () {
    test('message は先頭200文字に切り詰める', () {
      final long = 'あ' * 500;
      final entry = CrashLogEntry.fromError(
        Exception(long),
        null,
        timestamp: DateTime(2026, 11, 1, 9, 0),
      );
      // 'Exception: ' + 500文字 → 200文字へ
      expect(entry.message.length, CrashLogEntry.maxMessageLength);
      expect(entry.message, startsWith('Exception: '));
    });

    test('stack は先頭10フレーム（10行）に切り詰める', () {
      final stack = List.generate(30, (i) => '#$i  frame_$i').join('\n');
      final entry = CrashLogEntry.fromError(
        StateError('boom'),
        StackTrace.fromString(stack),
      );
      expect(entry.stackTop.split('\n').length, CrashLogEntry.maxStackLines);
      expect(entry.stackTop.split('\n').first, '#0  frame_0');
      expect(entry.stackTop.split('\n').last, '#9  frame_9');
    });

    test('toJson / fromJson で往復し、値等価になる', () {
      final entry = CrashLogEntry(
        timestamp: DateTime.utc(2026, 11, 1, 0, 30),
        kind: 'zone',
        message: 'boom',
        stackTop: '#0 a',
      );
      final restored = CrashLogEntry.fromJson(entry.toJson());
      expect(restored, entry);
      expect(restored!.hashCode, entry.hashCode);
      expect(restored.timestamp.isUtc, isTrue);
    });

    test('破損した JSON からは null を返す（例外を投げない）', () {
      expect(CrashLogEntry.fromJson(null), isNull);
      expect(CrashLogEntry.fromJson('not a map'), isNull);
      expect(CrashLogEntry.fromJson({'kind': 'x'}), isNull);
      expect(
        CrashLogEntry.fromJson(
            {'ts': 'not-a-date', 'kind': 'x', 'message': 'm'}),
        isNull,
      );
      expect(CrashLogEntry.tryDecode('{invalid json'), isNull);
    });

    test('stackTop 省略時は空文字', () {
      final entry = CrashLogEntry(
        timestamp: DateTime(2026),
        kind: 'error',
        message: 'm',
      );
      expect(entry.stackTop, '');
      expect(CrashLogEntry.fromJson(entry.toJson()), entry);
    });
  });
}
