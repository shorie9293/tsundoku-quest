import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/settings/data/text_scale_provider.dart';
import 'package:tsundoku_quest/features/settings/data/text_scale_repository.dart';
import 'package:tsundoku_quest/features/settings/domain/text_scale_setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  ProviderContainer createContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = createContainer();
  });

  group('TextScaleController', () {
    test('default state == 1.0', () {
      expect(container.read(textScaleProvider), 1.0);
    });

    test('setScale(0.9) updates state and persists', () async {
      await container.read(textScaleProvider.notifier).setScale(0.9);

      expect(container.read(textScaleProvider), 0.9);
      final saved =
          await const TextScaleRepository().loadScale();
      expect(saved, 0.9);
    });

    test('setScale(disallowed) throws ArgumentError and does NOT change state',
        () async {
      await expectLater(
        container.read(textScaleProvider.notifier).setScale(2.0),
        throwsArgumentError,
      );

      expect(container.read(textScaleProvider), 1.0);
      final saved =
          await const TextScaleRepository().loadScale();
      expect(saved, isNull);
    });

    test('load() restores a previously saved 1.25', () async {
      SharedPreferences.setMockInitialValues({
        TextScaleRepository.key: 1.25,
      });

      await container.read(textScaleProvider.notifier).load();

      expect(container.read(textScaleProvider), 1.25);
    });

    test('load() falls back to 1.0 when unset', () async {
      await container.read(textScaleProvider.notifier).load();
      expect(container.read(textScaleProvider),
          TextScaleSetting.normalScale);
    });
  });
}
