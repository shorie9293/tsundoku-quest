import 'package:flutter/foundation.dart';

import '../../tutorial/presentation/tutorial_content.dart';
import 'help_topic.dart';

/// ヘルプの章（見出し＋項目群）。
@immutable
class HelpSection {
  const HelpSection({
    required this.id,
    required this.title,
    required this.topics,
  });

  final String id;
  final String title;
  final List<HelpTopic> topics;
}

/// ヘルプ目録。
///
/// 文言は [TutorialContent] を正として生成する（二重管理しない）。
/// 検索は純粋関数（[search]）として実装し、UI から切り離して試練可能にする。
@immutable
class HelpCatalog {
  HelpCatalog({List<HelpSection>? sections})
      : sections = List<HelpSection>.unmodifiable(
          sections ?? defaultSections(),
        );

  /// 章の並び（宣言順がそのまま表示順）。
  final List<HelpSection> sections;

  /// 既定の章立て。チュートリアル文言から機械的に組み立てる。
  static List<HelpSection> defaultSections() => [
        HelpSection(
          id: 'lore',
          title: '世界観',
          topics: [
            for (final page in TutorialContent.lorePages) _fromPage(page),
          ],
        ),
        HelpSection(
          id: 'operation',
          title: '操作',
          topics: [_fromPage(TutorialContent.operationPage)],
        ),
      ];

  static HelpTopic _fromPage(TutorialPageData page) => HelpTopic(
        id: page.keyName,
        title: page.title,
        body: page.body,
      );

  /// 全項目を宣言順で返す。
  List<HelpTopic> get allTopics => List<HelpTopic>.unmodifiable(
        [for (final section in sections) ...section.topics],
      );

  /// 部分一致検索（大文字小文字を無視）。
  ///
  /// - 空クエリ・空白のみ → 全件
  /// - 該当なし → 空リスト
  /// - 並びは常に宣言順
  List<HelpTopic> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return allTopics;

    return List<HelpTopic>.unmodifiable([
      for (final topic in allTopics)
        if (topic.title.toLowerCase().contains(needle) ||
            topic.body.toLowerCase().contains(needle))
          topic,
    ]);
  }
}
