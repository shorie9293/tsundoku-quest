import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_recovery_policy.dart';

void main() {
  group('LockRecoveryPolicy', () {
    test('確認語は「初期化」', () {
      expect(LockRecoveryPolicy.confirmationPhrase, '初期化');
      expect(LockRecoveryPolicy.confirmationPhrase, kLockRecoveryConfirmationPhrase);
    });

    test('警告文はデータ消失に触れる', () {
      expect(LockRecoveryPolicy.warningMessage, contains('初期化'));
      expect(LockRecoveryPolicy.warningMessage, contains('元に戻せません'));
    });

    test('canRecover は enabled のときのみ true', () {
      expect(LockRecoveryPolicy.canRecover(enabled: true), isTrue);
      expect(LockRecoveryPolicy.canRecover(enabled: false), isFalse);
    });

    test('一致すれば true', () {
      expect(LockRecoveryPolicy.isConfirmationValid('初期化'), isTrue);
    });

    test('trim して一致すれば true', () {
      expect(LockRecoveryPolicy.isConfirmationValid('  初期化  '), isTrue);
      expect(LockRecoveryPolicy.isConfirmationValid('\n初期化\t'), isTrue);
    });

    test('不一致は false', () {
      expect(LockRecoveryPolicy.isConfirmationValid(''), isFalse);
      expect(LockRecoveryPolicy.isConfirmationValid('初期化して'), isFalse);
      expect(LockRecoveryPolicy.isConfirmationValid('しょうきょ'), isFalse);
    });
  });
}
