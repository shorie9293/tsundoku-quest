import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_repository.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_state.dart';

/// テスト用のMockAuthRepository
class MockAuthRepository implements AuthRepository {
  AuthState _state = const AuthLoading();

  void setState(AuthState state) => _state = state;

  @override
  AuthState get currentAuthState => _state;

  @override
  Stream<AuthState> get authStateChanges => Stream.value(_state);

  @override
  Future<AuthState> signInAnonymously() async {
    _state = const AuthGuest('mock-guest');
    return _state;
  }

  @override
  Future<AuthState> signInWithEmail(String email, String password) async {
    _state = AuthAuthenticated(uid: 'mock-user', email: email);
    return _state;
  }

  @override
  Future<AuthState> signUpWithEmail(String email, String password) async {
    _state = AuthAuthenticated(uid: 'mock-new-user', email: email);
    return _state;
  }

  @override
  Future<void> signOut() async {
    _state = const AuthLoading();
  }
}

void main() {
  group('AuthRepository interface', () {
    late MockAuthRepository repo;

    setUp(() {
      repo = MockAuthRepository();
    });

    test('should start as AuthLoading', () {
      expect(repo.currentAuthState, isA<AuthLoading>());
    });

    test('signInAnonymously should return AuthGuest', () async {
      final state = await repo.signInAnonymously();
      expect(state, isA<AuthGuest>());
      expect((state as AuthGuest).uid, 'mock-guest');
    });

    test('signInWithEmail should return AuthAuthenticated', () async {
      final state = await repo.signInWithEmail('test@example.com', 'pass123');
      expect(state, isA<AuthAuthenticated>());
      final authenticated = state as AuthAuthenticated;
      expect(authenticated.email, 'test@example.com');
      expect(authenticated.uid, 'mock-user');
    });

    test('signUpWithEmail should return AuthAuthenticated', () async {
      final state = await repo.signUpWithEmail('new@example.com', 'pass456');
      expect(state, isA<AuthAuthenticated>());
      final authenticated = state as AuthAuthenticated;
      expect(authenticated.email, 'new@example.com');
      expect(authenticated.uid, 'mock-new-user');
    });

    test('signOut should return to AuthLoading', () async {
      await repo.signInAnonymously();
      expect(repo.currentAuthState, isA<AuthGuest>());
      await repo.signOut();
      expect(repo.currentAuthState, isA<AuthLoading>());
    });

    test('authStateChanges should be a Stream', () {
      expect(repo.authStateChanges, isA<Stream<AuthState>>());
    });
  });
}
