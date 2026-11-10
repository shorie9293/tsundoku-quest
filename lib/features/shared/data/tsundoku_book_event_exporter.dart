import 'dart:convert';
import 'dart:io';
import 'package:tsundoku_quest/core/infrastructure/shared_file_store.dart';
import 'package:tsundoku_quest/core/logging/app_logger.dart';

/// 蔵書追加イベントを共有ストレージにJSONとして書き出すエクスポーター
///
/// Kozuchiアプリが読み取れるよう、共有ストレージ（[SharedFileStore]。
/// Android 実機では SAF の共有フォルダ）にJSONファイルを書き出す。
/// ファイル名の契約は [SharedCrossAppFiles.tsundokuBookEvents]。
class TsundokuBookEventExporter {
  /// 試練用の明示パス。null なら共有ストア（[SharedFileStore]）経由。
  final String? filePath;

  const TsundokuBookEventExporter({this.filePath});

  /// 蔵書追加イベントをエクスポート
  /// [bookTitle] 追加された本のタイトル
  /// [bookAuthor] 追加された本の著者（任意）
  /// [timestamp] 追加された時刻（ISO8601文字列）
  ///
  /// 共有ストア経由の失敗は [SharedStorageException] として**上位へ伝える**
  /// （UI・Supabase・Hive の本処理を止めないのは呼び出し側の責務）。
  Future<void> exportBookAdded({
    required String bookTitle,
    String? bookAuthor,
    required String timestamp,
  }) async {
    final json = {
      'event': 'book_added',
      'bookTitle': bookTitle,
      'bookAuthor': bookAuthor ?? '',
      'timestamp': timestamp,
    };
    final payload = jsonEncode(json);

    if (filePath != null) {
      await _writeToFile(payload);
      return;
    }
    await SharedFileStore.instance.writeString(
      SharedCrossAppFiles.tsundokuBookEvents,
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
      appLog.warn('TsundokuBookEventExporter: 書き込み失敗（明示パス・無視）: $e');
    }
  }
}
