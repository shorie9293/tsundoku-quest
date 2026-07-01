import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/infrastructure/hive/box_manager_provider.dart';
import '../../../domain/repositories/war_trophy_repository.dart';
import 'hive_war_trophy_repository.dart';

/// WarTrophyRepository の Riverpod Provider
/// Hive をプライマリデータストアとして使用する（Offline-First）
final warTrophyRepositoryProvider = Provider<WarTrophyRepository>((ref) {
  final boxManager = ref.watch(hiveBoxManagerProvider);
  return HiveWarTrophyRepository(boxManager);
});
