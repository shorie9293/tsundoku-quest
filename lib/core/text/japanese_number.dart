/// 日本語入力の数値正規化（全角数字・全角カンマ・全角マイナス）。
///
/// 日本語IMEでは「１２３」「１，２３４」「－５」が普通に入力される。
/// これらをそのまま `int.tryParse` へ渡すと null になり、呼び出し側の
/// フォールバックが黙って 0 を保存してしまう（改善提案#215）。
/// 本モジュールは全角表記を半角へ寄せてから解釈する純粋関数のみを提供する。
/// 副作用なし・外部依存なし。
///
/// 使い方:
/// ```dart
/// JapaneseNumber.normalizeDigits('１，２３４'); // => '1234'
/// JapaneseNumber.tryParseInt('－４２');          // => -42
/// JapaneseNumber.tryParseInt('たくさん');        // => null
/// JapaneseNumber.parseIntOr(null, 0);           // => 0
/// ```
library;

/// 全角数字・全角カンマ・全角マイナスを吸収して整数を解釈する。
class JapaneseNumber {
  const JapaneseNumber._();

  /// 全角数字０（U+FF10）
  static const int _fullwidthDigitZero = 0xFF10;

  /// 全角数字９（U+FF19）
  static const int _fullwidthDigitNine = 0xFF19;

  /// 全角英数字とASCIIの差分（'０' - '0'）
  static const int _fullwidthAsciiOffset = 0xFEE0;

  /// 全角カンマ（，）
  static const int _fullwidthComma = 0xFF0C;

  /// 半角カンマ（,）
  static const int _comma = 0x2C;

  /// 全角空白（　）
  static const int _fullwidthSpace = 0x3000;

  /// 全角マイナス（－）
  static const int _fullwidthMinus = 0xFF0D;

  /// 数学記号のマイナス（−）
  static const int _minusSign = 0x2212;

  /// 全角数字・全角カンマ・全角空白・全角マイナスを半角ASCIIへ正規化し、
  /// 前後の空白を除去する。
  ///
  /// - 全角数字０-９（U+FF10..U+FF19）→ 半角 0-9
  /// - 全角カンマ（，）・半角カンマ（,）→ 除去（桁区切りとして扱う）
  /// - 全角空白（　）→ 半角空白
  /// - 全角マイナス（－ U+FF0D）・数学記号のマイナス（− U+2212）→ ASCII の `-`
  /// - その他の文字はそのまま残す（数字以外が混ざれば後段で null になる）
  ///
  /// 冪等: `normalizeDigits(normalizeDigits(s)) == normalizeDigits(s)`
  static String normalizeDigits(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      if (rune >= _fullwidthDigitZero && rune <= _fullwidthDigitNine) {
        buffer.writeCharCode(rune - _fullwidthAsciiOffset);
        continue;
      }
      if (rune == _fullwidthComma || rune == _comma) {
        continue; // 桁区切りは数値に影響しないため落とす
      }
      if (rune == _fullwidthSpace) {
        buffer.write(' ');
        continue;
      }
      if (rune == _fullwidthMinus || rune == _minusSign) {
        buffer.write('-');
        continue;
      }
      buffer.writeCharCode(rune);
    }
    return buffer.toString().trim();
  }

  /// 正規化したうえで整数として解釈する。解釈できなければ null。
  ///
  /// null・空文字・空白のみ・数字以外を含む入力（`123abc` 等）は null。
  static int? tryParseInt(String? raw) {
    if (raw == null) return null;
    final normalized = normalizeDigits(raw);
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  /// 正規化したうえで整数として解釈し、解釈できなければ [fallback] を返す。
  static int parseIntOr(String? raw, int fallback) =>
      tryParseInt(raw) ?? fallback;
}
