import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/features/help/domain/help_catalog.dart';
import 'package:tsundoku_quest/features/help/domain/help_topic.dart';
import 'package:tsundoku_quest/features/tutorial/presentation/tutorial_content.dart';

/// ヘルプ目録 — チュートリアル文言を正として検索可能にする。
void main() {
  group('HelpCatalog（既定＝TutorialContent 由来）', () {
    final catalog = HelpCatalog();

    test('全項目の id が一意で title/body が非空', () {
      final topics = catalog.allTopics;
      expect(topics, isNotEmpty);

      final ids = topics.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);

      for (final topic in topics) {
        expect(topic.id.trim(), isNotEmpty, reason: topic.id);
        expect(topic.title.trim(), isNotEmpty, reason: topic.id);
        expect(topic.body.trim(), isNotEmpty, reason: topic.id);
      }
    });

    test('文言はチュートリアル4ページ＋操作ページから生成される（重複定義なし）', () {
      final topics = catalog.allTopics;
      expect(topics.length, TutorialContent.lorePages.length + 1);
      expect(
        topics.map((t) => t.title),
        [
          for (final page in TutorialContent.lorePages) page.title,
          TutorialContent.operationPage.title,
        ],
      );
      expect(
        topics.map((t) => t.body),
        [
          for (final page in TutorialContent.lorePages) page.body,
          TutorialContent.operationPage.body,
        ],
      );
    });

    test('部分一致ヒット', () {
      final hits = catalog.search('書庫');
      expect(hits, isNotEmpty);
      expect(hits.map((t) => t.id), contains('page_tutorial_operation'));
    });

    test('空クエリは全件', () {
      expect(catalog.search(''), hasLength(catalog.allTopics.length));
    });

    test('空白のみのクエリは全件', () {
      expect(catalog.search('   \n\t '), hasLength(catalog.allTopics.length));
    });

    test('該当なしは空リスト', () {
      expect(catalog.search('該当しない語句ZZZ'), isEmpty);
    });

    test('並びは宣言順を保つ', () {
      // 実データ（lore3 の見出し/本文と操作ページ本文）で順序を固定する。
      expect(
        catalog.search('書庫').map((t) => t.id),
        ['page_tutorial_lore3', 'page_tutorial_operation'],
      );
      expect(
        catalog.search('書庫').map((t) => t.id).toList(),
        catalog.allTopics
            .where((t) => catalog.search('書庫').any((h) => h.id == t.id))
            .map((t) => t.id)
            .toList(),
      );
    });
  });

  group('HelpCatalog（注入した章立て）', () {
    HelpCatalog build() => HelpCatalog(
          sections: const [
            HelpSection(
              id: 'test',
              title: 'Test',
              topics: [
                HelpTopic(id: 'a', title: 'Reading Log', body: 'PAGES today'),
                HelpTopic(id: 'b', title: '積読', body: '本棚の管理'),
              ],
            ),
          ],
        );

    test('大文字小文字を無視して一致する', () {
      final catalog = build();
      expect(catalog.search('reading').map((t) => t.id), ['a']);
      expect(catalog.search('READING').map((t) => t.id), ['a']);
      expect(catalog.search('pages').map((t) => t.id), ['a']);
    });

    test('章を跨いでも宣言順', () {
      final catalog = HelpCatalog(
        sections: const [
          HelpSection(
            id: 's1',
            title: 'S1',
            topics: [HelpTopic(id: 'x1', title: '共通キー', body: '本文')],
          ),
          HelpSection(
            id: 's2',
            title: 'S2',
            topics: [
              HelpTopic(id: 'y1', title: '別名', body: '共通キーを含む'),
              HelpTopic(id: 'z1', title: '無関係', body: '...'),
            ],
          ),
        ],
      );
      expect(catalog.search('共通キー').map((t) => t.id), ['x1', 'y1']);
    });
  });
}
