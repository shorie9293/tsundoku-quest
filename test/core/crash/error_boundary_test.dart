import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/crash/crash_log_repository.dart';
import 'package:tsundoku_quest/core/crash/crash_log_service.dart';
import 'package:tsundoku_quest/core/crash/error_boundary.dart';

/// [failing] が true の間は build で例外を投げる子。
class _FlakyChild extends StatelessWidget {
  const _FlakyChild({required this.failing});

  final ValueNotifier<bool> failing;

  @override
  Widget build(BuildContext context) {
    if (failing.value) {
      throw StateError('build failure');
    }
    return const Text('RECOVERED_CONTENT');
  }
}

void main() {
  testWidgets('build 中の例外を捕捉し復帰UIを表示する', (tester) async {
    final failing = ValueNotifier<bool>(true);
    addTearDown(failing.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(
          child: _FlakyChild(failing: failing),
          logger: CrashLogger(repository: InMemoryCrashLogRepository()),
        ),
      ),
    );

    expect(tester.takeException(), isNotNull);
    expect(find.byKey(CrashKeys.errorBoundaryFallback), findsOneWidget);
    expect(find.text('表示中に問題が発生しました'), findsOneWidget);
    expect(find.byKey(CrashKeys.errorBoundaryReload), findsOneWidget);
    expect(find.text('RECOVERED_CONTENT'), findsNothing);
  });

  testWidgets('再読み込みで child を作り直す', (tester) async {
    final failing = ValueNotifier<bool>(true);
    addTearDown(failing.dispose);
    var reloadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(
          child: _FlakyChild(failing: failing),
          logger: CrashLogger(repository: InMemoryCrashLogRepository()),
          onReload: () {
            reloadCount++;
            failing.value = false;
          },
        ),
      ),
    );
    expect(tester.takeException(), isNotNull);

    await tester.tap(find.byKey(CrashKeys.errorBoundaryReload));
    await tester.pump();

    expect(reloadCount, 1);
    expect(find.byKey(CrashKeys.errorBoundaryFallback), findsNothing);
    expect(find.text('RECOVERED_CONTENT'), findsOneWidget);
  });

  testWidgets('正常時は child をそのまま表示する', (tester) async {
    final failing = ValueNotifier<bool>(false);
    addTearDown(failing.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(
          child: _FlakyChild(failing: failing),
          logger: CrashLogger(repository: InMemoryCrashLogRepository()),
        ),
      ),
    );

    expect(find.text('RECOVERED_CONTENT'), findsOneWidget);
    expect(find.byKey(CrashKeys.errorBoundaryFallback), findsNothing);
  });

  testWidgets('dispose で元の ErrorWidget.builder に戻す', (tester) async {
    final original = ErrorWidget.builder;

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(
          child: const Text('ok'),
          logger: CrashLogger(repository: InMemoryCrashLogRepository()),
        ),
      ),
    );
    expect(identical(ErrorWidget.builder, original), isFalse);

    await tester.pumpWidget(const MaterialApp(home: Text('replaced')));
    expect(identical(ErrorWidget.builder, original), isTrue);
  });

  testWidgets('build 例外を端末内ログへ記録する', (tester) async {
    final repo = InMemoryCrashLogRepository();
    final failing = ValueNotifier<bool>(true);
    addTearDown(failing.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(
          child: _FlakyChild(failing: failing),
          logger: CrashLogger(repository: repo),
        ),
      ),
    );
    expect(tester.takeException(), isNotNull);
    // unawaited の記録をマイクロタスクとして流す
    await tester.pump();

    final entries = await repo.loadAll();
    expect(entries, hasLength(1));
    expect(entries.single.kind, 'widget');
    expect(entries.single.message, contains('build failure'));
  });
}
