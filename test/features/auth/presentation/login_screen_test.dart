import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_repository.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_state.dart';
import 'package:tsundoku_quest/features/auth/presentation/auth_provider.dart';
import 'package:tsundoku_quest/features/auth/presentation/login_screen.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

class MockLoginAuthRepository implements AuthRepository {
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

final mockLoginAuthRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockLoginAuthRepository();
});

Widget createLoginTestApp() {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithProvider(
        mockLoginAuthRepositoryProvider,
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const LoginScreen(),
    ),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('should display email and password fields', (tester) async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.authEmailField), findsOneWidget);
      expect(find.byKey(AppKeys.authPasswordField), findsOneWidget);
    });

    testWidgets('should display login button', (tester) async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.authSubmitButton), findsOneWidget);
    });

    testWidgets('should display login title', (tester) async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      expect(find.text('ログイン'), findsAtLeast(1));
    });

    testWidgets('should show back button', (tester) async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      // Back button or icon
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('should have Semantics on form fields', (tester) async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('should be wrapped in ErrorBoundary', (tester) async {
      await tester.pumpWidget(createLoginTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(ErrorBoundary), findsOneWidget);
    });
  });
}
