import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/account_deletion/domain/account_deletion_service.dart';
import 'package:tsundoku_quest/features/account_deletion/presentation/account_deletion_app_keys.dart';
import 'package:tsundoku_quest/features/account_deletion/presentation/account_deletion_screen.dart';

/// 退会画面 — 2段階確認（対象列挙 → 確認文字入力 → 実行）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    AccountDeletionService service,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AccountDeletionScreen(service: service)),
    );
    await tester.pump();
  }

  Future<void> openConfirmDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(AccountDeletionAppKeys.proceedButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> submitPhrase(WidgetTester tester, String phrase) async {
    await tester.enterText(
      find.byKey(AccountDeletionAppKeys.confirmField),
      phrase,
    );
    await tester.tap(find.byKey(AccountDeletionAppKeys.confirmSubmit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('1段目の対象列挙だけでは実行しない', (tester) async {
    var clearCalls = 0;
    var signOutCalls = 0;
    final service = AccountDeletionService(
      signOut: () async => signOutCalls++,
      clearLocalData: () async => clearCalls++,
    );

    await pumpScreen(tester, service);

    expect(find.byKey(AccountDeletionAppKeys.screen), findsOneWidget);
    expect(find.text('アカウント削除（退会）'), findsWidgets);
    expect(clearCalls, 0);
    expect(signOutCalls, 0);
  });

  testWidgets('誤入力では削除を実行しない', (tester) async {
    var clearCalls = 0;
    final service = AccountDeletionService(
      signOut: () async {},
      clearLocalData: () async => clearCalls++,
    );

    await pumpScreen(tester, service);
    await openConfirmDialog(tester);
    await submitPhrase(tester, '削除する');

    expect(clearCalls, 0);
    expect(find.byKey(AccountDeletionAppKeys.confirmError), findsOneWidget);
    expect(find.byKey(AccountDeletionAppKeys.confirmField), findsOneWidget);
  });

  testWidgets('正しい確認文字で1回だけ実行する', (tester) async {
    var clearCalls = 0;
    var signOutCalls = 0;
    final service = AccountDeletionService(
      signOut: () async => signOutCalls++,
      clearLocalData: () async => clearCalls++,
    );

    await pumpScreen(tester, service);
    await openConfirmDialog(tester);
    await submitPhrase(tester, ' 削除 ');

    expect(clearCalls, 1);
    expect(signOutCalls, 1);
  });

  testWidgets('成功時は成功文言を表示する', (tester) async {
    final service = AccountDeletionService(
      signOut: () async {},
      clearLocalData: () async {},
    );

    await pumpScreen(tester, service);
    await openConfirmDialog(tester);
    await submitPhrase(tester, '削除');

    expect(find.byKey(AccountDeletionAppKeys.successMessage), findsOneWidget);
    expect(find.byKey(AccountDeletionAppKeys.errorMessage), findsNothing);
  });

  testWidgets('失敗時は成功文言を出さずエラーと再試行を出す', (tester) async {
    final service = AccountDeletionService(
      signOut: () async => throw StateError('signOut failed'),
      clearLocalData: () async {},
    );

    await pumpScreen(tester, service);
    await openConfirmDialog(tester);
    await submitPhrase(tester, '削除');

    expect(find.byKey(AccountDeletionAppKeys.successMessage), findsNothing);
    expect(find.byKey(AccountDeletionAppKeys.errorMessage), findsOneWidget);
    expect(find.byKey(AccountDeletionAppKeys.retryButton), findsOneWidget);
  });
}
