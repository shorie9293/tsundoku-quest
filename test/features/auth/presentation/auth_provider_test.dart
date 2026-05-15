import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_repository.dart';
import 'package:tsundoku_quest/features/auth/domain/auth_state.dart';
import 'package:tsundoku_quest/features/auth/presentation/auth_provider.dart';

/// Mock AuthRepository for provider testing
class MockAuthRepository implements AuthRepository {
  AuthState _state = const AuthLoading();
  final _controller = StreamController<AuthState>.broadcast();
  bool shouldThrow = false;

  @override
  AuthState get currentAuthState => _state;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  Future<AuthState> signInAnonymously() async {
    if (shouldThrow) throw Exception('Mock error');
    _state = const AuthGuest('mock-guest');
    _controller.add(_state);
    return _state;
  }

  @override
  Future<AuthState> signInWithEmail(String email, String password) async {
    if (shouldThrow) throw Exception('Mock error');
    _state = AuthAuthenticated(uid: 'mock-user', email: email);
    _controller.add(_state);
    return _state;
  }

  @override
  Future<AuthState> signUpWithEmail(String email, String password) async {
    if (shouldThrow) throw Exception('Mock error');
    _state = AuthAuthenticated(uid: 'mock-new', email: email);
    _controller.add(_state);
    return _state;
  }

  @override
  Future<void> signOut() async {
    _state = const AuthLoading();
    _controller.add(_state);
  }

  void dispose() => _controller.close();
}

void main() {
  group('AuthNotifier', () {
    late MockAuthRepository mockRepo;
    late AuthNotifier notifier;

    setUp(() {
      mockRepo = MockAuthRepository();
      notifier = AuthNotifier(mockRepo);
    });

    tearDown(() {
      notifier.dispose();
      mockRepo.dispose();
    });

    test('should start as AuthLoading', () {
      expect(notifier.state, isA<AuthLoading>());
    });

    test('signInAnonymously should emit AuthGuest', () async {
      await notifier.signInAnonymously();
      expect(notifier.state, isA<AuthGuest>());
      expect((notifier.state as AuthGuest).uid, 'mock-guest');
    });

    test('signInWithEmail should emit AuthAuthenticated', () async {
      await notifier.signInWithEmail('test@example.com', 'pass');
      expect(notifier.state, isA<AuthAuthenticated>());
      final auth = notifier.state as AuthAuthenticated;
      expect(auth.email, 'test@example.com');
      expect(auth.uid, 'mock-user');
    });

    test('signUpWithEmail should emit AuthAuthenticated', () async {
      await notifier.signUpWithEmail('new@example.com', 'pass');
      expect(notifier.state, isA<AuthAuthenticated>());
      final auth = notifier.state as AuthAuthenticated;
      expect(auth.email, 'new@example.com');
      expect(auth.uid, 'mock-new');
    });

    test('signOut should emit AuthLoading', () async {
      await notifier.signInAnonymously();
      expect(notifier.state, isA<AuthGuest>());
      await notifier.signOut();
      expect(notifier.state, isA<AuthLoading>());
    });

    test('should handle errors gracefully', () async {
      mockRepo.shouldThrow = true;
      // Should not throw, should emit AuthLoading on error
      await notifier.signInAnonymously();
      // State should still be loading after error
      expect(notifier.state, isA<AuthLoading>());
    });

    test('should listen to authStateChanges stream', () async {
      // Simulate external state change via stream
      mockRepo.signInAnonymously();
      // Give the stream listener time to process
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // The notifier should have processed the stream event
      expect(notifier.state, isA<AuthGuest>());
    });
  });
}
