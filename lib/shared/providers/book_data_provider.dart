import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/shared_export_guard.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';
import 'package:tsundoku_quest/domain/repositories/user_book_repository.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/book_deletion_service.dart';
import 'package:tsundoku_quest/features/bookshelf/data/user_book_repository_provider.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_deletion_plan.dart';
import 'package:tsundoku_quest/features/reading/data/quick_memo_draft_store.dart';
import 'package:tsundoku_quest/features/reading/data/reading_session_repository_provider.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_provider.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_repository.dart';
import 'package:tsundoku_quest/features/shelves/data/shelf_repository_provider.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_reward_event_exporter.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_book_event_exporter.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_book_completion_exporter.dart';
import 'package:tsundoku_quest/features/shared/providers/reward_event_exporter_provider.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';
import 'package:tsundoku_quest/core/logging/app_logger.dart';

/// 読了ページ数マイルストーン閾値（1冊あたり）
const _bookPagesMilestones = [50, 100, 200, 500, 1000];

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
  final TsundokuRewardEventExporter? _rewardExporter;

  /// 試練用: 注入された書き出し先（Provider が単一インスタンスを渡しているか検証する）
  @visibleForTesting
  TsundokuRewardEventExporter? get rewardExporter => _rewardExporter;
  final TsundokuBookEventExporter? _bookEventExporter;
  final TsundokuBookCompletionExporter? _completionExporter;

  /// 本削除時に紐づく戦利品を削除するコールバック（warTrophyProvider 連携用）。
  /// Riverpod の循環参照を避けるため provider 側から注入する。
  void Function(String userBookId)? _trophyCleanup;

  /// 本削除時の連鎖削除（セッション/棚/キュー/メモ下書き）
  final BookDeletionService? _deletionService;

  /// 戦利品クリーンアップコールバックを設定する（provider 構築時に一度だけ呼ぶ）。
  // ignore: avoid_setters_without_getters
  set trophyCleanup(void Function(String userBookId)? callback) =>
      _trophyCleanup = callback;

  /// addUserBook 後に fetchBooks がインメモリデータを上書きするのを防ぐガード。
  /// addUserBook() で true に設定され、以降の fetchBooks() は
  /// state.userBooks が空でない限り早期リターンする。
  bool _initialFetchDone = false;

  /// [repository] が null の場合はインメモリモード、
  /// 指定時は Supabase 透過永続化モードで動作する。
  /// [rewardExporter] が指定された場合、本読了やページマイルストーン達成時に
  /// イベントを共有ストレージに書き出す。
  /// [bookEventExporter] が指定された場合、蔵書追加時に book_added イベントを
  /// 共有ストレージに書き出す（kozuchi アプリ連携用）。
  /// [completionExporter] が指定された場合、読了時に専用ファイルへの書き出しを行う（kozuchi金運バフ用）。
  /// [deletionService] が指定された場合、蔵書削除時に孤児データ（セッション/棚/
  /// 読書キュー/メモ下書き）を裏で連鎖削除する。
  BookDataNotifier([this._repository, this._sessionRepository, TsundokuRewardEventExporter? rewardExporter, TsundokuBookEventExporter? bookEventExporter, TsundokuBookCompletionExporter? completionExporter, BookDeletionService? deletionService])
      : _rewardExporter = rewardExporter,
        _bookEventExporter = bookEventExporter,
        _completionExporter = completionExporter,
        _deletionService = deletionService,
        super(BookDataState(isLoading: _repository != null));

  // ═══════════════════════════════════════════
  //  Supabase 連携
  // ═══════════════════════════════════════════

  /// Supabase から蔵書一覧を取得して state を更新する
  Future<void> fetchBooks() async {
    // ガード: addUserBook() が既にインメモリ状態を構築済みなら Supabase 取得をスキップ
    // （レースコンディション防止: 非同期の Supabase INSERT が完了していない状態で
    //   fetchBooks() が空データを返すと、インメモリのユーザーデータが上書き消失する）
    if (_initialFetchDone && state.userBooks.isNotEmpty) {
      appLog.debug('📦 [BookData] fetchBooks: 既に初期データあり→スキップ');
      return;
    }
    if (_repository == null) {
      appLog.debug('📦 [BookData] fetchBooks: リポジトリなし');
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: () => null);
    try {
      appLog.debug('📦 [BookData] fetchBooks: Supabaseから取得開始...');
      final books = await _repository.getMyBooks();
      appLog.debug('📦 [BookData] fetchBooks: ${books.length}件取得');
      state = state.copyWith(userBooks: books, isLoading: false);
    } catch (e, stack) {
      appLog.warn('📦 [BookData] fetchBooks 失敗: $e\n$stack');
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => '蔵書の取得に失敗しました: $e',
      );
    }
  }

  /// Supabase に蔵書追加（裏で非同期実行、UIは即時反映）
  Future<void> _syncAddToSupabase(UserBook userBook) async {
    if (_repository == null) {
      appLog.debug('📦 [BookData] リポジトリなし（オフラインモード）');
      return;
    }
    try {
      appLog.debug('📦 [BookData] Supabase保存開始: ${userBook.bookId}');
      await _repository.addBook(userBook);
      appLog.debug('📦 [BookData] Supabase保存成功: ${userBook.bookId}');
    } catch (e, stack) {
      appLog.warn('📦 [BookData] Supabase保存失敗: $e\n$stack');
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
  ///
  /// [index] を指定すると、その位置へ挿入する（一括削除の Undo で元の
  /// 並び順を取り戻すため）。範囲外はクランプされ、既存 ID の更新時は無視される。
  void addUserBook(UserBook userBook, {int? index}) {
    // 1. 即時UI反映（インメモリ）
    final updated = state.userBooks.toList();
    final existingIndex = updated.indexWhere((ub) => ub.id == userBook.id);
    if (existingIndex >= 0) {
      updated[existingIndex] = userBook;
    } else if (index != null) {
      final clamped = index.clamp(0, updated.length);
      updated.insert(clamped, userBook);
    } else {
      updated.add(userBook);
    }
    state = state.copyWith(userBooks: updated);

    // ガード: 初回の手動追加以降、fetchBooks() による上書きを防止
    _initialFetchDone = true;

    // 2. 裏でSupabase保存（失敗してもUIは崩さない）
    _syncAddToSupabase(userBook);

    // 3. 蔵書追加イベントを共有ストレージに書き出し（kozuchi連携）
    final bookEventExporter = _bookEventExporter;
    if (bookEventExporter != null) {
      guardSharedExport(
        bookEventExporter.exportBookAdded(
          bookTitle: userBook.book?.title ?? '不明',
          bookAuthor: userBook.book?.authors.isNotEmpty == true
              ? userBook.book!.authors.first
              : null,
          timestamp: DateTime.now().toUtc().toIso8601String(),
        ),
        label: 'book_added',
      );
    }
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

    // 報酬イベント: 読了
    if (status == BookStatus.completed && old.status != BookStatus.completed) {
      final rewardExporter = _rewardExporter;
      if (rewardExporter != null) {
        guardSharedExport(
          rewardExporter.exportBookCompleted(
            bookId: old.bookId,
            bookTitle: old.book?.title,
          ),
          label: 'book_completed',
        );
      }
      // Kozuchi金運バフ用: 専用ファイルにも読了イベントを書き出す
      final completionExporter = _completionExporter;
      if (completionExporter != null) {
        guardSharedExport(
          completionExporter.exportBookCompleted(
            bookId: old.bookId,
            bookTitle: old.book?.title,
            timestamp: DateTime.now().toUtc().toIso8601String(),
          ),
          label: 'book_completed_gold_luck',
        );
      }
    }

    // 報酬イベント: ページマイルストーン（1冊あたり）
    if (currentPage != null && currentPage > old.currentPage) {
      for (final milestone in _bookPagesMilestones) {
        if (old.currentPage < milestone && currentPage >= milestone) {
          final rewardExporter = _rewardExporter;
          if (rewardExporter != null) {
            guardSharedExport(
              rewardExporter.exportPagesMilestone(
                milestone: milestone,
                totalPages: currentPage,
              ),
              label: 'pages_milestone',
            );
          }
        }
      }
    }

    // 裏でSupabase保存
    _syncUpdateToSupabase(newBook);
  }

  /// 蔵書を削除。Supabase連携時は裏で非同期削除。
  void removeUserBook(String id) {
    final updated = state.userBooks.where((ub) => ub.id != id).toList();
    state = state.copyWith(userBooks: updated);

    // 紐づく戦利品（読書感想）も後片付け（足跡画面の「不明な本」残存防止）
    _trophyCleanup?.call(id);

    // 孤児データ（セッション/棚/読書キュー/メモ下書き）を裏で連鎖削除
    _runDeletionCleanup(id);

    // 裏でSupabase削除
    _syncDeleteFromSupabase(id);
  }

  /// 連鎖削除を投げっぱなしで実行する（UIを待たせず、例外も外へ出さない）。
  ///
  /// 呼出元（画面操作・試練）の zone を汚さないよう専用 zone で隔離する。
  /// 永続化層が未初期化の環境（headless 試練等）では Hive/SharedPreferences が
  /// 非同期に失敗し得るが、その失敗はここで握り、UI と既存試練を巻き込まない。
  void _runDeletionCleanup(String userBookId) {
    final service = _deletionService;
    if (service == null) return;
    unawaited(runZonedGuarded(
      () async {
        try {
          await service.run(BookDeletionPlan.forBook(userBookId));
        } catch (e, stack) {
          // service は throw しない契約だが、念のため握る
          appLog.warn('📦 [BookData] 連鎖削除で想定外の失敗: $e\n$stack');
        }
      },
      (e, stack) {
        // 永続化層の非同期失敗（Hive未初期化等）は隔離して記録のみ
        appLog.warn('📦 [BookData] 連鎖削除の非同期失敗を隔離: $e\n$stack');
      },
    ));
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
  ShelfRepository? shelfRepository;
  try {
    shelfRepository = ref.read(shelfRepositoryProvider);
  } catch (_) {
    // Hive未初期化（テスト環境）→ 棚掃除なしで動作
  }
  ReadingQueueRepository? readingQueueRepository;
  try {
    readingQueueRepository = ref.read(readingQueueRepositoryProvider);
  } catch (_) {
    // Hive未初期化（テスト環境）→ キュー掃除なしで動作
  }
  TsundokuRewardEventExporter? rewardExporter;
  try {
    rewardExporter = ref.read(tsundokuRewardEventExporterProvider);
  } catch (_) {
    // Supabase未初期化（テスト環境）→ 書き出しなしで動作
  }
  // 蔵書削除時の連鎖削除（孤児データ掃除）。
  // 戦利品は既存の trophyCleanup 経路（removeUserBook 内の直接呼出）が担うため、
  // service の trophies ステップには渡さない（二重削除の防止）。
  final deletionService = BookDeletionService(
    loadSessions: sessionRepository?.getByUserBook,
    deleteSession: sessionRepository?.deleteSession,
    loadShelves: shelfRepository?.listShelves,
    removeBookFromShelf: shelfRepository?.removeBookFromShelf,
    loadQueue: readingQueueRepository?.loadEntries,
    saveQueue: readingQueueRepository?.saveEntries,
    draftStore: SharedPreferencesQuickMemoDraftStore(),
  );
  return BookDataNotifier(
    repository,
    sessionRepository,
    rewardExporter,
    const TsundokuBookEventExporter(), // kozuchi 連携用（蔵書追加）
    const TsundokuBookCompletionExporter(), // kozuchi 連携用（読了→金運バフ）
    deletionService,
  )..trophyCleanup = (userBookId) {
      // 本削除時に紐づく戦利品（読書感想）も削除する
      try {
        ref
            .read(warTrophyProvider.notifier)
            .removeTrophiesByUserBook(userBookId);
      } catch (_) {
        // テスト環境等でリポジトリがない場合は何もしない
      }
    };
});
