import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'crash_log_service.dart';

/// 未捕捉例外の受け皿を、既存ハンドラを壊さずに設置する。
///
/// - [FlutterError.onError] … 既存ハンドラを保存し「既存呼出＋[CrashLogger.record]」へ差し替える。
/// - [PlatformDispatcher.onError] … 既存ハンドラへ合流した上で記録し `false` を返す。
///
/// 何度呼んでも二重ラップしない（既に設置済みなら何もしない）。
/// 戻り値は「新たに設置したか」。
bool installCrashGuard({CrashLogger? logger}) {
  if (_installed) return false;
  _installed = true;

  final crashLogger = logger ?? CrashLogger();

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      crashLogger.record(details.exception, details.stack, kind: 'flutter');
    } catch (_) {
      // 記録失敗は握る
    }
    if (previousOnError != null) {
      previousOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    try {
      crashLogger.record(error, stack, kind: 'platform');
    } catch (_) {
      // 記録失敗は握る
    }
    previousPlatformOnError?.call(error, stack);
    // 既存挙動（握りつぶしてアプリ継続）を保つ
    return false;
  };

  if (kDebugMode) {
    debugPrint('🛡️ CrashGuard 設置完了（FlutterError / PlatformDispatcher）');
  }
  return true;
}

bool _installed = false;

/// 試練用: 設置状態を戻す。
@visibleForTesting
void resetCrashGuardForTest({
  FlutterExceptionHandler? flutterOnError,
  ErrorCallback? platformOnError,
}) {
  _installed = false;
  FlutterError.onError = flutterOnError;
  PlatformDispatcher.instance.onError = platformOnError;
}
