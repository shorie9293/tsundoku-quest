import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/testing/widget_keys.dart';
import '../../../core/widgets/dungeon_background.dart';
import '../../../domain/models/book_shelf.dart';
import '../../../domain/models/user_book.dart';
import '../../../shared/providers/book_data_provider.dart';
import '../../shelves/data/shelf_controller.dart';
import '../domain/library_query.dart';
import 'widgets/book_card.dart';
import 'widgets/edit_book_modal.dart';

/// 蔵書検索・絞り込み・並び替え画面
class LibrarySearchScreen extends ConsumerStatefulWidget {
  /// 試練用注入（null の場合は Provider から取得）
  final List<UserBook>? booksOverride;

  /// 試練用注入（null の場合は Provider から取得）
  final List<BookShelf>? shelvesOverride;

  const LibrarySearchScreen({
    super.key,
    this.booksOverride,
    this.shelvesOverride,
  });

  @override
  ConsumerState<LibrarySearchScreen> createState() =>
      _LibrarySearchScreenState();
}

class _LibrarySearchScreenState extends ConsumerState<LibrarySearchScreen> {
  LibraryQuery _query = const LibraryQuery();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.shelvesOverride == null) {
      try {
        ref.read(shelfControllerProvider.notifier).load();
      } catch (_) {
        // 試練・オフライン環境で Provider 初期化に失敗しても
        // 画面描画は続行する（例外をゾーンに漏らさない）
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _updateQuery(LibraryQuery next) {
    setState(() => _query = next);
  }

  void _clearSearchText() {
    _textController.clear();
    _updateQuery(_query.copyWith(text: ''));
  }

  void _toggleStatus(BookStatus status) {
    final current = Set<BookStatus>.of(_query.statuses);
    if (!current.remove(status)) current.add(status);
    _updateQuery(_query.copyWith(statuses: current));
  }

  void _selectShelf(String? shelfId) {
    if (shelfId == null) {
      _updateQuery(_query.copyWith(clearShelfId: true));
    } else {
      _updateQuery(_query.copyWith(shelfId: shelfId));
    }
  }

  void _reset() {
    _textController.clear();
    _updateQuery(const LibraryQuery());
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.booksOverride ?? ref.watch(bookDataProvider).userBooks;
    final shelves = widget.shelvesOverride ??
        ref.watch(shelfControllerProvider) ??
        const <BookShelf>[];
    final membership = {
      for (final s in shelves) s.id: s.userBookIds.toSet(),
    };
    final results = LibraryQueryService.apply(books, _query,
        membership: membership);

    return Scaffold(
      key: AppKeys.librarySearchScreen,
      appBar: AppBar(title: const Text('🔍 蔵書検索')),
      body: DungeonBackground(
        screenType: ScreenType.bookshelf,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                key: AppKeys.librarySearchField,
                controller: _textController,
                onChanged: (value) =>
                    _updateQuery(_query.copyWith(text: value)),
                decoration: InputDecoration(
                  hintText: '書名・著者で検索',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isNotEmpty
                      ? IconButton(
                          key: AppKeys.librarySearchClearButton,
                          icon: const Icon(Icons.clear),
                          tooltip: '検索語をクリア',
                          onPressed: _clearSearchText,
                        )
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                key: AppKeys.libraryStatusFilterChips,
                spacing: 8,
                children: [
                  for (final status in BookStatus.values)
                    FilterChip(
                      key: ValueKey('libfilter_status_${status.value}'),
                      label: Text(_statusLabel(status)),
                      selected: _query.statuses.contains(status),
                      onSelected: (_) => _toggleStatus(status),
                    ),
                ],
              ),
            ),
            if (shelves.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  key: AppKeys.libraryShelfFilterChips,
                  children: [
                    ChoiceChip(
                      key: const ValueKey('libfilter_shelf_all'),
                      label: const Text('すべて'),
                      selected: _query.shelfId == null,
                      onSelected: (_) => _selectShelf(null),
                    ),
                    for (final shelf in shelves)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          key: ValueKey('libfilter_shelf_${shelf.id}'),
                          label: Text(shelf.name),
                          selected: _query.shelfId == shelf.id,
                          onSelected: (_) => _selectShelf(shelf.id),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  PopupMenuButton<LibrarySortOrder>(
                    key: AppKeys.librarySortButton,
                    tooltip: '並び替え',
                    initialValue: _query.sortOrder,
                    onSelected: (order) =>
                        _updateQuery(_query.copyWith(sortOrder: order)),
                    itemBuilder: (_) => [
                      for (final order in LibrarySortOrder.values)
                        PopupMenuItem(
                          key: ValueKey('libsort_${order.name}'),
                          value: order,
                          child: Text(order.label),
                        ),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort,
                            size: 18, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _query.sortOrder.label,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const Icon(Icons.arrow_drop_down,
                            size: 18, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_query.activeFilterCount > 0)
                    TextButton.icon(
                      key: AppKeys.libraryResetButton,
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('リセット'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  key: AppKeys.libraryResultCount,
                  LibraryQueryService.resultLabel(results.length),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: results.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      key: AppKeys.libraryResultList,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final ub = results[index];
                        return BookCard(
                          book: ub,
                          onTap: () => context.push('/reading?id=${ub.id}'),
                          onEdit: () => EditBookModal.show(context, ub),
                          onDelete: () => ref
                              .read(bookDataProvider.notifier)
                              .removeUserBook(ub.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: AppKeys.libraryEmptyState,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            '条件に合う本が見つかりません',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          if (_query.activeFilterCount > 0)
            TextButton(
              onPressed: _reset,
              child: const Text('検索条件をリセット'),
            ),
        ],
      ),
    );
  }

  String _statusLabel(BookStatus status) {
    switch (status) {
      case BookStatus.tsundoku:
        return '積読';
      case BookStatus.reading:
        return '読書中';
      case BookStatus.completed:
        return '討伐済';
    }
  }
}
