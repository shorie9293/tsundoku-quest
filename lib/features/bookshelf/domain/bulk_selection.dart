import 'dart:collection';

import '../../../domain/models/user_book.dart';

/// 本棚の一括操作で「どの蔵書が選ばれているか」を表す純粋値オブジェクト。
///
/// 内部は挿入順を保つ [LinkedHashSet] で、外部には unmodifiable な
/// [ids] としてのみ公開する。`toggle` / `selectAll` / `clear` は
/// いずれも新しいインスタンスを返し、元インスタンスは破壊しない
/// （Riverpod の状態更新で差分検知できるようにするため）。
class BulkSelection {
  final Set<String> _ids;

  /// 何も選択していない状態。
  const BulkSelection.empty() : _ids = const <String>{};

  const BulkSelection._(this._ids);

  /// [ids] を挿入順のまま選択状態にする。重複は 1 件に畳まれる。
  factory BulkSelection.of(Iterable<String> ids) {
    return BulkSelection._(
      UnmodifiableSetView<String>(LinkedHashSet<String>.of(ids)),
    );
  }

  /// 1 件以上選択されているか。
  bool get isSelecting => _ids.isNotEmpty;

  /// 選択件数。
  int get count => _ids.length;

  /// 選択中の蔵書 ID を挿入順で返す。返り値は変更不可。
  List<String> get ids => List<String>.unmodifiable(_ids);

  /// [id] が選択されているか。
  bool contains(String id) => _ids.contains(id);

  /// [id] の選択状態を反転した新しい選択を返す（追加／削除）。
  BulkSelection toggle(String id) {
    final next = LinkedHashSet<String>.of(_ids);
    if (!next.remove(id)) {
      next.add(id);
    }
    return BulkSelection._(UnmodifiableSetView<String>(next));
  }

  /// [ids] を既存選択に追加した新しい選択を返す。既存順を保ち重複は足さない。
  BulkSelection selectAll(Iterable<String> ids) {
    final next = LinkedHashSet<String>.of(_ids);
    next.addAll(ids);
    return BulkSelection._(UnmodifiableSetView<String>(next));
  }

  /// 全解除した新しい選択を返す。
  BulkSelection clear() => const BulkSelection.empty();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BulkSelection) return false;
    if (other._ids.length != _ids.length) return false;
    return _ids.every(other._ids.contains);
  }

  @override
  int get hashCode => Object.hashAllUnordered(_ids);

  @override
  String toString() => 'BulkSelection(${_ids.join(', ')})';
}

/// 一括削除の実行計画。
///
/// [toDelete] は実在する蔵書のみを本棚の元順序で保持する（Undo 復元順の
/// 安定性のため）。[unknownIds] は選択されたが本棚に存在しない ID で、
/// 画面側が「既に消えている」ことを無視できるようにするための情報。
class BulkDeletePlan {
  /// 実際に削除する蔵書。本棚の元順序を保つ。
  final List<UserBook> toDelete;

  /// 選択されたが本棚に存在しない ID。
  final List<String> unknownIds;

  const BulkDeletePlan({
    required this.toDelete,
    required this.unknownIds,
  });

  @override
  String toString() =>
      'BulkDeletePlan(toDelete: ${toDelete.length}, unknown: $unknownIds)';
}

/// [selection] を [books] に照合して一括削除の計画を組み立てる。
BulkDeletePlan buildBulkDeletePlan({
  required List<UserBook> books,
  required BulkSelection selection,
}) {
  final toDelete = <UserBook>[];
  final known = <String>{};
  for (final book in books) {
    if (selection.contains(book.id)) {
      toDelete.add(book);
    }
    known.add(book.id);
  }
  final unknownIds = selection.ids.where((id) => !known.contains(id)).toList();
  return BulkDeletePlan(toDelete: toDelete, unknownIds: unknownIds);
}

/// 棚へ移動する際の蔵書 ID 列を合成する。
///
/// [existing] の並び順を保ち、[adding] のうち未登録のものを末尾に足す。
/// 入力リストは破壊せず、返り値は変更不可。
List<String> mergeShelfBookIds({
  required List<String> existing,
  required Iterable<String> adding,
}) {
  final merged = LinkedHashSet<String>.of(existing)..addAll(adding);
  return List<String>.unmodifiable(merged);
}
