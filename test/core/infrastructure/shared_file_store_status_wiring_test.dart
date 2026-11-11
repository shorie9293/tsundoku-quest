import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/infrastructure/cross_app_link_status_store.dart';
import 'package:tsundoku_quest/core/infrastructure/shared_file_store.dart';

/// FileSharedFileStore の読み書きが連携記録へ配線されていることの試練。
void main() {
  late Directory directory;
  late FileSharedFileStore store;
  late InMemoryCrossAppLinkStatusStore statusStore;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cross_app_link_');
    store = FileSharedFileStore(directory);
    statusStore = InMemoryCrossAppLinkStatusStore();
    CrossAppLinkStatusRecorder.reset(
      CrossAppLinkStatusRecorder(
        store: statusStore,
        now: () => DateTime(2026, 11, 11, 9, 0),
      ),
    );
  });

  tearDown(() async {
    CrossAppLinkStatusRecorder.reset();
    await directory.delete(recursive: true);
  });

  /// 記録は unawaited で走るため、イベントループを1周させて確定させる。
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('writeString は送信1件として記録する', () async {
    await store.writeString('a.json', '{"x":1}');
    await flush();

    final sent = CrossAppLinkStatusRecorder.instance.cached.lastSent;
    expect(sent, isNotNull);
    expect(sent!.ok, isTrue);
    expect(sent.count, 1);
    expect(sent.fileName, 'a.json');
    expect(sent.at, DateTime(2026, 11, 11, 9, 0));
  });

  test('appendLine は送信1件として記録する', () async {
    await store.appendLine('a.jsonl', '{"x":1}');
    await flush();

    final sent = CrossAppLinkStatusRecorder.instance.cached.lastSent;
    expect(sent, isNotNull);
    expect(sent!.ok, isTrue);
    expect(sent.count, 1);
    expect(sent.fileName, 'a.jsonl');
  });

  test('readString は受信として行数を記録する', () async {
    await store.writeString('a.jsonl', 'one\ntwo\n');
    await flush();
    await store.readString('a.jsonl');
    await flush();

    final received = CrossAppLinkStatusRecorder.instance.cached.lastReceived;
    expect(received, isNotNull);
    expect(received!.ok, isTrue);
    expect(received.count, 2);
    expect(received.fileName, 'a.jsonl');
  });

  test('存在しないファイルの readString は記録しない', () async {
    final content = await store.readString('missing.json');
    await flush();

    expect(content, isNull);
    expect(CrossAppLinkStatusRecorder.instance.cached.lastReceived, isNull);
  });

  test('書込失敗は送信失敗 ok=false として理由付きで記録する', () async {
    // ファイル名と同名のディレクトリを作り、書込を確実に失敗させる。
    await Directory('${directory.path}/blocked.json').create();

    await expectLater(
      store.writeString('blocked.json', 'x'),
      throwsA(isA<SharedStorageException>()),
    );
    await flush();

    final sent = CrossAppLinkStatusRecorder.instance.cached.lastSent;
    expect(sent, isNotNull);
    expect(sent!.ok, isFalse);
    expect(sent.fileName, 'blocked.json');
    expect(sent.error, isNotNull);
    expect(sent.error, isNotEmpty);
  });

  test('ensureDirectory はフォルダ可否を記録する', () async {
    final ok = await store.ensureDirectory();
    await flush();

    expect(ok, isTrue);
    expect(
      CrossAppLinkStatusRecorder.instance.cached.sharedFolderReady,
      isTrue,
    );
  });
}
