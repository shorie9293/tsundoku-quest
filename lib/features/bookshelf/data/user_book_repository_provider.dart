import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/infrastructure/supabase/supabase_client_provider.dart';
import '../../../domain/repositories/user_book_repository.dart';
import 'supabase_user_book_repository.dart';

/// UserBookRepository の Riverpod Provider
/// Supabase をプライマリデータストアとして使用する
final userBookRepositoryProvider = Provider<UserBookRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseUserBookRepository(client);
});
