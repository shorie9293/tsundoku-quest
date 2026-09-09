import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dungeon_background.dart';
import '../../../domain/models/book_shelf.dart';
import '../../../domain/models/user_book.dart';
import '../../../shared/providers/book_data_provider.dart';
import '../data/shelf_controller.dart';

/// 自作棚を一覧・管理する画面（整理軸: タグ/コレクション）
class ShelfManagementScreen extends ConsumerStatefulWidget {
  const ShelfManagementScreen({super.key});

  @override
  ConsumerState<ShelfManagementScreen> createState() =>
      _ShelfManagementScreenState();
}

/// 棚の色パレット（Material 300系）
const _palette = <int>[
  0xFF90CAF9, // blue
  0xFFA5D6A7, // green
  0xFFFFCC80, // orange
  0xFFCE93D8, // purple
  0xFFEF9A9A, // red
  0xFF80DEEA, // cyan
];

class _ShelfManagementScreenState extends ConsumerState<ShelfManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shelfControllerProvider.notifier).load();
    });
  }

  Future<void> _createShelf() async {
    final name = await _promptName(context, title: '新しい棚を作る');
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(shelfControllerProvider.notifier)
        .createShelf(name.trim(), colorValue: _nextColor());
  }

  int _nextColor() {
    final count = ref.read(shelfControllerProvider).length;
    return _palette[count % _palette.length];
  }

  Future<void> _rename(BookShelf shelf) async {
    final name = await _promptName(context,
        title: '棚名を変更', initial: shelf.name);
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(shelfControllerProvider.notifier)
        .renameShelf(shelf.id, name.trim());
  }

  Future<void> _delete(BookShelf shelf) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('棚を削除'),
        content: Text('「${shelf.name}」を削除しますか？\n中の本は削除されません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(shelfControllerProvider.notifier)
          .deleteShelf(shelf.id);
    }
  }

  Future<void> _editBooks(BookShelf shelf) async {
    final books = ref.read(bookDataProvider).userBooks;
    final selected = shelf.userBookIds.toSet();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('${shelf.name} に入れる本'),
            content: SizedBox(
              width: double.maxFinite,
              height: 320,
              child: books.isEmpty
                  ? const Center(child: Text('蔵書がありません'))
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final ub in books)
                          CheckboxListTile(
                            value: selected.contains(ub.id),
                            title: Text(
                              ub.book?.title ?? '（本の情報なし）',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            dense: true,
                            onChanged: (checked) async {
                              final c = ref
                                  .read(shelfControllerProvider.notifier);
                              if (checked == true) {
                                selected.add(ub.id);
                                await c.addBook(shelf.id, ub.id);
                              } else {
                                selected.remove(ub.id);
                                await c.removeBook(shelf.id, ub.id);
                              }
                              if (dialogContext.mounted) {
                                setDialogState(() {});
                              }
                            },
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '例: 積ん読の山',
              counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shelves = ref.watch(shelfControllerProvider);
    final userBooks = ref.watch(bookDataProvider).userBooks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 自作棚'),
        actions: [
          IconButton(
            tooltip: '棚を作る',
            icon: const Icon(Icons.add),
            onPressed: _createShelf,
          ),
        ],
      ),
      body: DungeonBackground(
        screenType: ScreenType.bookshelf,
        child: shelves.isEmpty
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final shelf in shelves)
                    _ShelfCard(
                      shelf: shelf,
                      userBooks: userBooks,
                      onRename: () => _rename(shelf),
                      onDelete: () => _delete(shelf),
                      onEditBooks: () => _editBooks(shelf),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🗂️', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              '自作棚はまだありません',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '右上の ＋ から棚を作って、本をテーマ別に整理しましょう',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  final BookShelf shelf;
  final List<UserBook> userBooks;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onEditBooks;

  const _ShelfCard({
    required this.shelf,
    required this.userBooks,
    required this.onRename,
    required this.onDelete,
    required this.onEditBooks,
  });

  @override
  Widget build(BuildContext context) {
    final members = userBooks
        .where((ub) => shelf.userBookIds.contains(ub.id))
        .toList();
    final completed =
        members.where((ub) => ub.status == BookStatus.completed).length;
    final progress = members.isEmpty ? 0.0 : completed / members.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppTheme.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(shelf.colorValue),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.collections_bookmark,
                  color: Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shelf.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    members.isEmpty
                        ? '0冊'
                        : '$completed / ${members.length}冊 読了',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppTheme.border,
                      valueColor:
                          const AlwaysStoppedAnimation(AppTheme.completedColor),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '棚の操作',
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    onEditBooks();
                  case 'rename':
                    onRename();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('本を入れる/外す')),
                PopupMenuItem(value: 'rename', child: Text('棚名を変更')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('削除', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
