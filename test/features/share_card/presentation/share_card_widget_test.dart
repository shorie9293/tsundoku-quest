import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/share_card/domain/share_card_data.dart';
import 'package:tsundoku_quest/features/share_card/presentation/share_card_widget.dart';

ShareCardData _data({
  String title = '積読のすすめ',
  List<String> authors = const ['山田太郎'],
  int pages = 320,
  int? rating,
  List<String> shelves = const [],
}) {
  return ShareCardData(
    title: title,
    authors: authors,
    completedAt: DateTime.utc(2026, 9, 15),
    pages: pages,
    rating: rating,
    shelves: shelves,
  );
}

Future<void> _pump(WidgetTester tester, ShareCardData data) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: ShareCard(data: data)))),
  );
}

void main() {
  testWidgets('書名・著者・読了日・ページ数を表示する', (tester) async {
    await _pump(tester, _data());
    expect(find.byKey(AppKeys.shareCardTitle), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(AppKeys.shareCardTitle)).data, '積読のすすめ');
    expect(find.text('山田太郎'), findsOneWidget);
    expect(find.text('読了日: 2026年9月15日'), findsOneWidget);
    expect(find.text('320ページ'), findsOneWidget);
  });

  testWidgets('著者がいなければ 著者不明 を表示する', (tester) async {
    await _pump(tester, _data(authors: const []));
    expect(find.text('著者不明'), findsOneWidget);
  });

  testWidgets('ページ0 は ページ数不明 を表示する', (tester) async {
    await _pump(tester, _data(pages: 0));
    expect(find.text('ページ数不明'), findsOneWidget);
  });

  testWidgets('未評価なら評価行を表示しない', (tester) async {
    await _pump(tester, _data());
    expect(find.byKey(AppKeys.shareCardRating), findsNothing);
  });

  testWidgets('評価4は ★★★★☆ を表示する', (tester) async {
    await _pump(tester, _data(rating: 4));
    expect(find.byKey(AppKeys.shareCardRating), findsOneWidget);
    expect(find.text('評価: ★★★★☆'), findsOneWidget);
  });

  testWidgets('棚が空なら棚チップを表示しない', (tester) async {
    await _pump(tester, _data());
    expect(find.byKey(AppKeys.shareCardShelves), findsNothing);
  });

  testWidgets('棚があればチップを表示する', (tester) async {
    await _pump(tester, _data(shelves: const ['技術書', '積読']));
    expect(find.byKey(AppKeys.shareCardShelves), findsOneWidget);
    expect(find.text('技術書'), findsOneWidget);
    expect(find.text('積読'), findsOneWidget);
  });

  testWidgets('読了達成の見出しを表示する', (tester) async {
    await _pump(tester, _data());
    expect(find.text('📖 読了達成'), findsOneWidget);
  });
}
