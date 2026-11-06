import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/text/japanese_collation.dart';

void main() {
  group('titleSortKey', () {
    test('前後の空白を除去する', () {
      expect(titleSortKey('  こころ  '), 'ココロ');
    });

    test('ひらがなをカタカナへ寄せる（比較キーとしての正規化）', () {
      expect(titleSortKey('こころ'), titleSortKey('ココロ'));
    });

    test('半角カナを全角カタカナへ寄せる', () {
      expect(titleSortKey('ｸﾞﾘﾑ'), titleSortKey('グリム'));
    });

    test('全角空白を半角空白へ正規化する', () {
      expect(titleSortKey('吾輩は　猫である'), '吾輩ハ 猫デアル');
      expect(titleSortKey('a　b'), 'a b');
    });

    test('冪等: 二度適用しても結果が変わらない', () {
      const samples = [
        '  こころ  ',
        'ｸﾞﾘﾑ童話',
        '吾輩は　猫である',
        '',
        '   ',
        'Clean Code',
        'ヴィヨン',
        'ﾊﾟﾝ',
      ];
      for (final s in samples) {
        final once = titleSortKey(s);
        expect(titleSortKey(once), once, reason: 'sample: "$s"');
      }
    });
  });

  group('titleGroup', () {
    test('ひらがなは 0', () {
      expect(titleGroup('あ'), 0);
      expect(titleGroup('ん'), 0);
      expect(titleGroup('ぁ'), 0);
    });

    test('カタカナは 0', () {
      expect(titleGroup('ア'), 0);
      expect(titleGroup('ン'), 0);
      expect(titleGroup('ヴ'), 0);
    });

    test('長音は 0', () {
      expect(titleGroup('ー'), 0);
      expect(titleGroup('ラーメン'), 0);
    });

    test('半角カナは 0', () {
      expect(titleGroup('ｱ'), 0);
      expect(titleGroup('ﾝ'), 0);
    });

    test('漢字・英字・数字・記号・空文字は 1', () {
      expect(titleGroup('吾輩は猫である'), 1);
      expect(titleGroup('Clean Code'), 1);
      expect(titleGroup('123'), 1);
      expect(titleGroup('!?'), 1);
      expect(titleGroup(''), 1);
    });
  });

  group('compareJapaneseTitles', () {
    test('かな同士は五十音順（あ→ん）', () {
      final titles = ['ん', 'あ', 'い', 'う'];
      final sorted = List.of(titles)..sort(compareJapaneseTitles);
      expect(sorted, ['あ', 'い', 'う', 'ん']);
    });

    test('カタカナとひらがなは同一グループとして混在比較される', () {
      final titles = ['カラス', 'あひる', 'いろは', 'ん'];
      final sorted = List.of(titles)..sort(compareJapaneseTitles);
      // あひる → いろは → カラス → ん（カタカナが末尾に落ちない）
      expect(sorted, ['あひる', 'いろは', 'カラス', 'ん']);
    });

    test('「ア」は「ん」より前に来る', () {
      expect(compareJapaneseTitles('ア', 'ん'), lessThan(0));
    });

    test('半角カナもかなとして比較される', () {
      final titles = ['ｱﾋﾙ', 'いぬ', 'ねこ'];
      final sorted = List.of(titles)..sort(compareJapaneseTitles);
      expect(sorted, ['ｱﾋﾙ', 'いぬ', 'ねこ']);
    });

    test('漢字などの非かなはかなの後ろ（グループ1）に来る', () {
      final titles = ['亜細亜', 'あい', '英字'];
      final sorted = List.of(titles)..sort(compareJapaneseTitles);
      expect(sorted, ['あい', '亜細亜', '英字']);
    });

    test('同じグループ内では比較キーのコードポイント順（漢字同士は従来どおり）', () {
      expect(compareJapaneseTitles('吾輩は猫である', '銀河鉄道の夜'), lessThan(0));
    });

    test('空文字はグループ1の先頭として扱う', () {
      final titles = ['あい', '英字', '', '亜細亜'];
      final sorted = List.of(titles)..sort(compareJapaneseTitles);
      expect(sorted, ['あい', '', '亜細亜', '英字']);
    });

    test('同一キーなら 0（かな表記ゆれを吸収する）', () {
      expect(compareJapaneseTitles('こころ', 'ココロ'), 0);
      expect(compareJapaneseTitles('ｸﾞﾘﾑ', 'グリム'), 0);
    });

    test('反対称性: compare(a,b) == -compare(b,a)', () {
      const titles = ['あ', 'ア', 'ん', '亜', '', 'abc', 'ｱ', 'ー'];
      for (final a in titles) {
        for (final b in titles) {
          expect(
            compareJapaneseTitles(a, b),
            -compareJapaneseTitles(b, a),
            reason: 'a="$a" b="$b"',
          );
        }
      }
    });

    test('推移性（比較キー列が一意に定まる）', () {
      const titles = ['ん', 'ア', 'あ', 'い', '英字', 'ー', ''];
      final sorted = List.of(titles)..sort(compareJapaneseTitles);
      // 'あ' と 'ア' は同一キーのため順序は不定だが、キー列は一意に定まる
      expect(
        sorted.map(titleSortKey).toList(),
        ['ア', 'ア', 'イ', 'ン', 'ー', '', '英字'],
      );
    });
  });
}