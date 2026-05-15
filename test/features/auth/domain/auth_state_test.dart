import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_state.dart';

void main() {
  group('AuthState', () {
    test('AuthGuest should have uid', () {
      final state = AuthGuest('guest-123');
      expect(state, isA<AuthState>());
      expect(state.uid, 'guest-123');
    });

    test('AuthGuest equality', () {
      const a = AuthGuest('guest-1');
      const b = AuthGuest('guest-1');
      const c = AuthGuest('guest-2');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('AuthAuthenticated should have uid and email', () {
      const state = AuthAuthenticated(uid: 'user-1', email: 'test@example.com');
      expect(state, isA<AuthState>());
      expect(state.uid, 'user-1');
      expect(state.email, 'test@example.com');
    });

    test('AuthAuthenticated equality', () {
      const a = AuthAuthenticated(uid: 'u1', email: 'a@b.com');
      const b = AuthAuthenticated(uid: 'u1', email: 'a@b.com');
      const c = AuthAuthenticated(uid: 'u2', email: 'c@d.com');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('AuthLoading should be an AuthState', () {
      const state = AuthLoading();
      expect(state, isA<AuthState>());
    });

    test('AuthState sealed exhaustiveness', () {
      // This compile-time check ensures the sealed class is properly defined
      AuthState state = const AuthLoading();
      final desc = switch (state) {
        AuthGuest(:final uid) => 'guest: $uid',
        AuthAuthenticated(:final uid, :final email) => 'auth: $uid, $email',
        AuthLoading() => 'loading',
      };
      expect(desc, 'loading');
    });
  });
}
