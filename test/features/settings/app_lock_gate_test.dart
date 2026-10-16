import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_gate.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_repository.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpGate(
    WidgetTester tester,
    AppLockRepository repo,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          repository: repo,
          unlockedBuilder: (_) => const Scaffold(
            key: AppKeys.appLockGate,
            body: Text('UNLOCKED_CONTENT'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('無効時は素通りで子が表示される', (tester) async {
    await pumpGate(tester, InMemoryAppLockRepository());
    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('有効時は子が隠れ、誤コードでエラー・正コードで解除', (tester) async {
    final repo = InMemoryAppLockRepository();
    await repo.setPasscode('1234');
    await repo.setEnabled(true);
    await repo.setMethod(AppLockMethod.passcode);

    await pumpGate(tester, repo);

    // 子は隠れている
    expect(find.text('UNLOCKED_CONTENT'), findsNothing);
    expect(find.byKey(AppKeys.appLockLockedMessage), findsOneWidget);

    // 誤コード → エラー表示、まだロック中
    await tester.enterText(
      find.byKey(AppKeys.appLockPasscodeField),
      '9999',
    );
    await tester.tap(find.byKey(AppKeys.appLockUnlockButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('UNLOCKED_CONTENT'), findsNothing);
    expect(find.text('パスコードが正しくありません'), findsOneWidget);

    // 正コード → 解除
    await tester.enterText(
      find.byKey(AppKeys.appLockPasscodeField),
      '1234',
    );
    await tester.tap(find.byKey(AppKeys.appLockUnlockButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);
  });

  testWidgets('読込例外時は fail-open で素通り', (tester) async {
    final throwingRepo = _ThrowingAppLockRepository();
    await pumpGate(tester, throwingRepo);
    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);
  });
}

class _ThrowingAppLockRepository implements AppLockRepository {
  @override
  bool isEnabled() => throw StateError('boom');

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  AppLockMethod getMethod() => AppLockMethod.none;

  @override
  Future<void> setMethod(AppLockMethod method) async {}

  @override
  String? getPasscodeHash() => null;

  @override
  Future<void> setPasscode(String passcode) async {}

  @override
  Future<void> clearPasscode() async {}

  @override
  bool verifyPasscode(String passcode) => false;
}
