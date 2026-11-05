import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_repository.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_service.dart';
import 'package:tsundoku_quest/core/infrastructure/lock_recovery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<InMemoryAppLockRepository> lockedRepo() async {
    final repo = InMemoryAppLockRepository();
    await repo.setPasscode('1234');
    await repo.setEnabled(true);
    await repo.setMethod(AppLockMethod.passcode);
    return repo;
  }

  group('LockRecoveryService.recover', () {
    test('確認語が不一致なら拒否し、何も変更しない', () async {
      final repo = await lockedRepo();
      final service = AppLockService(repo);
      var backupCalled = false;
      var eraseCalled = false;
      final recovery = LockRecoveryService(
        service,
        backupExporter: () async {
          backupCalled = true;
          return 'backup.json';
        },
        dataEraser: () async {
          eraseCalled = true;
        },
      );

      final result = await recovery.recover(confirmation: 'ちがう');

      expect(result.succeeded, isFalse);
      expect(result.rejected, isTrue);
      expect(backupCalled, isFalse);
      expect(eraseCalled, isFalse);
      // 無変更: ロック有効のまま、パスコードも残る
      expect(repo.isEnabled(), isTrue);
      expect(repo.getPasscodeHash(), isNotNull);
      expect(repo.verifyPasscode('1234'), isTrue);
    });

    test('成功でロック無効・パスコード消去・初期化完了', () async {
      final repo = await lockedRepo();
      final service = AppLockService(repo);
      var eraseCalled = false;
      final recovery = LockRecoveryService(
        service,
        backupExporter: () async => 'auto_backups/backup.json',
        dataEraser: () async {
          eraseCalled = true;
        },
      );

      final result = await recovery.recover(confirmation: '初期化');

      expect(result.succeeded, isTrue);
      expect(result.rejected, isFalse);
      expect(result.backupPath, 'auto_backups/backup.json');
      expect(result.backupFailed, isFalse);
      expect(result.dataWiped, isTrue);
      expect(eraseCalled, isTrue);
      expect(repo.isEnabled(), isFalse);
      expect(repo.getPasscodeHash(), isNull);
      expect(repo.getMethod(), AppLockMethod.none);
      expect(repo.getFailedAttempts(), 0);
    });

    test('バックアップはロック解除より先に実行される', () async {
      final repo = await lockedRepo();
      final service = AppLockService(repo);
      final enabledAt = <String, bool>{};
      final recovery = LockRecoveryService(
        service,
        backupExporter: () async {
          enabledAt['backup'] = repo.isEnabled();
          return 'backup.json';
        },
        dataEraser: () async {
          enabledAt['erase'] = repo.isEnabled();
        },
      );

      await recovery.recover(confirmation: '初期化');

      // 書き出し時点ではまだ施錠中、初期化時点では解除済み。
      expect(enabledAt['backup'], isTrue);
      expect(enabledAt['erase'], isFalse);
    });

    test('バックアップが例外でも回復は成立する', () async {
      final repo = await lockedRepo();
      final service = AppLockService(repo);
      final recovery = LockRecoveryService(
        service,
        backupExporter: () async => throw StateError('disk full'),
        dataEraser: () async {},
      );

      final result = await recovery.recover(confirmation: '初期化');

      expect(result.succeeded, isTrue);
      expect(result.backupFailed, isTrue);
      expect(result.backupPath, isNull);
      expect(repo.isEnabled(), isFalse);
      expect(repo.getPasscodeHash(), isNull);
    });

    test('バックアップが null を返したら backupFailed', () async {
      final repo = await lockedRepo();
      final service = AppLockService(repo);
      final recovery = LockRecoveryService(
        service,
        backupExporter: () async => null,
        dataEraser: () async {},
      );

      final result = await recovery.recover(confirmation: '初期化');

      expect(result.succeeded, isTrue);
      expect(result.backupFailed, isTrue);
    });

    test('初期化が例外でもロック解除は成立する（fail-safe）', () async {
      final repo = await lockedRepo();
      final service = AppLockService(repo);
      final recovery = LockRecoveryService(
        service,
        backupExporter: () async => 'backup.json',
        dataEraser: () async => throw StateError('erase failed'),
      );

      final result = await recovery.recover(confirmation: '初期化');

      expect(result.succeeded, isTrue);
      expect(result.dataWiped, isFalse);
      expect(repo.isEnabled(), isFalse);
      expect(repo.getPasscodeHash(), isNull);
    });

    test('ロックが無効なら rejected（何もしない）', () async {
      final repo = InMemoryAppLockRepository();
      final service = AppLockService(repo);
      var called = false;
      final recovery = LockRecoveryService(
        service,
        backupExporter: () async {
          called = true;
          return null;
        },
        dataEraser: () async {
          called = true;
        },
      );

      final result = await recovery.recover(confirmation: '初期化');

      expect(result.succeeded, isFalse);
      expect(result.rejected, isTrue);
      expect(called, isFalse);
    });
  });
}
