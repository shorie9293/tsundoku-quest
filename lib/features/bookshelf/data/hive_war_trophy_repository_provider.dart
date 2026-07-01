/// Riverpod provider for HiveWarTrophyRepository
///
/// Provides a WarTrophyRepository backed by Hive local persistence.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/repositories/war_trophy_repository.dart';
import 'hive_war_trophy_repository.dart';

/// Hive-based WarTrophyRepository provider
final hiveWarTrophyRepositoryProvider = Provider<WarTrophyRepository>((ref) {
  final boxManager = ref.watch(hiveBoxManagerProvider);
  return HiveWarTrophyRepository(boxManager);
});
