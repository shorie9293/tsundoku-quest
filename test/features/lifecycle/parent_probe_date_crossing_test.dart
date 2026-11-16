/// 親探針: 本番配線（ProviderScope + AppLifecycleRefresher）を通した日付跨ぎ。
///
/// 子の試練は `ProviderContainer` を直接組み、`invalidateDateDependentProviders`
/// を手で呼ぶ。それでは「起動配線（main.dart の ProviderScope → AppLifecycleRefresher
/// → onRollover → invalidate）」が本当に繋がっているかを撃てない。
/// 本探針は main.dart と同じ構造（ProviderScope の中で AppLifecycleRefresher が
/// ツリーを包む）を組み、ライフサイクル通知だけで habit の再評価が起きるかを見る。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_provider.dart';
import 'package:tsundoku_quest/features/lifecycle/domain/day_rollover_detector.dart';
import 'package:tsundoku_quest/features/lifecycle/presentation/app_lifecycle_refresher.dart';
import 'package:tsundoku_quest/main.dart';

class _Counter {
  int habit = 0;
}

Future<void> _resumed(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// main.dart と同じ構造で「本番の無効化関数」を onRollover に渡す。
Future<void> _pumpProductionLikeTree(
  WidgetTester tester, {
  required ProviderContainer container,
  required DayRolloverDetector detector,
  required List<String> log,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Builder(
        builder: (context) => AppLifecycleRefresher(
          detector: detector,
          now: () => DateTime(2026, 11, 17, 9, 0),
          onRollover: () async {
            log.add('rollover');
            final c = ProviderScope.containerOf(context, listen: false);
            invalidateDateDependentProviders(c);
          },
          child: const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('P1 本番配線: 日付跨ぎの resumed で readingHabitSessionsProvider が再評価される',
      (tester) async {
    final counter = _Counter();
    final container = ProviderContainer(
      overrides: [
        readingHabitSessionsProvider.overrideWith((ref) async {
          counter.habit++;
          return const <ReadingSession>[];
        }),
      ],
    );
    addTearDown(container.dispose);

    // 画面が watch している状態を再現（購読が無いと invalidate しても再buildされない）
    final sub = container.listen(readingHabitSessionsProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(readingHabitSessionsProvider.future);
    expect(counter.habit, 1);

    final detector = DayRolloverDetector(lastSeen: DateTime(2026, 11, 16, 22, 0));
    final log = <String>[];
    await _pumpProductionLikeTree(tester,
        container: container, detector: detector, log: log);

    // 翌朝の復帰（detector は 11/16 22:00 を最終観測として保持）
    await _resumed(tester);

    expect(log, ['rollover'], reason: 'onRollover が1回だけ走る');
    await container.read(readingHabitSessionsProvider.future);
    expect(counter.habit, 2, reason: 'invalidate で再評価される（1→2）');
  });

  testWidgets('P2 同日復帰では onRollover が走らず再評価もされない（過剰無効化の抑止）',
      (tester) async {
    final counter = _Counter();
    final container = ProviderContainer(
      overrides: [
        readingHabitSessionsProvider.overrideWith((ref) async {
          counter.habit++;
          return const <ReadingSession>[];
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(readingHabitSessionsProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(readingHabitSessionsProvider.future);

    final detector = DayRolloverDetector(lastSeen: DateTime(2026, 11, 17, 8, 0));
    final log = <String>[];
    await _pumpProductionLikeTree(tester,
        container: container, detector: detector, log: log);
    await _resumed(tester);

    expect(log, isEmpty);
    expect(counter.habit, 1);
  });

  test('P3 無効化は1回につき1再build（二重invalidateを作らない）', () async {
    // Riverpod の scheduler は Timer を使うため、widget を立てない素の test で
    // 撃ち、Duration.zero の待機で scheduler を流す。
    final counter = _Counter();
    final container = ProviderContainer(
      overrides: [
        readingHabitSessionsProvider.overrideWith((ref) async {
          counter.habit++;
          return const <ReadingSession>[];
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(readingHabitSessionsProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(readingHabitSessionsProvider.future);
    expect(counter.habit, 1);

    invalidateDateDependentProviders(container);
    await Future<void>.delayed(Duration.zero);
    await container.read(readingHabitSessionsProvider.future);
    expect(counter.habit, 2, reason: '一覧のループで2回invalidateされていない');

    invalidateDateDependentProviders(container);
    await Future<void>.delayed(Duration.zero);
    await container.read(readingHabitSessionsProvider.future);
    expect(counter.habit, 3);
  });

  testWidgets('P4 onRollover が例外を投げてもアプリは継続し、次回の跨ぎで回復する',
      (tester) async {
    final counter = _Counter();
    final container = ProviderContainer(
      overrides: [
        readingHabitSessionsProvider.overrideWith((ref) async {
          counter.habit++;
          return const <ReadingSession>[];
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(readingHabitSessionsProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(readingHabitSessionsProvider.future);

    final detector = DayRolloverDetector(lastSeen: DateTime(2026, 11, 16, 22, 0));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Builder(
          builder: (context) => AppLifecycleRefresher(
            detector: detector,
            now: () => DateTime(2026, 11, 17, 9, 0),
            onRollover: () async => throw StateError('boom'),
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await _resumed(tester);
    expect(tester.takeException(), isNull, reason: '例外は握られゾーンへ漏れない');

    // 再入防止フラグが finally で戻っていること（次回の跨ぎで再度走れる）
    final log = <String>[];
    await _pumpProductionLikeTree(tester,
        container: container, detector: detector, log: log);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Builder(
          builder: (context) => AppLifecycleRefresher(
            detector: detector,
            now: () => DateTime(2026, 11, 18, 9, 0),
            onRollover: () async {
              log.add('rollover2');
              invalidateDateDependentProviders(
                  ProviderScope.containerOf(context, listen: false));
            },
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await _resumed(tester);
    expect(log, contains('rollover2'));
    await container.read(readingHabitSessionsProvider.future);
    expect(counter.habit, 2);
  });
}
