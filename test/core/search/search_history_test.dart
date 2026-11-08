import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/search/search_history.dart';

void main() {
  group('SearchHistory.normalize', () {
    test('前後の空白を除去する', () {
      expect(SearchHistory.normalize('  ドラゴン  '), 'ドラゴン');
    });

    test('全角空白を半角空白へ変換する', () {
      expect(SearchHistory.normalize('猫\u3000の\u3000物理'), '猫 の 物理');
    });

    test('連続空白を1つに畳む', () {
      expect(SearchHistory.normalize('猫   の     物理'), '猫 の 物理');
      expect(SearchHistory.normalize('猫 \u3000 \t 物理'), '猫 物理');
    });

    test('空白のみの語は空文字になる', () {
      expect(SearchHistory.normalize('   \u3000 '), '');
    });
  });

  group('SearchHistory.add', () {
    test('新しい語を先頭に積む（新しい順）', () {
      var history = SearchHistory.empty();
      history = history.add('猫');
      history = history.add('犬');
      expect(history.entries, ['犬', '猫']);
    });

    test('空文字・空白のみは積まない', () {
      final history = SearchHistory.empty();
      expect(history.add('').entries, isEmpty);
      expect(history.add('   ').entries, isEmpty);
      expect(history.add('\u3000').entries, isEmpty);
      expect(identical(history.add(''), history), isTrue);
    });

    test('追加時に正規化した表記で保存する', () {
      final history = SearchHistory.empty().add('  \u3000Dart  入門 \u3000');
      expect(history.entries, ['Dart 入門']);
    });

    test('大文字小文字を区別しない完全一致は先頭へ移動し表記を更新する', () {
      var history = SearchHistory.empty();
      history = history.add('dart');
      history = history.add('Flutter');
      expect(history.entries, ['Flutter', 'dart']);

      history = history.add('DART');
      expect(history.entries, ['DART', 'Flutter']);
      expect(history.entries.length, 2);
    });

    test('部分一致は別項目として積む', () {
      var history = SearchHistory.empty();
      history = history.add('猫');
      history = history.add('猫の物理学');
      expect(history.entries, ['猫の物理学', '猫']);
    });

    test('最大8件を超えると最古を落とす', () {
      var history = SearchHistory.empty();
      for (var i = 1; i <= 10; i++) {
        history = history.add('語$i');
      }
      expect(history.entries.length, SearchHistory.maxEntries);
      expect(history.entries.first, '語10');
      expect(history.entries.last, '語3');
      expect(history.entries.contains('語1'), isFalse);
      expect(history.entries.contains('語2'), isFalse);
    });

    test('元のインスタンスは変更されない', () {
      final base = SearchHistory.empty().add('猫');
      final next = base.add('犬');
      expect(base.entries, ['猫']);
      expect(next.entries, ['犬', '猫']);
    });

    test('entries は変更不可', () {
      final history = SearchHistory.empty().add('猫');
      expect(() => history.entries.add('犬'), throwsUnsupportedError);
    });
  });

  group('SearchHistory encode/decode', () {
    test('往復で内容が保たれる', () {
      final history = SearchHistory(entries: ['犬', '猫', 'Dart 入門']);
      expect(SearchHistory.decode(history.encode()), history);
    });

    test('null・空文字は空の履歴', () {
      expect(SearchHistory.decode(null).entries, isEmpty);
      expect(SearchHistory.decode('').entries, isEmpty);
    });

    test('壊れた JSON は空の履歴（例外を投げない）', () {
      expect(SearchHistory.decode('{not json'), isEmpty);
      expect(SearchHistory.decode('{"a":1}').entries, isEmpty);
      expect(SearchHistory.decode('"文字列"').entries, isEmpty);
      expect(SearchHistory.decode('123').entries, isEmpty);
    });

    test('配列内の非文字列・空文字は捨てる', () {
      final decoded = SearchHistory.decode('["猫", 42, "", null, "  犬  "]');
      expect(decoded.entries, ['猫', '犬']);
    });

    test('8件を超える保存値は先頭8件に切り詰める', () {
      const raw = '["語1","語2","語3","語4","語5","語6","語7","語8","語9"]';
      final decoded = SearchHistory.decode(raw);
      expect(decoded.entries.length, SearchHistory.maxEntries);
      expect(decoded.entries.first, '語1');
      expect(decoded.entries.contains('語9'), isFalse);
    });
  });

  group('SearchHistory 値等価', () {
    test('同じ内容なら等価・hashCode も一致する', () {
      final a = SearchHistory(entries: ['猫', '犬']);
      final b = SearchHistory(entries: ['猫', '犬']);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == SearchHistory(entries: ['犬', '猫']), isFalse);
    });
  });
}
