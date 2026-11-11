import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/infrastructure/cross_app_link_status.dart';
import 'package:tsundoku_quest/core/infrastructure/cross_app_link_status_store.dart';

/// load も save も失敗する保存先（記録が本処理を止めないことの検証用）。
class _ThrowingStore implements ICrossAppLinkStatusStore {
  @override
  Future<CrossAppLinkSnapshot> load() async => throw StateError('load failed');

  @override
  Future<void> save(CrossAppLinkSnapshot snapshot) async =>
      throw StateError('save failed');
}

void main() {
  final now = DateTime(2026, 11, 11, 9, 0);

  group('CrossAppLinkStatusRecorder', () {
    test('recordSent は最後の送信を成功として記録する', () async {
      final store = InMemoryCrossAppLinkStatusStore();
      final recorder = CrossAppLinkStatusRecorder(store: store, now: () => now);

      await recorder.recordSent(
        count: 3,
        fileName: 'tsundoku_reward_events.jsonl',
      );

      final sent = recorder.cached.lastSent;
      expect(sent, isNotNull);
      expect(sent!.ok, isTrue);
      expect(sent.count, 3);
      expect(sent.fileName, 'tsundoku_reward_events.jsonl');
      expect(sent.at, now);
      expect(sent.error, isNull);
      expect(store.saveCount, 1);
    });

    test('recordSendFailure は最後の送信を失敗として理由付きで記録する', () async {
      final store = InMemoryCrossAppLinkStatusStore();
      final recorder = CrossAppLinkStatusRecorder(store: store, now: () => now);

      await recorder.recordSendFailure(
        StateError('disk full'),
        fileName: 'a.jsonl',
      );

      final sent = recorder.cached.lastSent!;
      expect(sent.ok, isFalse);
      expect(sent.count, 0);
      expect(sent.fileName, 'a.jsonl');
      expect(sent.error, contains('disk full'));
    });

    test('recordReceived は最後の受信を成功として記録する', () async {
      final store = InMemoryCrossAppLinkStatusStore();
      final recorder = CrossAppLinkStatusRecorder(store: store, now: () => now);

      await recorder.recordReceived(count: 2, fileName: 'recv.jsonl');

      final received = recorder.cached.lastReceived!;
      expect(received.ok, isTrue);
      expect(received.count, 2);
      expect(received.fileName, 'recv.jsonl');
      expect(received.at, now);
      expect(recorder.cached.lastSent, isNull);
    });

    test('recordReceiveFailure は最後の受信を失敗として記録する', () async {
      final store = InMemoryCrossAppLinkStatusStore();
      final recorder = CrossAppLinkStatusRecorder(store: store, now: () => now);

      await recorder.recordReceiveFailure(
        StateError('read failed'),
        fileName: 'recv.jsonl',
      );

      final received = recorder.cached.lastReceived!;
      expect(received.ok, isFalse);
      expect(received.error, contains('read failed'));
    });

    test('recordFolderReady は共有フォルダの可否を記録する', () async {
      final store = InMemoryCrossAppLinkStatusStore();
      final recorder = CrossAppLinkStatusRecorder(store: store, now: () => now);

      await recorder.recordFolderReady(true);
      expect(recorder.cached.sharedFolderReady, isTrue);

      await recorder.recordFolderReady(false);
      expect(recorder.cached.sharedFolderReady, isFalse);
      expect(store.saveCount, 2);
    });

    test('保存が throw しても記録は漏れず、メモリ側に残る', () async {
      final store = InMemoryCrossAppLinkStatusStore()..throwOnSave = true;
      final recorder = CrossAppLinkStatusRecorder(store: store, now: () => now);

      await expectLater(
        recorder.recordSent(count: 1, fileName: 'a.jsonl'),
        completes,
      );

      expect(recorder.cached.lastSent!.ok, isTrue);
      expect(recorder.cached.lastSent!.fileName, 'a.jsonl');
      expect(store.saveCount, 0);
    });

    test('保存先の load が throw しても load() は空で返り throw しない', () async {
      final recorder = CrossAppLinkStatusRecorder(
        store: _ThrowingStore(),
        now: () => now,
      );

      final snapshot = await recorder.load();
      expect(snapshot.lastSent, isNull);
      expect(snapshot.lastReceived, isNull);

      await expectLater(
        recorder.recordSent(count: 1, fileName: 'a.jsonl'),
        completes,
      );
      expect(recorder.cached.lastSent!.count, 1);
    });

    test('並行10件の記録を取りこぼさない', () async {
      final store = InMemoryCrossAppLinkStatusStore();
      final recorder = CrossAppLinkStatusRecorder(store: store, now: () => now);

      await Future.wait([
        for (var i = 1; i <= 10; i++)
          recorder.recordSent(count: i, fileName: 'f$i.jsonl'),
      ]);

      expect(store.saveCount, 10);
      expect(recorder.cached.lastSent!.count, 10);
      expect(recorder.cached.lastSent!.fileName, 'f10.jsonl');
    });

    test('初回記録の前に保存済みの状態を読み、前回分を消さない', () async {
      final previous = CrossAppTransferRecord(
        at: DateTime(2026, 11, 10, 8, 0),
        ok: true,
        count: 5,
        fileName: 'prev.jsonl',
      );
      final store = InMemoryCrossAppLinkStatusStore(
        CrossAppLinkSnapshot(lastSent: previous, sharedFolderReady: true),
      );
      final recorder = CrossAppLinkStatusRecorder(store: store, now: () => now);

      await recorder.recordReceived(count: 2, fileName: 'recv.jsonl');

      expect(recorder.cached.lastSent!.count, 5);
      expect(recorder.cached.lastSent!.fileName, 'prev.jsonl');
      expect(recorder.cached.sharedFolderReady, isTrue);
      expect(recorder.cached.lastReceived!.count, 2);
    });

    test('reset で共有インスタンスを差し替えられる', () {
      final store = InMemoryCrossAppLinkStatusStore();
      final recorder = CrossAppLinkStatusRecorder(store: store);
      final original = CrossAppLinkStatusRecorder.instance;

      CrossAppLinkStatusRecorder.reset(recorder);
      expect(CrossAppLinkStatusRecorder.instance, same(recorder));

      CrossAppLinkStatusRecorder.reset();
      expect(CrossAppLinkStatusRecorder.instance, isNot(same(original)));
    });
  });
}
