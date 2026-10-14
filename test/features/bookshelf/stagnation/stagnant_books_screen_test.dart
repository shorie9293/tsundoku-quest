/// StagnantBooksScreen（積読放置本）の試練
///
/// entriesOverride を注入して Provider を一切開かない。
/// 行タップによる /reading 遷移は wiring 試練（stagnant_books_wiring_test.dart）
/// でルート配線込みで検証する。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/stagnation.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/stagnant_books_screen.dart';

void main() {
  UserBook ub(String id, String title, BookStatus status, String createdAt,
      {int currentPage = 0, List<String> authors = const ['著者']}) {
    return UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      book: Book(
        id: 'book-$id',
        title: title,
        authors: authors,
        source: BookSource.manual,
        createdAt: createdAt,
      ),
      status: status,
      medium: BookMedium.physical,
      currentPage: currentPage,
      createdAt: createdAt,
    );
  }

  List<UserBook> books() {
    return [
      // 100日放置・未着手（積読）
      ub('1', '放置本A', BookStatus.tsundoku, '2026-03-23T00:00:00Z'),
      // 60日放置・読書中だがページ0
      ub('2', '放置本B', BookStatus.reading, '2026-05-02T00:00:00Z'),
      // 40日放置・読書中で進捗あり
      ub('3', '放置本C', BookStatus.reading, '2026-05-22T00:00:00Z',
          currentPage: 10),
      // 10日しか経過していない（対象外のはずの本も渡して絞り込みを観察）
      ub('4', '最近の本D', BookStatus.tsundoku, '2026-06-21T00:00:00Z'),
    ];
  }

  List<StagnantBook> entries() {
    return StagnationService.detect(books(), now: DateTime(2026, 7, 1));
  }

  Widget testScreen([List<StagnantBook>? override]) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: StagnantBooksScreen(entriesOverride: override),
    );
  }

  testWidgets('should display stagnant list with correct keys', (tester) async {
    await tester.pumpWidget(testScreen(entries()));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.stagnantBooksScreen), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksThresholdChips), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksReasonChips), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksSearchField), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksResultCount), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksList), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksRow('1')), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksRow('2')), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksRow('3')), findsOneWidget);
    // 読了以外でも10日未満は停滞とみなさない
    expect(find.byKey(AppKeys.stagnantBooksRow('4')), findsNothing);
    // 日数ラベルが表示される（タイムゾーンずれを避けるため検出値から動的に検証）
    for (final entry in entries()) {
      expect(find.text(entry.daysLabel), findsOneWidget,
          reason: entry.userBook.id);
    }
    // 停滞日数の降順でソートされている
    final rows = find.byType(ListTile);
    expect(rows, findsNWidgets(3));
  });

  testWidgets('should show empty state when no stagnant books',
      (tester) async {
    await tester.pumpWidget(testScreen(const []));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.stagnantBooksEmpty), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksList), findsNothing);
  });

  testWidgets('should filter by text search and clear', (tester) async {
    await tester.pumpWidget(testScreen(entries()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(AppKeys.stagnantBooksSearchField), '放置本A');
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.stagnantBooksRow('1')), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksRow('2')), findsNothing);
    expect(find.byKey(AppKeys.stagnantBooksSearchClear), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.stagnantBooksSearchClear));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.stagnantBooksSearchClear), findsNothing);
    expect(find.byKey(AppKeys.stagnantBooksRow('2')), findsOneWidget);
  });

  testWidgets('should filter by author text search', (tester) async {
    await tester.pumpWidget(testScreen(entries()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(AppKeys.stagnantBooksSearchField), '著者');
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.stagnantBooksResultCount), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksRow('1')), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksRow('2')), findsOneWidget);
  });

  testWidgets('should filter by reason chip', (tester) async {
    await tester.pumpWidget(testScreen(entries()));
    await tester.pumpAndSettle();

    // 積読（未着手）のみ
    await tester.tap(find.byKey(const ValueKey('stagnant_reason_neverStarted')));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.stagnantBooksRow('1')), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksRow('2')), findsNothing);
    expect(find.byKey(AppKeys.stagnantBooksRow('3')), findsNothing);

    // すべてに戻す
    await tester.tap(find.byKey(const ValueKey('stagnant_reason_all')));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.stagnantBooksRow('3')), findsOneWidget);
  });

  testWidgets('should toggle threshold chips selection', (tester) async {
    await tester.pumpWidget(testScreen(entries()));
    await tester.pumpAndSettle();

    final chip60 = find.byKey(const ValueKey('stagnant_days_60'));
    expect(find.byKey(const ValueKey('stagnant_days_30')), findsOneWidget);
    expect(chip60, findsOneWidget);
    expect(find.byKey(const ValueKey('stagnant_days_90')), findsOneWidget);

    await tester.tap(chip60);
    await tester.pumpAndSettle();

    final chip60Widget =
        tester.widget<ChoiceChip>(find.byKey(const ValueKey('stagnant_days_60')));
    expect(chip60Widget.selected, isTrue);

    // 閾値チップは detect(minDays) と同じ集合を表示せよ（合成の不変条件）。
    // 日数はタイムゾーンで1日ずれ得るため、期待値はサービスから動的算出する。
    Set<String> idsFor(int minDays) => StagnationService.detect(
          books(),
          now: DateTime(2026, 7, 1),
          minDays: minDays,
        ).map((e) => e.userBook.id).toSet();
    final expected60 = idsFor(60);
    for (final id in ['1', '2', '3', '4']) {
      expect(
        find.byKey(AppKeys.stagnantBooksRow(id)),
        expected60.contains(id) ? findsOneWidget : findsNothing,
        reason: 'minDays=60 / id=$id',
      );
    }

    // 90日へ切り替えると絞り込みがさらに強くなる（部分集合）
    await tester.tap(find.byKey(const ValueKey('stagnant_days_90')));
    await tester.pumpAndSettle();
    final expected90 = idsFor(90);
    for (final id in ['1', '2', '3', '4']) {
      expect(
        find.byKey(AppKeys.stagnantBooksRow(id)),
        expected90.contains(id) ? findsOneWidget : findsNothing,
        reason: 'minDays=90 / id=$id',
      );
    }
    expect(expected90.length, lessThanOrEqualTo(expected60.length));
  });
}
