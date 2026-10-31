import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/crash/crash_guard.dart';
import 'package:tsundoku_quest/core/crash/crash_log_repository.dart';
import 'package:tsundoku_quest/core/crash/crash_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    resetCrashGuardForTest();
  });

  test('既存 FlutterError.onError を呼んだ上で記録する', () async {
    final repo = InMemoryCrashLogRepository();
    var previousCalls = 0;
    FlutterError.onError = (details) {
      previousCalls++;
    };

    expect(installCrashGuard(logger: CrashLogger(repository: repo)), isTrue);

    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('boom')),
    );
    await Future<void>.delayed(Duration.zero);

    expect(previousCalls, 1, reason: '既存ハンドラを壊さない');
    final entries = await repo.loadAll();
    expect(entries, hasLength(1));
    expect(entries.single.kind, 'flutter');
  });

  test('二重設置しない', () {
    FlutterError.onError = (details) {};
    final repo = InMemoryCrashLogRepository();
    expect(installCrashGuard(logger: CrashLogger(repository: repo)), isTrue);
    expect(installCrashGuard(logger: CrashLogger(repository: repo)), isFalse);
  });

  test('PlatformDispatcher.onError は既存へ合流し false を返す', () async {
    final repo = InMemoryCrashLogRepository();
    var previousCalls = 0;
    PlatformDispatcher.instance.onError = (error, stack) {
      previousCalls++;
      return true;
    };

    installCrashGuard(logger: CrashLogger(repository: repo));

    final result = PlatformDispatcher.instance.onError!(
        StateError('depth'), StackTrace.current);
    await Future<void>.delayed(Duration.zero);

    expect(previousCalls, 1);
    expect(result, isFalse, reason: '既存挙動（握りつぶして継続）を保つ');
    final entries = await repo.loadAll();
    expect(entries.single.kind, 'platform');
  });
}
