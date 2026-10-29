import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/about/presentation/about_screen.dart';
import 'package:tsundoku_quest/features/backup/presentation/backup_screen.dart';
import 'package:tsundoku_quest/features/reminders/data/reminder_providers.dart';
import 'package:tsundoku_quest/features/reminders/presentation/quiet_hours_settings_screen.dart';
import 'package:tsundoku_quest/features/reminders/data/notification_permission_requester.dart';
import 'package:tsundoku_quest/features/reminders/presentation/reminder_settings_screen.dart';
import 'package:tsundoku_quest/features/settings/presentation/app_lock_settings_screen.dart';
import 'package:tsundoku_quest/features/settings/presentation/reduce_motion_settings_screen.dart';
import 'package:tsundoku_quest/features/settings/presentation/text_scale_settings_screen.dart';
import 'package:tsundoku_quest/features/settings/presentation/theme_mode_settings_screen.dart';

/// 設定ハブ画面 — 散在する設定画面への導線を1画面に集約する。
///
/// 各遷移先は [WidgetBuilder] として注入できる（未指定なら実画面）。
/// 試練ではフェイクビルダーを差し込んで遷移だけを検証する。
///
/// 既存の go_router ルート（/settings/... 等）はそのまま残し、
/// この画面は「一覧から選ぶ」導線を追加するだけに留める。
class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({
    super.key,
    this.themeModeBuilder = buildThemeModeSettings,
    this.textScaleBuilder = buildTextScaleSettings,
    this.reduceMotionBuilder = buildReduceMotionSettings,
    this.appLockBuilder = buildAppLockSettings,
    this.reminderBuilder = buildReminderSettings,
    this.quietHoursBuilder = buildQuietHoursSettings,
    this.backupBuilder = buildBackupSettings,
    this.aboutBuilder = buildAboutSettings,
  });

  final WidgetBuilder themeModeBuilder;
  final WidgetBuilder textScaleBuilder;
  final WidgetBuilder reduceMotionBuilder;
  final WidgetBuilder appLockBuilder;
  final WidgetBuilder reminderBuilder;
  final WidgetBuilder quietHoursBuilder;
  final WidgetBuilder backupBuilder;
  final WidgetBuilder aboutBuilder;

  /// 一覧の定義（並び順がそのまま表示順）。
  List<_SettingsHubItem> get _items => [
        _SettingsHubItem(
          id: 'theme_mode',
          icon: Icons.brightness_6_outlined,
          label: 'テーマ設定',
          builder: themeModeBuilder,
        ),
        _SettingsHubItem(
          id: 'text_scale',
          icon: Icons.format_size,
          label: '文字サイズ',
          builder: textScaleBuilder,
        ),
        _SettingsHubItem(
          id: 'reduce_motion',
          icon: Icons.motion_photos_off_outlined,
          label: '動きを減らす',
          builder: reduceMotionBuilder,
        ),
        _SettingsHubItem(
          id: 'app_lock',
          icon: Icons.lock_outline,
          label: 'アプリロック',
          builder: appLockBuilder,
        ),
        _SettingsHubItem(
          id: 'reminder',
          icon: Icons.notifications_active_outlined,
          label: '読書リマインダー',
          builder: reminderBuilder,
        ),
        _SettingsHubItem(
          id: 'quiet_hours',
          icon: Icons.bedtime_outlined,
          label: '静穏時間（おやすみモード）',
          builder: quietHoursBuilder,
        ),
        _SettingsHubItem(
          id: 'backup',
          icon: Icons.cloud_upload_outlined,
          label: 'バックアップ',
          builder: backupBuilder,
        ),
        _SettingsHubItem(
          id: 'about',
          icon: Icons.info_outline,
          label: 'アプリについて',
          builder: aboutBuilder,
        ),
      ];

  void _open(BuildContext context, _SettingsHubItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: item.builder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.settingsHubScreen,
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          for (final item in _items)
            SemanticHelper.interactive(
              testId: 'item_settings_hub_${item.id}',
              label: item.label,
              child: ListTile(
                key: AppKeys.settingsHubItem(item.id),
                leading: Icon(item.icon),
                title: Text(item.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(context, item),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsHubItem {
  const _SettingsHubItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.builder,
  });

  final String id;
  final IconData icon;
  final String label;
  final WidgetBuilder builder;
}

/// 既定の遷移先ビルダー群（試練では注入で差し替える）。
Widget buildThemeModeSettings(BuildContext context) =>
    const ThemeModeSettingsScreen();

Widget buildTextScaleSettings(BuildContext context) =>
    const TextScaleSettingsScreen();

Widget buildReduceMotionSettings(BuildContext context) =>
    const ReduceMotionSettingsScreen();

Widget buildAppLockSettings(BuildContext context) =>
    const AppLockSettingsScreen();

/// リマインダー画面は静穏時間リポジトリの注入時のみ静穏時間への導線を出す。
/// app_router.dart の `/reminder-settings` と同じ結線を踏襲する。
Widget buildReminderSettings(BuildContext context) => Consumer(
      builder: (context, ref, _) => ReminderSettingsScreen(
        quietHoursRepository: ref.watch(quietHoursRepositoryProvider),
        // 通知権限の要求（Android 13+ は要求しないと通知が出ない）。
        permissionRequester: PlatformNotificationPermissionRequester(),
      ),
    );

Widget buildQuietHoursSettings(BuildContext context) => Consumer(
      builder: (context, ref, _) => QuietHoursSettingsScreen(
        repository: ref.watch(quietHoursRepositoryProvider),
      ),
    );

Widget buildBackupSettings(BuildContext context) => const BackupScreen();

Widget buildAboutSettings(BuildContext context) => const AboutScreen();
