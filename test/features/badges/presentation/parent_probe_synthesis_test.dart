import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/badges/data/badge_provider.dart';
import 'package:tsundoku_quest/features/badges/data/badge_record_repository.dart';
import 'package:tsundoku_quest/features/badges/presentation/badge_collection_screen.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_provider.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

/// 親探針: widget override を使わず provider 経由（実運用と同じ経路）で
/// 画面→provider→controller→repository の合成が成立することを撃つ。
/// さらに獲得日時が repository へ永続化されることを撃つ。
void main() {
  ReadingSession s(String id, DateTime start, int minutes) => ReadingSession(
        id: id,
        userBookId: 'ub-1',
        startedAt: start.toIso8601String(),
        startPage: 0,
        durationMinutes: minutes,
        createdAt: start.toIso8601String(),
      );

  testWidgets('親探針: provider経由（override無し）で描画され、獲得が repository へ永続化される',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = InMemoryBadgeRecordRepository();
    final sessions = <ReadingSession>[
      s('a', DateTime(2026, 10, 11, 9, 0), 120),
      s('b', DateTime(2026, 10, 12, 6, 30), 120),
      s('c', DateTime(2026, 10, 13, 7, 0), 120),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingHabitSessionsProvider.overrideWith((ref) => sessions),
          bookDataProvider.overrideWith((ref) => BookDataNotifier()),
          badgeRecordRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: BadgeCollectionScreen(nowOverride: DateTime(2026, 10, 13, 12)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 画面が描画される（ref.watch を build 外で呼んでいればここで例外になる）
    expect(find.byKey(AppKeys.badgeCollectionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 獲得済みバッジが repository に記録されている
    expect(repo.current.ids, isNotEmpty);
    expect(repo.current.ids.contains('minutes_60'), isTrue);
    expect(repo.current.ids.contains('streak_3'), isTrue);

    // 獲得日時が付けられている（今日=now と一致する日付）
    final earnedAt = repo.current.earnedAtOf('minutes_60');
    expect(earnedAt, isNotNull);
    expect(earnedAt!.toUtc().toIso8601String().substring(0, 10), '2026-10-13');

    // 獲得マークが出ている
    expect(find.byKey(AppKeys.badgeEarnedMark('minutes_60')), findsOneWidget);
  });
}
