import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/features/reading/data/quick_memo_draft_store.dart';
import 'package:tsundoku_quest/features/reading/domain/quick_memo.dart';
import 'package:tsundoku_quest/features/reading/presentation/reading_screen.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

const _bookId = 'test-id';
final _fixedNow = DateTime.utc(2026, 11, 2, 9, 0);

/// clear が必ず失敗するストア（「保存失敗時に下書きを残す」の検証用）
class _ClearFailingMemoStore extends InMemoryQuickMemoDraftStore {
  @override
  Future<void> clear(String userBookId) async {
    clearCalls.add(userBookId);
    throw StateError('clear failed');
  }
}

ProviderContainer _seedContainer() {
  final container = ProviderContainer();
  const book = Book(
    id: 'b1',
    title: 'Test Book',
    authors: ['Author'],
    source: BookSource.manual,
    createdAt: '2026-01-01T00:00:00Z',
  );
  const userBook = UserBook(
    id: _bookId,
    userId: 'u1',
    bookId: 'b1',
    book: book,
    status: BookStatus.reading,
    medium: BookMedium.physical,
    totalReadingMinutes: 30,
    createdAt: '2026-01-01T00:00:00Z',
  );
  container.read(bookDataProvider.notifier).addUserBook(userBook);
  return container;
}

Widget _screen(
  ProviderContainer container,
  QuickMemoDraftStore store,
) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: ReadingScreen(
        id: _bookId,
        memoDraftStore: store,
        memoDebounce: const Duration(milliseconds: 20),
        now: () => _fixedNow,
      ),
    ),
  );
}

/// クイックメモ欄までスクロールして表示する
Future<void> _revealMemo(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -500));
  await tester.pumpAndSettle();
}

String _memoText(WidgetTester tester) {
  final field = tester.widget<TextField>(find.byKey(AppKeys.readingMemo));
  return field.controller?.text ?? '';
}

/// 読了フロー（完了確認 → 読了 → 戦利品カード提出）を進める
Future<void> _submitTrophyViaUi(WidgetTester tester) async {
  await _revealMemo(tester);
  await tester.tap(find.byKey(AppKeys.readingComplete));
  await tester.pumpAndSettle();
  await tester.tap(find.text('読了する'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(AppKeys.trophySubmit));
  await tester.tap(find.byKey(AppKeys.trophySubmit));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('hive_quick_memo_').path);
  });
  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('入力がデバウンス後に下書き保存される', (tester) async {
    final container = _seedContainer();
    final store = InMemoryQuickMemoDraftStore();
    await tester.pumpWidget(_screen(container, store));
    await tester.pumpAndSettle();

    await _revealMemo(tester);
    await tester.enterText(find.byKey(AppKeys.readingMemo), '  一章の気づき  ');
    await tester.pump(const Duration(milliseconds: 5));
    expect(store.saveCalls, isEmpty); // デバウンス中は未保存

    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump();

    expect(store.saveCalls, [_bookId]);
    final draft = await store.load(_bookId);
    expect(draft?.body, '一章の気づき');
    expect(draft?.updatedAt, _fixedNow);

    container.dispose();
  });

  testWidgets('画面再入時に下書きが復元される', (tester) async {
    final store = InMemoryQuickMemoDraftStore();
    await store.save(
      _bookId,
      QuickMemoDraft(body: '昨日の続き\nメモ', updatedAt: _fixedNow),
    );

    final container = _seedContainer();
    await tester.pumpWidget(_screen(container, store));
    await tester.pumpAndSettle();

    await _revealMemo(tester);
    expect(_memoText(tester), '昨日の続き\nメモ');

    container.dispose();
  });

  testWidgets('空メモでは下書き保存を呼ばない', (tester) async {
    final container = _seedContainer();
    final store = InMemoryQuickMemoDraftStore();
    await tester.pumpWidget(_screen(container, store));
    await tester.pumpAndSettle();

    await _revealMemo(tester);
    await tester.enterText(find.byKey(AppKeys.readingMemo), '   ');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();

    expect(store.saveCalls, isEmpty);

    container.dispose();
  });

  testWidgets('完了時にメモが戦利品（既存の読書メモ経路）へ渡り下書きが消える',
      (tester) async {
    final container = _seedContainer();
    final store = InMemoryQuickMemoDraftStore();
    await tester.pumpWidget(_screen(container, store));
    await tester.pumpAndSettle();

    await _revealMemo(tester);
    await tester.enterText(find.byKey(AppKeys.readingMemo), '持ち帰る学び');
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump();
    expect((await store.load(_bookId))?.body, '持ち帰る学び');

    await _submitTrophyViaUi(tester);

    final trophies = container.read(warTrophyProvider);
    expect(trophies, isNotEmpty);
    final trophy = trophies.last;
    expect(trophy.userBookId, _bookId);
    expect(trophy.learnings, contains('持ち帰る学び'));
    expect(store.clearCalls, contains(_bookId));
    expect(await store.load(_bookId), isNull);

    container.dispose();
  });

  testWidgets('下書き消去が失敗しても戦利品保存は成立し下書きは残る', (tester) async {
    final container = _seedContainer();
    final store = _ClearFailingMemoStore();
    await tester.pumpWidget(_screen(container, store));
    await tester.pumpAndSettle();

    await _revealMemo(tester);
    await tester.enterText(find.byKey(AppKeys.readingMemo), '消えないメモ');
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump();

    await _submitTrophyViaUi(tester);

    final trophies = container.read(warTrophyProvider);
    final trophy = trophies.lastWhere((WarTrophy t) => t.userBookId == _bookId);
    expect(trophy.learnings, contains('消えないメモ'));
    expect(store.clearCalls, contains(_bookId));
    expect((await store.load(_bookId))?.body, '消えないメモ');

    container.dispose();
  });

  testWidgets('空メモのまま完了しても空文字の学びを追加しない', (tester) async {
    final container = _seedContainer();
    final store = InMemoryQuickMemoDraftStore();
    await tester.pumpWidget(_screen(container, store));
    await tester.pumpAndSettle();

    await _revealMemo(tester);
    await tester.enterText(find.byKey(AppKeys.readingMemo), '   ');
    await tester.pump(const Duration(milliseconds: 40));

    await _submitTrophyViaUi(tester);

    final trophy = container.read(warTrophyProvider).last;
    expect(trophy.learnings, isEmpty);
    expect(trophy.learnings, isNot(contains('')));

    container.dispose();
  });
}
