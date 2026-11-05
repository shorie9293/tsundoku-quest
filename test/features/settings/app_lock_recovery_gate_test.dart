import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_gate.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_repository.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_service.dart';
import 'package:tsundoku_quest/core/infrastructure/lock_recovery_service.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<InMemoryAppLockRepository> lockedRepo() async {
    final repo = InMemoryAppLockRepository();
    await repo.setPasscode('1234');
    await repo.setEnabled(true);
    await repo.setMethod(AppLockMethod.passcode);
    return repo;
  }

  Future<void> pumpGate(
    WidgetTester tester,
    InMemoryAppLockRepository repo,
  ) async {
    final service = AppLockService(repo);
    final recovery = LockRecoveryService(
      service,
      backupExporter: () async => 'backup.json',
      dataEraser: () async {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          repository: repo,
          recoveryService: recovery,
          unlockedBuilder: (_) => const Scaffold(
            key: AppKeys.appLockGate,
            body: Text('UNLOCKED_CONTENT'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('ロック画面に忘却時の導線が見える', (tester) async {
    final repo = await lockedRepo();
    await pumpGate(tester, repo);

    expect(find.byKey(AppKeys.appLockLockedMessage), findsOneWidget);
    expect(find.byKey(AppKeys.appLockForgotButton), findsOneWidget);
    expect(find.text('パスコードをお忘れですか？'), findsOneWidget);
  });

  testWidgets('忘却導線を押すと確認ダイアログが開く', (tester) async {
    final repo = await lockedRepo();
    await pumpGate(tester, repo);

    await tester.tap(find.byKey(AppKeys.appLockForgotButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.appLockRecoveryConfirmField), findsOneWidget);
    expect(find.byKey(AppKeys.appLockRecoveryConfirmButton), findsOneWidget);
    expect(find.byKey(AppKeys.appLockRecoveryCancelButton), findsOneWidget);
  });

  testWidgets('誤った確認語では解除されない', (tester) async {
    final repo = await lockedRepo();
    await pumpGate(tester, repo);

    await tester.tap(find.byKey(AppKeys.appLockForgotButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(AppKeys.appLockRecoveryConfirmField),
      'ちがう',
    );
    await tester.tap(find.byKey(AppKeys.appLockRecoveryConfirmButton));
    await tester.pumpAndSettle();

    expect(find.text('UNLOCKED_CONTENT'), findsNothing);
    expect(find.byKey(AppKeys.appLockRecoveryError), findsOneWidget);
    expect(repo.isEnabled(), isTrue);
    expect(repo.getPasscodeHash(), isNotNull);
  });

  testWidgets('正しい確認語で解除され unlockedBuilder が出る', (tester) async {
    final repo = await lockedRepo();
    await pumpGate(tester, repo);

    await tester.tap(find.byKey(AppKeys.appLockForgotButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(AppKeys.appLockRecoveryConfirmField),
      '初期化',
    );
    await tester.tap(find.byKey(AppKeys.appLockRecoveryConfirmButton));
    await tester.pumpAndSettle();

    expect(find.text('UNLOCKED_CONTENT'), findsOneWidget);
    expect(repo.isEnabled(), isFalse);
    expect(repo.getPasscodeHash(), isNull);
    // 結果は正直に SnackBar で伝える。
    expect(find.textContaining('ロックを解除しました'), findsOneWidget);
    expect(find.textContaining('データを初期化しました'), findsOneWidget);
  });

  testWidgets('キャンセルでダイアログが閉じ、ロックは継続', (tester) async {
    final repo = await lockedRepo();
    await pumpGate(tester, repo);

    await tester.tap(find.byKey(AppKeys.appLockForgotButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.appLockRecoveryCancelButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.appLockRecoveryConfirmField), findsNothing);
    expect(find.text('UNLOCKED_CONTENT'), findsNothing);
    expect(repo.isEnabled(), isTrue);
  });
}
