import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/search/search_history.dart';
import '../../../../core/search/search_history_chips.dart';
import '../../../../core/search/search_history_store.dart';
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

  /// 検索語履歴の保存先。null なら SharedPreferences 実装を使う
  final SearchHistoryStore? searchHistoryStore;

  const ReadingNoteSearchScreen({
    super.key,
    this.notesOverride,
    this.queryPreferences,
    this.searchHistoryStore,
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

  /// 検索語履歴（新しい順・最大 [SearchHistory.maxEntries] 件）
  SearchHistory _history = SearchHistory.empty();

  SearchHistoryStore get _historyStore =>
      widget.searchHistoryStore ?? const SharedPreferencesSearchHistoryStore();

  @override
  void initState() {
    super.initState();
    if (widget.queryPreferences != null) {
      unawaited(_restoreQuery());
    }
    unawaited(_restoreHistory());
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
    _rememberSearchTerm(silent: true);
    _persist();
    _controller.dispose();
    super.dispose();
  }

  /// 履歴を復元する。ユーザーが既に検索していれば上書きしない。
  Future<void> _restoreHistory() async {
    SearchHistory loaded;
    try {
      loaded = await _historyStore.load();
    } catch (_) {
      return; // 復元失敗は履歴なしのまま（画面を壊さない）
    }
    if (!mounted || loaded.entries.isEmpty) return;
    if (_history.entries.isNotEmpty) return; // ユーザー操作を優先
    setState(() => _history = loaded);
  }

  /// 現在の検索語を履歴へ積む（空語は積まない）。
  /// [silent] は dispose からの呼び出し用（再描画しない）。
  void _rememberSearchTerm({bool silent = false}) {
    final text = _query.text;
    if (SearchHistory.normalize(text).isEmpty) return;
    final next = _history.add(text);
    if (!silent) {
      setState(() => _history = next);
    }
    unawaited(_saveHistoryQuietly(next));
  }

  Future<void> _saveHistoryQuietly(SearchHistory history) async {
    try {
      await _historyStore.save(history);
    } catch (_) {
      // 永続化失敗は無音（検索操作を妨げない）
    }
  }

  /// 履歴チップの選択で検索語を差し替え、結果を再計算する。
  void _applyHistoryTerm(String term) {
    _userTouched = true;
    _controller.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    setState(() => _query = _query.copyWith(text: term));
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
                      _rememberSearchTerm();
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
          if (_history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: SearchHistoryChips(
                key: AppKeys.readingNoteSearchHistoryChips,
                entries: _history.entries,
                keyPrefix: 'notehistory_chip',
                onSelected: _applyHistoryTerm,
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
