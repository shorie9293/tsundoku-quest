import 'package:supabase_flutter/supabase_flutter.dart';

/// 認証リポジトリの抽象インターフェース
abstract class AuthRepository {
  /// 認証状態の変更を監視するストリーム
  Stream<AuthState> get authStateChanges;

  /// 現在のセッションを取得
  Session? get currentSession;

  /// 現在のユーザーを取得
  User? get currentUser;

  /// 匿名認証でサインイン
  Future<void> signInAnonymously();

  /// サインアウト
  Future<void> signOut();
}
