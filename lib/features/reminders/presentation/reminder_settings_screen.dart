import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import '../data/quiet_hours_repository.dart';
import '../data/reminder_providers.dart';
import 'quiet_hours_settings_screen.dart';

/// 読書リマインダー設定画面
///
/// 毎日の通知時刻と有効/無効トグル、対象読書状態を設定する。
///
/// 静穏時間（おやすみモード）への導線は **リポジトリまたは画面ビルダーが
/// 注入されたときだけ** 表示する（未注入の既存呼び出し・既存試練を無破壊に保つ）。
class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({
    super.key,
    this.quietHoursRepository,
    this.quietHoursScreenBuilder,
  });

  /// 静穏時間設定のリポジトリ（注入時のみ導線を出す）。
  final QuietHoursRepository? quietHoursRepository;

  /// 静穏時間画面のビルダー（試練での差し替え用）。
  final WidgetBuilder? quietHoursScreenBuilder;

  @override
  ConsumerState<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState
    extends ConsumerState<ReminderSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 保存済み設定を読み込み、通知を再スケジュールする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reminderSettingsProvider.notifier).load();
    });
  }

  Future<void> _pickTime(int currentHour, int currentMinute) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
    );
    if (picked != null) {
      await ref
          .read(reminderSettingsProvider.notifier)
          .setTime(hour: picked.hour, minute: picked.minute);
    }
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _statusLabel(BookStatus status) {
    return switch (status) {
      BookStatus.tsundoku => '積読',
      BookStatus.reading => '読書中',
      BookStatus.completed => '読了',
    };
  }

  /// 静穏時間画面への導線を出すか（未注入なら出さない）。
  bool get _showQuietHoursEntry =>
      widget.quietHoursScreenBuilder != null ||
      widget.quietHoursRepository != null;

  void _openQuietHoursSettings() {
    final builder = widget.quietHoursScreenBuilder;
    final repository = widget.quietHoursRepository;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => builder != null
            ? builder(context)
            : QuietHoursSettingsScreen(repository: repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(reminderSettingsProvider);
    return Scaffold(
      key: AppKeys.reminderSettingsScreen,
      appBar: AppBar(title: const Text('読書リマインダー')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('毎日のリマインダー'),
            subtitle: const Text('積読が残っているときに通知します'),
            trailing: Switch(
              key: AppKeys.reminderEnabledSwitch,
              value: settings.enabled,
              onChanged: (v) =>
                  ref.read(reminderSettingsProvider.notifier).setEnabled(v),
            ),
            onTap: () => ref
                .read(reminderSettingsProvider.notifier)
                .setEnabled(!settings.enabled),
          ),
          const Divider(),
          ListTile(
            key: AppKeys.reminderTimeTile,
            leading: const Icon(Icons.schedule),
            title: const Text('通知時刻'),
            trailing: Text(
              _formatTime(settings.hour, settings.minute),
              key: AppKeys.reminderTimeText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onTap: () => _pickTime(settings.hour, settings.minute),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.bookmark),
                const SizedBox(width: 16),
                const Expanded(child: Text('対象読書状態')),
                DropdownButton<BookStatus>(
                  value: settings.targetStatus,
                  items: BookStatus.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(_statusLabel(s)),
                          ))
                      .toList(),
                  onChanged: (s) {
                    if (s != null) {
                      ref
                          .read(reminderSettingsProvider.notifier)
                          .setTargetStatus(s);
                    }
                  },
                ),
              ],
            ),
          ),
          if (_showQuietHoursEntry) ...[
            const Divider(),
            ListTile(
              key: AppKeys.quietHoursEntry,
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('静穏時間（おやすみモード）'),
              subtitle: const Text('指定した時間帯の通知を抑止します'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openQuietHoursSettings,
            ),
          ],
        ],
      ),
    );
  }
}
