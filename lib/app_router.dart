import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/widgets/app_scaffold.dart';
import 'features/bookshelf/presentation/bookshelf_screen.dart';
import 'features/explore/presentation/explore_screen.dart';
import 'features/reading/presentation/reading_screen.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/recommendation/presentation/recommendation_screen.dart';
import 'features/tutorial/presentation/tutorial_screen.dart';
import 'features/tutorial/data/tutorial_preferences.dart';
import 'features/reminders/presentation/reminder_settings_screen.dart';
import 'features/shelves/presentation/shelf_management_screen.dart';

/// アプリ全体のルーティング設定
///
/// Next.jsのページルーティング＋TabBarをgo_router + BottomNavigationBarに移植。
/// ShellRouteで共通のAppScaffold（BottomNavigationBar付き）を提供し、
/// 3つのタブ画面を子ルートとして定義する。
///
/// 認証ゲート: 未ログイン時は /login へ強制リダイレクトする
/// （Google認証ゲート — 匿名認証廃止）。ログイン済みで /login への
/// 直行は '/' へ戻す。
class AppRouter {
  AppRouter._();

  /// Creates a new GoRouter instance.
  ///
  /// Use [createRouter] in tests to get a fresh router per test
  /// (avoids cross-test state contamination from the singleton).
  /// [isSignedIn] を差し替えることで認証ガードを試練から制御できる
  /// （既定は Supabase のセッション状態）。
  static GoRouter createRouter({bool Function()? isSignedIn}) {
    bool signedIn() {
      final check = isSignedIn;
      if (check != null) return check();
      try {
        return Supabase.instance.client.auth.currentUser != null;
      } catch (_) {
        return false;
      }
    }

    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final loggedIn = signedIn();
        final loggingIn = state.matchedLocation == '/login';
        if (!loggedIn && !loggingIn) return '/login';
        if (loggedIn && loggingIn) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
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
          path: '/recommendations',
          builder: (context, state) => const RecommendationScreen(),
        ),
        GoRoute(
          path: '/tutorial',
          builder: (context, state) {
            return FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return TutorialScreen(
                  prefs: TutorialPreferences(snapshot.data!),
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/reminder-settings',
          builder: (context, state) => const ReminderSettingsScreen(),
        ),
        GoRoute(
          path: '/shelves',
          builder: (context, state) => const ShelfManagementScreen(),
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