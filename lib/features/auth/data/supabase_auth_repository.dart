import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:tsundoku_quest/features/auth/domain/auth_repository.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_state.dart';

/// Supabaseを認証バックエンドに使用したAuthRepositoryの具象実装
///
/// Supabase Auth APIをラップし、 [AuthState] にマッピングする。
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  AuthState _lastState = const AuthLoading();

  SupabaseAuthRepository(this._client) {
    // 初期化時に現在のセッションを確認
    _updateStateFromSession();
  }

  void _updateStateFromSession() {
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;
    if (session != null && user != null) {
      if (user.isAnonymous) {
        _lastState = AuthGuest(user.id);
      } else {
        _lastState = AuthAuthenticated(
          uid: user.id,
          email: user.email ?? '',
        );
      }
    } else {
      _lastState = const AuthLoading();
    }
  }

  @override
  AuthState get currentAuthState => _lastState;

  @override
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange.map((supabaseAuthState) {
        final user = supabaseAuthState.session?.user;
        if (supabaseAuthState.session != null && user != null) {
          if (user.isAnonymous) {
            return AuthGuest(user.id);
          }
          return AuthAuthenticated(
            uid: user.id,
            email: user.email ?? '',
          );
        }
        return const AuthLoading();
      });

  @override
  Future<AuthState> signInAnonymously() async {
    final response = await _client.auth.signInAnonymously();
    final user = response.user;
    final state = AuthGuest(user?.id ?? '');
    _lastState = state;
    return state;
  }

  @override
  Future<AuthState> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    final state = AuthAuthenticated(
      uid: user?.id ?? '',
      email: user?.email ?? email,
    );
    _lastState = state;
    return state;
  }

  @override
  Future<AuthState> signUpWithEmail(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    final user = response.user;
    final state = AuthAuthenticated(
      uid: user?.id ?? '',
      email: user?.email ?? email,
    );
    _lastState = state;
    return state;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _lastState = const AuthLoading();
  }
}
