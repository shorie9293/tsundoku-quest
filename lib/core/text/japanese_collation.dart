/// 書名の「日本語かな順」ソート用の照合キー・比較器。
///
/// 従来の `String.compareTo` はコードポイント順であり、
/// カタカナ（U+30A1..）がひらがな（U+3041..U+3093）より全て後ろに来るため
/// 「あ→ん」の五十音順にならない（例: 'ア' が 'ん' より後ろ）。
/// 本ライブラリは「かな表記を畳んでから比較する」ことで近似の五十音順を与える。
///
/// 使い方:
/// ```dart
/// titles.sort(compareJapaneseTitles); // かな（0）が先、漢字など（1）が後ろ
/// titleSortKey('こころ') == titleSortKey('ココロ'); // => true
/// ```
library;

import 'kana_fold.dart';

/// ひらがな域（ぁ..ゖ）
const int _hiraganaStart = 0x3041;
const int _hiraganaEnd = 0x3096;

/// 全角カタカナ域（ァ..ヺ）
const int _katakanaStart = 0x30A1;
const int _katakanaEnd = 0x30FA;

/// 長音記号「ー」（単独でもかな扱い）
const int _prolongedSoundMark = 0x30FC;

/// 半角カタカナ域（ｦ..ﾝ。濁点 U+FF9E / 半濁点 U+FF9F は含めない）
const int _halfwidthKatakanaStart = 0xFF66;
const int _halfwidthKatakanaEnd = 0xFF9D;

const int _ideographicSpace = 0x3000;

/// 書名の照合キー。
///
/// trim → [foldKana]（ひらがな・半角カナ→カタカナ）→ 全角空白(U+3000)を半角空白へ、
/// の順に正規化する。かな表記ゆれを吸収するため、
/// `titleSortKey('こころ') == titleSortKey('ココロ')` となる。
///
/// 冪等: `titleSortKey(titleSortKey(s)) == titleSortKey(s)`
String titleSortKey(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return '';
  final folded = foldKana(trimmed);
  if (!folded.contains(String.fromCharCode(_ideographicSpace))) return folded;
  return folded.replaceAll(
    String.fromCharCode(_ideographicSpace),
    ' ',
  );
}

/// 書名のグループ。先頭文字がかななら 0、それ以外（漢字・英字・数字・記号・空文字）なら 1。
///
/// かなの範囲: ひらがな U+3041..U+3096 / カタカナ U+30A1..U+30FA / 長音 U+30FC /
/// 半角カナ U+FF66..U+FF9D。
int titleGroup(String title) {
  final key = titleSortKey(title);
  if (key.isEmpty) return 1;
  return _isKana(key.runes.first) ? 0 : 1;
}

/// 書名の日本語かな順比較。
///
/// グループ昇順（かな = 0 が先、漢字など = 1 が後ろ）→
/// 同一グループ内は [titleSortKey] のコードポイント比較。
/// 空文字はグループ 1 の先頭（＝コードポイント最小）として扱う。
///
/// 反対称: `compareJapaneseTitles(a, b) == -compareJapaneseTitles(b, a)`
int compareJapaneseTitles(String a, String b) {
  final groupA = titleGroup(a);
  final groupB = titleGroup(b);
  if (groupA != groupB) return groupA.compareTo(groupB);
  return titleSortKey(a).compareTo(titleSortKey(b));
}

/// 1 コードポイントがかな（ひらがな・カタカナ・長音・半角カナ）か
bool _isKana(int rune) {
  if (rune >= _hiraganaStart && rune <= _hiraganaEnd) return true;
  if (rune >= _katakanaStart && rune <= _katakanaEnd) return true;
  if (rune == _prolongedSoundMark) return true;
  if (rune >= _halfwidthKatakanaStart && rune <= _halfwidthKatakanaEnd) {
    return true;
  }
  return false;
}