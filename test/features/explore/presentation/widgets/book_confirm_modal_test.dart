import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/features/explore/presentation/widgets/book_confirm_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testBook = Book(
    id: 'gb-123',
    title: 'テスト本タイトル',
    authors: const ['著者A', '著者B'],
    publishedDate: '2020-05-01',
    pageCount: 320,
    coverImageUrl: null,
    source: BookSource.googleBooks,
    createdAt: '2026-09-09T00:00:00.000Z',
  );

  Future<void> pumpModal(
    WidgetTester tester, {
    Book? book,
    ValueChanged<Book>? onConfirm,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => BookConfirmModal.show(
                  context,
                  book: book ?? testBook,
                  onConfirm: onConfirm ?? (_) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('BookConfirmModal（バーコード登録確認）', () {
    testWidgets('書誌情報（タイトル・著者・ページ数）を表示する', (tester) async {
      await pumpModal(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.bookConfirmModal), findsOneWidget);
      expect(find.text('テスト本タイトル'), findsOneWidget);
      expect(find.textContaining('著者A'), findsOneWidget);
      expect(find.textContaining('320'), findsOneWidget);
    });

    testWidgets('「登録する」タップで onConfirm に本が渡り閉じる', (tester) async {
      Book? confirmed;
      await pumpModal(tester, onConfirm: (b) => confirmed = b);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.bookConfirmSubmit));
      await tester.pumpAndSettle();

      expect(confirmed?.id, 'gb-123');
      expect(find.byKey(AppKeys.bookConfirmModal), findsNothing);
    });

    testWidgets('「やめる」タップで onConfirm は呼ばれず閉じる', (tester) async {
      var called = false;
      await pumpModal(tester, onConfirm: (_) => called = true);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.bookConfirmCancel));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.byKey(AppKeys.bookConfirmModal), findsNothing);
    });
  });
}
