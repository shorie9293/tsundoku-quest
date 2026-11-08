/// 蔵書削除時に掃除すべき孤児データの種類。
///
/// 宣言順がそのまま削除順序（セッション→棚→読書キュー→クイックメモ下書き→戦利品）。
enum BookDeletionStep {
  sessions,
  shelves,
  readingQueue,
  quickMemoDraft,
  trophies,
}

/// 蔵書1冊の削除手順書（純粋ドメイン）。
///
/// Dart標準のみに依存し、I/O も Flutter も持たない。
/// 実際の削除は `BookDeletionService` が本計画の順序どおりに実行する。
class BookDeletionPlan {
  /// 対象の蔵書 id
  final String userBookId;

  BookDeletionPlan({required this.userBookId}) {
    if (userBookId.trim().isEmpty) {
      throw ArgumentError.value(
        userBookId,
        'userBookId',
        'userBookId must not be empty',
      );
    }
  }

  /// [userBookId] の削除計画を組み立てる
  factory BookDeletionPlan.forBook(String userBookId) =>
      BookDeletionPlan(userBookId: userBookId);

  /// 削除ステップ。enum 宣言順に固定（呼出側で並べ替えられない）
  List<BookDeletionStep> get steps => const [
        BookDeletionStep.sessions,
        BookDeletionStep.shelves,
        BookDeletionStep.readingQueue,
        BookDeletionStep.quickMemoDraft,
        BookDeletionStep.trophies,
      ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookDeletionPlan && other.userBookId == userBookId;

  @override
  int get hashCode => userBookId.hashCode;

  @override
  String toString() => 'BookDeletionPlan($userBookId)';
}
