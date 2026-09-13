import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/goals/data/reading_goal_provider.dart';
import 'package:tsundoku_quest/features/goals/data/reading_goal_repository.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal.dart';
import 'package:tsundoku_quest/features/goals/presentation/reading_goal_screen.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

UserBook _completed(String id, String completedAt) => UserBook(
      id: id,
      userId: 'u1',
      bookId: 'book-$id',
      book: Book(
        id: 'book-$id',
        title: 'Book $id',
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      ),
      status: BookStatus.completed,
      medium: BookMedium.physical,
      completedAt: completedAt,
      createdAt: '2026-01-01T00:00:00Z',
    );

class _FakeBookData extends BookDataNotifier {
  final List<UserBook> _books;
  _FakeBookData(this._books) : super(null);

  @override
  BookDataState get state =>
      BookDataState(userBooks: _books, isLoading: false);
}

Widget _wrap({
  required ReadingGoalRepository repo,
  List<UserBook> books = const [],
}) {
  return ProviderScope(
    overrides: [
      readingGoalRepositoryProvider.overrideWithValue(repo),
      bookDataProvider.overrideWith((ref) => _FakeBookData(books)),
    ],
    child: const MaterialApp(home: ReadingGoalScreen()),
  );
}

void main() {
  testWidgets('未設定のときは進捗が未設定表示になる', (tester) async {
    await tester.pumpWidget(_wrap(repo: InMemoryReadingGoalRepository()));
    await tester.pumpAndSettle();

    expect(find.text('🎯 読書目標'), findsOneWidget);
    expect(find.text('未設定'), findsNWidgets(2));
  });

  testWidgets('目標を入力して保存するとリポジトリへ永続化される', (tester) async {
    final repo = InMemoryReadingGoalRepository();
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(AppKeys.readingGoalMonthlyField), '2');
    await tester.enterText(find.byKey(AppKeys.readingGoalYearlyField), '24');
    await tester.tap(find.byKey(AppKeys.readingGoalSaveButton));
    await tester.pumpAndSettle();

    final saved = await repo.load();
    expect(saved.monthlyTarget, 2);
    expect(saved.yearlyTarget, 24);
  });

  testWidgets('設定済み目標は進捗パネルに反映される', (tester) async {
    final now = DateTime.now().toUtc();
    final repo = InMemoryReadingGoalRepository(
      initial: const ReadingGoal(monthlyTarget: 5, yearlyTarget: 50),
    );
    final books = [
      _completed('a', now.toIso8601String()),
      _completed('b', now.toIso8601String()),
    ];
    await tester.pumpWidget(_wrap(repo: repo, books: books));
    await tester.pumpAndSettle();

    expect(find.text('2 / 5 冊（40%）'), findsOneWidget);
    expect(find.text('2 / 50 冊（4%）'), findsOneWidget);
    expect(find.textContaining('残り'), findsNWidgets(2));
  });

  testWidgets('目標達成時は達成バッジを表示する', (tester) async {
    final now = DateTime.now().toUtc();
    final repo = InMemoryReadingGoalRepository(
      initial: const ReadingGoal(monthlyTarget: 1),
    );
    await tester.pumpWidget(_wrap(
      repo: repo,
      books: [_completed('a', now.toIso8601String())],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('🏆 目標達成'), findsOneWidget);
  });

  testWidgets('解除ボタンで目標が未設定に戻る', (tester) async {
    final repo = InMemoryReadingGoalRepository(
      initial: const ReadingGoal(monthlyTarget: 3),
    );
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.readingGoalClearButton));
    await tester.pumpAndSettle();

    expect((await repo.load()).isConfigured, isFalse);
    expect(find.text('未設定'), findsNWidgets(2));
  });

  testWidgets('不正な入力（文字列）は未設定として保存する', (tester) async {
    final repo = InMemoryReadingGoalRepository();
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(AppKeys.readingGoalMonthlyField), 'たくさん');
    await tester.tap(find.byKey(AppKeys.readingGoalSaveButton));
    await tester.pumpAndSettle();

    expect((await repo.load()).monthlyTarget, 0);
  });
}
