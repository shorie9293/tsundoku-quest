import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/infrastructure/cross_app_link_status.dart';
import 'package:tsundoku_quest/core/infrastructure/cross_app_link_status_store.dart';
import 'package:tsundoku_quest/features/settings/presentation/cross_app_link_status_screen.dart';

/// 読み出し回数を数え、状態を差し替えられる保存先（refresh の検証用）。
class _CountingStore implements ICrossAppLinkStatusStore {
  _CountingStore(this.snapshot);

  CrossAppLinkSnapshot snapshot;
  int loadCount = 0;

  @override
  Future<CrossAppLinkSnapshot> load() async {
    loadCount++;
    return snapshot;
  }

  @override
  Future<void> save(CrossAppLinkSnapshot next) async {
    snapshot = next;
  }
}

void main() {
  final at = DateTime(2026, 11, 11, 9, 12);

  Future<void> pumpScreen(
    WidgetTester tester,
    CrossAppLinkStatusRecorder recorder,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CrossAppLinkStatusScreen(recorder: recorder)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('空状態は未記録と未設定を表示する', (tester) async {
    final recorder = CrossAppLinkStatusRecorder(
      store: InMemoryCrossAppLinkStatusStore(),
    );

    await pumpScreen(tester, recorder);

    expect(find.text('連携状況'), findsOneWidget);
    expect(find.text('未設定（連携は停止中）'), findsOneWidget);
    expect(find.text('未記録'), findsNWidgets(2));
    expect(find.byKey(CrossAppLinkStatusScreen.sentKey), findsOneWidget);
    expect(find.byKey(CrossAppLinkStatusScreen.receivedKey), findsOneWidget);
  });

  testWidgets('記録ありは成否・時刻・件数・ファイル名を表示する', (tester) async {
    final store = InMemoryCrossAppLinkStatusStore(
      CrossAppLinkSnapshot(
        sharedFolderReady: true,
        lastSent: CrossAppTransferRecord(
          at: at,
          ok: true,
          count: 3,
          fileName: 'tsundoku_reward_events.jsonl',
        ),
        lastReceived: CrossAppTransferRecord(
          at: at,
          ok: true,
          count: 2,
          fileName: 'rpg_enemy_defeat_events.jsonl',
        ),
      ),
    );
    final recorder = CrossAppLinkStatusRecorder(store: store);

    await pumpScreen(tester, recorder);

    expect(find.text('設定済み'), findsOneWidget);
    expect(
      find.text('成功・2026/11/11 09:12・3件・tsundoku_reward_events.jsonl'),
      findsOneWidget,
    );
    expect(
      find.text('成功・2026/11/11 09:12・2件・rpg_enemy_defeat_events.jsonl'),
      findsOneWidget,
    );
  });

  testWidgets('失敗理由を詳細として表示する', (tester) async {
    final store = InMemoryCrossAppLinkStatusStore(
      CrossAppLinkSnapshot(
        lastSent: CrossAppTransferRecord(
          at: at,
          ok: false,
          count: 0,
          fileName: 'a.jsonl',
          error: 'disk full',
        ),
      ),
    );
    final recorder = CrossAppLinkStatusRecorder(store: store);

    await pumpScreen(tester, recorder);

    expect(find.text('失敗・2026/11/11 09:12・0件・a.jsonl'), findsOneWidget);
    expect(find.text('disk full'), findsOneWidget);
  });

  testWidgets('refresh で最新の状態を読み直す', (tester) async {
    final store = _CountingStore(CrossAppLinkSnapshot.empty);
    final recorder = CrossAppLinkStatusRecorder(store: store);

    await pumpScreen(tester, recorder);
    expect(find.text('未記録'), findsNWidgets(2));
    expect(store.loadCount, 1);

    store.snapshot = CrossAppLinkSnapshot(
      lastReceived: CrossAppTransferRecord(
        at: at,
        ok: true,
        count: 1,
        fileName: 'new.json',
      ),
    );
    await tester.tap(find.byKey(CrossAppLinkStatusScreen.refreshKey));
    await tester.pumpAndSettle();

    expect(store.loadCount, 2);
    expect(find.text('成功・2026/11/11 09:12・1件・new.json'), findsOneWidget);
  });
}
