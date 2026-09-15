import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/share_card/data/share_card_exporter.dart';
import 'package:tsundoku_quest/features/share_card/domain/share_card_data.dart';
import 'package:tsundoku_quest/features/share_card/presentation/share_card_capture.dart';
import 'package:tsundoku_quest/features/share_card/presentation/share_card_screen.dart';

class _FakeCapture implements ShareCardCapture {
  _FakeCapture(this.bytes);
  final Uint8List? bytes;
  int calls = 0;

  @override
  Future<Uint8List?> capture() async {
    calls++;
    return bytes;
  }
}

class _FakeExporter implements ShareCardExporter {
  Object? error;
  Uint8List? lastPng;
  String? lastText;
  int calls = 0;

  @override
  Future<void> shareImage({required Uint8List png, required String text}) async {
    calls++;
    lastPng = png;
    lastText = text;
    if (error != null) throw error!;
  }
}

ShareCardData _data(String title, {DateTime? completedAt, int rating = 0}) {
  return ShareCardData(
    title: title,
    authors: const ['山田太郎'],
    completedAt: completedAt ?? DateTime.utc(2026, 9, 15),
    pages: 320,
    rating: rating == 0 ? null : rating,
  );
}

final _png = Uint8List.fromList(const [1, 2, 3, 4]);

Future<void> _pump(
  WidgetTester tester, {
  required List<ShareCardData> candidates,
  ShareCardCapture? capture,
  ShareCardExporter? exporter,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ShareCardScreen(
        candidates: candidates,
        capture: capture,
        exporter: exporter,
      ),
    ),
  );
}

void main() {
  final clipboardCalls = <MethodCall>[];

  setUp(() {
    clipboardCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      clipboardCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('候補が空なら空状態を表示し例外を出さない', (tester) async {
    await _pump(tester, candidates: const []);
    expect(find.byKey(AppKeys.shareCardEmpty), findsOneWidget);
    expect(find.text('読了した本がまだない'), findsOneWidget);
    expect(find.byKey(AppKeys.shareCardShareButton), findsNothing);
  });

  testWidgets('候補1件なら既定で選択されカードを表示する', (tester) async {
    await _pump(tester, candidates: [_data('積読のすすめ')]);
    expect(find.byKey(AppKeys.shareCardScreen), findsOneWidget);
    expect(find.byKey(AppKeys.shareCardPreview), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(AppKeys.shareCardTitle)).data, '積読のすすめ');
  });

  testWidgets('候補1件なら切替セレクタを表示しない', (tester) async {
    await _pump(tester, candidates: [_data('A')]);
    expect(find.byKey(AppKeys.shareCardCandidate), findsNothing);
  });

  testWidgets('候補2件なら切替セレクタを表示し選択でカードが変わる', (tester) async {
    await _pump(tester, candidates: [_data('A'), _data('B')]);
    expect(find.byKey(AppKeys.shareCardCandidate), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(AppKeys.shareCardTitle)).data, 'A');

    await tester.tap(find.byKey(AppKeys.shareCardCandidate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(AppKeys.shareCardTitle)).data, 'B');
  });

  testWidgets('共有ボタンで画像とテキストを exporter に渡す', (tester) async {
    final capture = _FakeCapture(_png);
    final exporter = _FakeExporter();
    await _pump(
      tester,
      candidates: [_data('積読のすすめ')],
      capture: capture,
      exporter: exporter,
    );

    await tester.tap(find.byKey(AppKeys.shareCardShareButton));
    await tester.pumpAndSettle();

    expect(capture.calls, 1);
    expect(exporter.calls, 1);
    expect(exporter.lastPng, _png);
    expect(exporter.lastText, contains('『積読のすすめ』を読了しました'));
    expect(find.text('カードを共有しました'), findsOneWidget);
  });

  testWidgets('キャプチャ不能なら生成失敗を通知し exporter を呼ばない', (tester) async {
    final capture = _FakeCapture(null);
    final exporter = _FakeExporter();
    await _pump(
      tester,
      candidates: [_data('A')],
      capture: capture,
      exporter: exporter,
    );

    await tester.tap(find.byKey(AppKeys.shareCardShareButton));
    await tester.pumpAndSettle();

    expect(exporter.calls, 0);
    expect(find.text('カード画像を生成できませんでした'), findsOneWidget);
  });

  testWidgets('共有が例外なら失敗を通知する', (tester) async {
    final capture = _FakeCapture(_png);
    final exporter = _FakeExporter()..error = Exception('boom');
    await _pump(
      tester,
      candidates: [_data('A')],
      capture: capture,
      exporter: exporter,
    );

    await tester.tap(find.byKey(AppKeys.shareCardShareButton));
    await tester.pumpAndSettle();

    expect(find.text('カードの共有に失敗しました'), findsOneWidget);
  });

  testWidgets('コピーボタンで共有テキストをクリップボードへ送る', (tester) async {
    await _pump(tester, candidates: [_data('積読のすすめ')]);

    await tester.tap(find.byKey(AppKeys.shareCardCopyButton));
    await tester.pumpAndSettle();

    final copy = clipboardCalls.where((c) => c.method == 'Clipboard.setData');
    expect(copy, isNotEmpty);
    expect((copy.first.arguments as Map)['text'], contains('『積読のすすめ』を読了しました'));
    expect(find.text('テキストをコピーしました'), findsOneWidget);
  });

  testWidgets('評価付きの本はテキストに評価を含む', (tester) async {
    final exporter = _FakeExporter();
    await _pump(
      tester,
      candidates: [_data('A', rating: 5)],
      capture: _FakeCapture(_png),
      exporter: exporter,
    );

    await tester.tap(find.byKey(AppKeys.shareCardShareButton));
    await tester.pumpAndSettle();

    expect(exporter.lastText, contains('評価: ★★★★★'));
  });
}
