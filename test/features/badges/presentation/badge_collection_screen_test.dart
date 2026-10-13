import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/badges/data/badge_provider.dart';
import 'package:tsundoku_quest/features/badges/data/badge_record_repository.dart';
import 'package:tsundoku_quest/features/badges/presentation/badge_collection_screen.dart';

final DateTime _now = DateTime(2026, 10, 13, 12, 0);

ReadingSession _session(String startedAt) => ReadingSession(
      id: 's_${startedAt.hashCode}',
      userBookId: 'ub1',
      startedAt: startedAt,
      startPage: 1,
      endPage: 50,
      durationMinutes: 45,
      createdAt: startedAt,
    );

UserBook _completedBook() => const UserBook(
      id: 'ub1',
      userId: 'u1',
      bookId: 'bk1',
      status: BookStatus.completed,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00',
    );

Widget _wrap({
  List<ReadingSession> sessions = const [],
  List<UserBook> userBooks = const [],
}) {
  return ProviderScope(
    overrides: [
      badgeRecordRepositoryProvider
          .overrideWithValue(InMemoryBadgeRecordRepository()),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: BadgeCollectionScreen(
        sessionsOverride: sessions,
        userBooksOverride: userBooks,
        nowOverride: _now,
      ),
    ),
  );
}

void main() {
  testWidgets('サマリーとカテゴリセクションが表示される', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.badgeCollectionScreen), findsOneWidget);
    expect(find.byKey(AppKeys.badgeCollectionSummary), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(AppKeys.badgeCollectionSummary),
        matching: find.byKey(AppKeys.badgeCollectionSummaryLabel),
      ),
      findsOneWidget,
    );
    // 空入力でないので empty 文言は出ない
    expect(find.byKey(AppKeys.badgeCollectionEmpty), findsNothing);

    for (final category in BadgeCategoryName.all) {
      expect(
        find.byKey(AppKeys.badgeCategorySection(category)),
        findsOneWidget,
        reason: 'category: $category',
      );
    }
  });

  testWidgets('セッションと読了本から獲得済み・未獲得行が出る', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        sessions: [
          _session('2026-10-13T06:00:00'),
          _session('2026-10-12T06:00:00'),
          _session('2026-10-11T06:00:00'),
        ],
        userBooks: [_completedBook()],
      ),
    );
    await tester.pumpAndSettle();

    // 読了1冊 → books_1 は獲得済み（check_circle マーク付き）
    expect(
      find.byKey(AppKeys.badgeEarnedMark('books_1')),
      findsOneWidget,
    );
    expect(find.byKey(AppKeys.badgeRow('books_1')), findsOneWidget);

    // 5冊未達 → 未獲得行は出るが獲得マークは無い
    expect(find.byKey(AppKeys.badgeRow('books_5')), findsOneWidget);
    expect(find.byKey(AppKeys.badgeEarnedMark('books_5')), findsNothing);

    // 進捗ラベル（1 / 1）が表示される
    expect(find.text('1 / 1'), findsWidgets);
  });

  testWidgets('空入力では全バッジ行が未獲得で empty 文言は出ない', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.badgeEarnedMark('books_1')), findsNothing);
    expect(find.byKey(AppKeys.badgeRow('books_1')), findsOneWidget);
    expect(find.byKey(AppKeys.badgeCollectionEmpty), findsNothing);
  });
}

/// カテゴリ名（enum name）の想定一覧
class BadgeCategoryName {
  static const all = [
    'completedBooks',
    'streak',
    'readingTime',
    'pagesTotal',
    'timeOfDay',
  ];
}