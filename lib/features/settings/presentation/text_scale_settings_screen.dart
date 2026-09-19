import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/settings/data/text_scale_provider.dart';
import 'package:tsundoku_quest/features/settings/domain/text_scale_setting.dart';

/// 文字サイズ設定画面 — 3段階（小／通常／大）の選択と永続化
class TextScaleSettingsScreen extends ConsumerWidget {
  const TextScaleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = TextScaleSetting.normalized(ref.watch(textScaleProvider));
    final notifier = ref.read(textScaleProvider.notifier);

    return Scaffold(
      key: AppKeys.textScaleSettingsScreen,
      appBar: AppBar(title: const Text('文字サイズ設定')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('アプリ全体の文字サイズを選択できます。選択したサイズはすぐに反映され、次回起動時も保持されます。'),
          ),
          // 現在の倍率での見本表示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('見本: 積読 12冊',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    const Text('これは本文の表示サンプルです。'),
                  ],
                ),
              ),
            ),
          ),
          for (final preset in TextScaleSetting.presets)
            KeyedSubtree(
              key: AppKeys.textScaleOption(preset.scale),
              child: RadioListTile<double>(
                key: Key('text_scale_${preset.scale}'),
                title: Text(preset.label),
                value: preset.scale,
                groupValue: current,
                onChanged: (value) {
                  if (value == null) return;
                  notifier.setScale(value);
                },
              ),
            ),
        ],
      ),
    );
  }
}
