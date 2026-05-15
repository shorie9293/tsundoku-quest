import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/user_book.dart';
import '../../../domain/repositories/user_book_repository.dart';

/// Supabaseをデータストアに使用したUserBookRepositoryの具象実装
class SupabaseUserBookRepository implements UserBookRepository {
  final SupabaseClient _client;

  SupabaseUserBookRepository(this._client);

  @override
  Future<List<UserBook>> getMyBooks() async {
    final response = await _client
        .from('user_books')
        .select('*, book:books(*)')
        .order('created_at', ascending: false);
    return (response)
        .map((json) => UserBook.fromSupabase(json))
        .toList();
  }

  @override
  Future<List<UserBook>> getByStatus(BookStatus status) async {
    final response = await _client
        .from('user_books')
        .select('*, book:books(*)')
        .eq('status', status.value)
        .order('created_at', ascending: false);
    return (response)
        .map((json) => UserBook.fromSupabase(json))
        .toList();
  }

  @override
  Future<UserBook?> getById(String id) async {
    final response = await _client
        .from('user_books')
        .select('*, book:books(*)')
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return UserBook.fromSupabase(response);
  }

  @override
  Future<UserBook> addBook(UserBook userBook) async {
    final userId = _client.auth.currentUser?.id ??
        '00000000-0000-0000-0000-000000000000';

    // 1. 書籍マスターに登録（book_id がUUIDでない場合、自動生成）
    String bookId = userBook.bookId;
    if (userBook.book != null) {
      final bookData = _bookToSupabase(userBook.book!);
      bookData.remove('id'); // SupabaseにUUID自動生成させる
      final bookResult = await _client
          .from('books')
          .upsert(bookData)
          .select('id')
          .maybeSingle();
      if (bookResult != null) {
        bookId = bookResult['id'] as String;
      }
    }

    // 2. user_booksに登録（id は自動生成）
    final data = userBook.toSupabase();
    data.remove('id'); // SupabaseにUUID自動生成させる
    data['user_id'] = userId;
    data['book_id'] = bookId;

    final response = await _client
        .from('user_books')
        .insert(data)
        .select()
        .single();
    return UserBook.fromSupabase(response);
  }

  /// BookをSupabaseのスネークケース形式に変換
  Map<String, dynamic> _bookToSupabase(Book book) {
    return {
      'id': book.id,
      'isbn13': book.isbn13,
      'isbn10': book.isbn10,
      'title': book.title,
      'authors': book.authors,
      'publisher': book.publisher,
      'published_date': book.publishedDate,
      'description': book.description,
      'page_count': book.pageCount,
      'cover_image_url': book.coverImageUrl,
      'source': book.source.value,
      'created_at': book.createdAt,
    };
  }

  @override
  Future<UserBook> updateBook(UserBook userBook) async {
    final response = await _client
        .from('user_books')
        .update(userBook.toSupabase())
        .eq('id', userBook.id)
        .select()
        .single();
    return UserBook.fromSupabase(response);
  }

  @override
  Future<void> deleteBook(String id) async {
    await _client.from('user_books').delete().eq('id', id);
  }
}
