/// 認証状態の sealed class
///
/// ゲストファースト設計の核となる状態管理。
/// [AuthGuest] - 匿名サインイン済み
/// [AuthAuthenticated] - 恒久アカウントで認証済み
/// [AuthLoading] - 認証処理中
sealed class AuthState {
  const AuthState();
}

/// 匿名（ゲスト）認証状態
class AuthGuest extends AuthState {
  final String uid;
  const AuthGuest(this.uid);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AuthGuest && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}

/// 恒久アカウントで認証済み状態
class AuthAuthenticated extends AuthState {
  final String uid;
  final String email;
  const AuthAuthenticated({required this.uid, required this.email});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthAuthenticated && uid == other.uid && email == other.email;

  @override
  int get hashCode => Object.hash(uid, email);
}

/// 認証処理中状態
class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  bool operator ==(Object other) => other is AuthLoading;

  @override
  int get hashCode => runtimeType.hashCode;
}
