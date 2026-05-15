import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/repositories/user_book_repository.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/user_book_repository_provider.dart';
import 'package:tsundoku_quest/features/reading/data/reading_session_repository_provider.dart';

/// 本データの状態
class BookDataState {
  final List<Book> books;
  final List<UserBook> userBooks;
  final List<WarTrophy> trophies;
  final bool isLoading;
  final String? errorMessage;

  const BookDataState({
    this.books = const [],
    this.userBooks = const [],
    this.trophies = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  BookDataState copyWith({
    List<Book>? books,
    List<UserBook>? userBooks,
    List<WarTrophy>? trophies,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return BookDataState(
      books: books ?? this.books,
      userBooks: userBooks ?? this.userBooks,
      trophies: trophies ?? this.trophies,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

/// 本データを管理するStateNotifier
///
/// 透過型ハイブリッド:
/// - Repository あり → Supabase に永続化 + インメモリ即時反映
/// - Repository なし → インメモリのみ（テスト／オフライン用）
class BookDataNotifier extends StateNotifier<BookDataState> {
  final UserBookRepository? _repository;
  // ignore: unused_field — reserved for optional reading stats aggregation in fetchBooks
  final ReadingSessionRepository? _sessionRepository;

  /// [repository] が null の場合はインメモリモード、
  /// 指定時は Supabase 透過永続化モードで動作する。
  BookDataNotifier([this._repository, this._sessionRepository])
      : super(BookDataState(isLoading: _repository != null));

  // ═══════════════════════════════════════════
  //  Supabase 連携
  // ═══════════════════════════════════════════

  /// Supabase から蔵書一覧を取得して state を更新する
  Future<void> fetchBooks() async {
    if (_repository == null) {
      debugPrint('📦 [BookData] fetchBooks: リポジトリなし');
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      debugPrint('📦 [BookData] fetchBooks: Supabaseから取得開始...');
      final books = await _repository.getMyBooks();
      debugPrint('📦 [BookData] fetchBooks: ${books.length}件取得');
      state = state.copyWith(userBooks: books, isLoading: false);
    } catch (e, stack) {
      debugPrint('📦 [BookData] fetchBooks 失敗: $e\n$stack');
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => '蔵書の取得に失敗しました: $e',
      );
    }
  }

  /// Supabase に蔵書追加（裏で非同期実行、UIは即時反映）
  Future<void> _syncAddToSupabase(UserBook userBook) async {
    if (_repository == null) {
      debugPrint('📦 [BookData] リポジトリなし（オフラインモード）');
      return;
    }
    try {
      debugPrint('📦 [BookData] Supabase保存開始: ${userBook.bookId}');
      await _repository.addBook(userBook);
      debugPrint('📦 [BookData] Supabase保存成功: ${userBook.bookId}');
    } catch (e, stack) {
      debugPrint('📦 [BookData] Supabase保存失敗: $e\n$stack');
      state = state.copyWith(
        errorMessage: () => 'Supabase保存失敗（端末内のみ反映）: $e',
      );
    }
  }

  Future<void> _syncUpdateToSupabase(UserBook userBook) async {
    if (_repository == null) return;
    try {
      await _repository.updateBook(userBook);
    } catch (e) {
      state = state.copyWith(
        errorMessage: () => 'Supabase更新失敗: $e',
      );
    }
  }

  Future<void> _syncDeleteFromSupabase(String id) async {
    if (_repository == null) return;
    try {
      await _repository.deleteBook(id);
    } catch (e) {
      state = state.copyWith(
        errorMessage: () => 'Supabase削除失敗: $e',
      );
    }
  }

  // ═══════════════════════════════════════════
  //  Book 操作（インメモリのみ）
  // ═══════════════════════════════════════════

  void addBook(Book book) {
    final updatedBooks = state.books.toList();
    final existingIndex = updatedBooks.indexWhere((b) => b.id == book.id);
    if (existingIndex >= 0) {
      updatedBooks[existingIndex] = book;
    } else {
      updatedBooks.add(book);
    }
    state = state.copyWith(books: updatedBooks);
  }

  Book? getBook(String id) {
    try {
      return state.books.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════
  //  UserBook 操作（透過型: Supabaseあり→両方 / なし→メモリのみ）
  // ═══════════════════════════════════════════

  /// 蔵書を追加。Supabase連携時は裏で非同期保存。
  void addUserBook(UserBook userBook) {
    // 1. 即時UI反映（インメモリ）
    final updated = state.userBooks.toList();
    final existingIndex = updated.indexWhere((ub) => ub.id == userBook.id);
    if (existingIndex >= 0) {
      updated[existingIndex] = userBook;
    } else {
      updated.add(userBook);
    }
    state = state.copyWith(userBooks: updated);

    // 2. 裏でSupabase保存（失敗してもUIは崩さない）
    _syncAddToSupabase(userBook);
  }

  /// 蔵書を更新。Supabase連携時は裏で非同期保存。
  void updateUserBook({
    required String id,
    BookStatus? status,
    int? currentPage,
    int? totalReadingMinutes,
    int? rating,
    String? startedAt,
    String? completedAt,
    String? notes,
    BookMedium? medium,
  }) {
    final updated = state.userBooks.toList();
    final index = updated.indexWhere((ub) => ub.id == id);
    if (index < 0) return;

    final old = updated[index];
    final newBook = UserBook(
      id: old.id,
      userId: old.userId,
      bookId: old.bookId,
      book: old.book,
      status: status ?? old.status,
      medium: medium ?? old.medium,
      currentPage: currentPage ?? old.currentPage,
      totalReadingMinutes: totalReadingMinutes ?? old.totalReadingMinutes,
      rating: rating ?? old.rating,
      startedAt: startedAt ?? old.startedAt,
      completedAt: completedAt ?? old.completedAt,
      notes: notes ?? old.notes,
      createdAt: old.createdAt,
    );
    updated[index] = newBook;
    state = state.copyWith(userBooks: updated);

    // 裏でSupabase保存
    _syncUpdateToSupabase(newBook);
  }

  /// 蔵書を削除。Supabase連携時は裏で非同期削除。
  void removeUserBook(String id) {
    final updated = state.userBooks.where((ub) => ub.id != id).toList();
    state = state.copyWith(userBooks: updated);

    // 裏でSupabase削除
    _syncDeleteFromSupabase(id);
  }

  UserBook? getUserBook(String id) {
    try {
      return state.userBooks.firstWhere((ub) => ub.id == id);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════
  //  WarTrophy 操作（インメモリのみ）
  // ═══════════════════════════════════════════

  void addTrophy(WarTrophy trophy) {
    final updated = state.trophies.toList();
    final existingIndex = updated.indexWhere((t) => t.id == trophy.id);
    if (existingIndex >= 0) {
      updated[existingIndex] = trophy;
    } else {
      updated.add(trophy);
    }
    state = state.copyWith(trophies: updated);
  }

  WarTrophy? getTrophy(String id) {
    try {
      return state.trophies.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod プロバイダ
///
/// Supabase未初期化（テスト環境）ではリポジトリなしで動作。
/// 本番環境では起動時に fetchBooks() を呼ぶことで Supabase 連携が有効になる。
final bookDataProvider =
    StateNotifierProvider<BookDataNotifier, BookDataState>((ref) {
  UserBookRepository? repository;
  try {
    repository = ref.read(userBookRepositoryProvider);
  } catch (_) {
    // Supabase未初期化（テスト環境）→ リポジトリなしで動作
  }
  ReadingSessionRepository? sessionRepository;
  try {
    sessionRepository = ref.read(readingSessionRepositoryProvider);
  } catch (_) {
    // Supabase未初期化（テスト環境）→ リポジトリなしで動作
  }
  return BookDataNotifier(repository, sessionRepository);
});
