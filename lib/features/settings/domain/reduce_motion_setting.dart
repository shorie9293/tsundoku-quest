import 'package:flutter/material.dart';

/// 動きを減らす設定（Reduce Motion）
///
/// 端末の「アニメーションを減らす」設定に対する、アプリ内の明示的な
/// 上書き設定。SharedPreferences には [storageKey] を文字列で保存する。
/// 未保存・不正値は [ReduceMotionSetting.system]（＝端末設定に従う）とする。
enum ReduceMotionSetting {
  system('system', 'システムに従う', Icons.brightness_auto_outlined),
  off('off', '動きを有効', Icons.animation),
  on('on', '動きを減らす', Icons.motion_photos_off_outlined);

  const ReduceMotionSetting(this.storageKey, this.label, this.icon);

  /// 保存用キー（'system' / 'off' / 'on'）
  final String storageKey;

  /// UI表示用ラベル
  final String label;

  /// UI表示用アイコン
  final IconData icon;

  /// 保存キーに対応する設定。
  /// 'system'/'off'/'on' 以外および null は [ReduceMotionSetting.system]。
  static ReduceMotionSetting fromStorageKey(String? key) {
    for (final setting in values) {
      if (setting.storageKey == key) return setting;
    }
    return system;
  }

  /// 巡回: system→off→on→system
  ReduceMotionSetting get next => switch (this) {
        ReduceMotionSetting.system => ReduceMotionSetting.off,
        ReduceMotionSetting.off => ReduceMotionSetting.on,
        ReduceMotionSetting.on => ReduceMotionSetting.system,
      };

  /// アニメーション抑制の強制値。
  ///
  /// - [ReduceMotionSetting.on] → true（動きを減らす）
  /// - [ReduceMotionSetting.off] → false（利用者が明示的に動きを有効化し、
  ///   端末設定より優先する）
  /// - [ReduceMotionSetting.system] → null（端末設定に従う）
  bool? get forceDisableAnimations => switch (this) {
        ReduceMotionSetting.system => null,
        ReduceMotionSetting.off => false,
        ReduceMotionSetting.on => true,
      };
}

/// [MediaQueryData] に設定を適用する。
///
/// [ReduceMotionSetting.forceDisableAnimations] が null（system）の場合は
/// 受け取った [data] をそのまま返し、端末設定を尊重する。強制値がある場合のみ
/// [MediaQueryData.disableAnimations] を上書きしたコピーを返す。
MediaQueryData applyReduceMotion(
  MediaQueryData data,
  ReduceMotionSetting setting,
) {
  final forced = setting.forceDisableAnimations;
  if (forced == null) return data;
  return data.copyWith(disableAnimations: forced);
}
