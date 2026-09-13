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
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: ReadingGoalCard()),
      ),
    ),
  );
}

void main() {
  testWidgets('未設定なら目標設定への導線を表示する', (tester) async {
    await tester.pumpWidget(_wrap(repo: InMemoryReadingGoalRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.readingGoalCard), findsOneWidget);
    expect(find.text('読書目標'), findsOneWidget);
    expect(find.text('目標を立てる'), findsOneWidget);
    expect(find.textContaining('月間・年間の読了目標を設定して'), findsOneWidget);
  });

  testWidgets('設定済みなら今月・今年の進捗バーとバッジを表示する', (tester) async {
    final now = DateTime.now().toUtc();
    final repo = InMemoryReadingGoalRepository(
      initial: const ReadingGoal(monthlyTarget: 2, yearlyTarget: 24),
    );
    await tester.pumpWidget(_wrap(
      repo: repo,
      books: [
        _completed('a', now.toIso8601String()),
        _completed('b', now.toIso8601String()),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('今月 '), findsOneWidget);
    expect(find.text('今年 '), findsOneWidget);
    expect(find.text('2 / 2 冊'), findsOneWidget);
    expect(find.text('2 / 24 冊'), findsOneWidget);
    expect(find.text('設定を変更'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
  });

  testWidgets('目標を立てるボタンで目標画面へ遷移する', (tester) async {
    await tester.pumpWidget(_wrap(repo: InMemoryReadingGoalRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('目標を立てる'));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.readingGoalScreen), findsOneWidget);
  });
}
