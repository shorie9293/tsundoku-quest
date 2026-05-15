import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/infrastructure/supabase/supabase_client_provider.dart';
import '../../../domain/repositories/war_trophy_repository.dart';
import 'supabase_war_trophy_repository.dart';

/// WarTrophyRepository の Riverpod Provider
/// SupabaseClient を注入して SupabaseWarTrophyRepository を生成する
final warTrophyRepositoryProvider = Provider<WarTrophyRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseWarTrophyRepository(client);
});
