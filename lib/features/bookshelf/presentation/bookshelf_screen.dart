import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

/// 書庫画面（ホーム）
class BookshelfScreen extends ConsumerStatefulWidget {
  const BookshelfScreen({super.key});

  @override
  ConsumerState<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends ConsumerState<BookshelfScreen> {
  bool _readingOpen = true;
  bool _tsundokuOpen = true;
  bool _completedOpen = false;

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
        body: DungeonBackground(
          child: _buildSkeletonLoading(),
        ),
      );
    }

    return Scaffold(
      key: AppKeys.bookshelfScreen,
      appBar: AppBar(
        title: const Text('📚 書庫'),
      ),
      body: DungeonBackground(
        child: ListView(
          children: [
          // Adventurer header (watches adventurerProvider internally)
          const AdventurerHeader(),

          // Streak
          const StreakDisplay(),

          const SizedBox(height: 8),

          // 今日のおすすめ（ツンドク本がある場合のみ）
          if (tsundokuBooks.isNotEmpty)
            GestureDetector(
              onTap: () => context.push('/recommendations'),
              child: RecommendationCard(
                recommendation: RecommendationService.pickOne(tsundokuBooks)!,
              ),
            ),

          // みんなが読んでいる（蔵書がある場合のみ）
          if (hasBooks) const SocialReadingSection(),

          // Daily quest
          DailyQuest(
            hasBooks: hasBooks,
            onStartQuest: _startQuest,
          ),

          // Reading section
          if (readingBooks.isNotEmpty)
            BookShelfSection(
              title: '戦闘中！',
              icon: Icons.menu_book,
              iconColor: AppTheme.readingColor,
              isOpen: _readingOpen,
              onToggle: () => setState(() => _readingOpen = !_readingOpen),
              children: readingBooks
                  .map((book) => BookCard(
                        book: book,
                        onTap: () => context.push('/reading?id=${book.id}'),
                        onEdit: () => EditBookModal.show(context, book),
                        onDelete: () =>
                            ref.read(bookDataProvider.notifier).removeUserBook(book.id),
                      ))
                  .toList(),
            ),

          // Tsundoku section
          BookShelfSection(
            title: '待機中の冒険',
            icon: Icons.bookmark,
            iconColor: AppTheme.tsundokuColor,
            isOpen: _tsundokuOpen,
            onToggle: () => setState(() => _tsundokuOpen = !_tsundokuOpen),
            children: tsundokuBooks
                .map((book) => BookCard(
                      book: book,
                      onTap: () => context.push('/reading?id=${book.id}'),
                      onEdit: () => EditBookModal.show(context, book),
                      onDelete: () =>
                          ref.read(bookDataProvider.notifier).removeUserBook(book.id),
                    ))
                .toList(),
          ),

          // Completed section
          BookShelfSection(
            title: '討伐済',
            icon: Icons.check_circle,
            iconColor: AppTheme.completedColor,
            isOpen: _completedOpen,
            onToggle: () => setState(() => _completedOpen = !_completedOpen),
            children: completedBooks
                .map((book) => BookCard(
                      book: book,
                      onTap: () => context.go('/history'),
                      onEdit: () => EditBookModal.show(context, book),
                      onDelete: () =>
                          ref.read(bookDataProvider.notifier).removeUserBook(book.id),
                    ))
                .toList(),
          ),

          // Empty state
          if (!hasBooks)
            Padding(
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
                  ElevatedButton.icon(
                    onPressed: () => context.go('/explore'),
                    icon: const Text('🧭'),
                    label: const Text('探索に出る'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),
        ],
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
