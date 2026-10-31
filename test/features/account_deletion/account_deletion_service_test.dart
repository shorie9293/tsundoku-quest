import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/features/account_deletion/domain/account_deletion_service.dart';

/// 退会実行サービス — 削除→サインアウトの順序と失敗時の扱い。
void main() {
  test('未確認なら何も実行せず failure を返す', () async {
    var signOutCalls = 0;
    var clearCalls = 0;
    final service = AccountDeletionService(
      signOut: () async => signOutCalls++,
      clearLocalData: () async => clearCalls++,
    );

    final result = await service.execute(confirmed: false);

    expect(result.success, isFalse);
    expect(result.message, isNotEmpty);
    expect(signOutCalls, 0);
    expect(clearCalls, 0);
  });

  test('成功時は clearLocalData → signOut を各1回呼ぶ', () async {
    final calls = <String>[];
    final service = AccountDeletionService(
      signOut: () async => calls.add('signOut'),
      clearLocalData: () async => calls.add('clearLocalData'),
    );

    final result = await service.execute(confirmed: true);

    expect(result.success, isTrue);
    expect(result.message, isNotEmpty);
    expect(calls, <String>['clearLocalData', 'signOut']);
  });

  test('ローカル削除が失敗したら failure（signOut は呼ばない）', () async {
    var signOutCalls = 0;
    final service = AccountDeletionService(
      signOut: () async => signOutCalls++,
      clearLocalData: () async => throw StateError('disk error'),
    );

    final result = await service.execute(confirmed: true);

    expect(result.success, isFalse);
    expect(result.message, contains('削除'));
    expect(signOutCalls, 0);
  });

  test('サインアウトが失敗したら success を返さない', () async {
    var clearCalls = 0;
    final service = AccountDeletionService(
      signOut: () async => throw StateError('network error'),
      clearLocalData: () async => clearCalls++,
    );

    final result = await service.execute(confirmed: true);

    expect(result.success, isFalse);
    expect(result.message, isNotEmpty);
    expect(clearCalls, 1);
  });
}
