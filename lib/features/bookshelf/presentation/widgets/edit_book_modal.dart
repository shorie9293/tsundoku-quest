import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/testing/widget_keys.dart';
import '../../../../../domain/models/user_book.dart';
import '../../../../../shared/providers/book_data_provider.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 本の編集モーダル — BottomSheet で表示
///
/// 媒体・読書状態・評価・メモを編集し保存する。
class EditBookModal extends ConsumerStatefulWidget {
  final UserBook book;

  const EditBookModal({super.key, required this.book});

  /// BottomSheet として表示する静的メソッド
  static Future<void> show(BuildContext context, UserBook book) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBackground,
      builder: (_) => ProviderScope(
        overrides: const [],
        child: EditBookModal(book: book),
      ),
    );
  }

  @override
  ConsumerState<EditBookModal> createState() => _EditBookModalState();
}

class _EditBookModalState extends ConsumerState<EditBookModal> {
  late BookMedium _medium;
  late BookStatus _status;
  late int _rating;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final book = widget.book;
    _medium = book.medium;
    _status = book.status;
    _rating = book.rating ?? 0;
    _notesController = TextEditingController(text: book.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(bookDataProvider.notifier).updateUserBook(
          id: widget.book.id,
          status: _status,
          medium: _medium,
          rating: _rating > 0 ? _rating : null,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );
    Navigator.of(context).pop();
  }

  String _statusLabel(BookStatus status) {
    switch (status) {
      case BookStatus.tsundoku:
        return '待機中';
      case BookStatus.reading:
        return '戦闘中！';
      case BookStatus.completed:
        return '討伐済み';
    }
  }

  String _mediumIcon(BookMedium medium) {
    switch (medium) {
      case BookMedium.physical:
        return '📖';
      case BookMedium.ebook:
        return '📱';
      case BookMedium.audiobook:
        return '🎧';
    }
  }

  String _mediumLabel(BookMedium medium) {
    switch (medium) {
      case BookMedium.physical:
        return '物理';
      case BookMedium.ebook:
        return '電子';
      case BookMedium.audiobook:
        return 'オーディオ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: AppKeys.bookEditModal,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ━━━ タイトル行 ━━━
              SemanticHelper.container(
                testId: 'sec_edit_modal_header',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '✏️ 編集',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SemanticHelper.interactive(
                      testId: SemanticHelper.createTestId('btn', 'close_edit_modal'),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ━━━ 媒体選択 ━━━
              SemanticHelper.container(
                testId: 'sec_medium_selector',
                label: '媒体選択',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '媒体',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<BookMedium>(
                      segments: BookMedium.values.map((medium) {
                        return ButtonSegment<BookMedium>(
                          value: medium,
                          label: Text('${_mediumIcon(medium)} ${_mediumLabel(medium)}'),
                        );
                      }).toList(),
                      selected: {_medium},
                      onSelectionChanged: (Set<BookMedium> selected) {
                        setState(() => _medium = selected.first);
                      },
                      style: SegmentedButton.styleFrom(
                        backgroundColor: AppTheme.cardBackground,
                        foregroundColor: AppTheme.textSecondary,
                        selectedBackgroundColor: AppTheme.accent.withAlpha(60),
                        selectedForegroundColor: AppTheme.active,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ━━━ 読書状態 ━━━
              SemanticHelper.container(
                testId: 'sec_status_selector',
                label: '読書状態選択',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '読書状態',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<BookStatus>(
                      segments: BookStatus.values.map((status) {
                        return ButtonSegment<BookStatus>(
                          value: status,
                          label: Text(_statusLabel(status)),
                        );
                      }).toList(),
                      selected: {_status},
                      onSelectionChanged: (Set<BookStatus> selected) {
                        setState(() => _status = selected.first);
                      },
                      style: SegmentedButton.styleFrom(
                        backgroundColor: AppTheme.cardBackground,
                        foregroundColor: AppTheme.textSecondary,
                        selectedBackgroundColor: AppTheme.accent.withAlpha(60),
                        selectedForegroundColor: AppTheme.active,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ━━━ 評価 ━━━
              SemanticHelper.container(
                testId: 'sec_rating',
                label: '評価',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '評価',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        final starIndex = index + 1;
                        final isFilled = starIndex <= _rating;
                        return SemanticHelper.interactive(
                          testId: SemanticHelper.createTestId(
                            'btn',
                            'star_$starIndex',
                          ),
                          label: '評価 $starIndex',
                          child: IconButton(
                            icon: Icon(
                              isFilled ? Icons.star : Icons.star_border,
                              color: isFilled
                                  ? AppTheme.badge
                                  : AppTheme.textSecondary,
                              size: 32,
                            ),
                            onPressed: () {
                              setState(() {
                                _rating = _rating == starIndex ? 0 : starIndex;
                              });
                            },
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ━━━ メモ ━━━
              SemanticHelper.container(
                testId: 'sec_notes',
                label: 'メモ',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'メモ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SemanticHelper.textField(
                      testId: SemanticHelper.createTestId('txt', 'edit_notes'),
                      label: 'メモ入力',
                      child: TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: '読書メモを入力…',
                          hintStyle: const TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.accent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ━━━ 保存ボタン ━━━
              SemanticHelper.interactive(
                testId: SemanticHelper.createTestId('btn', 'save_edit'),
                label: '保存',
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '保存',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
