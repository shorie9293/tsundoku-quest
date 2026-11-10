import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/infrastructure/shared_file_store.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_book_completion_exporter.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_book_event_exporter.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_reward_event_exporter.dart';

/// 共有ストアのフェイク。書込失敗を注入できる。
class _FakeSharedFileStore implements ISharedFileStore {
  _FakeSharedFileStore({this.failure});

  /// 非 null なら全操作がこの例外で失敗する。
  final Object? failure;

  final Map<String, String> files = <String, String>{};
  final List<String> appendedLines = <String>[];

  void _maybeFail(String operation, String fileName) {
    if (failure != null) {
      throw SharedStorageException(operation, fileName, failure);
    }
  }

  @override
  Future<bool> ensureDirectory() async => failure == null;

  @override
  Future<bool> chooseDirectory() async => failure == null;

  @override
  Future<void> writeString(String fileName, String content) async {
    _maybeFail('write', fileName);
    files[fileName] = content;
  }

  @override
  Future<void> appendLine(String fileName, String line) async {
    _maybeFail('append', fileName);
    appendedLines.add(line);
    files[fileName] = '${files[fileName] ?? ''}$line\n';
  }

  @override
  Future<String?> readString(String fileName) async {
    _maybeFail('read', fileName);
    return files[fileName];
  }

  @override
  Future<bool> delete(String fileName) async {
    _maybeFail('delete', fileName);
    return files.remove(fileName) != null;
  }

  @override
  Future<bool> exists(String fileName) async {
    _maybeFail('exists', fileName);
    return files.containsKey(fileName);
  }

  @override
  Future<List<String>> listFiles() async {
    _maybeFail('list', '*');
    return files.keys.toList(growable: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    SharedFileStore.reset();
    tmp = await Directory.systemTemp.createTemp('shared_store_test_');
  });

