/// Riverpod provider for HiveBoxManager
///
/// Provides a singleton BoxManagerInterface for Hive operations.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';

/// HiveBoxManager の Riverpod Provider
final hiveBoxManagerProvider = Provider<BoxManagerInterface>((ref) {
  return HiveBoxManager();
});
