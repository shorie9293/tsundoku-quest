import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;
import 'package:tsundoku_quest/core/infrastructure/auth_service.dart';
import 'package:tsundoku_quest/core/infrastructure/supabase/supabase_client_provider.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/core/widgets/dungeon_background.dart';

/// Google ログインゲート画面 — 匿名認証廃止後の唯一の入口。
///
/// ログイン完了まで蔵書機能（'/' 以降）へ到達できないゲート構成。
/// Googleログイン → Supabase signInWithIdToken でセッション確立。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.authServiceOverride});

  /// 試練用: AuthService を差し替える（DI — Mock可能に）。
  final AuthService? authServiceOverride;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  AuthService _authService() {
    return widget.authServiceOverride ??
        AuthService(ref.read(supabaseClientProvider));
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _authService().signInWithGoogle();
      if (mounted) context.go('/');
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // ユーザーによるキャンセルはエラー扱いにしない
        return;
      }
      setState(() => _errorMessage = 'Googleログインに失敗しました: ${e.code}');
    } catch (e) {
      setState(() => _errorMessage = 'Googleログインに失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ErrorBoundary(
      key: AppKeys.authScreen,
      child: Scaffold(
        key: AppKeys.authScreen,
        body: DungeonBackground(
          screenType: ScreenType.auth,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Spacer(flex: 2),
                    Icon(
                      Icons.auto_stories,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ツンドクエスト',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '冒険の記録はGoogleアカウントに紐づく',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const Spacer(flex: 2),
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        key: AppKeys.authErrorText,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: SemanticHelper.interactive(
                        testId: 'btn_google_signin',
                        child: ElevatedButton.icon(
                          key: AppKeys.authGoogleSignInButton,
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: const Text(
                            'Googleでログイン',
                            style: TextStyle(fontSize: 16),
                          ),
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