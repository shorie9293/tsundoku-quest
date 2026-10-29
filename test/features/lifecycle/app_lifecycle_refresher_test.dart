import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/lifecycle/domain/day_rollover_detector.dart';
import 'package:tsundoku_quest/features/lifecycle/presentation/app_lifecycle_refresher.dart';

/// 実機同様の遷移を挟んで resumed を発火する。
///
/// `handleAppLifecycleStateChanged` は同一状態の連続通知を無視し得るため、
/// inactive → paused → resumed を明示的に踏む。
Future<void> _sendResumed(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

void main() {
  testWidgets('前面復帰で日付が変わっていれば onRollover が1回だけ呼ばれる', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 23, 50));

    await tester.pumpWidget(
      MaterialApp(
        home: AppLifecycleRefresher(
          detector: detector,
          now: () => DateTime(2026, 10, 30, 0, 5),
          onRollover: () async {
            calls++;
          },
          child: const Text('本体'),
        ),
      ),
    );

    expect(find.text('本体'), findsOneWidget);
    expect(calls, 0, reason: '初期化時点では走らない');

    await _sendResumed(tester);

    expect(calls, 1);

    // 同日中の再復帰では再実行しない
    await _sendResumed(tester);
    expect(calls, 1);
  });

  testWidgets('paused では onRollover を呼ばない', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 23, 50));

    await tester.pumpWidget(
      MaterialApp(
        home: AppLifecycleRefresher(
          detector: detector,
          now: () => DateTime(2026, 10, 30, 0, 5),
          onRollover: () async {
            calls++;
          },
          child: const Text('本体'),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(calls, 0);
  });

  testWidgets('日付が変わっていない復帰では onRollover を呼ばない', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 9, 0));

    await tester.pumpWidget(
      MaterialApp(
        home: AppLifecycleRefresher(
          detector: detector,
          now: () => DateTime(2026, 10, 29, 18, 30),
          onRollover: () async {
            calls++;
          },
          child: const Text('本体'),
        ),
      ),
    );

    await _sendResumed(tester);

    expect(calls, 0);
  });

  testWidgets('onRollover が throw しても widget は落ちず子は表示され続ける', (tester) async {
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 23, 50));

    await tester.pumpWidget(
      MaterialApp(
        home: AppLifecycleRefresher(
          detector: detector,
          now: () => DateTime(2026, 10, 30, 0, 5),
          onRollover: () async {
            throw StateError('再計算の失敗');
          },
          child: const Text('本体'),
        ),
      ),
    );

    await _sendResumed(tester);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('本体'), findsOneWidget);
  });

  testWidgets('時計巻き戻し（clockWentBack）では onRollover を呼ばない', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 30, 0, 5));

    await tester.pumpWidget(
      MaterialApp(
        home: AppLifecycleRefresher(
          detector: detector,
          now: () => DateTime(2026, 10, 29, 23, 0),
          onRollover: () async {
            calls++;
          },
          child: const Text('本体'),
        ),
      ),
    );

    await _sendResumed(tester);

    expect(calls, 0);
  });

  testWidgets('dispose 後は復帰通知を受けない', (tester) async {
    var calls = 0;
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 10, 29, 23, 50));

    await tester.pumpWidget(
      MaterialApp(
        home: AppLifecycleRefresher(
          detector: detector,
          now: () => DateTime(2026, 10, 30, 0, 5),
          onRollover: () async {
            calls++;
          },
          child: const Text('本体'),
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: Text('別画面')));
    await _sendResumed(tester);

    expect(calls, 0);
  });
}
