import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/infrastructure/hive/box_manager_provider.dart';
import '../../../core/infrastructure/supabase/supabase_client_provider.dart';
import '../../../domain/repositories/reading_session_repository.dart';
import 'fallback_reading_session_repository.dart';
import 'hive_reading_session_repository.dart';
import 'supabase_reading_session_repository.dart';

/// ReadingSessionRepository の Riverpod Provider
///
/// Supabase をプライマリ、Hive をフォールバックとして使用する。
/// オフライン等で Supabase への書き込みに失敗した場合、セッションは
/// Hive に退避され、オンライン復帰時に syncLocalSessionsToRemote() で
/// 同期される。これによりオフライン中の読書時間が消失しなくなる。
final readingSessionRepositoryProvider =
    Provider<ReadingSessionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final boxManager = ref.watch(hiveBoxManagerProvider);
  return FallbackReadingSessionRepository(
    primary: SupabaseReadingSessionRepository(client),
    local: HiveReadingSessionRepository(boxManager),
    boxManager: boxManager,
  );
});
