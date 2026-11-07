import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../bookshelf/data/query_preferences.dart';
import '../data/reading_notes_provider.dart';
import '../domain/reading_note_query.dart';
import '../widgets/reading_note_card.dart';

/// 読書感想の検索・絞り込み画面
class ReadingNoteSearchScreen extends ConsumerStatefulWidget {
  final List<ReadingNoteItem>? notesOverride;

  /// 検索条件の保存先。null なら永続化しない（既存挙動と同一）
  final ReadingNoteQueryPreferencesStore? queryPreferences;

  const ReadingNoteSearchScreen({
    super.key,
    this.notesOverride,
    this.queryPreferences,
  });

  @override
  ConsumerState<ReadingNoteSearchScreen> createState() =>
      _ReadingNoteSearchScreenState();
}

class _ReadingNoteSearchScreenState
    extends ConsumerState<ReadingNoteSearchScreen> {
  ReadingNoteQuery _query = const ReadingNoteQuery();
  final TextEditingController _controller = TextEditingController();

  /// ユーザーが一度でも操作したか（非同期復元に上書きされないための番人）
  bool _userTouched = false;

  @override
  void initState() {
    super.initState();
    if (widget.queryPreferences != null) {
      unawaited(_restoreQuery());
    }
  }

  Future<void> _restoreQuery() async {
    final store = widget.queryPreferences;
    if (store == null) return;
    ReadingNoteQuery? loaded;
    try {
      loaded = await store.load();
    } catch (_) {
      return; // 復元失敗は既定条件のまま（画面を壊さない）
    }
    if (!mounted || loaded == null) return;
    final restored = loaded;
    if (_userTouched) return;
    setState(() => _query = restored);
    if (_controller.text != restored.text) {
      _controller.value = TextEditingValue(
        text: restored.text,
        selection: TextSelection.collapsed(offset: restored.text.length),
      );
    }
  }

  void _persist() {
    final store = widget.queryPreferences;
    if (store == null) return;
    unawaited(_saveQuietly(store));
  }

  Future<void> _saveQuietly(ReadingNoteQueryPreferencesStore store) async {
    try {
      await store.save(_query);
    } catch (_) {
      // 永続化失敗は無音（検索操作を妨げない）
    }
  }

  @override
  void dispose() {
    _persist();
    _controller.dispose();
    super.dispose();
  }

  /// 絞り込み・並び順の変更（即保存）
  void _updateQuery(ReadingNoteQuery next) {
    _userTouched = true;
    setState(() => _query = next);
    _persist();
  }

  /// 検索語の変更（入力中は保存しない。確定・dispose で保存）
  void _updateText(String value) {
    _userTouched = true;
    setState(() => _query = _query.copyWith(text: value));
  }

  @override
  Widget build(BuildContext context) {
    final List<ReadingNoteItem> notes =
        widget.notesOverride ?? ref.watch(readingNotesProvider);
    final results = ReadingNoteQueryService.apply(notes, _query);
    final bookTitles = ReadingNoteQueryService.availableBookTitles(notes);

    return Scaffold(
      key: AppKeys.readingNoteSearchScreen,
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('🔍 感想を探す')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: AppKeys.readingNoteSearchField,
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '本文・書籍名で検索',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _updateText,
                    onSubmitted: (value) {
                      _userTouched = true;
                      _persist();
                    },
                  ),
                ),
                IconButton(
                  key: AppKeys.readingNoteSearchClear,
                  icon: const Icon(Icons.clear),
                  tooltip: '検索をクリア',
                  onPressed: () {
                    _controller.clear();
                    _updateQuery(_query.copyWith(text: ''));
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                PopupMenuButton<ReadingNoteSortOrder>(
                  key: AppKeys.readingNoteSortMenu,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, size: 18),
                        const SizedBox(width: 4),
                        Text(_query.sortOrder.label,
                            style: const TextStyle(fontSize: 13)),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                  onSelected: (order) =>
                      _updateQuery(_query.copyWith(sortOrder: order)),
                  itemBuilder: (_) => ReadingNoteSortOrder.values
                      .map((o) => PopupMenuItem(
                            value: o,
                            child: Text(o.label),
                          ))
                      .toList(),
                ),
                const Spacer(),
                TextButton(
                  key: AppKeys.readingNoteReset,
                  onPressed: _query.isDefault
                      ? null
                      : () {
                          _controller.clear();
                          _updateQuery(const ReadingNoteQuery());
                        },
                  child: const Text('条件をクリア'),
                ),
              ],
            ),
          ),
          if (bookTitles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                key: AppKeys.readingNoteBookChips,
                spacing: 6,
                children: bookTitles
                    .map((title) => FilterChip(
                          label: Text(title, style: const TextStyle(fontSize: 12)),
                          selected: _query.bookTitles.contains(title),
                          onSelected: (selected) {
                            final next = {..._query.bookTitles};
                            selected ? next.add(title) : next.remove(title);
                            _updateQuery(_query.copyWith(bookTitles: next));
                          },
                        ))
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              key: AppKeys.readingNoteContentChips,
              spacing: 6,
              children: ReadingNoteContentFilter.values
                  .map((f) => FilterChip(
                        label: Text(f.label,
                            style: const TextStyle(fontSize: 12)),
                        selected: _query.contentFilters.contains(f),
                        onSelected: (selected) {
                          final next = {..._query.contentFilters};
                          selected ? next.add(f) : next.remove(f);
                          _updateQuery(_query.copyWith(contentFilters: next));
                        },
                      ))
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                ReadingNoteQueryService.resultLabel(results.length),
                key: AppKeys.readingNoteResultLabel,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Container(
                    key: AppKeys.readingNoteEmpty,
                    alignment: Alignment.center,
                    child: const Text('条件に合う感想がありません'),
                  )
                : ListView.builder(
                    key: AppKeys.readingNoteList,
                    itemCount: results.length,
                    itemBuilder: (context, index) =>
                        ReadingNoteCard(note: results[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
