import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';

/// 「次に読む」キューの並び替え・解決を行う純粋ロジック。
///
/// UI・永続化に依存せず、与えられたリストのみから結果を返す。
/// すべてのメソッドは static かつ引数のリストを変更しない（非破壊）。
class ReadingQueueService {
  ReadingQueueService._();

  /// position を 1..n に詰め直し、
  /// position 昇順 → addedAt 昇順 → userBookId 昇順で安定ソートする。
  static List<ReadingQueueEntry> normalize(List<ReadingQueueEntry> entries) {
    final sorted = List<ReadingQueueEntry>.of(entries);
    sorted.sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      if (byPosition != 0) return byPosition;
      final byDate = a.addedAt.compareTo(b.addedAt);
      if (byDate != 0) return byDate;
      return a.userBookId.compareTo(b.userBookId);
    });
    return _renumber(sorted);
  }

  /// [userBookId] を末尾に追加する。
  ///
  /// 既に含まれるなら何も変更せず返す（冪等）。
  /// 空文字 [userBookId] は [ArgumentError]。
  static List<ReadingQueueEntry> enqueue(
    List<ReadingQueueEntry> current,
    String userBookId,
    DateTime addedAt,
  ) {
    if (userBookId.isEmpty) {
      throw ArgumentError.value(
        userBookId,
        'userBookId',
        'userBookId must not be empty',
      );
    }
    final ordered = normalize(current);
    if (ordered.any((entry) => entry.userBookId == userBookId)) {
      return ordered;
    }
    return [
      ...ordered,
      ReadingQueueEntry(
        userBookId: userBookId,
        position: ordered.length + 1,
        addedAt: addedAt,
      ),
    ];
  }

  /// リスト順に position を 1..n へ振り直す（並び替え結果を確定させる）。
  ///
  /// [normalize] は position を第一キーに再ソートするため、
  /// 並び替え後のリストに [normalize] を再適用すると順序が打ち消される。
  /// 並び替え系は必ず本メソッドで確定させること。
  static List<ReadingQueueEntry> _renumber(List<ReadingQueueEntry> entries) {
    return [
      for (var i = 0; i < entries.length; i++)
        entries[i].position == i + 1
            ? entries[i]
            : entries[i].copyWith(position: i + 1),
    ];
  }

  /// [userBookId] を除去して normalize する。
  static List<ReadingQueueEntry> dequeue(
    List<ReadingQueueEntry> current,
    String userBookId,
  ) {
    return normalize(
      current.where((entry) => entry.userBookId != userBookId).toList(),
    );
  }

  /// [userBookId] を1つ前へ移動する。先頭・不存在では何もしない。
  static List<ReadingQueueEntry> moveUp(
    List<ReadingQueueEntry> current,
    String userBookId,
  ) {
    return _moveBy(current, userBookId, -1);
  }

  /// [userBookId] を1つ後ろへ移動する。末尾・不存在では何もしない。
  static List<ReadingQueueEntry> moveDown(
    List<ReadingQueueEntry> current,
    String userBookId,
  ) {
    return _moveBy(current, userBookId, 1);
  }

  /// [userBookId] を 0 始まりの [index] へ移動する。範囲外では何もしない。
  static List<ReadingQueueEntry> moveTo(
    List<ReadingQueueEntry> current,
    String userBookId,
    int index,
  ) {
    final normalized = normalize(current);
    final from = normalized.indexWhere((entry) => entry.userBookId == userBookId);
    if (from < 0 || index < 0 || index >= normalized.length || index == from) {
      return normalized;
    }
    final list = List<ReadingQueueEntry>.of(normalized);
    final moved = list.removeAt(from);
    list.insert(index, moved);
    return _renumber(list);
  }

  static List<ReadingQueueEntry> _moveBy(
    List<ReadingQueueEntry> current,
    String userBookId,
    int delta,
  ) {
    final normalized = normalize(current);
    final from = normalized.indexWhere((entry) => entry.userBookId == userBookId);
    if (from < 0) return normalized;
    final to = from + delta;
    if (to < 0 || to >= normalized.length) return normalized;
    final list = List<ReadingQueueEntry>.of(normalized);
    final moved = list.removeAt(from);
    list.insert(to, moved);
    return _renumber(list);
  }

  /// キュー順を保ちつつ、[userBooks] に存在しない userBookId と
  /// status == BookStatus.completed の本を除外したリストを返す。
  static List<UserBook> resolveQueue(
    List<ReadingQueueEntry> entries,
    List<UserBook> userBooks,
  ) {
    final byId = {for (final ub in userBooks) ub.id: ub};
    final result = <UserBook>[];
    for (final entry in normalize(entries)) {
      final ub = byId[entry.userBookId];
      if (ub == null) continue;
      if (ub.status == BookStatus.completed) continue;
      result.add(ub);
    }
    return result;
  }

  /// 次に読むべき1冊（無ければ null）。
  static UserBook? nextToRead(
    List<ReadingQueueEntry> entries,
    List<UserBook> userBooks,
  ) {
    final queue = resolveQueue(entries, userBooks);
    return queue.isEmpty ? null : queue.first;
  }
}
