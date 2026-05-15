import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:tsundoku_quest/features/auth/data/supabase_auth_repository.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_repository.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_state.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockAuthResponse extends Mock implements AuthResponse {}

/// Helper to create a minimal User for testing
User createTestUser({required String id, String? email}) {
  return User(
    id: id,
    appMetadata: <String, dynamic>{},
    userMetadata: <String, dynamic>{},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    isAnonymous: email == null,
    email: email,
  );
}

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late SupabaseAuthRepository repository;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    repository = SupabaseAuthRepository(mockClient);
  });

  group('SupabaseAuthRepository', () {
    test('should implement AuthRepository', () {
      expect(repository, isA<AuthRepository>());
    });

    test('currentAuthState should be AuthLoading initially', () {
      when(() => mockAuth.currentSession).thenReturn(null);
      // We need to set currentUser to null as well
      when(() => mockAuth.currentUser).thenReturn(null);

      final repo = SupabaseAuthRepository(mockClient);
      expect(repo.currentAuthState, isA<AuthLoading>());
    });

    group('signInAnonymously', () {
      test('should return AuthGuest on success', () async {
        final mockResponse = MockAuthResponse();
        when(() => mockResponse.user).thenReturn(
          createTestUser(id: 'anon-123'),
        );
        when(() => mockAuth.signInAnonymously())
            .thenAnswer((_) async => mockResponse);

        final state = await repository.signInAnonymously();

        expect(state, isA<AuthGuest>());
        expect((state as AuthGuest).uid, 'anon-123');
        verify(() => mockAuth.signInAnonymously()).called(1);
      });
    });

    group('signInWithEmail', () {
      test('should return AuthAuthenticated on success', () async {
        final mockResponse = MockAuthResponse();
        when(() => mockResponse.user).thenReturn(
          createTestUser(id: 'user-1', email: 'test@example.com'),
        );
        when(() => mockAuth.signInWithPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => mockResponse);

        final state =
            await repository.signInWithEmail('test@example.com', 'pass123');

        expect(state, isA<AuthAuthenticated>());
        final auth = state as AuthAuthenticated;
        expect(auth.uid, 'user-1');
        expect(auth.email, 'test@example.com');
        verify(() => mockAuth.signInWithPassword(
              email: 'test@example.com',
              password: 'pass123',
            )).called(1);
      });
    });

    group('signUpWithEmail', () {
      test('should return AuthAuthenticated on success', () async {
        final mockResponse = MockAuthResponse();
        when(() => mockResponse.user).thenReturn(
          createTestUser(id: 'new-user', email: 'new@example.com'),
        );
        when(() => mockAuth.signUp(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenAnswer((_) async => mockResponse);

        final state =
            await repository.signUpWithEmail('new@example.com', 'pass456');

        expect(state, isA<AuthAuthenticated>());
        final auth = state as AuthAuthenticated;
        expect(auth.uid, 'new-user');
        expect(auth.email, 'new@example.com');
        verify(() => mockAuth.signUp(
              email: 'new@example.com',
              password: 'pass456',
            )).called(1);
      });
    });

    group('signOut', () {
      test('should call auth.signOut', () async {
        when(() => mockAuth.signOut()).thenAnswer((_) async {});

        await repository.signOut();

        verify(() => mockAuth.signOut()).called(1);
      });
    });

    group('authStateChanges', () {
      test('should be a Stream<AuthState>', () {
        when(() => mockAuth.onAuthStateChange).thenAnswer(
          (_) => const Stream.empty(),
        );

        expect(repository.authStateChanges, isA<Stream<AuthState>>());
      });
    });
  });
}
