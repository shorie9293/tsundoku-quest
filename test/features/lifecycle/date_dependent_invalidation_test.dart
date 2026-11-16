/// 日付跨ぎ（前面復帰）で落とすべき Provider の網羅性を撃つ試練。
///
/// 背景（禍津）: [readingHabitSessionsProvider] が
/// [invalidateDateDependentProviders] の無効化リストから漏れていた。
/// 同 Provider は autoDispose でない FutureProvider のため、invalidate しない
/// 限り一度読んだキャッシュがアプリ再起動まで固定される。結果、日付が変わって
/// 復帰してもヒートマップ・日次目標・バッジが前日の集計を表示し続けた。
///
/// 時刻は必ずローカル暦（`DateTime(...)`）で組み立てる。`DateTime.utc` を混ぜると
/// TZ=UTC と TZ=Asia/Tokyo で判定が割れる。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/bookshelf/data/daily_mission_provider.dart';
import 'package:tsundoku_quest/features/goals/data/reading_goal_provider.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_provider.dart';
import 'package:tsundoku_quest/features/history/data/reading_statistics_provider.dart';
import 'package:tsundoku_quest/features/history/data/weekly_reading_provider.dart';
import 'package:tsundoku_quest/features/lifecycle/domain/day_rollover_detector.dart';
import 'package:tsundoku_quest/features/lifecycle/presentation/app_lifecycle_refresher.dart';
import 'package:tsundoku_quest/main.dart';

