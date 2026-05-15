import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/supabase/supabase_client_provider.dart';
import 'package:tsundoku_quest/domain/repositories/auth_repository.dart';
import 'package:tsundoku_quest/features/shared/data/supabase_auth_repository.dart';

/// AuthRepositoryを提供するRiverpodプロバイダー
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
});
