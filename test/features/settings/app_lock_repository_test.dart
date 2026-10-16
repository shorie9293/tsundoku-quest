import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesAppLockRepository', () {
    late SharedPreferencesAppLockRepository repo;

    setUp(() async {
      repo = SharedPreferencesAppLockRepository(
        await SharedPreferences.getInstance(),
      );
    });

    test('初期状態は無効・方式 none・ハッシュ null', () {
      expect(repo.isEnabled(), isFalse);
      expect(repo.getMethod(), AppLockMethod.none);
      expect(repo.getPasscodeHash(), isNull);
    });

    test('setPasscode は salt+sha256 でハッシュ化する（平文を保存しない）', () async {
      await repo.setPasscode('1234');
      final hash = repo.getPasscodeHash()!;
      expect(hash, isNot('1234'));
      expect(hash.length, 64);
      // salt 付きであることの間接検証: 平文の sha256 とは異なる
      expect(repo.verifyPasscode('1234'), isTrue);
      expect(repo.verifyPasscode('1235'), isFalse);
    });

    test('setEnabled / setMethod の往復', () async {
      await repo.setEnabled(true);
      await repo.setMethod(AppLockMethod.biometric);
      expect(repo.isEnabled(), isTrue);
      expect(repo.getMethod(), AppLockMethod.biometric);
    });

    test('clearPasscode でハッシュが消える', () async {
      await repo.setPasscode('1234');
      await repo.clearPasscode();
      expect(repo.getPasscodeHash(), isNull);
      expect(repo.verifyPasscode('1234'), isFalse);
    });

    test('キー名は凍結仕様どおり', () async {
      await repo.setEnabled(true);
      await repo.setMethod(AppLockMethod.passcode);
      await repo.setPasscode('1234');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app_lock.enabled'), isTrue);
      expect(prefs.getString('app_lock.method'), 'passcode');
      expect(prefs.getString('app_lock.passcode_hash'), isNotNull);
    });
  });

  group('InMemoryAppLockRepository', () {
    test('SharedPreferences 実装と同じ振る舞い', () async {
      final repo = InMemoryAppLockRepository();
      expect(repo.isEnabled(), isFalse);
      await repo.setPasscode('9999');
      await repo.setEnabled(true);
      await repo.setMethod(AppLockMethod.passcode);
      expect(repo.isEnabled(), isTrue);
      expect(repo.getMethod(), AppLockMethod.passcode);
      expect(repo.verifyPasscode('9999'), isTrue);
      expect(repo.verifyPasscode('9998'), isFalse);
      await repo.clearPasscode();
      expect(repo.getPasscodeHash(), isNull);
    });
  });
}
