import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/infrastructure/supabase/supabase_client_provider.dart';
import '../../../domain/repositories/user_book_repository.dart';
import 'supabase_user_book_repository.dart';

/// UserBookRepository の Riverpod Provider
/// SupabaseClient を注入して SupabaseUserBookRepository を生成する
final userBookRepositoryProvider = Provider<UserBookRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseUserBookRepository(client);
});
