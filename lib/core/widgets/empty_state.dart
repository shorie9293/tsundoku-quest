import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

import '../theme/app_theme.dart';

/// 空状態の「意味」だけを持つ純粋データ。
///
/// 文言は画面側が注入する（部品に文言を埋めない）。不変条件は
/// assert ではなく**非const コンストラクタ本体**で検証する
/// （release ビルドでも壊れた空状態を描画させないため）。
class EmptyStateSpec {
  /// 見出し（必須・空文字不可）。
  final String title;

  /// 補足説明。null なら描画しない。
  final String? description;

  /// 行動ボタンのラベル。[onAction] と同時に指定する。
  final String? actionLabel;

  /// 行動ボタンの処理。[actionLabel] と同時に指定する。
  final void Function()? onAction;

  EmptyStateSpec({
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', '見出しを空にはできません');
    }
    if ((actionLabel == null) != (onAction == null)) {
      throw ArgumentError(
        'actionLabel と onAction は両方指定するか、両方 null にしてください',
      );
    }
  }
}

/// 空状態の共通表示。
///
/// アイコン（任意）・見出し・説明・行動ボタン（任意）を縦に並べる。
/// [EmptyStateSpec.onAction] が null のときボタンは描画しない。
class EmptyStateView extends StatelessWidget {
  /// 表示内容。
  final EmptyStateSpec spec;

  /// 絵文字アイコン（例: '📚'）。null なら描画しない。
  final String? emoji;

  /// 絵文字のフォントサイズ。
  final double emojiSize;

  /// 行動ボタンの [Key]（試練用）。
  final Key? actionKey;

  /// 行動ボタンの Semantics identifier（試練・読み上げ用）。
  final String actionSemanticId;

  /// 行動ボタンへ添える絵文字（例: '🧭'）。null なら描画しない。
  final String? actionEmoji;

  /// 外側の余白。
  final EdgeInsetsGeometry padding;

  const EmptyStateView({
    required Key key,
    required this.spec,
    this.emoji,
    this.emojiSize = 40,
    this.actionKey,
    this.actionSemanticId = 'btn_empty_state_action',
    this.actionEmoji,
    this.padding = const EdgeInsets.all(32),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final description = spec.description;
    final actionLabel = spec.actionLabel;
    final onAction = spec.onAction;

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: TextStyle(fontSize: emojiSize)),
            const SizedBox(height: 16),
          ],
          Text(
            spec.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            SemanticHelper.interactive(
              testId: actionSemanticId,
              label: actionLabel,
              child: ElevatedButton(
                key: actionKey,
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                ),
                child: actionEmoji == null
                    ? Text(actionLabel)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(actionEmoji!),
                          const SizedBox(width: 8),
                          Text(actionLabel),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
