import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/infrastructure/app_lock_repository.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/settings/presentation/app_lock_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryAppLockRepository repo;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AppLockSettingsScreen(repository: repo)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  setUp(() {
    repo = InMemoryAppLockRepository();
  });

  testWidgets('不一致パスコードはエラー文言で拒否される', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
      find.byKey(AppKeys.appLockNewPasscodeField),
      '1234',
    );
    await tester.enterText(
      find.byKey(AppKeys.appLockConfirmPasscodeField),
      '5678',
    );
    await tester.tap(find.byKey(AppKeys.appLockEnableButton));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(AppKeys.appLockErrorText), findsOneWidget);
    expect(find.text('確認用と一致しません'), findsOneWidget);
    expect(repo.isEnabled(), isFalse);
  });

  testWidgets('桁不足・非数字はエラー文言で拒否される', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
      find.byKey(AppKeys.appLockNewPasscodeField),
      '12',
    );
    await tester.enterText(
      find.byKey(AppKeys.appLockConfirmPasscodeField),
      '12',
    );
    await tester.tap(find.byKey(AppKeys.appLockEnableButton));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(AppKeys.appLockErrorText), findsOneWidget);
    expect(find.text('4桁の数字を入力せよ'), findsOneWidget);
    expect(repo.isEnabled(), isFalse);
  });

  testWidgets('一致する4桁で有効化、以後ロック有効', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
      find.byKey(AppKeys.appLockNewPasscodeField),
      '1234',
    );
    await tester.enterText(
      find.byKey(AppKeys.appLockConfirmPasscodeField),
      '1234',
    );
    await tester.tap(find.byKey(AppKeys.appLockEnableButton));
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.isEnabled(), isTrue);
    expect(repo.verifyPasscode('1234'), isTrue);
    expect(find.text('アプリロック有効'), findsOneWidget);
  });

  testWidgets('有効状態から無効化できる', (tester) async {
    await repo.setPasscode('1234');
    await repo.setEnabled(true);
    await repo.setMethod(AppLockMethod.passcode);

    await pumpScreen(tester);
    expect(find.text('アプリロック有効'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.appLockDisableButton));
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.isEnabled(), isFalse);
    expect(repo.getPasscodeHash(), isNull);
    // 有効化フォームが再表示される
    expect(find.byKey(AppKeys.appLockEnableButton), findsOneWidget);
  });
}
