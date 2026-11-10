import 'dart:convert';
import 'dart:io';
import 'package:tsundoku_quest/core/infrastructure/shared_file_store.dart';
import 'package:tsundoku_quest/core/logging/app_logger.dart';

/// 読了イベントを共有ストレージにJSONとして書き出すエクスポーター
///
/// Kozuchiアプリが金運上昇バフ発動のために読み取れるよう、
/// 共有ストレージ（[SharedFileStore]。Android 実機では SAF の共有フォルダ）に
/// JSONファイルを書き出す。ファイル名の契約は
/// [SharedCrossAppFiles.tsundokuBookCompleted]。
///
/// 既存の TsundokuRewardEventExporter（JSONL追記）とは別に、
/// Kozuchiが単一ファイル読み取りで完結できるように用意する。
class TsundokuBookCompletionExporter {
  /// 試練用の明示パス。null なら共有ストア（[SharedFileStore]）経由。
  final String? filePath;

  const TsundokuBookCompletionExporter({this.filePath});

  /// 読了イベントをエクスポート
  ///
  /// [bookId] 読了した本のID
  /// [bookTitle] 読了した本のタイトル（任意）
  /// [timestamp] 読了日時（ISO8601文字列）
  ///
  /// 共有ストア経由の失敗は [SharedStorageException] として**上位へ伝える**
  /// （読了の本処理を止めないのは呼び出し側の責務）。
  Future<void> exportBookCompleted({
    required String bookId,
    String? bookTitle,
    required String timestamp,
  }) async {
    final json = {
      'event': 'book_completed',
      'bookId': bookId,
      'bookTitle': bookTitle ?? '',
      'timestamp': timestamp,
    };
    final payload = jsonEncode(json);

    if (filePath != null) {
      await _writeToFile(payload);
      return;
    }
    await SharedFileStore.instance.writeString(
      SharedCrossAppFiles.tsundokuBookCompleted,
      payload,
    );
  }

  /// 試練用: 明示パスへの直書き（従来の契約を保持）。
  ///
  /// 失敗は投げないが、無音にもしない（[appLog.warn] を1行残す）。
  Future<void> _writeToFile(String payload) async {
    try {
      final file = File(filePath!);
      await file.parent.create(recursive: true);
      await file.writeAsString(payload);
    } catch (e) {
      appLog.warn('TsundokuBookCompletionExporter: 書き込み失敗（明示パス・無視）: $e');
    }
  }
}
