import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/infrastructure/supabase/supabase_client_provider.dart';
import '../../../domain/repositories/reading_session_repository.dart';
import 'supabase_reading_session_repository.dart';

/// ReadingSessionRepository の Riverpod Provider
/// SupabaseClient を注入して SupabaseReadingSessionRepository を生成する
final readingSessionRepositoryProvider =
    Provider<ReadingSessionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseReadingSessionRepository(client);
});
