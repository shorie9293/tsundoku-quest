import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/settings/data/theme_mode_provider.dart';
import 'package:tsundoku_quest/features/settings/domain/theme_mode_setting.dart';

/// テーマ設定画面 — ライト/ダーク/システムの選択と永続化
class ThemeModeSettingsScreen extends ConsumerWidget {
  const ThemeModeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      key: AppKeys.themeModeScreen,
      appBar: AppBar(title: const Text('テーマ設定')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'アプリのテーマを選択できます。「システム」を選ぶと端末の設定に従います。選択したテーマはすぐに反映され、次回起動時も保持されます。',
            ),
          ),
          for (final mode in ThemeModeSetting.values)
            KeyedSubtree(
              key: AppKeys.themeModeOption(mode.storageKey),
              child: RadioListTile<ThemeModeSetting>(
                key: Key('theme_mode_${mode.storageKey}'),
                secondary: Icon(mode.icon),
                title: Text(mode.label),
                value: mode,
                groupValue: current,
                onChanged: (value) {
                  if (value == null) return;
                  notifier.setMode(value);
                },
              ),
            ),
        ],
      ),
    );
  }
}
