// 空状態の共通部品（EmptyStateView）普及の試練。
//
// 0件データのとき、各画面が生 Text ではなく EmptyStateView を1つ描くこと、
// および既存の導線がある画面では行動ボタン（Semantics id
// 'btn_empty_state_action'）が1つだけ出ることを検める。文言は既存のまま
// （一字も変えない）ので、旧来の文言が見出し・説明として残っていることも
// 併せて確認する。
//
// この現世は WashiBackground / DungeonBackground 等の不確定アニメーションを
// 含むため pumpAndSettle は使わず pump(Duration) で進める。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/core/crash/crash_log_repository.dart';
import 'package:tsundoku_quest/core/crash/crash_log_screen.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/core/widgets/empty_state.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/book_list_screen.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/library_search_screen.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/stagnant_books_screen.dart';
import 'package:tsundoku_quest/features/help/presentation/help_screen.dart';
import 'package:tsundoku_quest/features/history/data/reading_notes_provider.dart';
import 'package:tsundoku_quest/features/history/presentation/reading_note_search_screen.dart';
import 'package:tsundoku_quest/features/history/presentation/reading_session_log_screen.dart';
import 'package:tsundoku_quest/features/reading/presentation/reading_screen.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_provider.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_repository.dart';
import 'package:tsundoku_quest/features/reading_queue/presentation/reading_queue_screen.dart';
import 'package:tsundoku_quest/features/recommendation/presentation/recommendation_screen.dart';
import 'package:tsundoku_quest/features/shelves/data/shelf_repository_provider.dart';
import 'package:tsundoku_quest/features/shelves/presentation/shelf_management_screen.dart';
import 'package:tsundoku_quest/features/share_card/presentation/share_card_screen.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

const String _actionSemanticsId = 'btn_empty_state_action';

/// 不確定アニメーションを含む画面でも固まらないよう pump で進める。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

ReadingNoteItem _note(String id) => ReadingNoteItem(
      id: id,
      userBookId: 'ub_$id',
      bookTitle: '吾輩は猫である',
      learnings: const ['主観は移ろいやすい'],
      action: '',
      createdAt: '2026-03-01T10:00:00Z',
    );

void main() {
  setUpAll(() {
    final tempDir = Directory.systemTemp.createTempSync('hive_adoption_');
    Hive.init(tempDir.path);
    SharedPreferences.setMockInitialValues({});
  });
  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('読書画面: 本が無いとき EmptyStateView を出し行動ボタンは出さない',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReadingScreen())),
    );
    await tester.pump();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('本が見つかりません'), findsOneWidget);
    // この画面に新しい遷移は無いのでボタンは描かない。
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });

  testWidgets('読書記録: 0件で EmptyStateView と「手動で記録」の行動ボタンが1つ出る',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReadingSessionLogScreen(
            booksOverride: const <UserBook>[],
            sessionsOverride: const [],
            nowOverride: () => DateTime(2026, 10, 4, 21, 30),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    // 旧 Key・旧文言は不変。
    expect(find.byKey(AppKeys.readingSessionLogEmpty), findsOneWidget);
    expect(find.text('読書記録がありません'), findsOneWidget);
    expect(find.text('手動で記録'), findsWidgets);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsOneWidget);
  });

  testWidgets('感想検索: 0件で EmptyStateView（条件が既定なら行動ボタンなし）',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ReadingNoteSearchScreen(notesOverride: const [])),
      ),
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.byKey(AppKeys.readingNoteEmpty), findsOneWidget);
    expect(find.text('条件に合う感想がありません'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });

  testWidgets('感想検索: 絞り込みで0件なら「条件をクリア」の行動ボタンを差し出す',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReadingNoteSearchScreen(notesOverride: [_note('n1')]),
        ),
      ),
    );
    await _settle(tester);

    await tester.enterText(find.byType(TextField).first, '該当しない語句ZZZ');
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('条件に合う感想がありません'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsOneWidget);
    expect(find.text('条件をクリア'), findsWidgets);
  });

  testWidgets('読了カード: 候補0件で EmptyStateView を出し行動ボタンは出さない',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ShareCardScreen(candidates: [])),
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.byKey(AppKeys.shareCardEmpty), findsOneWidget);
    expect(find.text('読了した本がまだない'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });

  testWidgets('自作棚: 0件で EmptyStateView と「棚を作る」の行動ボタンが1つ出る',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shelfRepositoryProvider.overrideWithValue(InMemoryShelfRepository()),
        ],
        child: const MaterialApp(home: ShelfManagementScreen()),
      ),
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('自作棚はまだありません'), findsWidgets);
    expect(
      find.text('右上の ＋ から棚を作って、本をテーマ別に整理しましょう'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsOneWidget);
  });

  testWidgets('読書キュー: 空キューで EmptyStateView と「積読から追加」の行動ボタンが1つ出る',
      (tester) async {
    final repo = InMemoryReadingQueueRepository();
    await repo.saveEntries(const <ReadingQueueEntry>[]);

    final container = ProviderContainer(
      overrides: [
        readingQueueRepositoryProvider.overrideWithValue(repo),
        bookDataProvider.overrideWith((ref) => BookDataNotifier()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReadingQueueScreen()),
      ),
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.byKey(AppKeys.readingQueueEmpty), findsOneWidget);
    expect(find.text('キューが空です。積読から本を追加しよう。'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsOneWidget);
  });

  testWidgets('不具合ログ: 0件で EmptyStateView を出し行動ボタンは出さない',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CrashLogScreen(repository: InMemoryCrashLogRepository()),
      ),
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('記録された不具合はありません'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });

  testWidgets('停滞本: 0件で EmptyStateView を出し行動ボタンは出さない',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StagnantBooksScreen(entriesOverride: const []),
        ),
      ),
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.byKey(AppKeys.stagnantBooksEmpty), findsOneWidget);
    expect(find.text('停滞している本はありません'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });

  testWidgets('書庫検索: 0件で EmptyStateView（絞り込みなしなら行動ボタンなし）',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LibrarySearchScreen(
            booksOverride: const <UserBook>[],
            shelvesOverride: const [],
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.byKey(AppKeys.libraryEmptyState), findsOneWidget);
    expect(find.text('条件に合う本が見つかりません'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });

  testWidgets('本一覧: 0件で EmptyStateView を出し行動ボタンは出さない',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BookListScreen(title: 'テスト一覧', books: []),
      ),
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('表示する本がありません'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });

  testWidgets('ヘルプ: 検索0件で EmptyStateView を出し行動ボタンは出さない',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    await _settle(tester);

    await tester.enterText(
      find.byKey(AppKeys.helpSearchField),
      '該当しない語句ZZZ',
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.byKey(AppKeys.helpEmptyMessage), findsOneWidget);
    expect(find.text('見つかりませんでした'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });

  testWidgets('自動バックアップ: 0件で EmptyStateView を出し行動ボタンは出さない',
      (tester) async {
    final now = DateTime(2026, 10, 29, 9, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: AutoBackupScreen(
          store: InMemoryAutoBackupStore(now: () => now),
          now: () => now,
        ),
      ),
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.byKey(const ValueKey('auto_backup_empty')), findsOneWidget);
    expect(find.text('バックアップはまだありません'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });

  testWidgets('おすすめ: 0件で EmptyStateView を出し行動ボタンは出さない',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RecommendationScreen())),
    );
    await _settle(tester);

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('現在のおすすめはありません'), findsOneWidget);
    expect(find.bySemanticsIdentifier(_actionSemanticsId), findsNothing);
  });
}
