import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'core/theme/app_theme.dart';
import 'core/infrastructure/supabase/supabase_config.dart';
import 'core/infrastructure/connectivity/connectivity_provider.dart';
import 'core/infrastructure/hive/hive_initializer.dart';
import 'core/infrastructure/hive/adapters/book_adapters.dart';
import 'core/infrastructure/hive/adapters/reading_session_adapter.dart';
import 'core/infrastructure/hive/adapters/daily_mission_adapters.dart';
import 'core/infrastructure/hive/adapters/war_trophy_adapter.dart';
import 'core/infrastructure/hive/box_manager.dart';
import 'core/infrastructure/hive/migration_service.dart';
import 'domain/models/user_book.dart';
import 'domain/models/reading_session.dart';
import 'app_router.dart';
import 'features/shared/data/adventurer_repository_provider.dart';
import 'features/tutorial/data/tutorial_preferences.dart';
import 'shared/providers/adventurer_provider.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

Future<void> main() async {
  debugPrint('🔵 main() 開始');
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = SupabaseConfig.url;
  const supabaseKey = SupabaseConfig.anonKey;

  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
      debugPrint('✅ Supabase 初期化完了');

      // ゲストファースト：匿名サインインを自動実行
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          await Supabase.instance.client.auth.signInAnonymously();
          debugPrint('✅ 匿名サインイン完了');
        }
      } catch (e) {
        debugPrint('⚠️ 匿名サインイン失敗（オフラインモード継続）: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Supabase初期化失敗（オフラインモード）: $e');
    }
  } else {
    debugPrint('⚠️ SUPABASE_URL/SUPABASE_ANON_KEY 未設定（オフラインモード）');
  }

  // ① Widgetツリー内の例外を捕捉
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return ErrorBoundaryWidget(
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // ② Flutterフレームワーク内の非同期エラー
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // ③ ゾーン外の非同期エラー（Platformレベル）
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('💀 捕捉不能エラー: $error\n$stack');
    return true;
  };

  // ── Hive 初期化 ──
  try {
    await initializeHive(
      registerAdaptersCallback: () {
        Hive.registerAdapter(BookSourceAdapter());
        Hive.registerAdapter(BookAdapter());
        Hive.registerAdapter(BookStatusAdapter());
        Hive.registerAdapter(BookMediumAdapter());
        Hive.registerAdapter(UserBookAdapter());
        Hive.registerAdapter(ReadingSessionAdapter());
        Hive.registerAdapter(DailyMissionTypeAdapter());
        Hive.registerAdapter(DailyMissionAdapter());
        Hive.registerAdapter(WarTrophyAdapter());
      },
    );
    debugPrint('✅ Hive 初期化完了');
  } catch (e) {
    debugPrint('⚠️ Hive 初期化失敗（オフライン永続化不可）: $e');
  }

  // ── データ移行（初回起動時のみ）──
  await _runHiveMigration();

  debugPrint('🚀 runApp 開始...');
  runApp(
    const ProviderScope(
      child: TsundokuQuestApp(),
    ),
  );
  debugPrint('🏁 runApp 完了');
}

