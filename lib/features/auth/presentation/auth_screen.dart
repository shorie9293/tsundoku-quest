import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;
import '../../../../core/widgets/dungeon_background.dart';

/// 認証選択画面 — ゲストファースト設計
///
/// 3つの選択肢を提示:
/// 1. ゲストとして始める（匿名サインイン）
/// 2. ログイン（既存アカウント）
/// 3. 新規登録（新規アカウント作成）
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      key: AppKeys.authScreen,
      child: Scaffold(
        key: AppKeys.authScreen,
        body: DungeonBackground(
          child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(flex: 2),
                  // アプリアイコン
                  Icon(
                    Icons.auto_stories,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  // タイトル
                  Text(
                    'ツンドクエスト',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '読書を冒険に変える',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const Spacer(flex: 2),
                  // ゲストとして始める
                  SizedBox(
                    width: double.infinity,
                    child: SemanticHelper.interactive(
                      testId: 'btn_auth_guest',
                      child: ElevatedButton(
                        key: AppKeys.authGuestButton,
                        onPressed: () => context.go('/'),
                        child: const Text('ゲストとして始める'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ログイン
                  SizedBox(
                    width: double.infinity,
                    child: SemanticHelper.interactive(
                      testId: 'btn_auth_login',
                      child: OutlinedButton(
                        key: AppKeys.authLoginButton,
                        onPressed: () => context.go('/auth/login'),
                        child: const Text('ログイン'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 新規登録
                  SizedBox(
                    width: double.infinity,
                    child: SemanticHelper.interactive(
                      testId: 'btn_auth_signup',
                      child: TextButton(
                        key: AppKeys.authSignupButton,
                        onPressed: () => context.go('/auth/signup'),
                        child: const Text('新規登録'),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
