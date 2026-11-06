import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/text/japanese_number.dart';

/// 日本語入力の数値正規化（全角数字・全角カンマ・全角マイナス）の試練。
///
/// 日本語IMEでは「１２３」「１，２３４」「－５」が普通に入力される。
/// これらを int.tryParse へ素通しすると null になり、画面側の
/// フォールバックが黙って 0 を保存してしまう（改善提案#215）。
void main() {
  group('normalizeDigits', () {
    test('全角数字０-９を半角へ変換する', () {
      expect(JapaneseNumber.normalizeDigits('１２３４５６７８９０'), '1234567890');
    });

    test('全角カンマを除去する', () {
      expect(JapaneseNumber.normalizeDigits('１，２３４'), '1234');
    });

    test('半角カンマを除去する', () {
      expect(JapaneseNumber.normalizeDigits('1,234'), '1234');
    });

    test('全角マイナス（U+FF0D）をASCIIの-へ変換する', () {
      expect(JapaneseNumber.normalizeDigits('－５'), '-5');
    });

    test('数学記号のマイナス（U+2212）をASCIIの-へ変換する', () {
      expect(JapaneseNumber.normalizeDigits('−５'), '-5');
    });

    test('全角空白を半角空白へ変換し前後をtrimする', () {
      expect(JapaneseNumber.normalizeDigits('　１２　'), '12');
    });

    test('半角のみの入力は不変（trimのみ）', () {
      expect(JapaneseNumber.normalizeDigits(' 42 '), '42');
    });

    test('冪等である（2回適用しても結果が変わらない）', () {
      const raw = '　１，２３４－　';
      final once = JapaneseNumber.normalizeDigits(raw);
      expect(JapaneseNumber.normalizeDigits(once), once);
    });
  });

  group('tryParseInt', () {
    test('全角数字を数値として解釈する', () {
      expect(JapaneseNumber.tryParseInt('１２３'), 123);
    });

    test('半角数字は従来通り解釈する', () {
      expect(JapaneseNumber.tryParseInt('123'), 123);
    });

    test('混在した全角数字＋全角カンマを解釈する（１，２３４→1234）', () {
      expect(JapaneseNumber.tryParseInt('１，２３４'), 1234);
    });

    test('半角カンマ区切りを解釈する', () {
      expect(JapaneseNumber.tryParseInt('1,234'), 1234);
    });

    test('全角数字＋全角マイナスの負値を解釈する', () {
      expect(JapaneseNumber.tryParseInt('－４２'), -42);
    });

    test('半角の負値を解釈する', () {
      expect(JapaneseNumber.tryParseInt('-42'), -42);
    });

    test('０は0として解釈する（nullにしない）', () {
      expect(JapaneseNumber.tryParseInt('０'), 0);
    });

    test('nullはnullを返す', () {
      expect(JapaneseNumber.tryParseInt(null), isNull);
    });

    test('空文字はnullを返す', () {
      expect(JapaneseNumber.tryParseInt(''), isNull);
    });

    test('半角空白のみはnullを返す', () {
      expect(JapaneseNumber.tryParseInt('   '), isNull);
    });

    test('全角空白のみはnullを返す', () {
      expect(JapaneseNumber.tryParseInt('　　'), isNull);
    });

    test('数字に文字が混ざる 123abc はnullを返す', () {
      expect(JapaneseNumber.tryParseInt('123abc'), isNull);
    });

    test('全角数字に文字が混ざる １２３あ はnullを返す', () {
      expect(JapaneseNumber.tryParseInt('１２３あ'), isNull);
    });

    test('小数 1.5 はnullを返す（整数入力欄のため）', () {
      expect(JapaneseNumber.tryParseInt('1.5'), isNull);
    });

    test('前後の全角空白を許容する', () {
      expect(JapaneseNumber.tryParseInt('　４２　'), 42);
    });
  });

  group('parseIntOr', () {
    test('解釈できない入力はフォールバック値を返す', () {
      expect(JapaneseNumber.parseIntOr('たくさん', 7), 7);
    });

    test('nullはフォールバック値を返す', () {
      expect(JapaneseNumber.parseIntOr(null, 7), 7);
    });

    test('全角数字はフォールバックより優先して解釈する', () {
      expect(JapaneseNumber.parseIntOr('９９', 7), 99);
    });
  });
}
