/// 「次に読む」キューの1エントリ。
///
/// [userBookId] の本を読む順序を [position]（1始まり）で表す。
/// 同一性は `userBookId` に基づく（同じ本はキュー内に1件のみ）。
class ReadingQueueEntry {
  final String userBookId;

  /// 読む順序（1始まり）
  final int position;
  final DateTime addedAt;

  ReadingQueueEntry({
    required this.userBookId,
    required this.position,
    required this.addedAt,
  }) {
    if (userBookId.isEmpty) {
      throw ArgumentError.value(
        userBookId,
        'userBookId',
        'userBookId must not be empty',
      );
    }
    if (position < 1) {
      throw ArgumentError.value(
        position,
        'position',
        'position must be >= 1',
      );
    }
  }

  ReadingQueueEntry copyWith({int? position, DateTime? addedAt}) {
    return ReadingQueueEntry(
      userBookId: userBookId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'userBookId': userBookId,
        'position': position,
        'addedAt': addedAt.toIso8601String(),
      };

  /// JSON マップから復元する。
  ///
  /// 必須項目の欠落・型不一致は [FormatException] を投げる
  /// （リポジトリ側で読み飛ばす判断ができるようにするため）。
  factory ReadingQueueEntry.fromJson(Map<String, dynamic> map) {
    final userBookId = map['userBookId'];
    if (userBookId is! String || userBookId.isEmpty) {
      throw const FormatException('ReadingQueueEntry.userBookId is missing');
    }
    final position = map['position'];
    if (position is! int || position < 1) {
      throw const FormatException('ReadingQueueEntry.position is invalid');
    }
    final addedAt = DateTime.tryParse('${map['addedAt']}');
    if (addedAt == null) {
      throw const FormatException('ReadingQueueEntry.addedAt is invalid');
    }
    return ReadingQueueEntry(
      userBookId: userBookId,
      position: position,
      addedAt: addedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingQueueEntry &&
          runtimeType == other.runtimeType &&
          userBookId == other.userBookId &&
          position == other.position;

  @override
  int get hashCode => Object.hash(userBookId, position);

  @override
  String toString() =>
      'ReadingQueueEntry(userBookId: $userBookId, position: $position)';
}
