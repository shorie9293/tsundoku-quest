import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/user_book.dart';
import '../../history/domain/reading_note_query.dart';
import '../domain/library_query.dart';

/// [LibraryQuery] の JSON シリアライズ（純粋関数のみ・Flutter 非依存）。
///
/// [decode] は決して例外を投げない。壊れた値・型不一致・未知 enum 名は
/// すべて既定値へフォールバックする（ユーザーの検索条件は失われても
/// アプリを壊してはならない）。
class LibraryQueryPreferences {
  const LibraryQueryPreferences._();

  static const String textKey = 'text';
  static const String statusesKey = 'statuses';
  static const String shelfIdKey = 'shelfId';
  static const String sortOrderKey = 'sortOrder';

  static String encode(LibraryQuery q) => jsonEncode(<String, Object?>{
        textKey: q.text,
        statusesKey: q.statuses.map((s) => s.name).toList(),
        shelfIdKey: q.shelfId,
        sortOrderKey: q.sortOrder.name,
      });

  static LibraryQuery decode(String? raw) {
    final map = _decodeObject(raw);
    if (map == null) return const LibraryQuery();
    return LibraryQuery(
      text: _asString(map[textKey]) ?? '',
      statuses: _enumNameSet(map[statusesKey], BookStatus.values),
      shelfId: _asString(map[shelfIdKey]),
      sortOrder: _enumByName(map[sortOrderKey], LibrarySortOrder.values) ??
          LibrarySortOrder.addedNewest,
    );
  }
}

/// [ReadingNoteQuery] の JSON シリアライズ（純粋関数のみ・Flutter 非依存）。
class ReadingNoteQueryPreferences {
  const ReadingNoteQueryPreferences._();

  static const String textKey = 'text';
  static const String bookTitlesKey = 'bookTitles';
  static const String contentFiltersKey = 'contentFilters';
  static const String sortOrderKey = 'sortOrder';

  static String encode(ReadingNoteQuery q) => jsonEncode(<String, Object?>{
        textKey: q.text,
        bookTitlesKey: q.bookTitles.toList(),
        contentFiltersKey: q.contentFilters.map((f) => f.name).toList(),
        sortOrderKey: q.sortOrder.name,
      });

  static ReadingNoteQuery decode(String? raw) {
    final map = _decodeObject(raw);
    if (map == null) return const ReadingNoteQuery();
    return ReadingNoteQuery(
      text: _asString(map[textKey]) ?? '',
      bookTitles: _stringSet(map[bookTitlesKey]),
      contentFilters:
          _enumNameSet(map[contentFiltersKey], ReadingNoteContentFilter.values),
      sortOrder: _enumByName(map[sortOrderKey], ReadingNoteSortOrder.values) ??
          ReadingNoteSortOrder.createdNewest,
    );
  }
}

/// JSON オブジェクトのみ受け付ける。それ以外は null。
Map<Object?, Object?>? _decodeObject(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return decoded;
    return null;
  } catch (_) {
    return null;
  }
}

String? _asString(Object? value) => value is String ? value : null;

T? _enumByName<T extends Enum>(Object? raw, List<T> values) {
  final name = _asString(raw);
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

/// 文字列リスト → enum 集合。未知名・非文字列要素は個別に捨てる。
Set<T> _enumNameSet<T extends Enum>(Object? raw, List<T> values) {
  if (raw is! List) return <T>{};
  final result = <T>{};
  for (final item in raw) {
    final value = _enumByName(item, values);
    if (value != null) result.add(value);
  }
  return result;
}

/// 文字列リスト → 文字列集合。非文字列要素は個別に捨てる。
Set<String> _stringSet(Object? raw) {
  if (raw is! List) return <String>{};
  final result = <String>{};
  for (final item in raw) {
    final value = _asString(item);
    if (value != null) result.add(value);
  }
  return result;
}

/// 検索条件の保存先（試練では差し替え可能）
abstract class LibraryQueryPreferencesStore {
  Future<LibraryQuery?> load();
  Future<void> save(LibraryQuery q);
}

/// 読書メモ検索条件の保存先（試練では差し替え可能）
abstract class ReadingNoteQueryPreferencesStore {
  Future<ReadingNoteQuery?> load();
  Future<void> save(ReadingNoteQuery q);
}

/// SharedPreferences 実装。プラグイン不在・IO 失敗は握りつぶす
/// （永続化できないだけで、検索画面は操作可能でなければならない）。
class SharedPreferencesLibraryQueryPreferencesStore
    implements LibraryQueryPreferencesStore {
  static const String key = 'library_search_query_v1';

  const SharedPreferencesLibraryQueryPreferencesStore();

  @override
  Future<LibraryQuery?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return LibraryQueryPreferences.decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(LibraryQuery q) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, LibraryQueryPreferences.encode(q));
    } catch (_) {
      // 永続化失敗は無音（UX を妨げない）
    }
  }
}

class SharedPreferencesReadingNoteQueryPreferencesStore
    implements ReadingNoteQueryPreferencesStore {
  static const String key = 'reading_note_search_query_v1';

  const SharedPreferencesReadingNoteQueryPreferencesStore();

  @override
  Future<ReadingNoteQuery?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return ReadingNoteQueryPreferences.decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(ReadingNoteQuery q) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, ReadingNoteQueryPreferences.encode(q));
    } catch (_) {
      // 永続化失敗は無音
    }
  }
}
