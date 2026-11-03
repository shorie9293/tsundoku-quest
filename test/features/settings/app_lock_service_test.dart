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

  group('AppLockService ロックアウト', () {
    late DateTime now;
    late InMemoryAppLockRepository repo;
    late AppLockService timed;

    setUp(() async {
      now = DateTime(2026, 1, 1, 9, 0, 0);
      repo = InMemoryAppLockRepository();
      timed = AppLockService(repo, now: () => now);
      await timed.enableWithPasscode('1234');
    });

    test('5回失敗で30秒ロックアウトし、正コードでも照合しない', () async {
      for (var i = 0; i < 5; i++) {
        expect(await timed.unlock(passcode: '0000'), isFalse);
      }
      expect(repo.getFailedAttempts(), 5);
      expect(timed.isLockedOut, isTrue);
      expect(timed.lockoutRemainingSeconds, 30);
      expect(repo.getLockedUntil(), now.add(const Duration(seconds: 30)));

      // ロックアウト中は正コードでも解除されない
      expect(await timed.unlock(passcode: '1234'), isFalse);
      expect(repo.getFailedAttempts(), 5);

      // 30秒後に解除できる
      now = now.add(const Duration(seconds: 31));
      expect(timed.isLockedOut, isFalse);
      expect(await timed.unlock(passcode: '1234'), isTrue);
      expect(repo.getFailedAttempts(), 0);
      expect(repo.getLockedUntil(), isNull);
    });

    test('成功すると失敗回数がリセットされる', () async {
      await timed.unlock(passcode: '0000');
      await timed.unlock(passcode: '0000');
      expect(repo.getFailedAttempts(), 2);
      expect(await timed.unlock(passcode: '1234'), isTrue);
      expect(repo.getFailedAttempts(), 0);
      expect(timed.isLockedOut, isFalse);
    });

    test('猶予の既定は0で、設定が往復する', () async {
      expect(timed.relockGrace, Duration.zero);
      await timed.setRelockGrace(const Duration(minutes: 5));
      expect(timed.relockGrace, const Duration(minutes: 5));
      expect(() => timed.setRelockGrace(const Duration(seconds: -1)),
          throwsArgumentError);
    });
  });
}
