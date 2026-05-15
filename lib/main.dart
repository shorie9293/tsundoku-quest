import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/infrastructure/supabase/supabase_config.dart';
import 'app_router.dart';
import 'features/shared/data/adventurer_repository_provider.dart';
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

  debugPrint('🚀 runApp 開始...');
  runApp(
    const ProviderScope(
      child: TsundokuQuestApp(),
    ),
  );
  debugPrint('🏁 runApp 完了');
}

class TsundokuQuestApp extends StatelessWidget {
  const TsundokuQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ツンドクエスト',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      builder: (context, child) => _AppStartupInitializer(child: child!),
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
    // 初回フレーム描画後に Supabase からステータスをロード
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final repository = ref.read(adventurerRepositoryProvider);
        ref.read(adventurerProvider.notifier).loadFromRepository(repository);
      } catch (e) {
        debugPrint('⚠️ 冒険者ステータスの初期ロード失敗: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
