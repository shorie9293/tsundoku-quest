import 'package:flutter/material.dart';

/// 検索語の履歴チップ列。履歴が空なら何も表示しない。
class SearchHistoryChips extends StatelessWidget {
  /// 新しい順の検索語。
  final List<String> entries;

  /// チップ選択時のコールバック。
  final ValueChanged<String> onSelected;

  /// 各チップの Key 接頭辞（`<prefix>_<index>`）。
  final String keyPrefix;

  const SearchHistoryChips({
    super.key,
    required this.entries,
    required this.onSelected,
    this.keyPrefix = 'search_history_chip',
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < entries.length; i++)
          ActionChip(
            key: ValueKey('${keyPrefix}_$i'),
            label: Text(entries[i], style: const TextStyle(fontSize: 12)),
            onPressed: () => onSelected(entries[i]),
          ),
      ],
    );
  }
}
