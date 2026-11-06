/// かな表記ゆれの吸収（ひらがな⇄カタカナ・半角カナ→全角カナ）。
///
/// 検索時に「ひらがなで入力したが書名はカタカナ」「半角カナで入力した」といった
/// 表記ゆれを一致させるための純粋関数群。副作用なし・冪等。
///
/// 使い方（検索語と対象文字列の両方に適用する）:
/// ```dart
/// foldKana('ぐりむどうわ');   // => 'グリムドウワ'
/// foldKana('ｸﾞﾘﾑ');          // => 'グリム'
/// foldKana('グリム');         // => 'グリム'（不変）
/// ```
library;

/// 半角カタカナ（U+FF66..U+FF9D）→ 全角カタカナの表引き。
///
/// 濁点（U+FF9E）・半濁点（U+FF9F）は単独では結合できないため含めず、
/// 直前の文字と合成する処理を [foldKana] 内で行う。
const Map<int, String> _halfwidthKatakana = {
  0xFF66: 'ヲ', // ｦ
  0xFF67: 'ァ', // ｧ
  0xFF68: 'ィ', // ｨ
  0xFF69: 'ゥ', // ｩ
  0xFF6A: 'ェ', // ｪ
  0xFF6B: 'ォ', // ｫ
  0xFF6C: 'ャ', // ｬ
  0xFF6D: 'ュ', // ｭ
  0xFF6E: 'ョ', // ｮ
  0xFF6F: 'ッ', // ｯ
  0xFF70: 'ー', // ｰ
  0xFF71: 'ア', // ｱ
  0xFF72: 'イ', // ｲ
  0xFF73: 'ウ', // ｳ
  0xFF74: 'エ', // ｴ
  0xFF75: 'オ', // ｵ
  0xFF76: 'カ', // ｶ
  0xFF77: 'キ', // ｷ
  0xFF78: 'ク', // ｸ
  0xFF79: 'ケ', // ｹ
  0xFF7A: 'コ', // ｺ
  0xFF7B: 'サ', // ｻ
  0xFF7C: 'シ', // ｼ
  0xFF7D: 'ス', // ｽ
  0xFF7E: 'セ', // ｾ
  0xFF7F: 'ソ', // ｿ
  0xFF80: 'タ', // ﾀ
  0xFF81: 'チ', // ﾁ
  0xFF82: 'ツ', // ﾂ
  0xFF83: 'テ', // ﾃ
  0xFF84: 'ト', // ﾄ
  0xFF85: 'ナ', // ﾅ
  0xFF86: 'ニ', // ﾆ
  0xFF87: 'ヌ', // ﾇ
  0xFF88: 'ネ', // ﾈ
  0xFF89: 'ノ', // ﾉ
  0xFF8A: 'ハ', // ﾊ
  0xFF8B: 'ヒ', // ﾋ
  0xFF8C: 'フ', // ﾌ
  0xFF8D: 'ヘ', // ﾍ
  0xFF8E: 'ホ', // ﾎ
  0xFF8F: 'マ', // ﾏ
  0xFF90: 'ミ', // ﾐ
  0xFF91: 'ム', // ﾑ
  0xFF92: 'メ', // ﾒ
  0xFF93: 'モ', // ﾓ
  0xFF94: 'ヤ', // ﾔ
  0xFF95: 'ユ', // ﾕ
  0xFF96: 'ヨ', // ﾖ
  0xFF97: 'ラ', // ﾗ
  0xFF98: 'リ', // ﾘ
  0xFF99: 'ル', // ﾙ
  0xFF9A: 'レ', // ﾚ
  0xFF9B: 'ロ', // ﾛ
  0xFF9C: 'ワ', // ﾜ
  0xFF9D: 'ン', // ﾝ
};

/// 濁点（U+FF9E）との合成表。キーは合成前の全角カタカナ1文字。
const Map<String, String> _dakutenCombine = {
  'ウ': 'ヴ',
  'カ': 'ガ',
  'キ': 'ギ',
  'ク': 'グ',
  'ケ': 'ゲ',
  'コ': 'ゴ',
  'サ': 'ザ',
  'シ': 'ジ',
  'ス': 'ズ',
  'セ': 'ゼ',
  'ソ': 'ゾ',
  'タ': 'ダ',
  'チ': 'ヂ',
  'ツ': 'ヅ',
  'テ': 'デ',
  'ト': 'ド',
  'ハ': 'バ',
  'ヒ': 'ビ',
  'フ': 'ブ',
  'ヘ': 'ベ',
  'ホ': 'ボ',
  'ワ': 'ヷ',
  'ヰ': 'ヸ',
  'ヱ': 'ヹ',
  'ヲ': 'ヺ',
};

/// 半濁点（U+FF9F）との合成表。キーは合成前の全角カタカナ1文字。
const Map<String, String> _handakutenCombine = {
  'ハ': 'パ',
  'ヒ': 'ピ',
  'フ': 'プ',
  'ヘ': 'ペ',
  'ホ': 'ポ',
};

const int _dakuten = 0xFF9E;
const int _handakuten = 0xFF9F;

/// かな表記をカタカナへ寄せる。
///
/// - ひらがな U+3041..U+3096（ゕ・ゖ を含む）→ +0x60 でカタカナへ
/// - 半角カタカナ U+FF66..U+FF9D → 全角カタカナ（[_halfwidthKatakana]）
/// - 半角濁点/半濁点 U+FF9E/U+FF9F → 直前の文字と合成（ガ・パ 等）
/// - 全角カタカナ・ASCII・漢字などは不変
///
/// 冪等: `foldKana(foldKana(s)) == foldKana(s)`
String foldKana(String input) {
  if (input.isEmpty) return input;

  final out = <String>[];
  var changed = false;

  for (final rune in input.runes) {
    // ひらがな → カタカナ（ァ..ゖ の連続域）
    if (rune >= 0x3041 && rune <= 0x3096) {
      out.add(String.fromCharCode(rune + 0x60));
      changed = true;
      continue;
    }

    // 半角カタカナ → 全角カタカナ
    final fullwidth = _halfwidthKatakana[rune];
    if (fullwidth != null) {
      out.add(fullwidth);
      changed = true;
      continue;
    }

    // 半角濁点・半濁点は直前の文字と合成する
    if (rune == _dakuten || rune == _handakuten) {
      final table = rune == _dakuten ? _dakutenCombine : _handakutenCombine;
      if (out.isNotEmpty) {
        final combined = table[out.last];
        if (combined != null) {
          out[out.length - 1] = combined;
          changed = true;
          continue;
        }
      }
      // 合成先が無い場合は全角の結合用濁点/半濁点として残す（情報を落とさない）
      out.add(rune == _dakuten ? '\u3099' : '\u309A');
      changed = true;
      continue;
    }

    out.add(String.fromCharCode(rune));
  }

  return changed ? out.join() : input;
}
