import 'dart:convert';
import 'dart:io';

/// 蔵書追加イベントを共有ストレージにJSONとして書き出すエクスポーター
///
/// Kozuchiアプリが読み取れるよう、共有ストレージにJSONファイルを書き出す。
/// パス: /data/local/tmp/takamagahara_shared/tsundoku_book_events.json
class TsundokuBookEventExporter {
  final String filePath;

  const TsundokuBookEventExporter({
    this.filePath = '/data/local/tmp/takamagahara_shared/tsundoku_book_events.json',
  });

  /// 蔵書追加イベントをエクスポート
  /// [bookTitle] 追加された本のタイトル
  /// [bookAuthor] 追加された本の著者（任意）
  /// [timestamp] 追加された時刻（ISO8601文字列）
  ///
  /// 共有ストレージ書き込みはベストエフォート。失敗しても蔵書追加の
  /// 本処理（UI・Supabase・Hive）を妨げないよう例外は握りつぶす。
  /// （テスト環境や共有ストレージ未マウント環境では /data が書けず
  ///  PathAccessException になるため、単体テストを壊さないための防御。）
  Future<void> exportBookAdded({
    required String bookTitle,
    String? bookAuthor,
    required String timestamp,
  }) async {
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);

      final json = {
        'event': 'book_added',
        'bookTitle': bookTitle,
        'bookAuthor': bookAuthor ?? '',
        'timestamp': timestamp,
      };

      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      // 共有ストレージ書込はオプション機能。失敗は握りつぶす（ログのみ）。
      // ignore: avoid_print
      print('TsundokuBookEventExporter: 書き込み失敗（無視）: $e');
    }
  }
}
