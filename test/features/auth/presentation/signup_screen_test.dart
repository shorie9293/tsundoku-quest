import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_repository.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_state.dart';
import 'package:tsundoku_quest/features/auth/presentation/auth_provider.dart';
import 'package:tsundoku_quest/features/auth/presentation/signup_screen.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

class MockSignupAuthRepository implements AuthRepository {
  @override
  AuthState get currentAuthState => const AuthGuest('guest');

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<AuthState> signInAnonymously() async {
    return const AuthGuest('guest');
  }

  @override
  Future<AuthState> signInWithEmail(String email, String password) async {
    return AuthAuthenticated(uid: 'u1', email: email);
  }

  @override
  Future<AuthState> signUpWithEmail(String email, String password) async {
    return AuthAuthenticated(uid: 'u2', email: email);
  }

  @override
  Future<void> signOut() async {}
}

final mockSignupAuthRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockSignupAuthRepository();
});

Widget createSignupTestApp() {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithProvider(
        mockSignupAuthRepositoryProvider,
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const SignupScreen(),
    ),
  );
}

void main() {
  group('SignupScreen', () {
    testWidgets('should display email and password fields', (tester) async {
      await tester.pumpWidget(createSignupTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.authEmailField), findsOneWidget);
      expect(find.byKey(AppKeys.authPasswordField), findsOneWidget);
      expect(find.byKey(AppKeys.authConfirmPasswordField), findsOneWidget);
    });

    testWidgets('should display signup button', (tester) async {
      await tester.pumpWidget(createSignupTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.authSubmitButton), findsOneWidget);
    });

    testWidgets('should display signup title', (tester) async {
      await tester.pumpWidget(createSignupTestApp());
      await tester.pumpAndSettle();

      expect(find.text('新規登録'), findsAtLeast(1));
    });

    testWidgets('should show back button', (tester) async {
      await tester.pumpWidget(createSignupTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('should have Semantics on form fields', (tester) async {
      await tester.pumpWidget(createSignupTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('should be wrapped in ErrorBoundary', (tester) async {
      await tester.pumpWidget(createSignupTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(ErrorBoundary), findsOneWidget);
    });
  });
}
