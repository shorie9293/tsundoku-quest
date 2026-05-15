import 'auth_state.dart';

/// 認証リポジトリの抽象インターフェース
///
/// ゲストファースト設計に基づき、匿名サインイン→後で恒久アカウント登録をサポート。
/// [AuthState] にマッピングされた状態変化を Stream で提供する。
abstract class AuthRepository {
  /// 匿名サインイン
  Future<AuthState> signInAnonymously();

  /// メール+パスワードでログイン
  Future<AuthState> signInWithEmail(String email, String password);

  /// メール+パスワードで新規登録
  Future<AuthState> signUpWithEmail(String email, String password);

  /// サインアウト
  Future<void> signOut();

  /// 認証状態の変更を監視するストリーム
  Stream<AuthState> get authStateChanges;

  /// 現在の認証状態（初回は [AuthLoading]）
  AuthState get currentAuthState;
}
