import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/core/theme/app_theme.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/edit_book_modal.dart';

/// テスト用のMockBookDataNotifier — updateUserBook の呼出しを記録
class MockBookDataNotifier extends BookDataNotifier {
  bool updateUserBookCalled = false;
  String? lastUpdatedId;
  BookStatus? lastUpdatedStatus;
  BookMedium? lastUpdatedMedium;
  int? lastUpdatedRating;
  String? lastUpdatedNotes;

  MockBookDataNotifier() : super();

  @override
  void updateUserBook({
    required String id,
    BookStatus? status,
    int? currentPage,
    int? totalReadingMinutes,
    int? rating,
    String? startedAt,
    String? completedAt,
    String? notes,
    BookMedium? medium,
  }) {
    updateUserBookCalled = true;
    lastUpdatedId = id;
    lastUpdatedStatus = status;
    lastUpdatedMedium = medium;
    lastUpdatedRating = rating;
    lastUpdatedNotes = notes;
  }
}

/// テスト用ラッパー — EditBookModal を Scaffold に直接配置
Widget _wrapModal(Widget modal) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppTheme.background,
      colorScheme: const ColorScheme.dark(
        surface: AppTheme.background,
        primary: AppTheme.accent,
        secondary: AppTheme.active,
      ),
    ),
    home: Scaffold(
      body: modal,
    ),
  );
}

Book _testBook(String id) => Book(
      id: id,
      title: 'テスト本 $id',
      authors: ['著者'],
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    );

UserBook _testUserBook({
  String id = 'ub-1',
  BookStatus status = BookStatus.tsundoku,
  BookMedium medium = BookMedium.physical,
  int? rating,
  String? notes,
}) =>
    UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-1',
      book: _testBook('book-1'),
      status: status,
      medium: medium,
      rating: rating,
      notes: notes,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  group('EditBookModal', () {
    late MockBookDataNotifier mockNotifier;

    setUp(() {
      mockNotifier = MockBookDataNotifier();
    });

    Future<void> pumpModal(
      WidgetTester tester, {
      UserBook? book,
    }) async {
      final targetBook = book ?? _testUserBook();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookDataProvider.overrideWith((ref) => mockNotifier),
          ],
          child: _wrapModal(
            EditBookModal(book: targetBook),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('should display the modal with edit title and close button',
        (tester) async {
      await pumpModal(tester);

      expect(find.text('✏️ 編集'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byKey(AppKeys.bookEditModal), findsOneWidget);
    });

    testWidgets('should display medium segmented buttons', (tester) async {
      await pumpModal(tester);

      expect(find.text('📖 物理'), findsOneWidget);
      expect(find.text('📱 電子'), findsOneWidget);
      expect(find.text('🎧 オーディオ'), findsOneWidget);
    });

    testWidgets('should display status segmented buttons', (tester) async {
      await pumpModal(tester);

      expect(find.text('待機中'), findsOneWidget);
      expect(find.text('戦闘中！'), findsOneWidget);
      expect(find.text('討伐済み'), findsOneWidget);
    });

    testWidgets('should display rating stars', (tester) async {
      await pumpModal(tester);

      // 5つの星アイコンが表示されている
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    });

    testWidgets('should display notes text field', (tester) async {
      await pumpModal(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('読書メモを入力…'), findsOneWidget);
    });

    testWidgets('should display save button', (tester) async {
      await pumpModal(tester);

      expect(find.text('保存'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('should toggle star rating on tap', (tester) async {
      await pumpModal(tester);

      // 初期状態: 評価なし → すべて star_border
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
      expect(find.byIcon(Icons.star), findsNothing);

      // 3つめの星をタップ
      final starButtons = find.byIcon(Icons.star_border);
      await tester.tap(starButtons.at(2));
      await tester.pumpAndSettle();

      // 3つ filled, 2つ border
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    });

    testWidgets('should call updateUserBook with correct values on save',
        (tester) async {
      final book = _testUserBook(
        id: 'ub-1',
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        rating: null,
        notes: null,
      );
      await pumpModal(tester, book: book);

      // 媒体を電子に変更
      await tester.tap(find.text('📱 電子'));
      await tester.pumpAndSettle();

      // 状態を戦闘中に変更
      await tester.tap(find.text('戦闘中！'));
      await tester.pumpAndSettle();

      // 評価3をタップ
      final starButtons = find.byIcon(Icons.star_border);
      await tester.tap(starButtons.at(2));
      await tester.pumpAndSettle();

      // メモ入力
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'テストメモ');
      await tester.pumpAndSettle();

      // 保存ボタンをタップ
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(mockNotifier.updateUserBookCalled, isTrue);
      expect(mockNotifier.lastUpdatedId, 'ub-1');
      expect(mockNotifier.lastUpdatedStatus, BookStatus.reading);
      expect(mockNotifier.lastUpdatedMedium, BookMedium.ebook);
      expect(mockNotifier.lastUpdatedRating, 3);
      expect(mockNotifier.lastUpdatedNotes, 'テストメモ');
    });

    testWidgets('should close modal after save', (tester) async {
      await pumpModal(tester);

      // モーダルが表示されている
      expect(find.byKey(AppKeys.bookEditModal), findsOneWidget);

      // 保存ボタンをタップ
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(mockNotifier.updateUserBookCalled, isTrue);
    });

    testWidgets('should close modal on close button tap', (tester) async {
      await pumpModal(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 閉じた後はモーダルキーがない
      expect(find.byKey(AppKeys.bookEditModal), findsNothing);
    });

    testWidgets('should pre-fill existing rating', (tester) async {
      final book = _testUserBook(rating: 4);
      await pumpModal(tester, book: book);

      // 4つの星がfilled
      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border), findsNWidgets(1));
    });

    testWidgets('should pre-fill existing notes', (tester) async {
      final book = _testUserBook(notes: '既存のメモ');
      await pumpModal(tester, book: book);

      expect(find.text('既存のメモ'), findsOneWidget);
    });
  });
}
