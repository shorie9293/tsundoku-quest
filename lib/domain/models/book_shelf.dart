import 'package:flutter/foundation.dart';

/// 自作棚（コレクション）モデル
///
/// 蔵書（UserBook）の状態管理（積読/読書中/読了）とは独立した、
/// 「自分だけの整理軸」として機能する。1つの蔵書は複数の棚に属せる
/// （タグ/コレクション的意味合い）。userBookIds は属する蔵書の id 一覧。
@immutable
class BookShelf {
  final String id;
  final String name;
  final int colorValue;
  final String createdAt;

  /// この棚に属する蔵書（UserBook）の id 一覧
  final List<String> userBookIds;

  const BookShelf({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    this.userBookIds = const [],
  });

  BookShelf copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? createdAt,
    List<String>? userBookIds,
  }) {
    return BookShelf(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      userBookIds: userBookIds ?? this.userBookIds,
    );
  }

  factory BookShelf.fromJson(Map<String, dynamic> json) {
    return BookShelf(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: json['colorValue'] as int? ?? 0,
      createdAt: json['createdAt'] as String,
      userBookIds:
          (json['userBookIds'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'createdAt': createdAt,
      'userBookIds': userBookIds,
    };
  }

  /// 棚を作成する（id は時刻から採番）
  factory BookShelf.create({
    required String name,
    int colorValue = 0,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    return BookShelf(
      id: n.microsecondsSinceEpoch.toString(),
      name: name,
      colorValue: colorValue,
      createdAt: n.toIso8601String(),
    );
  }
}
