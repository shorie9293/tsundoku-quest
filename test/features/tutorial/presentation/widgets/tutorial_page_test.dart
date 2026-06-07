import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/tutorial/presentation/tutorial_content.dart';
import 'package:tsundoku_quest/features/tutorial/presentation/widgets/tutorial_page.dart';

Widget createTestWidget(TutorialPageData pageData) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: TutorialPage(pageData: pageData),
    ),
  );
}

void main() {
  group('TutorialPage', () {
    const testPageData = TutorialPageData(
      keyName: 'test_page',
      icon: Icons.auto_stories,
      title: 'テストタイトル',
      body: 'テスト本文です。これはテスト用の内容です。',
    );

    testWidgets('should display icon, title, and body from pageData',
        (tester) async {
      await tester.pumpWidget(createTestWidget(testPageData));

      expect(find.byIcon(Icons.auto_stories), findsOneWidget);
      expect(find.text('テストタイトル'), findsOneWidget);
      expect(find.text('テスト本文です。これはテスト用の内容です。'), findsOneWidget);
    });

    testWidgets('should have correct pageKey set', (tester) async {
      await tester.pumpWidget(createTestWidget(testPageData));

      expect(find.byKey(const Key('test_page')), findsOneWidget);
    });

    testWidgets('should center-align text', (tester) async {
      await tester.pumpWidget(createTestWidget(testPageData));

      final titleText =
          tester.widget<Text>(find.text('テストタイトル'));
      expect(titleText.textAlign, TextAlign.center);

      final bodyText = tester.widget<Text>(
          find.text('テスト本文です。これはテスト用の内容です。'));
      expect(bodyText.textAlign, TextAlign.center);
    });

    testWidgets('should render icon inside circular container',
        (tester) async {
      await tester.pumpWidget(createTestWidget(testPageData));

      // Find the circular container wrapping the icon
      final containers = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(containers, findsOneWidget);

      // Verify the icon exists within the circular container
      expect(find.byIcon(Icons.auto_stories), findsOneWidget);
    });
  });
}
