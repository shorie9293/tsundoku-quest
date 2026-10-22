import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_provider.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

/// 「次に読む」読書キュー画面
///
/// - キューの先頭1冊を「次に読む一冊」として表示（無ければ空状態メッセージ）
/// - 順序付きリストで上下移動・削除が可能
/// - 積読（status == tsundoku）からキューへ追加できるボトムシート
///
/// 試練では `readingQueueRepositoryProvider` / `bookDataProvider` を
/// ProviderScope overrides で差し替えて注入する。
class ReadingQueueScreen extends ConsumerWidget {
  const ReadingQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(readingQueueControllerProvider);
    final userBooks = ref.watch(bookDataProvider).userBooks;

    final byId = {for (final ub in userBooks) ub.id: ub};
    final queued = <(ReadingQueueEntry, UserBook)>[
      for (final e in entries)
        if (byId[e.userBookId] case final ub?) (e, ub),
    ];
    final next = queued.isEmpty ? null : queued.first;
    final rest = queued.isEmpty ? queued : queued.sublist(1);
    final queueIds = {for (final e in entries) e.userBookId};
    final tsundokuBooks = userBooks
        .where((ub) => ub.status == BookStatus.tsundoku && !queueIds.contains(ub.id))
        .toList();

    return Scaffold(
      key: AppKeys.readingQueueScreen,
      appBar: AppBar(title: const Text('📖 次に読む')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (next != null)
              _NextCard(ub: next.$2)
            else
              SemanticHelper.container(
                testId: 'txt_reading_queue_empty',
                label: 'キューが空です',
                child: const Padding(
                  key: AppKeys.readingQueueEmpty,
                  padding: EdgeInsets.all(16),
                  child: Text('キューが空です。積読から本を追加しよう。'),
                ),
              ),
            const Divider(height: 1),
            if (rest.isNotEmpty)
              Expanded(
                // 一覧 identifier は外側で1回だけ付与する（行ごとの重複発行を避ける）
                child: SemanticHelper.container(
                  testId: 'list_reading_queue',
                  label: '読書キューの一覧',
                  explicitChildNodes: true,
                  child: ListView.builder(
                    key: AppKeys.readingQueueList,
                    itemCount: rest.length,
                    itemBuilder: (context, index) =>
                        _QueueTile(entry: rest[index].$1, ub: rest[index].$2),
                  ),
                ),
              )
            else
              const Expanded(
                child: Center(child: Text('待ちの本はまだ無い')),
              ),
          ],
        ),
      ),
      floatingActionButton: SemanticHelper.interactive(
        testId: 'btn_reading_queue_add',
        label: '積読から追加',
        child: FloatingActionButton(
          key: AppKeys.readingQueueAddButton,
          onPressed: () => _showAddSheet(context, ref, tsundokuBooks),
          tooltip: '積読から追加',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAddSheet(
    BuildContext context,
    WidgetRef ref,
    List<UserBook> tsundokuBooks,
  ) {
    final controller = ref.read(readingQueueControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: tsundokuBooks.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('追加できる積読がありません'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('積読から追加する'),
                  ),
                  for (final ub in tsundokuBooks)
                    SemanticHelper.interactive(
                      testId: 'btn_reading_queue_add_book_${ub.id}',
                      label: '積読「${ub.book?.title ?? '無題の本'}」をキューに追加',
                      child: ListTile(
                        title: Text(ub.book?.title ?? '無題の本'),
                        subtitle: Text(ub.id),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          controller.enqueue(ub.id);
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// 「次に読む一冊」カード
class _NextCard extends StatelessWidget {
  const _NextCard({required this.ub});

  final UserBook ub;

  @override
  Widget build(BuildContext context) {
    return SemanticHelper.interactive(
      testId: 'btn_reading_queue_next_start',
      label: '次に読む一冊「${ub.book?.title ?? '無題の本'}」を開く',
      child: Card(
        key: AppKeys.readingQueueNextCard,
        margin: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: AppKeys.readingQueueStartFromCard,
          // 読書画面へ遷移する（id は userBookId。bookId ではない）
          onTap: () => context.push('/reading?id=${ub.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '⚔️ 次に読む一冊',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  ub.book?.title ?? '無題の本',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// キューの1行（上下移動・削除）
class _QueueTile extends ConsumerWidget {
  const _QueueTile({required this.entry, required this.ub});

  final ReadingQueueEntry entry;
  final UserBook ub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(readingQueueControllerProvider.notifier);
    return SemanticHelper.container(
      testId: 'reading_queue_row_${entry.userBookId}',
      label: 'キュー${entry.position}番「${ub.book?.title ?? '無題の本'}」',
      explicitChildNodes: true,
      child: InkWell(
        // 行タップでも読書画面へ（id は userBookId）
        key: ValueKey('reading_queue_start_${entry.userBookId}'),
        onTap: () => context.push('/reading?id=${ub.id}'),
        child: ListTile(
          key: ValueKey('reading_queue_item_${entry.userBookId}'),
          leading: Text('#${entry.position}'),
          title: Text(ub.book?.title ?? '無題の本'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SemanticHelper.interactive(
                testId: 'btn_reading_queue_up_${entry.userBookId}',
                label: '前へ移動',
                child: IconButton(
                  key: ValueKey('reading_queue_up_${entry.userBookId}'),
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: '前へ',
                  onPressed: () => controller.moveUp(entry.userBookId),
                ),
              ),
              SemanticHelper.interactive(
                testId: 'btn_reading_queue_down_${entry.userBookId}',
                label: '後へ移動',
                child: IconButton(
                  key: ValueKey('reading_queue_down_${entry.userBookId}'),
                  icon: const Icon(Icons.arrow_downward),
                  tooltip: '後へ',
                  onPressed: () => controller.moveDown(entry.userBookId),
                ),
              ),
              SemanticHelper.interactive(
                testId: 'btn_reading_queue_remove_${entry.userBookId}',
                label: 'キューから削除',
                child: IconButton(
                  key: ValueKey('reading_queue_remove_${entry.userBookId}'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '削除',
                  onPressed: () => controller.dequeue(entry.userBookId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
