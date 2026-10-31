import 'dart:convert';

/// 端末内クラッシュログの1件分。
///
/// 純粋モデル（依存なし）。保存サイズを抑えるため、
/// [message] は先頭 [maxMessageLength] 文字、[stackTop] は先頭
/// [maxStackLines] 行に切り詰める。値等価で比較できる。
class CrashLogEntry {
  const CrashLogEntry({
    required this.timestamp,
    required this.kind,
    required this.message,
    this.stackTop = '',
  });

  /// 例外情報から1件を組み立てる（切り詰め済み）。
  factory CrashLogEntry.fromError(
    Object error,
    StackTrace? stack, {
    String kind = 'error',
    DateTime? timestamp,
  }) {
    return CrashLogEntry(
      timestamp: timestamp ?? DateTime.now(),
      kind: kind,
      message: truncateMessage(error.toString()),
      stackTop: truncateStack(stack?.toString() ?? ''),
    );
  }

  /// message の最大文字数。
  static const int maxMessageLength = 200;

  /// stack の最大行数（= 先頭フレーム数）。
  static const int maxStackLines = 10;

  final DateTime timestamp;
  final String kind;
  final String message;
  final String stackTop;

  /// 先頭 [maxMessageLength] 文字に切り詰める。
  static String truncateMessage(String message) {
    if (message.length <= maxMessageLength) return message;
    return message.substring(0, maxMessageLength);
  }

  /// 空行を除いた先頭 [maxStackLines] 行に切り詰める。
  static String truncateStack(String stack) {
    if (stack.isEmpty) return '';
    final lines = stack
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(maxStackLines);
    return lines.join('\n');
  }

  Map<String, dynamic> toJson() => {
        'ts': timestamp.toIso8601String(),
        'kind': kind,
        'message': message,
        'stackTop': stackTop,
      };

  /// 破損した JSON からは null を返す（例外は投げない）。
  static CrashLogEntry? fromJson(Object? json) {
    try {
      if (json is! Map) return null;
      final ts = json['ts'];
      final kind = json['kind'];
      final message = json['message'];
      if (ts is! String || kind is! String || message is! String) return null;
      final timestamp = DateTime.tryParse(ts);
      if (timestamp == null) return null;
      final stackTop = json['stackTop'];
      return CrashLogEntry(
        timestamp: timestamp,
        kind: kind,
        message: message,
        stackTop: stackTop is String ? stackTop : '',
      );
    } catch (_) {
      return null;
    }
  }

  static CrashLogEntry? tryDecode(String line) {
    try {
      return fromJson(jsonDecode(line));
    } catch (_) {
      return null;
    }
  }

  String toJsonLine() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrashLogEntry &&
          other.timestamp == timestamp &&
          other.kind == kind &&
          other.message == message &&
          other.stackTop == stackTop;

  @override
  int get hashCode => Object.hash(timestamp, kind, message, stackTop);

  @override
  String toString() => 'CrashLogEntry($timestamp, $kind, $message)';
}
