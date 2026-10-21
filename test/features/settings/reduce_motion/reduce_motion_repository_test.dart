import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/settings/data/reduce_motion_repository.dart';
import 'package:tsundoku_quest/features/settings/domain/reduce_motion_setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReduceMotionRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('保存キーは tsundoku_reduce_motion', () {
      expect(ReduceMotionRepository.key, 'tsundoku_reduce_motion');
    });

    test('未保存なら loadReduceMotion() は null', () async {
      const repository = ReduceMotionRepository();
      expect(await repository.loadReduceMotion(), isNull);
    });

    test('saveReduceMotion(on) が round-trip する', () async {
      const repository = ReduceMotionRepository();
      await repository.saveReduceMotion(ReduceMotionSetting.on);
      expect(await repository.loadReduceMotion(), ReduceMotionSetting.on);
    });

    test('saveReduceMotion(off) が round-trip する', () async {
      const repository = ReduceMotionRepository();
      await repository.saveReduceMotion(ReduceMotionSetting.off);
      expect(await repository.loadReduceMotion(), ReduceMotionSetting.off);
    });

    test('不正値が保存されていれば null を返す', () async {
      SharedPreferences.setMockInitialValues({
        ReduceMotionRepository.key: 'bogus',
      });
      const repository = ReduceMotionRepository();
      expect(await repository.loadReduceMotion(), isNull);
    });

    test('上書き保存できる', () async {
      const repository = ReduceMotionRepository();
      await repository.saveReduceMotion(ReduceMotionSetting.off);
      await repository.saveReduceMotion(ReduceMotionSetting.on);
      expect(await repository.loadReduceMotion(), ReduceMotionSetting.on);
    });
  });

  group('InMemoryReduceMotionRepository', () {
    test('未保存は null、save 後は saved が返る', () async {
      final repository = InMemoryReduceMotionRepository();
      expect(await repository.loadReduceMotion(), isNull);
      expect(repository.saveCount, 0);

      await repository.saveReduceMotion(ReduceMotionSetting.on);
      expect(await repository.loadReduceMotion(), ReduceMotionSetting.on);
      expect(repository.saved, ReduceMotionSetting.on);
      expect(repository.saveCount, 1);
    });

    test('saveCount は保存のたびに増える', () async {
      final repository = InMemoryReduceMotionRepository();
      await repository.saveReduceMotion(ReduceMotionSetting.off);
      await repository.saveReduceMotion(ReduceMotionSetting.system);
      expect(repository.saveCount, 2);
      expect(repository.saved, ReduceMotionSetting.system);
    });
  });
}
