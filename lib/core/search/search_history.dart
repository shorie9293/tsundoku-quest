import 'dart:convert';

/// 検索語の履歴（新しい順・最大 [maxEntries] 件）を保持する不変オブジェクト。
///
/// 純粋 Dart（Flutter 非依存）。[add] は新しいインスタンスを返し、
/// [encode] / [decode] は例外を投げない（破損値は空の履歴として扱う）。
class SearchHistory {
  /// 保持する最大件数。超えた分は最古から落とす。
  static const int maxEntries = 8;

  /// 新しい順の検索語リスト（変更不可）。
  final List<String> entries;

  SearchHistory({List<String> entries = const <String>[]})
      : entries = List<String>.unmodifiable(entries.take(maxEntries));

  /// 空の履歴。
  static SearchHistory empty() => SearchHistory();

  bool get isEmpty => entries.isEmpty;

  bool get isNotEmpty => entries.isNotEmpty;

  /// 検索語を正規化する。
  ///
  /// 前後空白の除去・全角空白（U+3000）→半角空白・連続空白の1つへの畳み込み。
  /// 空文字・空白のみは空文字を返す。
  static String normalize(String raw) {
    final halfWidth = raw.replaceAll('\u3000', ' ');
    final collapsed = halfWidth.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed;
  }

  /// 検索語を履歴へ追加した新しい履歴を返す。
  ///
  /// - 正規化後に空なら追加しない（[this] をそのまま返す）
  /// - 大文字小文字を区別しない完全一致は先頭へ移動し、表記を新しいもので更新
  /// - [maxEntries] を超えたら最古を落とす
  SearchHistory add(String raw) {
    final value = normalize(raw);
    if (value.isEmpty) return this;

    final key = value.toLowerCase();
    final next = <String>[value];
    for (final entry in entries) {
      if (entry.toLowerCase() == key) continue;
      next.add(entry);
    }
    return SearchHistory(entries: next);
  }

  /// JSON 文字列（文字列の配列）へ符号化する。
  String encode() => jsonEncode(entries);

  /// JSON 文字列から復号する。破損・型不一致は空の履歴へフォールバックする。
  static SearchHistory decode(String? raw) {
    if (raw == null || raw.isEmpty) return SearchHistory.empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return SearchHistory.empty();
      final values = <String>[];
      for (final item in decoded) {
        if (item is! String) continue;
        final value = normalize(item);
        if (value.isEmpty) continue;
        values.add(value);
      }
      return SearchHistory(entries: values);
    } catch (_) {
      return SearchHistory.empty();
    }
  }

  @override
  String toString() => 'SearchHistory($entries)';

  @override
  bool operator ==(Object other) =>
      other is SearchHistory &&
      other.entries.length == entries.length &&
      _indexedEquals(other.entries);

  bool _indexedEquals(List<String> other) {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(entries);
}
