import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/data/query_preferences.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/library_query.dart';
import 'package:tsundoku_quest/features/history/domain/reading_note_query.dart';

void main() {
  group('LibraryQueryPreferences codec', () {
    test('全フィールド round-trip（shelfId 非null）', () {
      const q = LibraryQuery(
        text: 'ぐりむ',
        statuses: {BookStatus.reading, BookStatus.completed},
        shelfId: 'shelf-1',
        sortOrder: LibrarySortOrder.pagesDesc,
      );
      expect(
          LibraryQueryPreferences.decode(LibraryQueryPreferences.encode(q)), q);
    });

    test('全フィールド round-trip（shelfId null・既定値）', () {
      const q = LibraryQuery();
      expect(
          LibraryQueryPreferences.decode(LibraryQueryPreferences.encode(q)), q);
      const q2 = LibraryQuery(text: 'a', statuses: {BookStatus.tsundoku});
      expect(LibraryQueryPreferences.decode(LibraryQueryPreferences.encode(q2)),
          q2);
    });

    test('null / 空 / 壊れたJSON は既定クエリ（例外なし）', () {
      expect(LibraryQueryPreferences.decode(null), const LibraryQuery());
      expect(LibraryQueryPreferences.decode(''), const LibraryQuery());
      expect(LibraryQueryPreferences.decode('not json'), const LibraryQuery());
      expect(LibraryQueryPreferences.decode('{"text":'), const LibraryQuery());
      expect(LibraryQueryPreferences.decode('[1,2,3]'), const LibraryQuery());
      expect(LibraryQueryPreferences.decode('"string"'), const LibraryQuery());
      expect(LibraryQueryPreferences.decode('123'), const LibraryQuery());
    });

    test('型不一致はそのフィールドだけ既定値', () {
      final q = LibraryQueryPreferences.decode(
          '{"text":123,"statuses":"tsundoku","shelfId":9,"sortOrder":true}');
      expect(q.text, '');
      expect(q.statuses, isEmpty);
      expect(q.shelfId, isNull);
      expect(q.sortOrder, LibrarySortOrder.addedNewest);
    });

    test('未知 enum 名は既定（不明要素は個別に捨てる）', () {
      final q = LibraryQueryPreferences.decode(
          '{"sortOrder":"nope","statuses":["nope","reading","tsundoku"]}');
      expect(q.sortOrder, LibrarySortOrder.addedNewest);
      expect(q.statuses, {BookStatus.reading, BookStatus.tsundoku});
    });

    test('未知キーは無視する', () {
      final q = LibraryQueryPreferences.decode(
          '{"text":"abc","unknownKey":42,"another":{"x":1}}');
      expect(q, const LibraryQuery(text: 'abc'));
    });
  });

  group('ReadingNoteQueryPreferences codec', () {
    test('全フィールド round-trip', () {
      const q = ReadingNoteQuery(
        text: '正義',
        bookTitles: {'坊っちゃん', '吾輩は猫である'},
        contentFilters: {
          ReadingNoteContentFilter.hasLearning,
          ReadingNoteContentFilter.hasQuote,
        },
        sortOrder: ReadingNoteSortOrder.titleAsc,
      );
      expect(
          ReadingNoteQueryPreferences.decode(
              ReadingNoteQueryPreferences.encode(q)),
          q);
    });

    test('既定値 round-trip', () {
      const q = ReadingNoteQuery();
      expect(
          ReadingNoteQueryPreferences.decode(
              ReadingNoteQueryPreferences.encode(q)),
          q);
    });

    test('null / 空 / 壊れたJSON / 型不一致 / 未知enum（例外なし）', () {
      expect(
          ReadingNoteQueryPreferences.decode(null), const ReadingNoteQuery());
      expect(ReadingNoteQueryPreferences.decode(''), const ReadingNoteQuery());
      expect(
          ReadingNoteQueryPreferences.decode('{{{'), const ReadingNoteQuery());
      expect(
          ReadingNoteQueryPreferences.decode(
              '{"text":1,"bookTitles":1,"contentFilters":[1],"sortOrder":"x"}'),
          const ReadingNoteQuery());
      final q = ReadingNoteQueryPreferences.decode(
          '{"bookTitles":["a",3],"contentFilters":["hasAction","bogus"]}');
      expect(q.bookTitles, {'a'});
      expect(q.contentFilters, {ReadingNoteContentFilter.hasAction});
      expect(q.sortOrder, ReadingNoteSortOrder.createdNewest);
    });

    test('未知キーは無視する', () {
      expect(ReadingNoteQueryPreferences.decode('{"text":"x","zzz":1}'),
          const ReadingNoteQuery(text: 'x'));
    });
  });

  group('SharedPreferences ストア', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('save → load round-trip（本棚検索）', () async {
      const store = SharedPreferencesLibraryQueryPreferencesStore();
      const q = LibraryQuery(
          text: '猫',
          statuses: {BookStatus.completed},
          shelfId: 's1',
          sortOrder: LibrarySortOrder.authorAsc);
      await store.save(q);
      expect(await store.load(), q);
    });

    test('キー不在は null', () async {
      const store = SharedPreferencesLibraryQueryPreferencesStore();
      expect(await store.load(), isNull);
    });

    test('壊れた値は既定クエリ', () async {
      SharedPreferences.setMockInitialValues(
          {SharedPreferencesLibraryQueryPreferencesStore.key: '{{{'});
      const store = SharedPreferencesLibraryQueryPreferencesStore();
      expect(await store.load(), const LibraryQuery());
    });

    test('save → load round-trip（読書メモ検索）', () async {
      const store = SharedPreferencesReadingNoteQueryPreferencesStore();
      const q = ReadingNoteQuery(
          text: '学び',
          bookTitles: {'本'},
          contentFilters: {ReadingNoteContentFilter.hasAction},
          sortOrder: ReadingNoteSortOrder.learningCountDesc);
      await store.save(q);
      expect(await store.load(), q);
    });

    test('読書メモ: キー不在は null・壊れた値は既定', () async {
      const store = SharedPreferencesReadingNoteQueryPreferencesStore();
      expect(await store.load(), isNull);
      SharedPreferences.setMockInitialValues(
          {SharedPreferencesReadingNoteQueryPreferencesStore.key: '[]'});
      expect(await store.load(), const ReadingNoteQuery());
    });
  });
}
