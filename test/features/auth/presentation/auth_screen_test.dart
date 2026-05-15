import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_repository.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_state.dart';
import 'package:tsundoku_quest/features/auth/presentation/auth_provider.dart';
import 'package:tsundoku_quest/features/auth/presentation/auth_screen.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// Mock AuthRepository for screen tests
class MockScreenAuthRepository implements AuthRepository {
  @override
  AuthState get currentAuthState => const AuthGuest('guest');

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<AuthState> signInAnonymously() async {
    return const AuthGuest('guest-screen');
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

/// Override provider for tests
final mockAuthRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockScreenAuthRepository();
});

Widget createTestApp({Widget? home}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithProvider(mockAuthRepositoryProvider),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: home ?? const AuthScreen(),
    ),
  );
}

void main() {
  group('AuthScreen', () {
    testWidgets('should display title and subtitle', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('ツンドクエスト'), findsOneWidget);
      expect(find.text('読書を冒険に変える'), findsOneWidget);
    });

    testWidgets('should show all three action buttons', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.authGuestButton), findsOneWidget);
      expect(find.byKey(AppKeys.authLoginButton), findsOneWidget);
      expect(find.byKey(AppKeys.authSignupButton), findsOneWidget);
    });

    testWidgets('guest button should have correct text', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('ゲストとして始める'), findsOneWidget);
    });

    testWidgets('login button should have correct text', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('ログイン'), findsOneWidget);
    });

    testWidgets('signup button should have correct text', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('新規登録'), findsOneWidget);
    });

    testWidgets('should have Semantics on buttons', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('guest button should be wrapped in ErrorBoundary',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(ErrorBoundary), findsOneWidget);
    });
  });
}
