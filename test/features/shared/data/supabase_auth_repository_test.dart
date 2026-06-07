import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/domain/repositories/auth_repository.dart';
import 'package:tsundoku_quest/features/shared/data/supabase_auth_repository.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockSession extends Mock implements Session {}

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

  group('SupabaseAuthRepository (shared)', () {
    test('implements AuthRepository interface', () {
      expect(repository, isA<AuthRepository>());
    });

    test('currentSession delegates to auth.currentSession', () {
      final mockSession = MockSession();
      when(() => mockAuth.currentSession).thenReturn(mockSession);

      final session = repository.currentSession;

      expect(session, mockSession);
      verify(() => mockAuth.currentSession).called(1);
    });

    test('currentSession returns null when no session', () {
      when(() => mockAuth.currentSession).thenReturn(null);

      expect(repository.currentSession, isNull);
    });

    test('currentUser delegates to auth.currentUser', () {
      final mockUser = MockUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      final user = repository.currentUser;

      expect(user, mockUser);
      verify(() => mockAuth.currentUser).called(1);
    });

    test('currentUser returns null when not authenticated', () {
      when(() => mockAuth.currentUser).thenReturn(null);

      expect(repository.currentUser, isNull);
    });

    group('signInAnonymously', () {
      test('calls auth.signInAnonymously', () async {
        when(() => mockAuth.signInAnonymously())
            .thenAnswer((_) async => MockAuthResponse());

        await repository.signInAnonymously();

        verify(() => mockAuth.signInAnonymously()).called(1);
      });
    });

    group('signOut', () {
      test('calls auth.signOut', () async {
        when(() => mockAuth.signOut()).thenAnswer((_) async {});

        await repository.signOut();

        verify(() => mockAuth.signOut()).called(1);
      });
    });

    group('authStateChanges', () {
      test('returns a Stream from onAuthStateChange', () {
        when(() => mockAuth.onAuthStateChange).thenAnswer(
          (_) => const Stream.empty(),
        );

        expect(repository.authStateChanges, isA<Stream<AuthState>>());
      });
    });
  });
}

/// Minimal AuthResponse mock for signInAnonymously
class MockAuthResponse extends Mock implements AuthResponse {}