/// 初回起動時の Hive データ移行を実行する
///
/// Supabase に保存された UserBook と ReadingSession を Hive に移行し、
/// 移行完了フラグを SharedPreferences に保存する。
/// 移行が完了している場合や Supabase が未初期化の場合は何もせず復帰する。
Future<void> _runHiveMigration() async {
  try {
    final boxManager = HiveBoxManager();

    final migrationService = HiveMigrationService(
      boxManager: boxManager,
      // Supabase から UserBook 一覧を取得し、ドメインオブジェクトに変換
      onFetchUserBooks: () async {
        try {
          final client = Supabase.instance.client;
          final response = await client
              .from('user_books')
              .select('*, book:books(*)')
              .order('created_at', ascending: false);
          return response
              .map((json) => UserBook.fromSupabase(json))
              .toList();
        } catch (e) {
          debugPrint('[HiveMigration] UserBook fetch failed: $e');
          return [];
        }
      },
      // Supabase から ReadingSession 一覧を取得し、ドメインオブジェクトに変換
      onFetchReadingSessions: () async {
        try {
          final client = Supabase.instance.client;
          final response = await client
              .from('reading_sessions')
              .select()
              .order('created_at', ascending: false)
              .limit(1000);
          return response
              .map((json) => ReadingSession.fromSupabase(json))
              .toList();
        } catch (e) {
          debugPrint('[HiveMigration] ReadingSession fetch failed: $e');
          return [];
        }
      },
    );

    final result = await migrationService.migrate();
    debugPrint(
      '[HiveMigration] 結果: '
      'completed=${result.completed}, skipped=${result.skipped}, '
      'books=${result.booksMigrated}, sessions=${result.sessionsMigrated}, '
      'tutorial=${result.tutorialMigrated}',
    );
    if (result.error != null) {
      debugPrint('[HiveMigration] エラー: ${result.error}');
    }
  } catch (e) {
    // 移行失敗はアプリ起動を妨げない
    debugPrint('[HiveMigration] 移行全体が失敗: $e');
  }
}

class TsundokuQuestApp extends ConsumerStatefulWidget {
  const TsundokuQuestApp({super.key});

  @override
  ConsumerState<TsundokuQuestApp> createState() => _TsundokuQuestAppState();
}

class _TsundokuQuestAppState extends ConsumerState<TsundokuQuestApp> {
  @override
  void initState() {
    super.initState();
    // 接続状態の変化を監視し、オンライン復帰時に自動リトライ
    ref.listenManual(isOnlineProvider, (prev, next) {
      if (prev == false && next == true) {
        // オフライン → オンライン復帰
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ 接続が復帰しました'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
        // Supabase から冒険者ステータスを再取得
        _retryLoadAdventurer();
      } else if (next == false) {
        // オフライン検知（ログのみ）
        debugPrint('📡 [App] オフライン状態を検知');
      }
    });
  }

  void _retryLoadAdventurer() {
    try {
      final repository = ref.read(adventurerRepositoryProvider);
      ref.read(adventurerProvider.notifier).loadFromRepository(repository);
    } catch (e) {
      debugPrint('⚠️ 冒険者ステータスの再取得失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ツンドクエスト',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return _AppStartupInitializer(child: child!);
      },
    );
  }
}

/// アプリ起動時に Supabase から冒険者ステータスを読み込む初期化ウィジェット
class _AppStartupInitializer extends ConsumerStatefulWidget {
  final Widget child;
  const _AppStartupInitializer({required this.child});

  @override
  _AppStartupInitializerState createState() => _AppStartupInitializerState();
}

class _AppStartupInitializerState
    extends ConsumerState<_AppStartupInitializer> {
  @override
  void initState() {
    super.initState();
    // 初回フレーム描画後に初期化処理を実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdventurerStatus();
      _checkTutorial();
    });
  }

  /// Supabase から冒険者ステータスを読み込む
  void _loadAdventurerStatus() {
    try {
      final repository = ref.read(adventurerRepositoryProvider);
      ref.read(adventurerProvider.notifier).loadFromRepository(repository);
    } catch (e) {
      debugPrint('⚠️ 冒険者ステータスの初期ロード失敗: $e');
    }
  }

  /// 初回起動時にチュートリアル画面を表示
  Future<void> _checkTutorial() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final tutorialPrefs = TutorialPreferences(prefs);
      if (!mounted) return;
      if (tutorialPrefs.isFirstLaunch) {
        GoRouter.of(context).push('/tutorial');
      }
    } catch (e) {
      debugPrint('⚠️ チュートリアル判定失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // オフラインバナーを画面上部に表示
    final isOnline = ref.watch(isOnlineProvider);
    return Column(
      children: [
        if (!isOnline)
          MaterialBanner(
            content: const Row(
              children: [
                Text('⚠️', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'オフラインモード — 一部機能が制限されます',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade900,
            actions: const [SizedBox.shrink()],
            forceActionsBelow: true,
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
