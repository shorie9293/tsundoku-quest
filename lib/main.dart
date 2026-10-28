import 'dart:ui';
import 'dart:async';
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
import 'core/infrastructure/hive/adapters/reading_reminder_adapter.dart';
import 'core/infrastructure/hive/box_manager.dart';
import 'core/infrastructure/hive/migration_service.dart';
import 'domain/models/user_book.dart';
import 'domain/models/reading_session.dart';
import 'app_router.dart';
import 'features/shared/data/adventurer_repository_provider.dart';
import 'features/reading/data/reading_session_repository_provider.dart';
import 'features/reading/data/fallback_reading_session_repository.dart';
import 'features/tutorial/data/tutorial_preferences.dart';
import 'features/reminders/data/reminder_providers.dart';
import 'features/reminders/presentation/notification_tap_router.dart';
import 'features/settings/data/text_scale_provider.dart';
import 'features/settings/data/theme_mode_provider.dart';
import 'features/settings/data/reduce_motion_provider.dart';
import 'features/settings/domain/reduce_motion_setting.dart';
import 'shared/providers/adventurer_provider.dart';
import 'shared/providers/startup_loader.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:app_links/app_links.dart';
import 'core/infrastructure/deep_link_service.dart';
import 'core/infrastructure/app_lock_gate.dart';
import 'features/shared/data/tsundoku_reward_event_exporter.dart';
import 'features/shared/data/reward_event_user_linker.dart';
import 'features/shared/providers/reward_event_exporter_provider.dart';

/// アプリ完全終了状態から起動した場合の初期ディープリンクを保持
Uri? _pendingInitialDeepLink;

/// 全画面をアプリロックゲートで包む builder（試練からも撃てるよう公開）。
Widget buildWithAppLockGate(BuildContext context, Widget? child) {
  return AppLockGate(
    unlockedBuilder: (_) => child ?? const SizedBox.shrink(),
  );
}

/// クロスアプリ報酬イベント書き出しの起動時配線。
///
/// 単一の [TsundokuRewardEventExporter] を生成した main() から呼ばれる。
/// rpg-task（Kozuchi）は JSONL の各行を `user_id` 必須で解釈するため、
/// 書き出し前に認証状態を購読して userId を追随させる必要がある。
///
/// - [userIdChanges] 指定時はそれを購読（試練用の注入点）。
/// - [authStates] 指定時は Supabase の AuthState を購読。
/// - どちらも未指定なら Supabase の現在セッションと認証状態ストリームを使う。
///
/// Supabase 未初期化（テスト環境・オフライン）では**静かに何もしない**。
/// 例外は投げない（アプリ起動を妨げない）。既存の try/catch 流儀に倣う。
void wireRewardEventExporter({
  required TsundokuRewardEventExporter exporter,
  Stream<AuthState>? authStates,
  Stream<String?>? userIdChanges,
}) {
  try {
    if (userIdChanges != null) {
      RewardEventUserLinker(exporter: exporter).bind(userIdChanges);
      return;
    }
    if (authStates != null) {
      RewardEventUserLinker(exporter: exporter).bindSupabaseAuthStates(authStates);
      return;
    }
    // Supabase 未初期化時は tryCreateForSupabase が内部で握りつぶして null を返す
    RewardEventUserLinker.tryCreateForSupabase(exporter);
  } catch (e) {
    debugPrint('⚠️ 報酬イベント書き出しの配線失敗（アプリは継続）: $e');
  }
}

