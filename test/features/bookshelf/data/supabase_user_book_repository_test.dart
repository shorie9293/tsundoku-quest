import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/features/bookshelf/data/supabase_user_book_repository.dart';

/// _bookToSupabase 検証用のダミークライアント（変換のみで通信しない）
class _FakeClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('_bookToSupabase published_date 正規化（再起動後蔵書消失 禍津の回帰試練）', () {
    // 禍津: Google Books API の publishedDate は "2020" のような年のみ
    // 文字列を返すことがあり、Supabase の DATE 列が 22007 で拒否 →
    // books INSERT 失敗 → user_books にも登録されず、再起動後に蔵書が消える。
    // 修正: 日付として不正な形式は null に正規化する。

    Book makeBook(String? publishedDate) {
      return Book(
        id: 'test-book-id',
        title: 'テスト本',
        authors: const ['著者'],
        publishedDate: publishedDate,
        source: BookSource.googleBooks,
        createdAt: '2026-09-09T00:00:00.000Z',
      );
    }

    Map<String, dynamic> toSupabase(String? publishedDate) {
      // _bookToSupabase は private のため、public addBook 経由の代わりに
      // 可視化テスト用ヘルパー（@visibleForTesting）を経由する
      final repo = SupabaseUserBookRepository(_FakeClient());
      return repo.bookToSupabaseForTest(makeBook(publishedDate));
    }

    test('年のみ "2020" → null に正規化される', () {
      expect(toSupabase('2020')['published_date'], isNull);
    });

    test('年月のみ "2020-05" → null に正規化される（DATE は完全日付のみ許容）', () {
      expect(toSupabase('2020-05')['published_date'], isNull);
    });

    test('英文月名 "May 2020" → null に正規化される', () {
      expect(toSupabase('May 2020')['published_date'], isNull);
    });

    test('完全日付 "2020-05-01" → そのまま保持される', () {
      expect(toSupabase('2020-05-01')['published_date'], '2020-05-01');
    });

    test('null → null のまま', () {
      expect(toSupabase(null)['published_date'], isNull);
    });

    test('空文字 → null に正規化される', () {
      expect(toSupabase('')['published_date'], isNull);
    });
  });
}
