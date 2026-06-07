import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/tutorial/presentation/tutorial_content.dart';

void main() {
  group('TutorialPageData', () {
    const testPage = TutorialPageData(
      keyName: 'test_key',
      icon: Icons.star,
      title: 'Test Title',
      body: 'Test body content.',
    );

    test('constructor sets all fields correctly', () {
      expect(testPage.keyName, 'test_key');
      expect(testPage.icon, Icons.star);
      expect(testPage.title, 'Test Title');
      expect(testPage.body, 'Test body content.');
    });

    test('pageKey returns a Key with the correct keyName', () {
      final key = testPage.pageKey;
      expect(key, isA<Key>());
      // ValueKey stores the value; we check by constructing the same Key
      expect(key, const Key('test_key'));
    });

    test('two instances with the same fields are equal', () {
      const same = TutorialPageData(
        keyName: 'test_key',
        icon: Icons.star,
        title: 'Test Title',
        body: 'Test body content.',
      );
      expect(same, testPage);
    });

    test('two instances with different fields are not equal', () {
      const different = TutorialPageData(
        keyName: 'other_key',
        icon: Icons.favorite,
        title: 'Other Title',
        body: 'Other body.',
      );
      expect(different, isNot(testPage));
    });
  });

  group('TutorialContent.lorePages', () {
    test('has exactly 4 pages', () {
      expect(TutorialContent.lorePages.length, 4);
    });

    test('each page has a non-empty keyName', () {
      for (final page in TutorialContent.lorePages) {
        expect(page.keyName, isNotEmpty);
      }
    });

    test('each page has a non-empty title', () {
      for (final page in TutorialContent.lorePages) {
        expect(page.title, isNotEmpty);
      }
    });

    test('each page has a non-empty body', () {
      for (final page in TutorialContent.lorePages) {
        expect(page.body, isNotEmpty);
      }
    });

    test('each page has a non-null icon', () {
      for (final page in TutorialContent.lorePages) {
        expect(page.icon, isNotNull);
      }
    });

    test('each page has unique keyNames', () {
      final keyNames = TutorialContent.lorePages.map((p) => p.keyName).toSet();
      expect(keyNames.length, TutorialContent.lorePages.length);
    });
  });

  group('TutorialContent.lorePageCount', () {
    test('returns 4', () {
      expect(TutorialContent.lorePageCount, 4);
    });
  });

  group('TutorialContent.operationPage', () {
    test('is not null', () {
      expect(TutorialContent.operationPage, isNotNull);
    });

    test('has keyName page_tutorial_operation', () {
      expect(TutorialContent.operationPage.keyName, 'page_tutorial_operation');
    });

    test('has non-empty title', () {
      expect(TutorialContent.operationPage.title, isNotEmpty);
    });

    test('has non-empty body', () {
      expect(TutorialContent.operationPage.body, isNotEmpty);
    });

    test('has non-null icon', () {
      expect(TutorialContent.operationPage.icon, isNotNull);
    });
  });
}