Future<void> main() async {
  debugPrint('🔵 main() 開始');
  WidgetsFlutterBinding.ensureInitialized();

  // ━━━ Firebase 運用監視基盤（Crashlytics クラッシュ検知 + Analytics KPI計測）━━━
  try {
    await Firebase.initializeApp();
    // Analytics: セッション開始を記録し DAU/定着率のKPI計測を有効化
    unawaited(FirebaseAnalytics.instance.logAppOpen());
    debugPrint('✅ Firebase 初期化完了');
  } catch (e) {
    // テスト環境や Firebase 未設定時はアプリ起動を妨げず継続する
    debugPrint('⚠️ Firebase初期化失敗（アプリは継続）: $e');
  }

  const supabaseUrl = SupabaseConfig.url;
  const supabaseKey = SupabaseConfig.anonKey;

  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
      debugPrint('✅ Supabase 初期化完了');
      // 認証は Google ネイティブ認証（google_sign_in 7.x）に一本化。
      // 未ログイン時は GoRouter redirect が /login へ導くため、
      // ここでの匿名サインインは行わない（匿名認証廃止）。
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
    // クラッシュ検知: 致命的エラーを Crashlytics へ送信（未初期化時はスキップ）
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (e) {
      // Firebase 未初期化（テスト環境等）はスキップ
    }
    FlutterError.presentError(details);
  };

  // ③ ゾーン外の非同期エラー（Platformレベル）
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('💀 捕捉不能エラー: $error\n$stack');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // Firebase 未初期化（テスト環境等）はスキップ
    }
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
        Hive.registerAdapter(ReadingReminderAdapter());
      },
    );
    debugPrint('✅ Hive 初期化完了');
  } catch (e) {
    debugPrint('⚠️ Hive 初期化失敗（オフライン永続化不可）: $e');
  }

  // ── データ移行（初回起動時のみ）──
  await _runHiveMigration();

  debugPrint('🚀 runApp 開始...');
  // ━━━ アプリ間送客用ディープリンク受信基盤 ━━━
  // app://cross-reward?source=<送客元>&reward=<報酬タイプ>
  final appLinks = AppLinks();

  // 完全終了状態からディープリンクで起動した場合の初期リンクを取得
  try {
    _pendingInitialDeepLink = await appLinks.getInitialLink();
  } catch (e) {
    // ignore: avoid_print
    print('[main] Error getting initial deep link: $e');
  }

  // バックグラウンド→フォアグラウンド復帰時のリンクをリッスン
  appLinks.uriLinkStream.listen(_handleDeepLink);

  // ── クロスアプリ報酬イベント書き出し（rpg-task/Kozuchi 連携）──
  // Supabase 初期化の成否に関わらず単一インスタンスを生成し、runApp 前に
  // ProviderScope へ override して全 Notifier に同一インスタンスを配る。
  // Supabase 未初期化時は userId が空のままで書き出しはスキップされる
  // （rpg 側で解釈できない行を作らない）。
  final rewardEventExporter = TsundokuRewardEventExporter();
  // 認証状態を購読して userId を追随させる（Supabase 未初期化なら静かに no-op）
  wireRewardEventExporter(exporter: rewardEventExporter);

  runApp(
    ProviderScope(
      overrides: [
        tsundokuRewardEventExporterProvider
            .overrideWithValue(rewardEventExporter),
      ],
      child: const TsundokuQuestApp(),
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

/// ディープリンクURLを解析し、該当導線に引き渡す。
///
/// 対応URL形式:
///   app://cross-reward?source=<送客元>&reward=<報酬タイプ>
///   app://open                       （送客元アプリからのホーム起動導線）
void _handleDeepLink(Uri uri) {
  // ignore: avoid_print
  print('[main] Deep link received: $uri');

  // 送客元アプリからのホーム起動導線（app://open）。
  // 起動先はホーム（'/'）のため、単に受信を確認してホーム表示へそのまま進む。
  if (DeepLinkService.isAppOpenLink(uri)) {
    debugPrint('[main] Open app from sender (app://open)');
    return;
  }

  final link = DeepLinkService.parse(uri);
  if (link == null) return;

  // 送客元現世と報酬タイプを記録（受信基盤の具現化）。
  // 報酬付与は既存の報酬サービス等が担うため、ここでは受信を確認する。
  debugPrint('[main] Cross reward: source=${link.source}, reward=${link.reward}');
}

class TsundokuQuestApp extends ConsumerStatefulWidget {
  const TsundokuQuestApp({super.key});

  @override
  ConsumerState<TsundokuQuestApp> createState() => _TsundokuQuestAppState();
}

class _TsundokuQuestAppState extends ConsumerState<TsundokuQuestApp> {
  bool _firstFrameHandled = false;

  @override
  void initState() {
    super.initState();
    // 初回フレーム後に保留中のディープリンクを処理
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrame);
    // 保存済みの文字サイズ設定を読み込む（失敗しても起動を妨げない）
    try {
      unawaited(
        ref.read(textScaleProvider.notifier).load().catchError((_) {}),
      );
    } catch (e) {
      debugPrint('⚠️ 文字サイズ設定の読み込み失敗: $e');
    }
    // 保存済みのテーマモード設定を読み込む（失敗しても起動を妨げない）
    try {
      unawaited(
        ref.read(themeModeProvider.notifier).load().catchError((_) {}),
      );
    } catch (e) {
      debugPrint('⚠️ テーマモード設定の読み込み失敗: $e');
    }
    // 保存済みの「動きを減らす」設定を読み込む（失敗しても起動を妨げない）
    try {
      unawaited(
        ref.read(reduceMotionProvider.notifier).load().catchError((_) {}),
      );
    } catch (e) {
      debugPrint('⚠️ 動きを減らす設定の読み込み失敗: $e');
    }
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
        // オフライン中にローカル退避した読書セッションを Supabase へ同期
        try {
          final repo = ref.read(readingSessionRepositoryProvider);
          if (repo is FallbackReadingSessionRepository) {
            repo.syncLocalSessionsToRemote();
          }
        } catch (e) {
          debugPrint('⚠️ 読書セッション同期失敗: $e');
        }
      } else if (next == false) {
        // オフライン検知（ログのみ）
        debugPrint('📡 [App] オフライン状態を検知');
      }
    });
  }

  /// 初回フレーム描画後に保留中のディープリンクを処理する。
  ///
  /// アプリ完全終了状態からディープリンクで起動された場合、
  /// [main()] 内ではまだ Navigator が存在しないため、
  /// 初回フレームまで遅延させる必要がある。
  void _onFirstFrame(Duration _) {
    if (_firstFrameHandled) return;
    _firstFrameHandled = true;

    final pendingLink = _pendingInitialDeepLink;
    _pendingInitialDeepLink = null;
    if (pendingLink != null) {
      _handleDeepLink(pendingLink);
    }
  }

  Future<void> _retryLoadAdventurer() async {
    try {
      final notifier = ref.read(adventurerProvider.notifier);
      // 先にローカルの積み上げを復元してからサーバ統計を重ねる
      await notifier.loadProgress();
      notifier.loadFromRepository(ref.read(adventurerRepositoryProvider));
    } catch (e) {
      debugPrint('⚠️ 冒険者ステータスの再取得失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // アプリ全体の文字スケール（アクセシビリティ設定）
    final textScale = ref.watch(textScaleProvider);
    // アプリ全体のテーマモード（ライト/ダーク/システム）
    final themeMode = ref.watch(themeModeProvider);
    // アプリ全体の「動きを減らす」設定（端末設定の上書き）
    final reduceMotion = ref.watch(reduceMotionProvider);
    return MaterialApp.router(
      title: 'ツンドクエスト',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode.toThemeMode(),
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return MediaQuery(
          data: applyReduceMotion(
            MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            reduceMotion,
          ),
          child: _AppStartupInitializer(
            child: buildWithAppLockGate(context, child),
          ),
        );
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
      _loadStartupData();
      _syncOfflineReadingSessions();
      _checkTutorial();
      _initReminder();
    });
  }

  /// 読書リマインダーを初期化する
  ///
  /// 通知プラグインを初期化し、保存済み設定を読み込んで毎日の通知を
  /// スケジュールする。失敗してもアプリ動作は妨げない。
  /// 通知タップの遷移先（payload）は [NotificationTapRouter] が
  /// go_router へ渡す。起動前タップは保留から1度だけ回収する。
  void _initReminder() {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final service = ref.read(notificationTapServiceProvider);
          final tapRouter = NotificationTapRouter(
            routerGetter: () => AppRouter.router,
          );
          // 稼働中のタップはコールバックへ直送（未知 route は router 側で無視）
          service?.onRouteSelected = tapRouter.onNotificationTap;

          await ref.read(localNotificationSchedulerProvider).initialize();

          // 完全終了状態から通知タップで起動した場合の回収（1度だけ）。
          final pending = service?.consumePendingRoute();
          if (pending != null) tapRouter.handle(pending);

          await ref.read(reminderSettingsProvider.notifier).load();
        } catch (e) {
          debugPrint('⚠️ リマインダー初期化失敗: $e');
        }
      });
    } catch (e) {
      debugPrint('⚠️ リマインダー初期化失敗: $e');
    }
  }

  /// Supabase から冒険者ステータスを読み込む
  ///
  /// 先にローカルへ永続化した積み上げ（レベル・XP・称号・読書日）を復元し、
  /// その後サーバ統計を重ねる（順序を逆にすると再起動で見習いに戻る）。
  Future<void> _loadAdventurerStatus() async {
    try {
      await ref.read(adventurerProvider.notifier).loadProgress();
      final repository = ref.read(adventurerRepositoryProvider);
      ref.read(adventurerProvider.notifier).loadFromRepository(repository);
    } catch (e) {
      debugPrint('⚠️ 冒険者ステータスの初期ロード失敗: $e');
    }
  }

  /// 起動時に戦利品（読書感想）等の表示データをロードする
  Future<void> _loadStartupData() async {
    final container = ProviderScope.containerOf(context, listen: false);
    await loadStartupData(container);
  }

  /// 起動時にオフライン中にローカル退避した読書セッションを同期する。
  /// （接続リスナーは offline→online 遷移しか拾わないため、
  ///  アプリ停止中に溜まった未同期セッションは起動時の同期で回収する）
  Future<void> _syncOfflineReadingSessions() async {
    try {
      final repo = ref.read(readingSessionRepositoryProvider);
      if (repo is FallbackReadingSessionRepository) {
        await repo.syncLocalSessionsToRemote();
      }
    } catch (e) {
      debugPrint('⚠️ 起動時読書セッション同期失敗: $e');
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
