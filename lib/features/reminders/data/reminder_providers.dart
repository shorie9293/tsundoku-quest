/// リマインダー機能の Riverpod providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/shared/providers/derived_provider.dart';
import '../domain/reading_reminder_scheduler.dart';
import 'flutter_local_reminder_service.dart';
import 'hive_reminder_settings_repository.dart';
import 'local_notification_scheduler.dart';
import 'reminder_settings_repository.dart';

/// ローカル通知スケジューラ（テストでは Fake に置換）
final localNotificationSchedulerProvider =
    Provider<LocalNotificationScheduler>((ref) {
  return FlutterLocalReminderService(FlutterLocalNotificationsPlugin());
});

/// リマインダー統括サービス
final readingReminderSchedulerProvider =
    Provider<ReadingReminderScheduler>((ref) {
  return ReadingReminderScheduler(ref.watch(localNotificationSchedulerProvider));
});

/// Hive 永続化リポジトリ
final hiveReminderSettingsRepositoryProvider =
    Provider<ReminderSettingsRepository>((ref) {
  final boxManager = ref.watch(hiveBoxManagerProvider);
  return HiveReminderSettingsRepository(boxManager);
});

/// リマインダー設定を管理する StateNotifier
///
/// 設定変更時はリポジトリに永続化し、通知スケジューラを再適用する。
class ReminderSettingsNotifier extends StateNotifier<ReadingReminderSettings> {
  final ReminderSettingsRepository _repository;
  final ReadingReminderScheduler _scheduler;
  final Ref _ref;

  ReminderSettingsNotifier(this._repository, this._scheduler, this._ref)
      : super(const ReadingReminderSettings());

  /// 保存済み設定を読み込み、通知を再スケジュールする
  Future<void> load() async {
    state = await _repository.load();
    await _reschedule();
  }

  /// 有効/無効を切替
  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _persist();
  }

  /// 通知時刻を設定
  Future<void> setTime({required int hour, required int minute}) async {
    state = state.copyWith(hour: hour, minute: minute);
    await _persist();
  }

  /// 対象読書状態を設定
  Future<void> setTargetStatus(BookStatus status) async {
    state = state.copyWith(targetStatus: status);
    await _persist();
  }

  Future<void> _persist() async {
    await _repository.save(state);
    await _reschedule();
  }

  Future<void> _reschedule() async {
    final count = _ref.read(userBooksByStatusProvider(state.targetStatus)).length;
    await _scheduler.applySettings(settings: state, tsundokuCount: count);
  }
}

final reminderSettingsProvider =
    StateNotifierProvider<ReminderSettingsNotifier, ReadingReminderSettings>(
        (ref) {
  final repository = ref.watch(hiveReminderSettingsRepositoryProvider);
  final scheduler = ref.watch(readingReminderSchedulerProvider);
  return ReminderSettingsNotifier(repository, scheduler, ref);
});
