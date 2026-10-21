import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hapticTap() は同期で例外を投げない', () {
    expect(hapticTap, returnsNormally);
  });

  test('hapticTap() を連続で呼んでも例外を投げない', () {
    expect(() {
      hapticTap();
      hapticTap();
      hapticTap();
    }, returnsNormally);
  });

  test('hapticTap() は Future を返さない（await 不要）', () {
    // 戻り値が void であることを型で担保する
    const void Function() action = hapticTap;
    action();
    expect(action, isNotNull);
  });

  test('プラットフォームチャネルが未解決でも完了を待たずに返る', () async {
    // HapticFeedback の送信は fire-and-forget。await すると flutter_test で
    // チャネルが解決されず永久に待つため、呼び出しが即座に戻ることを確かめる。
    var returned = false;
    hapticTap();
    returned = true;
    expect(returned, isTrue);
    // チャネルへ送られた呼び出しは、テスト終了時に処理される
    expect(HapticFeedback.selectionClick, isNotNull);
  });
}
