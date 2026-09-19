import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/settings/data/text_scale_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextScaleRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadScale() returns null when unset', () async {
      final repository = const TextScaleRepository();
      expect(await repository.loadScale(), isNull);
    });

    test('saveScale(1.25) then loadScale() == 1.25', () async {
      final repository = const TextScaleRepository();
      await repository.saveScale(1.25);
      expect(await repository.loadScale(), 1.25);
    });

    test('saveScale(0.9) round-trips', () async {
      final repository = const TextScaleRepository();
      await repository.saveScale(0.9);
      expect(await repository.loadScale(), 0.9);
    });

    test('stored disallowed value makes loadScale() return null', () async {
      SharedPreferences.setMockInitialValues({
        TextScaleRepository.key: 3.0,
      });
      final repository = const TextScaleRepository();
      expect(await repository.loadScale(), isNull);
    });

    test('saveScale(2.0) throws ArgumentError and leaves storage unchanged',
        () async {
      final repository = const TextScaleRepository();
      await repository.saveScale(1.0);

      await expectLater(
        repository.saveScale(2.0),
        throwsArgumentError,
      );

      // 保存内容は変化していない
      expect(await repository.loadScale(), 1.0);
    });
  });
}
