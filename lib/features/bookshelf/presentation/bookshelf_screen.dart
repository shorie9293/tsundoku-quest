import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;
import '../../../core/theme/app_theme.dart';
import '../../../core/testing/widget_keys.dart';
import '../../../core/widgets/dungeon_background.dart';
import '../../../domain/models/user_book.dart';
import '../../../shared/providers/book_data_provider.dart';
import 'widgets/adventurer_header.dart';
import 'widgets/streak_display.dart';
import 'widgets/daily_quest.dart';
import '../../recommendation/presentation/widgets/recommendation_card.dart';
import 'widgets/book_card.dart';
import 'widgets/book_shelf_section.dart';
import 'widgets/edit_book_modal.dart';
import '../../recommendation/domain/recommendation_service.dart';
import '../../recommendation/presentation/widgets/social_reading_section.dart';
import '../../about/presentation/about_app_keys.dart';
import 'widgets/completed_book_detail_modal.dart';

/// 書庫画面（ホーム）
class BookshelfScreen extends ConsumerStatefulWidget {
  const BookshelfScreen({super.key});

  @override
  ConsumerState<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends ConsumerState<BookshelfScreen> {
  bool _readingOpen = true;
  bool _tsundokuOpen = true;
  bool _completedOpen = true;

  @override
  void initState() {
    super.initState();
    // Supabase 接続時のみ蔵書復元（UI描画後に実行）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookDataProvider.notifier).fetchBooks();
    });
  }

  void _startQuest() {
    final userBooks = ref.read(bookDataProvider).userBooks;
    final reading =
        userBooks.where((ub) => ub.status == BookStatus.reading).firstOrNull;
    final tsundoku =
        userBooks.where((ub) => ub.status == BookStatus.tsundoku).firstOrNull;
    final target = reading ?? tsundoku;
    if (target != null) {
      context.push('/reading?id=${target.id}');
    } else {
      context.go('/explore');
    }
  }

  void _showCompletedDetail(UserBook book) {
    CompletedBookDetailModal.show(context, book);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookDataProvider);
    final userBooks = state.userBooks;
    final isLoading = state.isLoading;

    // ステータス別にインラインでフィルタ（Provider再リビルドを1つに統合）
    final readingBooks =
        userBooks.where((ub) => ub.status == BookStatus.reading).toList();
    final tsundokuBooks =
        userBooks.where((ub) => ub.status == BookStatus.tsundoku).toList();
    final completedBooks =
        userBooks.where((ub) => ub.status == BookStatus.completed).toList();

    final hasBooks = userBooks.isNotEmpty;

    // 初回ローディング中かつデータ未取得時はスケルトン表示
    if (isLoading && !hasBooks) {
      return Scaffold(
        key: AppKeys.bookshelfScreen,
        appBar: AppBar(
          title: const Text('📚 書庫'),
        ),
        body: DungeonBackground(screenType: ScreenType.bookshelf,
          child: SemanticHelper.container(
            testId: 'sec_bookshelf_skeleton',
            label: '読み込み中',
            explicitChildNodes: true,
            child: _buildSkeletonLoading(),
          ),
        ),
      );
    }

    return Scaffold(
      key: AppKeys.bookshelfScreen,
      appBar: AppBar(
        title: const Text('📚 書庫'),
        actions: [
          SemanticHelper.interactive(
            testId: 'btn_bookshelf_search',
            label: '蔵書を検索',
            child: IconButton(
              key: AppKeys.librarySearchButton,
              icon: const Icon(Icons.search),
              tooltip: '蔵書を検索',
              onPressed: () => context.push('/library-search'),
            ),
          ),
          SemanticHelper.interactive(
            testId: 'btn_bookshelf_reading_queue',
            label: '次に読む',
            child: IconButton(
              key: AppKeys.readingQueueButton,
              icon: const Icon(Icons.format_list_numbered),
              tooltip: '次に読む',
              onPressed: () => context.push('/reading-queue'),
            ),
          ),
          SemanticHelper.interactive(
            testId: 'btn_bookshelf_stagnant_books',
            label: '積読放置',
            child: IconButton(
              key: AppKeys.stagnantBooksButton,
              icon: const Icon(Icons.hourglass_bottom),
              tooltip: '積読放置',
              onPressed: () => context.push('/stagnant-books'),
            ),
          ),
          SemanticHelper.interactive(
            testId: 'btn_bookshelf_reminder_settings',
            label: '読書リマインダー',
            child: IconButton(
              key: AppKeys.reminderSettingsButton,
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: '読書リマインダー',
              onPressed: () => context.push('/reminder-settings'),
            ),
          ),
          SemanticHelper.interactive(
            testId: 'btn_bookshelf_text_scale',
            label: '文字サイズ',
            child: IconButton(
              key: AppKeys.textScaleSettingsButton,
              icon: const Icon(Icons.format_size),
              tooltip: '文字サイズ',
              onPressed: () => context.push('/settings/text-scale'),
            ),
          ),
          SemanticHelper.interactive(
            testId: 'btn_bookshelf_theme_mode',
            label: 'テーマ設定',
            child: IconButton(
              key: AppKeys.themeModeEntry,
              icon: const Icon(Icons.brightness_6_outlined),
              tooltip: 'テーマ設定',
              onPressed: () => context.push('/settings/theme'),
            ),
          ),
          SemanticHelper.interactive(
            testId: 'btn_bookshelf_reduce_motion',
            label: '動きを減らす',
            child: IconButton(
              key: AppKeys.reduceMotionEntry,
              icon: const Icon(Icons.motion_photos_off_outlined),
              tooltip: '動きを減らす',
              onPressed: () => context.push('/settings/reduce-motion'),
            ),
          ),
          SemanticHelper.interactive(
            testId: 'btn_bookshelf_app_lock',
            label: 'アプリロック',
            child: IconButton(
              key: AppKeys.appLockSettingsButton,
              icon: const Icon(Icons.lock_outline),
              tooltip: 'アプリロック',
              onPressed: () => context.push('/settings/app-lock'),
            ),
          ),
          SemanticHelper.interactive(
            testId: 'btn_bookshelf_backup',
            label: 'バックアップ',
            child: IconButton(
              key: AppKeys.backupSettingsButton,
              icon: const Icon(Icons.cloud_upload_outlined),
              tooltip: 'バックアップ',
              onPressed: () => context.push('/settings/backup'),
            ),
          ),
          SemanticHelper.interactive(
            testId: 'btn_bookshelf_about',
            label: 'アプリについて',
            child: IconButton(
              key: AboutAppKeys.entryFromSettings,
              icon: const Icon(Icons.info_outline),
              tooltip: 'アプリについて',
              onPressed: () => context.push('/settings/about'),
            ),
          ),
          SemanticHelper.interactive(
            testId: 'btn_bookshelf_shelf_management',
            label: '自作棚',
            child: IconButton(
              icon: const Icon(Icons.collections_bookmark),
              tooltip: '自作棚',
              onPressed: () => context.push('/shelves'),
            ),
          ),
        ],
      ),
      body: DungeonBackground(screenType: ScreenType.bookshelf,
        child: SemanticHelper.container(
          testId: 'list_bookshelf',
          label: '書庫の本一覧',
          explicitChildNodes: true,
          child: ListView(
          children: [
          // Adventurer header (watches adventurerProvider internally)
          const AdventurerHeader(),

          // Streak
          const StreakDisplay(),

          const SizedBox(height: 8),

          // 今日のおすすめ（ツンドク本がある場合のみ）
          if (tsundokuBooks.isNotEmpty)
            SemanticHelper.interactive(
              testId: 'btn_recommendation_card',
              label: '今日のおすすめを見る',
              child: GestureDetector(
                onTap: () => context.push('/recommendations'),
                child: RecommendationCard(
                  recommendation: RecommendationService.pickOne(tsundokuBooks)!,
                ),
              ),
            ),

          // みんなが読んでいる（蔵書がある場合のみ）
          if (hasBooks) const SocialReadingSection(),

          // Daily quest
          SemanticHelper.container(
            testId: 'sec_daily_quest',
            label: '今日のクエスト',
            explicitChildNodes: true,
            child: DailyQuest(
              hasBooks: hasBooks,
              onStartQuest: _startQuest,
            ),
          ),

          // Reading section
          if (readingBooks.isNotEmpty)
            SemanticHelper.container(
              testId: 'sec_books_reading',
              label: '戦闘中！',
              explicitChildNodes: true,
              child: BookShelfSection(
              title: '戦闘中！',
              icon: Icons.menu_book,
              iconColor: AppTheme.readingColor,
              isOpen: _readingOpen,
              onToggle: () => setState(() => _readingOpen = !_readingOpen),
              children: readingBooks
                  .map((book) => SemanticHelper.container(
                        testId: 'item_book_${book.id}',
                        explicitChildNodes: true,
                        child: BookCard(
                        book: book,
                        onTap: () => context.push('/reading?id=${book.id}'),
                        onEdit: () => EditBookModal.show(context, book),
                        onDelete: () =>
                            ref.read(bookDataProvider.notifier).removeUserBook(book.id),
                      ),
                      ))
                  .toList(),
            ),
            ),

          // Tsundoku section
          SemanticHelper.container(
            testId: 'sec_books_tsundoku',
            label: '待機中の冒険',
            explicitChildNodes: true,
            child: BookShelfSection(
            title: '待機中の冒険',
            icon: Icons.bookmark,
            iconColor: AppTheme.tsundokuColor,
            isOpen: _tsundokuOpen,
            onToggle: () => setState(() => _tsundokuOpen = !_tsundokuOpen),
            children: tsundokuBooks
                .map((book) => SemanticHelper.container(
                      testId: 'item_book_${book.id}',
                      explicitChildNodes: true,
                      child: BookCard(
                      book: book,
                      onTap: () => context.push('/reading?id=${book.id}'),
                      onEdit: () => EditBookModal.show(context, book),
                      onDelete: () =>
                          ref.read(bookDataProvider.notifier).removeUserBook(book.id),
                    ),
                    ))
                .toList(),
          ),
          ),

          // Completed section
          if (completedBooks.isNotEmpty)
            SemanticHelper.container(
              testId: 'sec_books_completed',
              label: '討伐済',
              explicitChildNodes: true,
              child: BookShelfSection(
              title: '討伐済',
              icon: Icons.check_circle,
              iconColor: AppTheme.completedColor,
              isOpen: _completedOpen,
              onToggle: () => setState(() => _completedOpen = !_completedOpen),
              children: completedBooks
                  .map((book) => SemanticHelper.container(
                        testId: 'item_book_${book.id}',
                        explicitChildNodes: true,
                        child: BookCard(
                        book: book,
                        onTap: () => _showCompletedDetail(book),
                        onEdit: () => EditBookModal.show(context, book),
                        onDelete: () =>
                            ref.read(bookDataProvider.notifier).removeUserBook(book.id),
                      ),
                      ))
                  .toList(),
            ),
            ),

          // Empty state
          if (!hasBooks)
            SemanticHelper.container(
              testId: 'sec_bookshelf_empty',
              label: '書庫はまだ空です',
              explicitChildNodes: true,
              child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text('📚', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  const Text(
                    '書庫はまだ空です',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '最初の冒険の書を登録して、ダンジョンへの扉を開きましょう！',
                    style:
                        TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SemanticHelper.interactive(
                    testId: 'btn_empty_state_explore',
                    label: '探索に出る',
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/explore'),
                      icon: const Text('🧭'),
                      label: const Text('探索に出る'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),

          const SizedBox(height: 32),
        ],
      ),
        ),
        ),
    );
  }

  /// スケルトンローディング表示
  Widget _buildSkeletonLoading() {
    return ListView(
      children: [
        const SizedBox(height: 16),
        // 3つのスケルトンカード
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // 表紙プレースホルダ
                  Container(
                    width: 40,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // タイトル・著者プレースホルダ
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
