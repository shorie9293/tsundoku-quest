// 天浮橋計画 — tsundoku-quest スモークテスト
// 単独実行: flutter test integration_test/smoke_test.dart -d <device>
//
// 本番の起動経路（main() → runZonedGuarded → bootstrap() → runApp）をそのまま通し、
// ErrorBoundary / AppLifecycleRefresher を含む実際の配線を検証する。
// pumpAndSettle は使わない（BGM やローディング等の繰り返しアニメーションで
// 永久に待ち続けるため）。
//
// Supabase / Firebase の資格情報は CI では渡さないが、bootstrap() 側が
// それぞれ try/catch でオフラインモード継続するためダミー初期化は不要。
//
// テスト終了時はウィジェットツリーを明示破棄する。これをしないと各画面の
// dispose が走らず、残留アニメーションで "An animation is still running" に落ちる。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tsundoku_quest/main.dart' as app;

/// [finder] が現れるまで、実時間予算 [timeout] の範囲で [step] 刻みに pump する。
///
/// 本番起動は非同期初期化（Firebase・Hive・設定読込・通知等）を伴うため、固定回数の
/// pump では環境次第で足りない。pumpAndSettle は繰り返しアニメーションで終わらない。
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 60),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
    if (!DateTime.now().isBefore(deadline)) {
      expect(
        finder,
        findsWidgets,
        reason: '$finder が ${timeout.inSeconds} 秒以内に現れること',
      );
      return;
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('スモーク: 本番起動経路で MaterialApp が配線される', (tester) async {
    // main() は void のため await できない。内部の runApp はゾーン内で呼ばれる。
    app.main();

    await pumpUntilFound(tester, find.byType(MaterialApp));

    expect(
      find.byType(MaterialApp),
      findsOneWidget,
      reason: 'tsundoku-quest アプリが正常に起動していること',
    );

    // ツリーを明示破棄する（各画面の dispose を走らせ、残留アニメーションを止める）。
    await tester.pumpWidget(const SizedBox.shrink());
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
