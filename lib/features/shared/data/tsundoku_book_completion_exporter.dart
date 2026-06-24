import 'dart:convert';
import 'dart:io';

/// 読了イベントを共有ストレージにJSONとして書き出すエクスポーター
///
/// Kozuchiアプリが金運上昇バフ発動のために読み取れるよう、
/// 共有ストレージにJSONファイルを書き出す。
/// パス: /data/local/tmp/takamagahara_shared/tsundoku_book_completed.json
///
/// 既存の TsundokuRewardEventExporter（JSONL追記）とは別に、
/// Kozuchiが単一ファイル読み取りで完結できるように用意する。
class TsundokuBookCompletionExporter {
  /// 出力先ファイルパス
  final String filePath;

  const TsundokuBookCompletionExporter({
    this.filePath =
        '/data/local/tmp/takamagahara_shared/tsundoku_book_completed.json',
  });

  /// 読了イベントをエクスポート
  ///
  /// [bookId] 読了した本のID
  /// [bookTitle] 読了した本のタイトル（任意）
  /// [timestamp] 読了日時（ISO8601文字列）
  Future<void> exportBookCompleted({
    required String bookId,
    String? bookTitle,
    required String timestamp,
  }) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final json = {
      'event': 'book_completed',
      'bookId': bookId,
      'bookTitle': bookTitle ?? '',
      'timestamp': timestamp,
    };

    await file.writeAsString(jsonEncode(json));
  }
}
