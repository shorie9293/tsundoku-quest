import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/help/domain/help_catalog.dart';
import 'package:tsundoku_quest/features/help/domain/help_topic.dart';
import 'package:tsundoku_quest/features/help/presentation/help_screen.dart';
import 'package:tsundoku_quest/features/tutorial/presentation/tutorial_content.dart';

/// 遊び方・ヘルプ画面 — チュートリアル文言を読み返す。
void main() {
  Future<void> pumpHelp(WidgetTester tester, {HelpCatalog? catalog}) async {
    await tester.pumpWidget(MaterialApp(home: HelpScreen(catalog: catalog)));
    await tester.pumpAndSettle();
  }

  testWidgets('タイトルと章・項目が表示される', (tester) async {
    await pumpHelp(tester);

    expect(find.byKey(AppKeys.helpScreen), findsOneWidget);
    expect(find.text('遊び方・ヘルプ'), findsOneWidget);
    expect(find.byKey(AppKeys.helpSearchField), findsOneWidget);

    // 章見出し（世界観／操作）
    expect(find.byKey(AppKeys.helpSectionTitle('lore')), findsOneWidget);
    expect(find.byKey(AppKeys.helpSectionTitle('operation')), findsOneWidget);

    // 先頭のチュートリアル見出しはそのまま流用される
    expect(find.text(TutorialContent.lorePages.first.title), findsOneWidget);
    expect(
      find.byKey(AppKeys.helpTopic(TutorialContent.lorePages.first.keyName)),
      findsOneWidget,
    );
  });

  testWidgets('検索入力で絞り込める', (tester) async {
    await pumpHelp(tester);

    await tester.enterText(find.byKey(AppKeys.helpSearchField), 'タブ');
    await tester.pumpAndSettle();

    // 操作ページだけがヒットする（他の世界観ページは消える）
    expect(
      find.byKey(AppKeys.helpTopic(TutorialContent.operationPage.keyName)),
      findsOneWidget,
    );
    expect(find.text(TutorialContent.lorePages.first.title), findsNothing);
    expect(find.text(TutorialContent.lorePages[1].title), findsNothing);
    expect(find.byKey(AppKeys.helpSectionTitle('lore')), findsNothing);
    expect(find.byKey(AppKeys.helpSectionTitle('operation')), findsOneWidget);
  });

  testWidgets('0件のときは「見つかりませんでした」を出す', (tester) async {
    await pumpHelp(tester);

    await tester.enterText(find.byKey(AppKeys.helpSearchField), '該当しない語句ZZZ');
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.helpEmptyMessage), findsOneWidget);
    expect(find.text('見つかりませんでした'), findsOneWidget);
    expect(find.byKey(AppKeys.helpTopicList), findsNothing);
  });

  testWidgets('注入した目録を表示する', (tester) async {
    await pumpHelp(
      tester,
      catalog: HelpCatalog(
        sections: const [
          HelpSection(
            id: 'only',
            title: '章',
            topics: [HelpTopic(id: 'only1', title: '唯一の項目', body: '本文')],
          ),
        ],
      ),
    );

    expect(find.text('唯一の項目'), findsOneWidget);
    expect(find.text(TutorialContent.lorePages.first.title), findsNothing);
  });
}
