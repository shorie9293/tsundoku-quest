import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/domain/repositories/auth_repository.dart';

/// Supabaseを認証バックエンドに使用したAuthRepositoryの具象実装
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Future<void> signInAnonymously() async {
    await _client.auth.signInAnonymously();
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
