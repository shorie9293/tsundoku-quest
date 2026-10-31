import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/features/account_deletion/domain/account_deletion_policy.dart';

/// アカウント削除ポリシー — 削除可否・確認文字・対象一覧の純粋判定。
void main() {
  group('canDelete', () {
    test('セッションが無ければ削除できない', () {
      expect(
        AccountDeletionPolicy.canDelete(
          hasActiveSession: false,
          isAnonymous: false,
        ),
        isFalse,
      );
    });

    test('匿名ゲストは削除対象外', () {
      expect(
        AccountDeletionPolicy.canDelete(
          hasActiveSession: true,
          isAnonymous: true,
        ),
        isFalse,
      );
    });

    test('恒久アカウントのセッションがあるときのみ削除できる', () {
      expect(
        AccountDeletionPolicy.canDelete(
          hasActiveSession: true,
          isAnonymous: false,
        ),
        isTrue,
      );
    });
  });

  group('確認文字', () {
    test('confirmationPhrase は「削除」', () {
      expect(AccountDeletionPolicy.confirmationPhrase, '削除');
    });

    test('前後空白を除いた完全一致のみ満たす', () {
      expect(
        AccountDeletionPolicy.isConfirmationSatisfied(
          input: '  削除 ',
          expected: AccountDeletionPolicy.confirmationPhrase,
        ),
        isTrue,
      );
      expect(
        AccountDeletionPolicy.isConfirmationSatisfied(
          input: '削除する',
          expected: AccountDeletionPolicy.confirmationPhrase,
        ),
        isFalse,
      );
      expect(
        AccountDeletionPolicy.isConfirmationSatisfied(
          input: '',
          expected: AccountDeletionPolicy.confirmationPhrase,
        ),
        isFalse,
      );
    });
  });

  group('summary / targetBoxNames', () {
    test('summary は対象 Box 件数を含む説明文を返す', () {
      final summary = AccountDeletionPolicy.summary(
        hasActiveSession: true,
        isAnonymous: false,
      );
      expect(summary, isNotEmpty);
      expect(summary, contains('${AccountDeletionPolicy.targetBoxNames.length}'));
      expect(summary, contains('取り消せません'));
    });

    test('targetBoxNames は既存 Hive BoxNames.all と一致する', () {
      expect(AccountDeletionPolicy.targetBoxNames, BoxNames.all);
      expect(AccountDeletionPolicy.targetBoxNames, isNotEmpty);
    });
  });
}
