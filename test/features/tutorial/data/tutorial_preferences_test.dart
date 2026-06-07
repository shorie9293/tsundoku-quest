import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/features/tutorial/data/tutorial_preferences.dart';

void main() {
  group('TutorialPrefKeys', () {
    test('キー名が正しい', () {
      expect(TutorialPrefKeys.loreSeen, 'tutorial_lore_seen');
      expect(TutorialPrefKeys.operationSeen, 'tutorial_operation_seen');
    });
  });

  group('TutorialPreferences', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('初回起動時は isFirstLaunch が true', () {
      final tp = TutorialPreferences(prefs);
      expect(tp.isLoreNotSeen, isTrue);
      expect(tp.isOperationNotSeen, isTrue);
      expect(tp.isFirstLaunch, isTrue);
    });

    test('markLoreSeen 後は isLoreNotSeen が false', () async {
      final tp = TutorialPreferences(prefs);
      await tp.markLoreSeen();
      expect(tp.isLoreNotSeen, false);
      expect(tp.isFirstLaunch, false); // 片方だけ表示済み
    });

    test('markOperationSeen 後は isOperationNotSeen が false', () async {
      final tp = TutorialPreferences(prefs);
      await tp.markOperationSeen();
      expect(tp.isOperationNotSeen, false);
      expect(tp.isFirstLaunch, false);
    });

    test('両方表示済みで isFirstLaunch が false', () async {
      final tp = TutorialPreferences(prefs);
      await tp.markLoreSeen();
      await tp.markOperationSeen();
      expect(tp.isLoreNotSeen, false);
      expect(tp.isOperationNotSeen, false);
      expect(tp.isFirstLaunch, false);
    });

    test('デフォルト値(null)の場合は false 扱いで未表示', () {
      // setMockInitialValuesで空のため、getBoolはnullを返し ?? false でfalse
      final tp = TutorialPreferences(prefs);
      // null ?? false = false → !false = true → 未表示
      expect(tp.isLoreNotSeen, isTrue);
    });

    test('明示的に false が保存されている場合も未表示', () async {
      await prefs.setBool(TutorialPrefKeys.loreSeen, false);
      final tp = TutorialPreferences(prefs);
      // false ?? false = false → !false = true → 未表示（表示済みフラグが立っていない）
      expect(tp.isLoreNotSeen, isTrue);
    });

    test('明示的に true が保存されている場合は表示済み', () async {
      await prefs.setBool(TutorialPrefKeys.loreSeen, true);
      final tp = TutorialPreferences(prefs);
      expect(tp.isLoreNotSeen, false);
    });
  });
}
