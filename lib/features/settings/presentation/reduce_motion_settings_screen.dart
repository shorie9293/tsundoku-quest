import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/settings/data/reduce_motion_provider.dart';
import 'package:tsundoku_quest/features/settings/data/reduce_motion_repository.dart';
import 'package:tsundoku_quest/features/settings/domain/reduce_motion_setting.dart';

/// 動きを減らす設定画面 — システムに従う/動きを有効/動きを減らす の選択
///
/// [repository] を注入すると Provider 無しでも動作する（試練用）。
/// 未注入時は [reduceMotionProvider] を介して保存する。
class ReduceMotionSettingsScreen extends StatelessWidget {
  const ReduceMotionSettingsScreen({super.key, this.repository});

  /// 試練用の任意注入リポジトリ。null の場合は Provider 経由で動作する。
  final ReduceMotionRepository? repository;

  @override
  Widget build(BuildContext context) {
    final injected = repository;
    if (injected == null) return const _ProviderReduceMotionScreen();
    return _InjectedReduceMotionScreen(repository: injected);
  }
}

/// Provider 経由の画面
class _ProviderReduceMotionScreen extends ConsumerWidget {
  const _ProviderReduceMotionScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(reduceMotionProvider);
    final notifier = ref.read(reduceMotionProvider.notifier);
    return _ReduceMotionScaffold(
      current: current,
      onChanged: notifier.setSetting,
    );
  }
}

/// 注入リポジトリ経由の画面（Provider 不要）
class _InjectedReduceMotionScreen extends StatefulWidget {
  const _InjectedReduceMotionScreen({required this.repository});

  final ReduceMotionRepository repository;

  @override
  State<_InjectedReduceMotionScreen> createState() =>
      _InjectedReduceMotionScreenState();
}

class _InjectedReduceMotionScreenState
    extends State<_InjectedReduceMotionScreen> {
  ReduceMotionSetting _current = ReduceMotionSetting.system;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await widget.repository.loadReduceMotion();
    if (!mounted) return;
    setState(() => _current = saved ?? ReduceMotionSetting.system);
  }

  Future<void> _select(ReduceMotionSetting setting) async {
    await widget.repository.saveReduceMotion(setting);
    if (!mounted) return;
    setState(() => _current = setting);
  }

  @override
  Widget build(BuildContext context) {
    return _ReduceMotionScaffold(
      current: _current,
      onChanged: _select,
    );
  }
}

/// 画面本体（選択肢＋説明カード）
class _ReduceMotionScaffold extends StatelessWidget {
  const _ReduceMotionScaffold({
    required this.current,
    required this.onChanged,
  });

  final ReduceMotionSetting current;
  final ValueChanged<ReduceMotionSetting> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: AppKeys.reduceMotionScreen,
      appBar: AppBar(title: const Text('動きを減らす設定')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'アニメーションや画面遷移の動きを抑えられます。'
              '「システムに従う」を選ぶと端末の設定に従います。'
              '「動きを有効」は端末設定より優先して動きを有効にします。',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Card(
            key: AppKeys.reduceMotionNote,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.accessibility_new_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '動きに敏感な方のための設定です（WCAG 2.3.3 アニメーションからの相互作用への配慮）。'
                      '「動きを減らす」を選ぶと、画面遷移や演出のアニメーションを短く・控えめにします。',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          RadioGroup<ReduceMotionSetting>(
            groupValue: current,
            onChanged: (value) {
              if (value == null) return;
              onChanged(value);
            },
            child: Column(
              children: [
                for (final setting in ReduceMotionSetting.values)
                  RadioListTile<ReduceMotionSetting>(
                    key: ValueKey('reduce_motion_option_${setting.storageKey}'),
                    secondary: Icon(setting.icon),
                    title: Text(setting.label),
                    value: setting,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
