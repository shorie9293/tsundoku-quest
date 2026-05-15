import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/features/auth/data/supabase_auth_repository.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_repository.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_state.dart';
import 'package:tsundoku_quest/core/infrastructure/supabase/supabase_client_provider.dart';

/// AuthRepositoryを提供するRiverpodプロバイダー
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
});

/// 認証状態管理のStateNotifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  StreamSubscription<AuthState>? _subscription;

  AuthNotifier(this._repository) : super(const AuthLoading()) {
    _subscription = _repository.authStateChanges.listen(
      (authState) {
        if (mounted) {
          state = authState;
        }
      },
      onError: (_) {
        if (mounted) state = const AuthLoading();
      },
    );
    // 現在の状態を反映
    final current = _repository.currentAuthState;
    if (current is! AuthLoading) {
      state = current;
    }
  }

  Future<void> signInAnonymously() async {
    state = const AuthLoading();
    try {
      state = await _repository.signInAnonymously();
    } catch (_) {
      state = const AuthLoading();
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AuthLoading();
    try {
      state = await _repository.signInWithEmail(email, password);
    } catch (_) {
      state = const AuthLoading();
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = const AuthLoading();
    try {
      state = await _repository.signUpWithEmail(email, password);
    } catch (_) {
      state = const AuthLoading();
    }
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
      state = const AuthLoading();
    } catch (_) {
      // ignore error
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// AuthNotifierを提供するStateNotifierProvider
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