  tearDown(() async {
    SharedFileStore.reset();
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } catch (_) {
      // 後片付けはベストエフォート
    }
  });

  group('FileSharedFileStore', () {
    test('ensureDirectory はディレクトリを作る', () async {
      final dir = Directory('${tmp.path}/created/deep');
      final store = FileSharedFileStore(dir);

      expect(await store.ensureDirectory(), isTrue);
      expect(dir.existsSync(), isTrue);
    });

    test('writeString → readString で往復する', () async {
      final store = FileSharedFileStore(tmp);

      await store.writeString('a.json', '{"k":1}');

      expect(await store.readString('a.json'), '{"k":1}');
    });

    test('writeString は既存内容を上書きする', () async {
      final store = FileSharedFileStore(tmp);

      await store.writeString('a.json', 'old');
      await store.writeString('a.json', 'new');

      expect(await store.readString('a.json'), 'new');
    });

    test('appendLine は改行付きで追記する', () async {
      final store = FileSharedFileStore(tmp);

      await store.appendLine('e.jsonl', '{"n":1}');
      await store.appendLine('e.jsonl', '{"n":2}');

      final raw = await File('${tmp.path}/e.jsonl').readAsString();
      expect(raw, '{"n":1}\n{"n":2}\n');
    });

    test('readString は存在しないファイルで null', () async {
      final store = FileSharedFileStore(tmp);

      expect(await store.readString('missing.json'), isNull);
    });

    test('delete は存在すれば true・無ければ false', () async {
      final store = FileSharedFileStore(tmp);
      await store.writeString('a.json', 'x');

      expect(await store.delete('a.json'), isTrue);
      expect(await store.delete('a.json'), isFalse);
    });

    test('exists は有無を返す', () async {
      final store = FileSharedFileStore(tmp);
      await store.writeString('a.json', 'x');

      expect(await store.exists('a.json'), isTrue);
      expect(await store.exists('b.json'), isFalse);
    });

    test('listFiles はファイル名のみを返す', () async {
      final store = FileSharedFileStore(tmp);
      await store.writeString('a.json', '1');
      await store.writeString('b.jsonl', '2');
      await Directory('${tmp.path}/sub').create();

      final names = await store.listFiles();

      expect(names.toSet(), {'a.json', 'b.jsonl'});
    });

    test('listFiles はディレクトリ未作成なら空', () async {
      final store = FileSharedFileStore(Directory('${tmp.path}/none'));

      expect(await store.listFiles(), isEmpty);
    });

    test('chooseDirectory は実ファイル実装では ensureDirectory と同じ', () async {
      final store = FileSharedFileStore(Directory('${tmp.path}/chosen'));

      expect(await store.chooseDirectory(), isTrue);
      expect(Directory('${tmp.path}/chosen').existsSync(), isTrue);
    });
  });

  group('FileSharedFileStore の失敗は SharedStorageException になる', () {
    /// 親が通常ファイルなのでディレクトリ作成が必ず失敗するパス。
    Future<FileSharedFileStore> brokenStore() async {
      final blocker = File('${tmp.path}/blocker');
      await blocker.writeAsString('not a directory');
      return FileSharedFileStore(Directory('${blocker.path}/sub'));
    }

    test('writeString の失敗が operation=write で伝わる', () async {
      final store = await brokenStore();

      await expectLater(
        store.writeString('a.json', 'x'),
        throwsA(isA<SharedStorageException>()
            .having((e) => e.operation, 'operation', 'write')
            .having((e) => e.fileName, 'fileName', 'a.json')
            .having((e) => e.cause, 'cause', isNotNull)),
      );
    });

    test('appendLine の失敗が operation=append で伝わる', () async {
      final store = await brokenStore();

      await expectLater(
        store.appendLine('a.jsonl', 'x'),
        throwsA(isA<SharedStorageException>()
            .having((e) => e.operation, 'operation', 'append')),
      );
    });
  });

  group('AndroidSharedFileStore', () {
    const channel = MethodChannel('com.shorie.tsundoku/shared_storage');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('MethodChannel 名は契約どおり', () {
      // 既定チャネルで送った呼出がモックに届くこと自体が名前の検証になる。
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });

      return AndroidSharedFileStore().ensureDirectory().then((ok) {
        expect(ok, isTrue);
        expect(calls.single.method, 'ensureDirectory');
      });
    });

    test('PlatformException は SharedStorageException に変換される', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'no_directory', message: 'not chosen');
      });

      await expectLater(
        AndroidSharedFileStore().chooseDirectory(),
        throwsA(isA<SharedStorageException>()),
      );
    });

    test('書込時の PlatformException が operation=writeString で伝わる', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'ensureDirectory') return true;
        throw PlatformException(code: 'write_failed', message: 'io');
      });

      await expectLater(
        AndroidSharedFileStore().writeString('a.json', 'x'),
        throwsA(isA<SharedStorageException>()
            .having((e) => e.operation, 'operation', 'writeString')),
      );
    });

    test('ensureDirectory が false なら writeString は失敗する（無音にしない）', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => false);

      await expectLater(
        AndroidSharedFileStore().writeString('a.json', 'x'),
        throwsA(isA<SharedStorageException>()),
      );
    });

    test('writeString は name/content をネイティブへ渡す', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'ensureDirectory') return true;
        return null;
      });

      await AndroidSharedFileStore().writeString('a.json', '{"k":1}');

      final write = calls.firstWhere((c) => c.method == 'writeString');
      expect(write.arguments, {'name': 'a.json', 'content': '{"k":1}'});
    });

    test('ensureDirectory が false なら readString は null', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => false);

      expect(await AndroidSharedFileStore().readString('a.json'), isNull);
    });
  });

  group('エクスポーター（filePath 未指定）は共有ストアへ書く', () {
    test('報酬イベントは tsundoku_reward_events.jsonl へ追記される', () async {
      final store = _FakeSharedFileStore();
      SharedFileStore.configure(store);

      await TsundokuRewardEventExporter(userId: 'u1')
          .exportLevelUp(newLevel: 3, title: 't');

      final line = store.appendedLines.single;
      expect(
          store.files.keys, contains(SharedCrossAppFiles.tsundokuRewardEvents));
      final decoded = jsonDecode(line) as Map<String, dynamic>;
      expect(decoded['event_type'], 'level_up');
      expect(decoded['user_id'], 'u1');
      expect((decoded['metadata'] as Map)['new_level'], 3);
    });

    test('読了イベントは tsundoku_book_completed.json へ書かれる', () async {
      final store = _FakeSharedFileStore();
      SharedFileStore.configure(store);

      await TsundokuBookCompletionExporter().exportBookCompleted(
        bookId: 'b1',
        bookTitle: '本',
        timestamp: '2026-01-01T00:00:00Z',
      );

      final raw = store.files[SharedCrossAppFiles.tsundokuBookCompleted]!;
      expect(jsonDecode(raw), {
        'event': 'book_completed',
        'bookId': 'b1',
        'bookTitle': '本',
        'timestamp': '2026-01-01T00:00:00Z',
      });
    });

    test('蔵書追加イベントは tsundoku_book_events.json へ書かれる', () async {
      final store = _FakeSharedFileStore();
      SharedFileStore.configure(store);

      await TsundokuBookEventExporter().exportBookAdded(
        bookTitle: '本',
        timestamp: '2026-01-01T00:00:00Z',
      );

      final raw = store.files[SharedCrossAppFiles.tsundokuBookEvents]!;
      expect(jsonDecode(raw)['event'], 'book_added');
      expect(jsonDecode(raw)['bookAuthor'], '');
    });

    test('userId が空なら共有ストアへ1行も書かない', () async {
      final store = _FakeSharedFileStore();
      SharedFileStore.configure(store);

      await TsundokuRewardEventExporter().exportReadingStreak(streak: 7);

      expect(store.appendedLines, isEmpty);
      expect(store.files, isEmpty);
    });
  });

  group('共有ストアの失敗は呼び出し元で観測できる（無音でない）', () {
    test('報酬イベント書込失敗が SharedStorageException として伝わる', () async {
      SharedFileStore.configure(
        _FakeSharedFileStore(failure: const FileSystemException('read-only')),
      );

      await expectLater(
        TsundokuRewardEventExporter(userId: 'u1')
            .exportReadingStreak(streak: 3),
        throwsA(isA<SharedStorageException>()),
      );
    });

    test('読了イベント書込失敗が SharedStorageException として伝わる', () async {
      SharedFileStore.configure(
        _FakeSharedFileStore(failure: const FileSystemException('read-only')),
      );

      await expectLater(
        TsundokuBookCompletionExporter().exportBookCompleted(
          bookId: 'b1',
          timestamp: '2026-01-01T00:00:00Z',
        ),
        throwsA(isA<SharedStorageException>()
            .having((e) => e.operation, 'operation', 'write')),
      );
    });

    test('蔵書追加イベント書込失敗が SharedStorageException として伝わる', () async {
      SharedFileStore.configure(
        _FakeSharedFileStore(failure: const FileSystemException('read-only')),
      );

      await expectLater(
        TsundokuBookEventExporter().exportBookAdded(
          bookTitle: '本',
          timestamp: '2026-01-01T00:00:00Z',
        ),
        throwsA(isA<SharedStorageException>()),
      );
    });
  });

  group('filePath 指定時は従来どおり直書き（後方互換）', () {
    test('報酬イベントは明示パスへ追記される', () async {
      final path = '${tmp.path}/legacy.jsonl';

      await TsundokuRewardEventExporter(filePath: path, userId: 'u1')
          .exportLevelUp(newLevel: 1, title: 't');

      final lines = await File(path).readAsLines();
      expect(lines.length, 1);
      expect(jsonDecode(lines.single)['event_type'], 'level_up');
    });

    test('読了イベントは明示パスへ書かれる', () async {
      final path = '${tmp.path}/legacy_completed.json';

      await TsundokuBookCompletionExporter(filePath: path).exportBookCompleted(
        bookId: 'b1',
        timestamp: '2026-01-01T00:00:00Z',
      );

      expect(await File(path).exists(), isTrue);
    });
  });

  group('SharedFileStore の設定状態', () {
    test('configure 前は isConfigured=false・configure 後は true', () {
      expect(SharedFileStore.isConfigured, isFalse);

      SharedFileStore.configure(FileSharedFileStore(tmp));

      expect(SharedFileStore.isConfigured, isTrue);
    });

    test('reset で未設定に戻る', () {
      SharedFileStore.configure(FileSharedFileStore(tmp));
      SharedFileStore.reset();

      expect(SharedFileStore.isConfigured, isFalse);
    });
  });
}
