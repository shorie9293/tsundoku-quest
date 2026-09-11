import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/core/infrastructure/auth_service.dart';
import 'package:tsundoku_quest/core/infrastructure/supabase/supabase_client_provider.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/auth/presentation/login_screen.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;
import 'package:hive/hive.dart';
import 'dart:io';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockAuthService extends Mock implements AuthService {}

void _initTestHive() {
  final tempDir = Directory.systemTemp.createTempSync('hive_test_');
  Hive.init(tempDir.path);
}

/// ログインゲート画面の試練（Google認証移行後）
void main() {
  setUpAll(() {
    _initTestHive();
  });
  tearDownAll(() async {
    await Hive.close();
  });

  group('LoginScreen', () {
    testWidgets('should display Google sign-in button', (tester) async {
      final mockAuth = _MockAuthService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(_MockSupabaseClient()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: LoginScreen(authServiceOverride: mockAuth),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.authGoogleSignInButton), findsOneWidget);
    });

    testWidgets('should display app title', (tester) async {
      final mockAuth = _MockAuthService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(_MockSupabaseClient()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: LoginScreen(authServiceOverride: mockAuth),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ツンドクエスト'), findsAtLeast(1));
    });

    testWidgets('should be wrapped in ErrorBoundary', (tester) async {
      final mockAuth = _MockAuthService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(_MockSupabaseClient()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: LoginScreen(authServiceOverride: mockAuth),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorBoundary), findsOneWidget);
    });

    testWidgets('should have Semantics on sign-in button', (tester) async {
      final mockAuth = _MockAuthService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(_MockSupabaseClient()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: LoginScreen(authServiceOverride: mockAuth),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('should show error text when sign-in fails', (tester) async {
      final mockAuth = _MockAuthService();
      when(() => mockAuth.signInWithGoogle())
          .thenThrow(const AuthException('boom'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(_MockSupabaseClient()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: LoginScreen(authServiceOverride: mockAuth),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.authGoogleSignInButton));
      await tester.pump();

      expect(find.byKey(AppKeys.authErrorText), findsOneWidget);
    });
  });
}