import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Google ネイティブ認証 → Supabase セッション確立を担うサービス。
///
/// rpg-task の実績実装を移植。google_sign_in 7.x の新API
/// （シングルトン + initialize + authenticate）に準拠。
/// - authenticate で得た ID トークンを Supabase の signInWithIdToken へ渡す。
/// - RLS は auth.uid() ベースのまま（user_id は Google アカウント単位で不変）。
class AuthService {
  /// 本番用コンストラクタ。GoogleSignIn シングルトンを利用する。
  AuthService(SupabaseClient supabase) : this._(supabase, GoogleSignIn.instance);

  AuthService._(this._supabase, this._googleSignIn);

  final SupabaseClient _supabase;
  final GoogleSignIn _googleSignIn;
  bool _initialized = false;

  /// テスト用に GoogleSignIn インスタンスを差し替えられるコンストラクタ。
  AuthService.withGoogleSignIn(SupabaseClient supabase, GoogleSignIn gsi)
      : this._(supabase, gsi);

  /// テスト用アクセサ（モック検証に使用）。
  @visibleForTesting
  GoogleSignIn get googleSignInForTest => _googleSignIn;

  /// google_sign_in の1回限りの初期化。authenticate 前に必ず呼ぶ。
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize(
      serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
    );
    _initialized = true;
  }

  /// Google ネイティブ認証を実行し、Supabase セッションを確立する。
  ///
  /// キャンセル時は [GoogleSignInException]（code=canceled）が投げられる。
  Future<AuthResponse> signInWithGoogle() async {
    await ensureInitialized();

    final GoogleSignInAccount account = await _googleSignIn.authenticate(
      scopeHint: const <String>['email', 'profile'],
    );

    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google IDトークンの取得に失敗しました');
    }

    return _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// サインアウト（Google + Supabase 両方）。
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[AuthService] GoogleSignIn signOut failed: $e');
    }
    await _supabase.auth.signOut();
  }

  /// 現在のログインユーザー（未ログインなら null）。
  User? get currentUser => _supabase.auth.currentUser;

  /// ログイン済みか。
  bool get isSignedIn => currentUser != null;
}