import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/repositories/adventurer_repository.dart';
import '../../bookshelf/data/supabase_adventurer_repository.dart';
import '../../reading/data/reading_session_repository_provider.dart';
import '../../bookshelf/data/user_book_repository_provider.dart';

/// AdventurerRepository の Riverpod Provider
final adventurerRepositoryProvider = Provider<AdventurerRepository>((ref) {
  final sessionRepo = ref.watch(readingSessionRepositoryProvider);
  final userBookRepo = ref.watch(userBookRepositoryProvider);
  return SupabaseAdventurerRepository(sessionRepo, userBookRepo);
});
