import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/user_book.dart';
import '../../../domain/repositories/user_book_repository.dart';

/// ネットワークエラー時に投げられるカスタム例外
class NetworkException implements Exception {
  final String message;
  final Object? cause;

  NetworkException(this.message, [this.cause]);

  @override
  String toString() => 'NetworkException: $message';
}

/// Supabaseをデータストアに使用したUserBookRepositoryの具象実装
class SupabaseUserBookRepository implements UserBookRepository {
  final SupabaseClient _client;

  SupabaseUserBookRepository(this._client);

  @override
  Future<List<UserBook>> getMyBooks() async {
    try {
      final response = await _client
          .from('user_books')
          .select('*, book:books(*)')
          .order('created_at', ascending: false);
      return (response)
          .map((json) => UserBook.fromSupabase(json))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Supabase getMyBooks 失敗: $e');
      throw _wrapError(e);
    }
  }

  @override
  Future<List<UserBook>> getByStatus(BookStatus status) async {
    try {
      final response = await _client
          .from('user_books')
          .select('*, book:books(*)')
          .eq('status', status.value)
          .order('created_at', ascending: false);
      return (response)
          .map((json) => UserBook.fromSupabase(json))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Supabase getByStatus 失敗: $e');
      throw _wrapError(e);
    }
  }

  @override
  Future<UserBook?> getById(String id) async {
    try {
      final response = await _client
          .from('user_books')
          .select('*, book:books(*)')
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return UserBook.fromSupabase(response);
    } catch (e) {
      debugPrint('⚠️ Supabase getById 失敗: $e');
      throw _wrapError(e);
    }
  }

  @override
  Future<UserBook> addBook(UserBook userBook) async {
    try {
      final userId = _client.auth.currentUser?.id ??
          '00000000-0000-0000-0000-000000000000';

      // 1. 書籍マスターに登録（book_id がUUIDでない場合、自動生成）
      String bookId = userBook.bookId;
      if (userBook.book != null) {
        final bookData = _bookToSupabase(userBook.book!);
        bookData.remove('id'); // SupabaseにUUID自動生成させる
        
        // 空文字は UNIQUE 制約違反を防ぐため null に変換
        if (bookData['isbn13'] == '') bookData['isbn13'] = null;
        if (bookData['isbn10'] == '') bookData['isbn10'] = null;
        
        final isbn13 = bookData['isbn13'] as String?;
        Map<String, dynamic>? existingBook;
        
        if (isbn13 != null && isbn13.isNotEmpty) {
          existingBook = await _client
              .from('books')
              .select('id')
              .eq('isbn13', isbn13)
              .maybeSingle();
        }
        
        if (existingBook != null) {
          bookId = existingBook['id'] as String;
        } else {
          final bookResult = await _client
              .from('books')
              .insert(bookData)
              .select('id')
              .maybeSingle();
          if (bookResult != null) {
            bookId = bookResult['id'] as String;
          }
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
    } catch (e) {
      debugPrint('⚠️ Supabase addBook 失敗: $e');
      throw _wrapError(e);
    }
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
    try {
      final response = await _client
          .from('user_books')
          .update(userBook.toSupabase())
          .eq('id', userBook.id)
          .select()
          .single();
      return UserBook.fromSupabase(response);
    } catch (e) {
      debugPrint('⚠️ Supabase updateBook 失敗: $e');
      throw _wrapError(e);
    }
  }

  @override
  Future<void> deleteBook(String id) async {
    try {
      await _client.from('user_books').delete().eq('id', id);
    } catch (e) {
      debugPrint('⚠️ Supabase deleteBook 失敗: $e');
      throw _wrapError(e);
    }
  }

  /// 例外をラップして NetworkException に変換
  Exception _wrapError(Object e) {
    if (e is SocketException ||
        e is HandshakeException ||
        e.toString().contains('SocketException') ||
        e.toString().contains('Connection refused') ||
        e.toString().contains('Network is unreachable') ||
        e.toString().contains('Connection timed out')) {
      return NetworkException('ネットワーク接続に失敗しました', e);
    }
    if (e is NetworkException) return e;
    return Exception('Supabase操作に失敗しました: $e');
  }
}
