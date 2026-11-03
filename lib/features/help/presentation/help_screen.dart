import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/help/domain/help_catalog.dart';
import 'package:tsundoku_quest/features/help/domain/help_topic.dart';

/// 遊び方・ヘルプ画面 — チュートリアル文言を「読み返せる」形で提供する。
///
/// 文言の正は [TutorialContent]（[HelpCatalog] 経由で参照）。この画面は
/// 表示と絞り込みだけを担い、必須依存は持たない。
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, this.catalog});

  /// 目録（省略時は既定の [HelpCatalog]）。試練から差し替え可能。
  final HelpCatalog? catalog;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late final HelpCatalog _catalog = widget.catalog ?? HelpCatalog();
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hits = _catalog.search(_query);

    return Scaffold(
      key: AppKeys.helpScreen,
      appBar: AppBar(title: const Text('遊び方・ヘルプ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SemanticHelper.textField(
              testId: 'field_help_search',
              label: 'ヘルプを検索',
              child: TextField(
                key: AppKeys.helpSearchField,
                controller: _controller,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'キーワードで検索（例: 書庫・タブ）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),
          Expanded(
            child: hits.isEmpty
                ? const Center(
                    child: Text(
                      '見つかりませんでした',
                      key: AppKeys.helpEmptyMessage,
                    ),
                  )
                : ListView(
                    key: AppKeys.helpTopicList,
                    children: [
                      for (final section in _catalog.sections)
                        ..._buildSection(section, hits),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 章見出し＋該当項目。ヒットしない章は丸ごと出さない。
  List<Widget> _buildSection(HelpSection section, List<HelpTopic> hits) {
    final topics = [
      for (final topic in section.topics)
        if (hits.any((hit) => hit.id == topic.id)) topic,
    ];
    if (topics.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          section.title,
          key: AppKeys.helpSectionTitle(section.id),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      for (final topic in topics) _buildTopic(topic),
    ];
  }

  Widget _buildTopic(HelpTopic topic) {
    return ExpansionTile(
      key: AppKeys.helpTopic(topic.id),
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(topic.title),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(topic.body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
