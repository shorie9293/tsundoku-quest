/// 蔵書の単体削除を取り消す（Undo）ための純粋ドメイン。
///
/// [BookRestorePlan] は削除計画（[BookDeletionPlan]）の**逆順**を宣言で固定する。
/// 呼出側が並べ替えることはできない（`steps` は常に同じ並びを返す）。
/// I/O も Flutter も持たない。
library;

import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_deletion_plan.dart';
import 'package:tsundoku_quest/features/reading/domain/quick_memo.dart';

/// 蔵書1冊の復元手順。
///
/// 宣言順がそのまま復元順序。子データは削除計画の逆順、本体（[book]）は
/// 子の復元先が存在するよう先頭に置く。
enum BookRestoreStep {
  /// 蔵書本体（削除計画に対応する削除ステップを持たない）
  book,

  /// 戦利品（削除計画の末尾）
  trophies,

  /// クイックメモ下書き
  quickMemoDraft,

  /// 読書キュー
  readingQueue,

  /// 棚との紐付け
  shelves,

  /// 読書セッション（削除計画の先頭）
  sessions,
}

/// 蔵書1冊の復元手順書（純粋ドメイン）。
class BookRestorePlan {
  /// 対象の蔵書 id
  final String userBookId;

  BookRestorePlan({required this.userBookId}) {
    if (userBookId.trim().isEmpty) {
      throw ArgumentError.value(
        userBookId,
        'userBookId',
        'userBookId must not be empty',
      );
    }
  }

  /// [userBookId] の復元計画を組み立てる
  factory BookRestorePlan.forBook(String userBookId) =>
      BookRestorePlan(userBookId: userBookId);

  /// 復元ステップ。宣言順に固定（呼出側で並べ替えられない）
  List<BookRestoreStep> get steps => const [
        BookRestoreStep.book,
        BookRestoreStep.trophies,
        BookRestoreStep.quickMemoDraft,
        BookRestoreStep.readingQueue,
        BookRestoreStep.shelves,
        BookRestoreStep.sessions,
      ];

  /// 削除計画側の子ステップの逆順（[steps] から本体を除いたもの）。
  ///
  /// この並びが [BookDeletionPlan.steps] の厳密な逆順であることを試練が固定する。
  static const List<BookRestoreStep> childStepsInReverseDeletionOrder = [
    BookRestoreStep.trophies,
    BookRestoreStep.quickMemoDraft,
    BookRestoreStep.readingQueue,
    BookRestoreStep.shelves,
    BookRestoreStep.sessions,
  ];

  /// 削除ステップ → 復元ステップの対応（逆順の根拠をコード上で1箇所に固定）
  static Map<BookDeletionStep, BookRestoreStep> get reverseOfDeletion => {
        for (final i in childStepsInReverseDeletionOrder.indexed)
          BookDeletionStep.values[BookDeletionStep.values.length - 1 - i.$1]:
              i.$2,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookRestorePlan && other.userBookId == userBookId;

  @override
  int get hashCode => userBookId.hashCode;

  @override
  String toString() => 'BookRestorePlan($userBookId)';
}

/// 削除**前**に取得する復元用スナップショット。
///
/// 空 id を渡すと [ArgumentError]（const 本体を持てないため非const生成）。
class BookRestoreSnapshot {
  /// 削除された蔵書本体
  final UserBook userBook;

  /// 紐づいていた読書セッション（削除前の完成済みオブジェクト）
  final List<ReadingSession> sessions;

  /// 所属していた棚の id
  final List<String> shelfIds;

  /// 読書キュー内のエントリ（position / addedAt 保持）
  final List<ReadingQueueEntry> queueEntries;

  /// クイックメモ下書き（無ければ null）
  final QuickMemoDraft? quickMemoDraft;

  /// 削除された戦利品
  final List<WarTrophy> trophies;

  BookRestoreSnapshot({
    required this.userBook,
    this.sessions = const [],
    this.shelfIds = const [],
    this.queueEntries = const [],
    this.quickMemoDraft,
    this.trophies = const [],
  }) {
    if (userBook.id.trim().isEmpty) {
      throw ArgumentError.value(
          userBook.id, 'userBook.id', 'must not be empty');
    }
    for (final session in sessions) {
      if (session.id.trim().isEmpty) {
        throw ArgumentError.value(
            session.id, 'sessions[].id', 'must not be empty');
      }
    }
    for (final shelfId in shelfIds) {
      if (shelfId.trim().isEmpty) {
        throw ArgumentError.value(shelfId, 'shelfIds[]', 'must not be empty');
      }
    }
    for (final entry in queueEntries) {
      if (entry.userBookId.trim().isEmpty) {
        throw ArgumentError.value(
          entry.userBookId,
          'queueEntries[].userBookId',
          'must not be empty',
        );
      }
    }
    for (final trophy in trophies) {
      if (trophy.id.trim().isEmpty) {
        throw ArgumentError.value(
            trophy.id, 'trophies[].id', 'must not be empty');
      }
    }
  }

  /// 復元対象が本体だけか（子データを持たない）
  bool get hasChildren =>
      sessions.isNotEmpty ||
      shelfIds.isNotEmpty ||
      queueEntries.isNotEmpty ||
      quickMemoDraft != null ||
      trophies.isNotEmpty;

  /// 子データの総件数（本体は含まない）
  int get childCount =>
      sessions.length +
      shelfIds.length +
      queueEntries.length +
      (quickMemoDraft != null ? 1 : 0) +
      trophies.length;

  @override
  String toString() => 'BookRestoreSnapshot(${userBook.id}, '
      'sessions: ${sessions.length}, shelves: ${shelfIds.length}, '
      'queue: ${queueEntries.length}, memo: ${quickMemoDraft != null}, '
      'trophies: ${trophies.length})';
}
