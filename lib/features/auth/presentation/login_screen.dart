import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_state.dart';
import 'package:tsundoku_quest/features/auth/presentation/auth_provider.dart';
import 'package:tsundoku_quest/features/auth/presentation/widgets/auth_form_field.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// ログイン画面
///
/// メールアドレスとパスワードでログイン。
/// エラー表示とローディング状態をサポート。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);
    try {
      await ref
          .read(authStateProvider.notifier)
          .signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _errorMessage = 'ログインに失敗しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState is AuthLoading;

    return ErrorBoundary(
      key: AppKeys.authScreen,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: AppKeys.authBackButton,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/auth'),
          ),
          title: const Text('ログイン'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),
                AuthFormField(
                  testId: 'txt_auth_email',
                  label: 'メールアドレス',
                  hintText: 'example@email.com',
                  controller: _emailController,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'メールアドレスを入力してください';
                    }
                    if (!v.contains('@')) {
                      return '有効なメールアドレスを入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthFormField(
                  testId: 'txt_auth_password',
                  label: 'パスワード',
                  obscureText: true,
                  controller: _passwordController,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'パスワードを入力してください';
                    }
                    if (v.length < 6) {
                      return 'パスワードは6文字以上必要です';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    identifier: 'txt_auth_error',
                    child: Text(
                      _errorMessage!,
                      key: AppKeys.authErrorText,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: SemanticHelper.interactive(
                    testId: 'btn_auth_submit',
                    child: ElevatedButton(
                      key: AppKeys.authSubmitButton,
                      onPressed: isLoading ? null : _handleLogin,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('ログイン'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
