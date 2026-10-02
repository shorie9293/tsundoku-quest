import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/history/data/reading_statistics_provider.dart';
import 'package:tsundoku_quest/features/history/presentation/widgets/reading_statistics_dashboard.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

UserBook _ub({
  required String id,
  String? completedAt,
  int pages = 300,
}) {
  final book = Book(
    id: 'book-$id',
    title: 'Book $id',
    source: BookSource.manual,
    createdAt: '2026-01-01T00:00:00Z',
  );
  return UserBook(
    id: id,
    userId: 'u1',
    bookId: 'book-$id',
    book: book,
    status: completedAt != null ? BookStatus.completed : BookStatus.reading,
    medium: BookMedium.physical,
    currentPage: pages,
    completedAt: completedAt,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

class _FakeBookData extends BookDataNotifier {
  final List<UserBook> _books;
  _FakeBookData(this._books) : super(null);

  @override
  BookDataState get state => BookDataState(
        userBooks: _books,
        isLoading: false,
      );
}

/// 試練は実時計に依存させない。now を注入して決定論化する。
Widget _wrap(List<UserBook> books, {DateTime? now}) {
  return ProviderScope(
    overrides: [
      bookDataProvider.overrideWith((ref) => _FakeBookData(books)),
      // 「今月」判定を固定（注入しなければ暦が進むたびに赤化する時限爆弾）
      statisticsClockProvider.overrideWithValue(
        () => now ?? DateTime(2026, 9, 15),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ListView(children: [ReadingStatisticsDashboard()]),
      ),
    ),
  );
}

void main() {
  testWidgets('月次・年次パネルが描画される', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();
    expect(find.text('📆 月間読了'), findsOneWidget);
    expect(find.text('🗓 年間読了'), findsOneWidget);
  });

  testWidgets('読了本がある月のグラフに冊数が表示される', (tester) async {
    final books = [
      _ub(id: 'a', completedAt: '2026-09-05T10:00:00Z', pages: 200),
      _ub(id: 'b', completedAt: '2026-09-20T10:00:00Z', pages: 120),
    ];
    await tester.pumpWidget(_wrap(books));
    await tester.pumpAndSettle();
    expect(find.text('今月: 2冊・320ページ'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('棚別パネルは棚が空なら表示されない', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();
    expect(find.text('🗂 棚別の蔵書'), findsNothing);
  });

  testWidgets('時計注入により現在月が変われる（実時計非依存の回帰試練）', (tester) async {
    final books = [
      _ub(id: 'a', completedAt: '2026-09-05T10:00:00Z', pages: 200),
    ];
    // 現在月を10月に注入すると、9月の読了は「今月」に数えられない
    await tester.pumpWidget(_wrap(books, now: DateTime(2026, 10, 3)));
    await tester.pumpAndSettle();
    expect(find.text('今月: 1冊・200ページ'), findsNothing);
    expect(find.text('今月の読了はまだありません'), findsOneWidget);
  });
}