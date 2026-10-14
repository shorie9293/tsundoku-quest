import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/testing/widget_keys.dart';
import '../../../core/widgets/dungeon_background.dart';
import '../../../shared/providers/book_data_provider.dart';
import '../domain/stagnation.dart';

/// 積読の長期放置検知と優先提示 画面
///
/// 停滞本（読了以外で createdAt から既定 30 日以上経過）を抽出し、
/// 閾値チップ・理由チップ・書名/著者検索で絞り込んで一覧表示する。
class StagnantBooksScreen extends ConsumerStatefulWidget {
  /// 試練用注入（null の場合は Provider から取得）
  final List<StagnantBook>? entriesOverride;

  const StagnantBooksScreen({super.key, this.entriesOverride});

  @override
  ConsumerState<StagnantBooksScreen> createState() =>
      _StagnantBooksScreenState();
}

class _StagnantBooksScreenState extends ConsumerState<StagnantBooksScreen> {
  int _minDays = StagnationService.defaultMinDays;
  StagnationReason? _reason;
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _clearSearchText() {
    _textController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entriesOverride ?? _detectEntries();

    // 閾値チップは注入された entries に対しても適用する
    // （entriesOverride 注入時も本番と同じ挙動を保ち、表示と操作を一致させる）
    var visible = StagnationService.sortByDays(
      StagnationService.filterByReason(
        entries.where((e) => e.daysStalled >= _minDays).toList(),
        _reason,
      ),
    );
    visible = StagnationService.searchByText(visible, _textController.text);

    return Scaffold(
      key: AppKeys.stagnantBooksScreen,
      appBar: AppBar(title: const Text('⏳ 積読放置')),
      body: DungeonBackground(
        screenType: ScreenType.bookshelf,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                key: AppKeys.stagnantBooksThresholdChips,
                spacing: 8,
                children: [
                  for (final days in StagnationService.minDaysChoices)
                    ChoiceChip(
                      key: ValueKey('stagnant_days_$days'),
                      label: Text('$days日以上'),
                      selected: _minDays == days,
                      onSelected: (_) => setState(() => _minDays = days),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                key: AppKeys.stagnantBooksReasonChips,
                spacing: 8,
                children: [
                  ChoiceChip(
                    key: const ValueKey('stagnant_reason_all'),
                    label: const Text('すべて'),
                    selected: _reason == null,
                    onSelected: (_) => setState(() => _reason = null),
                  ),
                  for (final reason in StagnationReason.values)
                    ChoiceChip(
                      key: ValueKey('stagnant_reason_${reason.name}'),
                      label: Text(reason.label),
                      selected: _reason == reason,
                      onSelected: (_) => setState(() => _reason = reason),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                key: AppKeys.stagnantBooksSearchField,
                controller: _textController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '書名・著者で検索',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _textController.text.isNotEmpty
                      ? IconButton(
                          key: AppKeys.stagnantBooksSearchClear,
                          icon: const Icon(Icons.clear),
                          tooltip: '検索語をクリア',
                          onPressed: _clearSearchText,
                        )
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  key: AppKeys.stagnantBooksResultCount,
                  '${visible.length} 件の停滞本',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      key: AppKeys.stagnantBooksEmpty,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('⏳', style: TextStyle(fontSize: 40)),
                          SizedBox(height: 12),
                          Text(
                            '停滞している本はありません',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      key: AppKeys.stagnantBooksList,
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final entry = visible[index];
                        return ListTile(
                          key: AppKeys.stagnantBooksRow(entry.userBook.id),
                          title: Text(entry.title),
                          subtitle: Text(entry.daysLabel),
                          trailing: Text(entry.reason.label),
                          onTap: () =>
                              context.push('/reading?id=${entry.userBook.id}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Provider の蔵書から停滞本を検出する。
  List<StagnantBook> _detectEntries() {
    try {
      final books = ref.read(bookDataProvider).userBooks;
      final entries =
          StagnationService.detect(books, now: DateTime.now(), minDays: _minDays);
      return entries;
    } catch (_) {
      // 試練・オフライン環境で Provider 初期化に失敗しても
      // 画面描画は続行する（例外をゾーンに漏らさない）
      return const <StagnantBook>[];
    }
  }
}
