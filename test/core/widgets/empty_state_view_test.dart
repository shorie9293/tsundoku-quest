import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/widgets/empty_state.dart';

/// 空状態共通部品の試練。
///
/// EmptyStateSpec = 純粋データ（不変条件は非constコンストラクタで throw）、
/// EmptyStateView = 表示のみ（文言は注入される）。
void main() {
  Widget host(Widget child) {
    return MaterialApp(home: Scaffold(body: Center(child: child)));
  }

  group('EmptyStateSpec の不変条件', () {
    test('title が空文字なら ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('actionLabel だけ指定すると ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: 't', actionLabel: '追加'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('onAction だけ指定すると ArgumentError', () {
      expect(
        () => EmptyStateSpec(title: 't', onAction: () {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('title のみでも構築でき、任意項目は null', () {
      final spec = EmptyStateSpec(title: '書庫はまだ空です');
      expect(spec.title, '書庫はまだ空です');
      expect(spec.description, isNull);
      expect(spec.actionLabel, isNull);
      expect(spec.onAction, isNull);
    });

    test('全項目を指定できる', () {
      var tapped = 0;
      final spec = EmptyStateSpec(
        title: '書庫はまだ空です',
        description: '最初の冒険の書を登録しよう',
        actionLabel: '探索に出る',
        onAction: () => tapped++,
      );
      expect(spec.description, '最初の冒険の書を登録しよう');
      expect(spec.actionLabel, '探索に出る');
      spec.onAction!();
      expect(tapped, 1);
    });
  });

  group('EmptyStateView の描画', () {
    testWidgets('見出しと説明を表示する', (tester) async {
      await tester.pumpWidget(host(EmptyStateView(
        key: const Key('empty'),
        spec: EmptyStateSpec(
          title: '書庫はまだ空です',
          description: '最初の冒険の書を登録して、ダンジョンへの扉を開きましょう！',
        ),
      )));

      expect(find.text('書庫はまだ空です'), findsOneWidget);
      expect(find.text('最初の冒険の書を登録して、ダンジョンへの扉を開きましょう！'), findsOneWidget);
      expect(find.byKey(const Key('empty')), findsOneWidget);
    });

    testWidgets('description が null なら説明文を描画しない', (tester) async {
      await tester.pumpWidget(host(EmptyStateView(
        key: const Key('empty'),
        spec: EmptyStateSpec(title: '見出しのみ'),
      )));

      expect(find.text('見出しのみ'), findsOneWidget);
      // 見出し以外の Text は存在しない
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('action が null ならボタンを描画しない', (tester) async {
      await tester.pumpWidget(host(EmptyStateView(
        key: const Key('empty'),
        spec: EmptyStateSpec(title: '見出しのみ'),
      )));

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('actionLabel と onAction があればボタンを描画し、タップで発火する', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(host(EmptyStateView(
        key: const Key('empty'),
        actionKey: const Key('empty_action'),
        actionSemanticId: 'btn_empty_state_explore',
        spec: EmptyStateSpec(
          title: '書庫はまだ空です',
          actionLabel: '探索に出る',
          onAction: () => tapped++,
        ),
      )));

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('探索に出る'), findsOneWidget);
      expect(find.byKey(const Key('empty_action')), findsOneWidget);

      await tester.tap(find.byKey(const Key('empty_action')));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('ボタンの Semantics identifier を指定できる（読み上げ・試練用）', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(EmptyStateView(
        key: const Key('empty'),
        actionSemanticId: 'btn_empty_state_explore',
        spec: EmptyStateSpec(
          title: '書庫はまだ空です',
          actionLabel: '探索に出る',
          onAction: () {},
        ),
      )));

      expect(find.bySemanticsIdentifier('btn_empty_state_explore'),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('emoji を指定したときだけアイコンを描画する', (tester) async {
      await tester.pumpWidget(host(EmptyStateView(
        key: const Key('empty_with_icon'),
        emoji: '📚',
        spec: EmptyStateSpec(title: 'アイコンあり'),
      )));
      expect(find.text('📚'), findsOneWidget);

      await tester.pumpWidget(host(EmptyStateView(
        key: const Key('empty_no_icon'),
        spec: EmptyStateSpec(title: 'アイコンなし'),
      )));
      await tester.pumpAndSettle();
      expect(find.text('📚'), findsNothing);
    });

    testWidgets('文言は部品に埋め込まれず、注入値がそのまま表示される', (tester) async {
      await tester.pumpWidget(host(EmptyStateView(
        key: const Key('empty'),
        spec: EmptyStateSpec(
          title: 'A',
          description: 'B',
          actionLabel: 'C',
          onAction: () {},
        ),
      )));

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      // 既定文言が混入していないこと
      expect(find.text('まだありません'), findsNothing);
      expect(find.text('追加する'), findsNothing);
    });
  });
}
