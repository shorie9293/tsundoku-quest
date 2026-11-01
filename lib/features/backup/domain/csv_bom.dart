/// CSV 共有用の UTF-8 BOM 付与（純粋関数）
///
/// 【禍津の根治】
/// 旧 `SharePlusBackupGateway` は `Uint8List.fromList(body.codeUnits)` を用いていた。
/// `codeUnits` は UTF-16 コードユニット列であり、日本語（'あ'=0x3042）は
/// Uint8List 変換時に下位バイト 0x42 へ切り詰められ、バイト列自体が破壊される。
/// 本ヘルパは常に `utf8.encode` を用い、CSV には BOM を付す。
///
/// BOM は Excel(Windows/macOS) が UTF-8 を ANSI と誤認するのを防ぐため必須。
library;

import 'dart:convert';

/// CSV の MIME タイプ判定（`text/csv; charset=utf-8` 等のパラメータ付きも許容）
bool isCsvMimeType(String mimeType) {
  final normalized = mimeType.trim().toLowerCase();
  return normalized == 'text/csv' || normalized.startsWith('text/csv;');
}

/// 先頭に U+FEFF を付した文字列を返す（元の文字列は改変しない）
String withUtf8Bom(String csv) => '\uFEFF$csv';

/// BOM 付き UTF-8 バイト列（先頭3バイトは 0xEF,0xBB,0xBF）
List<int> csvBytes(String csv) => utf8.encode(withUtf8Bom(csv));

/// 共有に渡すバイト列を組み立てる（純粋関数・プラットフォーム非依存）
///
/// - `text/csv` 系: BOM 付き UTF-8
/// - それ以外（JSON 等）: BOM 無し UTF-8
List<int> shareFileBytes({required String mimeType, required String body}) {
  return isCsvMimeType(mimeType) ? csvBytes(body) : utf8.encode(body);
}
