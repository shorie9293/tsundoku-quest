import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/settings/data/reduce_motion_provider.dart';
import 'package:tsundoku_quest/features/settings/data/reduce_motion_repository.dart';
import 'package:tsundoku_quest/features/settings/domain/reduce_motion_setting.dart';

/// save で必ず失敗するリポジトリ（state 反映より先に保存することを検証する）
class _ThrowingRepository implements ReduceMotionRepository {
  @override
  Future<ReduceMotionSetting?> loadReduceMotion() async =>
      ReduceMotionSetting.system;

  @override
  Future<void> saveReduceMotion(ReduceMotionSetting setting) async {
    throw StateError('save failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('初期状態は system', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(reduceMotionProvider), ReduceMotionSetting.system);
  });

  test('load() は保存済みの値を読み込む', () async {
    SharedPreferences.setMockInitialValues({
      ReduceMotionRepository.key: 'on',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(reduceMotionProvider.notifier).load();
    expect(container.read(reduceMotionProvider), ReduceMotionSetting.on);
  });

  test('load() は未保存なら system にフォールバックする', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(reduceMotionProvider.notifier).load();
    expect(container.read(reduceMotionProvider), ReduceMotionSetting.system);
  });

  test('setSetting() は repository へ保存してから state を更新する', () async {
    final repository = InMemoryReduceMotionRepository();
    final container = ProviderContainer(
      overrides: [
        reduceMotionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(reduceMotionProvider.notifier)
        .setSetting(ReduceMotionSetting.on);

    expect(repository.saved, ReduceMotionSetting.on);
    expect(repository.saveCount, 1);
    expect(container.read(reduceMotionProvider), ReduceMotionSetting.on);
  });

  test('保存に失敗した場合は state を更新しない', () async {
    final container = ProviderContainer(
      overrides: [
        reduceMotionRepositoryProvider.overrideWithValue(_ThrowingRepository()),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(reduceMotionProvider.notifier)
          .setSetting(ReduceMotionSetting.on),
      throwsStateError,
    );
    expect(container.read(reduceMotionProvider), ReduceMotionSetting.system);
  });
}
