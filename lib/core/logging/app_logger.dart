import 'package:flutter/foundation.dart';

/// ログ出力先。試練では捕捉用リスト、本番では [debugPrint]。
typedef LogSink = void Function(String message);

/// 本番ログ垂れ流しを是正するための薄いログ窓口。
///
/// 方針:
/// - [debug] / [info] … 開発時のみ（`isDebug == false` なら**何も出力しない**）
/// - [warn] / [error] … 常時出力（障害調査を潰さない）
/// - どのレベルも**例外を投げない**（ログがアプリを壊してはならない）
///
/// 出力は `[LEVEL] message` 形式で、レベルを機械的に判別できる。
/// 既定の [isDebug] は `kDebugMode`、既定の sink は `debugPrint`。
class AppLogger {
  AppLogger({bool? isDebug, LogSink? sink})
      : isDebug = isDebug ?? kDebugMode,
        _sink = sink ?? debugPrint;

  /// true のときのみ [debug] / [info] を出力する。
  final bool isDebug;

  final LogSink _sink;

  /// 開発時のみ流れる詳細ログ（release では無出力）。
  void debug(String message) {
    if (!isDebug) return;
    _sink('[DEBUG] $message');
  }

  /// 開発時のみ流れる情報ログ（release では無出力）。
  void info(String message) {
    if (!isDebug) return;
    _sink('[INFO] $message');
  }

  /// 想定内の失敗。release でも出力する。
  void warn(String message, [Object? error, StackTrace? stack]) {
    _sink(_format('WARN', message, error, stack));
  }

  /// 想定外の失敗。release でも出力する。**throw しない**。
  void error(String message, [Object? error, StackTrace? stack]) {
    _sink(_format('ERROR', message, error, stack));
  }

  String _format(
    String level,
    String message,
    Object? error,
    StackTrace? stack,
  ) {
    final buffer = StringBuffer('[$level] $message');
    if (error != null) {
      buffer.write(' | error: $error');
    }
    if (stack != null) {
      buffer.write('\n$stack');
    }
    return buffer.toString();
  }
}

/// アプリ全体で共有する既定インスタンス。
final appLog = AppLogger();
