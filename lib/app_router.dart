import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/widgets/app_scaffold.dart';
import 'features/bookshelf/presentation/bookshelf_screen.dart';
import 'features/explore/presentation/explore_screen.dart';
import 'features/reading/presentation/reading_screen.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/recommendation/presentation/recommendation_screen.dart';

/// アプリ全体のルーティング設定
///
/// Next.jsのページルーティング＋TabBarをgo_router + BottomNavigationBarに移植。
/// ShellRouteで共通のAppScaffold（BottomNavigationBar付き）を提供し、
/// 4つのタブ画面を子ルートとして定義する。
class AppRouter {
  AppRouter._();

  /// Creates a new GoRouter instance.
  ///
  /// Use [createRouter] in tests to get a fresh router per test
  /// (avoids cross-test state contamination from the singleton).
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppScaffold(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const BookshelfScreen(),
            ),
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ExploreScreen(),
            ),
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
        // /reading は ShellRoute 外（読書中タブ削除により BottomNav 非表示に）
        GoRoute(
          path: '/reading',
          builder: (context, state) =>
              ReadingScreen(id: state.uri.queryParameters['id']),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) => const AuthScreen(),
          routes: [
            GoRoute(
              path: 'login',
              builder: (context, state) => const LoginScreen(),
            ),
            GoRoute(
              path: 'signup',
              builder: (context, state) => const SignupScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/recommendations',
          builder: (context, state) => const RecommendationScreen(),
        ),
      ],
    );
  }
  /// Singleton router instance for production use.
  static final GoRouter router = createRouter();
}

/// プレースホルダー画面
///
/// 各タブの実画面が実装されるまでの仮画面。
/// Phase 3.2〜3.5 で各Feature画面に置き換えられる。
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    // Determine the AppKey based on title
    final screenKey = switch (title) {
      '書庫' => const Key('screen_bookshelf'),
      '探索' => const Key('screen_explore'),
      '読書中' => const Key('screen_reading'),
      '足跡' => const Key('screen_history'),
      _ => Key('screen_${title.toLowerCase()}'),
    };

    return Scaffold(
      key: screenKey,
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