/// 実機同様の遷移を挟んで resumed を発火する（同一状態の連続通知は無視され得る）。
Future<void> _sendResumed(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

/// 各 Provider の build 回数（invalidate が効いたかを数える）。
class _Builds {
  int clock = 0;
  int monthly = 0;
  int yearly = 0;
  int weekly = 0;
  int habit = 0;

  @override
  String toString() =>
      'clock=$clock monthly=$monthly yearly=$yearly weekly=$weekly habit=$habit';
}

/// 日付依存 Provider を「build 回数を数えるスタブ」で差し替えたコンテナ。
///
/// override しても Provider の同一性は変わらないため、本番の
/// [invalidateDateDependentProviders] をそのまま撃てる。
ProviderContainer _countingContainer(_Builds builds) {
  return ProviderContainer(
    overrides: [
      statisticsClockProvider.overrideWith((ref) {
        builds.clock++;
        return () => DateTime(2026, 11, 17, 23, 50);
      }),
      monthlyGoalProgressProvider.overrideWith((ref) {
        builds.monthly++;
        return const ReadingGoalProgress(target: 0, achieved: 0);
      }),
      yearlyGoalProgressProvider.overrideWith((ref) {
        builds.yearly++;
        return const ReadingGoalProgress(target: 0, achieved: 0);
      }),
      weeklyReadingMinutesProvider.overrideWith((ref) async {
        builds.weekly++;
        return List<int>.filled(7, 0);
      }),
      readingHabitSessionsProvider.overrideWith((ref) async {
        builds.habit++;
        return <ReadingSession>[];
      }),
    ],
  );
}

/// 日付依存 Provider を一通り読む（キャッシュを温める）。
Future<void> _warmAll(ProviderContainer container) async {
  container.read(statisticsClockProvider);
  container.read(monthlyGoalProgressProvider);
  container.read(yearlyGoalProgressProvider);
  await container.read(weeklyReadingMinutesProvider.future);
  await container.read(readingHabitSessionsProvider.future);
}

void main() {
  test('日付跨ぎの無効化で readingHabitSessionsProvider が再評価される', () async {
    final builds = _Builds();
    final container = _countingContainer(builds);
    addTearDown(container.dispose);

    await container.read(readingHabitSessionsProvider.future);
    expect(builds.habit, 1);

    invalidateDateDependentProviders(container);

    await container.read(readingHabitSessionsProvider.future);
    expect(builds.habit, 2, reason: 'ヒートマップ・日次目標・バッジの元データも日付跨ぎで落とすべき');
  });

  test('invalidate しなければ再評価されない（アブレーションの対照）', () async {
    final builds = _Builds();
    final container = _countingContainer(builds);
    addTearDown(container.dispose);

    await container.read(readingHabitSessionsProvider.future);
    await container.read(readingHabitSessionsProvider.future);

    expect(builds.habit, 1,
        reason: '非autoDispose の FutureProvider は invalidate しない限りキャッシュが固定される');
  });

  test('日付跨ぎ合成: rolledOver で ヒートマップが watch する Provider が再評価される', () async {
    final builds = _Builds();
    final container = _countingContainer(builds);
    addTearDown(container.dispose);

    // ReadingHabitHeatmap（reading_habit_heatmap.dart:37）の ref.watch と同じ形
    final heatmapPanelProvider = Provider<List<ReadingSession>>((ref) {
      return ref.watch(readingHabitSessionsProvider).valueOrNull ??
          const <ReadingSession>[];
    });
    // BadgeCollectionScreen（badge_collection_screen.dart:76）の ref.listen と同じ形
    var notifications = 0;
    final subscription = container.listen<AsyncValue<List<ReadingSession>>>(
      readingHabitSessionsProvider,
      (_, __) => notifications++,
    );
    addTearDown(subscription.close);

    expect(container.read(heatmapPanelProvider), isEmpty);
    await container.read(readingHabitSessionsProvider.future);
    expect(builds.habit, 1);
    final notificationsBefore = notifications;

    // 日付跨ぎ判定 → 跨いだ時だけ無効化（main.dart の onRollover と同じ順序）
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 11, 17, 23, 50));
    final result = detector.check(DateTime(2026, 11, 18, 0, 5));
    expect(result, DayRolloverResult.rolledOver);
    if (result == DayRolloverResult.rolledOver) {
      invalidateDateDependentProviders(container);
    }

    await container.read(readingHabitSessionsProvider.future);

    expect(builds.habit, 2, reason: 'ヒートマップの watch が前日集計のまま残ってはいけない');
    expect(notifications, greaterThan(notificationsBefore),
        reason: 'バッジ画面の ref.listen が発火し _load() が再計算されるべき');
  });

  testWidgets('同日復帰（sameDay）では onRollover が走らず invalidate 回数も増えない',
      (tester) async {
    final builds = _Builds();
    final container = _countingContainer(builds);
    addTearDown(container.dispose);

    var rollovers = 0;
    var now = DateTime(2026, 11, 17, 9, 0);
    final detector =
        DayRolloverDetector(lastSeen: DateTime(2026, 11, 17, 9, 0));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppLifecycleRefresher(
            detector: detector,
            now: () => now,
            onRollover: () async {
              rollovers++;
              invalidateDateDependentProviders(container);
            },
            child: const Text('本体'),
          ),
        ),
      ),
    );
    await container.read(readingHabitSessionsProvider.future);
    expect(builds.habit, 1);

    // ① 同日復帰 → 何も落とさない（過剰無効化の抑止）
    now = DateTime(2026, 11, 17, 18, 30);
    await _sendResumed(tester);
    expect(rollovers, 0);
    expect(builds.habit, 1, reason: '同日復帰で落とすのは過剰無効化');

    // ② 翌日復帰 → 1回だけ落ちる（対照）
    now = DateTime(2026, 11, 18, 0, 5);
    await _sendResumed(tester);
    expect(rollovers, 1);
    await container.read(readingHabitSessionsProvider.future);
    expect(builds.habit, 2);
  });

  test('無効化リストの全要素が ProviderContainer 上で invalidate 可能', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(dateDependentProviders, isNotEmpty);
    expect(dateDependentProviders.toSet().length, dateDependentProviders.length,
        reason: '同じ Provider を二重に載せない');

    for (final provider in dateDependentProviders) {
      expect(() => container.invalidate(provider), returnsNormally,
          reason: '$provider の invalidate が例外を投げた');
    }

    expect(
      dateDependentProviders,
      containsAll([
        statisticsClockProvider,
        monthlyGoalProgressProvider,
        yearlyGoalProgressProvider,
        dailyMissionProvider,
        weeklyReadingMinutesProvider,
        readingHabitSessionsProvider,
      ]),
      reason: '日付依存 Provider の列挙から漏れると前日集計が固定される',
    );
  });

  test('リストの各要素を個別に落とすと再評価される（habit 以外の回帰）', () async {
    final builds = _Builds();
    final container = _countingContainer(builds);
    addTearDown(container.dispose);

    await _warmAll(container);
    expect(builds.toString(), 'clock=1 monthly=1 yearly=1 weekly=1 habit=1');

    container.invalidate(statisticsClockProvider);
    container.invalidate(monthlyGoalProgressProvider);
    container.invalidate(yearlyGoalProgressProvider);
    container.invalidate(weeklyReadingMinutesProvider);
    container.invalidate(readingHabitSessionsProvider);

    await _warmAll(container);
    expect(builds.toString(), 'clock=2 monthly=2 yearly=2 weekly=2 habit=2');
  });
}
