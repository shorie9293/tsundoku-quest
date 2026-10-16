import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_repository.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_service.dart';

/// AppLockService の純ロジック試練（TDD RED→GREEN）。
void main() {
  group('AppLockService: 無効時', () {
    test('isLocked は false、unlock は常に true', () async {
      final service = AppLockService(InMemoryAppLockRepository());
      expect(service.isLocked, isFalse);
      expect(await service.unlock(), isTrue);
      expect(await service.unlock(passcode: '9999'), isTrue);
    });
  });

  group('AppLockService: パスコード有効時', () {
    test('enableWithPasscode 後はロックされ、正解でのみ解除', () async {
      final repo = InMemoryAppLockRepository();
      final service = AppLockService(repo);

      await service.enableWithPasscode('1234');
      expect(service.isLocked, isTrue);
      expect(repo.getMethod(), AppLockMethod.passcode);

      expect(await service.unlock(), isFalse);
      expect(await service.unlock(passcode: '0000'), isFalse);
      expect(await service.unlock(passcode: '1234'), isTrue);
    });

    test('enableWithPasscode は4桁数字以外を ArgumentError で拒む', () async {
      final service = AppLockService(InMemoryAppLockRepository());
      for (final bad in ['123', '12345', '12a4', '', '１２３４']) {
        await expectLater(
          service.enableWithPasscode(bad),
          throwsArgumentError,
          reason: '「$bad」は4桁数字ではない',
        );
      }
    });

    test('disable 後は素通りになり、パスコードも消える', () async {
      final repo = InMemoryAppLockRepository();
      final service = AppLockService(repo);
      await service.enableWithPasscode('1234');
      await service.disable();
      expect(service.isLocked, isFalse);
      expect(repo.getPasscodeHash(), isNull);
      expect(await service.unlock(passcode: '1234'), isTrue);
    });
  });
}
