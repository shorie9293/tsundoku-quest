import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/core/infrastructure/auth_service.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _FakeGoogleSignInAccount extends Fake implements GoogleSignInAccount {
  @override
  final GoogleSignInAuthentication authentication;
  _FakeGoogleSignInAccount(GoogleSignInAuthentication auth)
      : authentication = auth;
}

class _FakeAuthResponse extends Fake implements AuthResponse {}

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late AuthService service;

  setUpAll(() {
    registerFallbackValue(OAuthProvider.google);
  });

  setUp(() {
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    when(() => client.auth).thenReturn(auth);
    service = AuthService.withGoogleSignIn(client, _MockGoogleSignIn());
  });

  group('AuthService', () {
    test('ensureInitialized は初期化済みなら再度 initialize を呼ばない', () async {
      final gsi = service.googleSignInForTest as _MockGoogleSignIn;
      when(() => gsi.initialize(serverClientId: any(named: 'serverClientId')))
          .thenAnswer((_) async => gsi);

      await service.ensureInitialized();
      await service.ensureInitialized();

      verify(() => gsi.initialize(serverClientId: any(named: 'serverClientId')))
          .called(1);
    });

    test('signInWithGoogle は IDトークンで signInWithIdToken を呼ぶ', () async {
      final gsi = service.googleSignInForTest as _MockGoogleSignIn;
      final account = _FakeGoogleSignInAccount(
        const GoogleSignInAuthentication(idToken: 'id-token-abc'),
      );
      when(() => gsi.initialize(serverClientId: any(named: 'serverClientId')))
          .thenAnswer((_) async => gsi);
      when(() => gsi.authenticate(scopeHint: any(named: 'scopeHint')))
          .thenAnswer((_) async => account);
      final response = _FakeAuthResponse();
      when(() => auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'id-token-abc',
          )).thenAnswer((_) async => response);

      final result = await service.signInWithGoogle();

      expect(result, same(response));
      verify(() => auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'id-token-abc',
          )).called(1);
    });

    test('IDトークンがnullなら AuthException を投げる', () async {
      final gsi = service.googleSignInForTest as _MockGoogleSignIn;
      final account = _FakeGoogleSignInAccount(
        const GoogleSignInAuthentication(idToken: null),
      );
      when(() => gsi.initialize(serverClientId: any(named: 'serverClientId')))
          .thenAnswer((_) async => gsi);
      when(() => gsi.authenticate(scopeHint: any(named: 'scopeHint')))
          .thenAnswer((_) async => account);

      await expectLater(
        service.signInWithGoogle(),
        throwsA(isA<AuthException>()),
      );
      verifyNever(() => auth.signInWithIdToken(
            provider: any(named: 'provider'),
            idToken: any(named: 'idToken'),
          ));
    });

    test('currentUser / isSignedIn は Supabase の状態を反映', () {
      when(() => auth.currentUser).thenReturn(null);
      expect(service.isSignedIn, isFalse);
    });
  });
}