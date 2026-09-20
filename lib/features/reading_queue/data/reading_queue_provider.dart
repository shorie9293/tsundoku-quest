/// 「次に読む」読書キューの Riverpod 配線
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_repository.dart';
import 'package:tsundoku_quest/features/reading_queue/domain/reading_queue_service.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

/// リポジトリ
///
/// HiveBoxManager が初期化されていれば Hive 永続化、それ以外は
/// インメモリ実装にフォールバックする（テスト／オフライン用）。
final readingQueueRepositoryProvider = Provider<ReadingQueueRepository>((ref) {
  try {
    final boxManager = ref.read(hiveBoxManagerProvider);
    return HiveReadingQueueRepository(boxManager);
  } catch (_) {
    return InMemoryReadingQueueRepository();
  }
});

/// 読書キューの状態管理
///
/// state は常に [ReadingQueueService.normalize] 済みのリスト。
/// 変更操作は repository へ永続化してから state に反映する。
class ReadingQueueController extends StateNotifier<List<ReadingQueueEntry>> {
  ReadingQueueController(this._repository) : super(const []);

  final ReadingQueueRepository _repository;

  /// 保存済みキューを読み込む
  Future<void> load() async {
    state = await _repository.loadEntries();
  }

  /// [userBookId] を末尾に追加する
  Future<void> enqueue(String userBookId, {DateTime? addedAt}) async {
    final next = ReadingQueueService.enqueue(
      state,
      userBookId,
      addedAt ?? DateTime.now(),
    );
    await _repository.saveEntries(next);
    state = next;
  }

  /// [userBookId] をキューから除去する
  Future<void> dequeue(String userBookId) async {
    final next = ReadingQueueService.dequeue(state, userBookId);
    await _repository.saveEntries(next);
    state = next;
  }

  /// [userBookId] を1つ前へ移動する
  Future<void> moveUp(String userBookId) => _reorder(
        (entries) => ReadingQueueService.moveUp(entries, userBookId),
      );

  /// [userBookId] を1つ後ろへ移動する
  Future<void> moveDown(String userBookId) => _reorder(
        (entries) => ReadingQueueService.moveDown(entries, userBookId),
      );

  /// [userBookId] を 0 始まりの [index] へ移動する
  Future<void> moveTo(String userBookId, int index) => _reorder(
        (entries) => ReadingQueueService.moveTo(entries, userBookId, index),
      );

  Future<void> _reorder(
    List<ReadingQueueEntry> Function(List<ReadingQueueEntry>) transform,
  ) async {
    final next = transform(state);
    await _repository.saveEntries(next);
    state = next;
  }
}

final readingQueueControllerProvider = StateNotifierProvider<
    ReadingQueueController, List<ReadingQueueEntry>>((ref) {
  return ReadingQueueController(ref.watch(readingQueueRepositoryProvider))
    ..load();
});

/// 次に読むべき1冊（無ければ null）
///
/// キュー順を保ちつつ、蔵書に存在しない本と読了済みを除外する。
final nextToReadProvider = Provider<UserBook?>((ref) {
  final entries = ref.watch(readingQueueControllerProvider);
  final userBooks = ref.watch(bookDataProvider).userBooks;
  return ReadingQueueService.nextToRead(entries, userBooks);
});

/// キュー順に並んだ読書予定の本一覧
final queuedBooksProvider = Provider<List<UserBook>>((ref) {
  final entries = ref.watch(readingQueueControllerProvider);
  final userBooks = ref.watch(bookDataProvider).userBooks;
  return ReadingQueueService.resolveQueue(entries, userBooks);
});
