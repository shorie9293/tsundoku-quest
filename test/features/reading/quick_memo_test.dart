import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/features/reading/data/quick_memo_draft_store.dart';
import 'package:tsundoku_quest/features/reading/domain/quick_memo.dart';

void main() {
  group('QuickMemoPolicy', () {
    test('normalize は前後の空白のみ除去し改行を保つ', () {
      expect(QuickMemoPolicy.normalize('  一行目\n二行目  '), '一行目\n二行目');
      expect(QuickMemoPolicy.normalize('   '), '');
      expect(QuickMemoPolicy.normalize('本文'), '本文');
    });

    test('truncate は最大長で切り詰める', () {
      final body = 'あ' * (QuickMemoDraft.maxLength + 10);
      final truncated = QuickMemoPolicy.truncate(body);
      expect(truncated.length, QuickMemoDraft.maxLength);
      expect(QuickMemoPolicy.truncate('短い'), '短い');
    });

    test('shouldPersist は正規化後の変化だけを真とする', () {
      expect(
        QuickMemoPolicy.shouldPersist(previousBody: '', nextBody: 'メモ'),
        isTrue,
      );
      expect(
        QuickMemoPolicy.shouldPersist(previousBody: 'メモ', nextBody: ' メモ '),
        isFalse,
      );
      expect(
        QuickMemoPolicy.shouldPersist(previousBody: 'メモ', nextBody: ''),
        isTrue,
      );
    });

    test('shouldAttachToTrophy は空・空白のみを拒否する', () {
      expect(QuickMemoPolicy.shouldAttachToTrophy(''), isFalse);
      expect(QuickMemoPolicy.shouldAttachToTrophy('   '), isFalse);
      expect(QuickMemoPolicy.shouldAttachToTrophy('気づき'), isTrue);
    });
  });

  group('QuickMemoDraft', () {
    test('create は正規化と最大長丸めを適用し now を記録する', () {
      final now = DateTime.utc(2026, 11, 2, 9, 30);
      final draft = QuickMemoDraft.create('  ${
          'x' * (QuickMemoDraft.maxLength + 5)
        }  ', now: now);
      expect(draft.body.length, QuickMemoDraft.maxLength);
      expect(draft.updatedAt, now);
      expect(draft.isNotEmpty, isTrue);
      expect(QuickMemoDraft.create('  ', now: now).isEmpty, isTrue);
    });

    test('JSON 往復で本文と更新時刻を保つ', () {
      final draft = QuickMemoDraft(
        body: '学び\nメモ',
        updatedAt: DateTime.utc(2026, 11, 2, 0, 0),
      );
      final restored = QuickMemoDraft.fromJson(draft.toJson());
      expect(restored, draft);
    });

    test('fromJson は破損・欠損を null にする', () {
      expect(QuickMemoDraft.fromJson(null), isNull);
      expect(QuickMemoDraft.fromJson('文字列'), isNull);
      expect(QuickMemoDraft.fromJson({'body': 'x'}), isNull);
      expect(
        QuickMemoDraft.fromJson({'body': 1, 'updatedAt': '2026-11-02T00:00:00Z'}),
        isNull,
      );
      expect(
        QuickMemoDraft.fromJson({'body': 'x', 'updatedAt': 'not-a-date'}),
        isNull,
      );
    });
  });

  group('SharedPreferencesQuickMemoDraftStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('save → load → clear が往復する', () async {
      final store = SharedPreferencesQuickMemoDraftStore();
      final now = DateTime.utc(2026, 11, 2, 10);
      expect(await store.load('book-1'), isNull);

      await store.save('book-1', QuickMemoDraft(body: '下書き', updatedAt: now));
      final loaded = await store.load('book-1');
      expect(loaded?.body, '下書き');
      expect(loaded?.updatedAt, now);

      await store.clear('book-1');
      expect(await store.load('book-1'), isNull);
    });

    test('破損 JSON は null として無視する', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesQuickMemoDraftStore.keyFor('book-1'): '{壊れ',
      });
      final store = SharedPreferencesQuickMemoDraftStore();
      expect(await store.load('book-1'), isNull);
    });

    test('蔵書ごとに独立している', () async {
      final store = SharedPreferencesQuickMemoDraftStore();
      final now = DateTime.utc(2026, 11, 2, 10);
      await store.save('a', QuickMemoDraft(body: 'A', updatedAt: now));
      await store.save('b', QuickMemoDraft(body: 'B', updatedAt: now));
      expect((await store.load('a'))?.body, 'A');
      expect((await store.load('b'))?.body, 'B');
      await store.clear('a');
      expect(await store.load('a'), isNull);
      expect((await store.load('b'))?.body, 'B');
    });
  });

  group('InMemoryQuickMemoDraftStore', () {
    test('save/clear の呼出履歴を観測できる', () async {
      final store = InMemoryQuickMemoDraftStore();
      final now = DateTime.utc(2026, 11, 2);
      await store.save('id', QuickMemoDraft(body: 'x', updatedAt: now));
      await store.clear('id');
      expect(store.saveCalls, ['id']);
      expect(store.clearCalls, ['id']);
      expect(await store.load('id'), isNull);
    });
  });
}
