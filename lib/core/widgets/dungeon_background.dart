import 'package:flutter/material.dart';

/// ダンジョンのような暗く神秘的な背景Widget
///
/// 全画面の背景として使用し、暗い和風幻想の雰囲気を演出する。
/// Stackで構成され、最背面にグラデーション背景を配置する。
///
/// 使用例:
/// ```dart
/// Scaffold(
///   body: DungeonBackground(
///     child: Center(child: Text('本棚の中身')),
///   ),
/// )
/// ```
class DungeonBackground extends StatelessWidget {
  /// 背景の上に表示する子Widget
  final Widget? child;

  const DungeonBackground({super.key, this.child});

  // ━━━ 背景色 ━━━
  // 深いダンジョンの石壁の色調（半透明で画像を透過）
  static const Color _deepStone = Color(0xCC0A080C);
  static const Color _midStone = Color(0xCC141013);
  static const Color _warmStone = Color(0xCC1A1514);

  // 灯りの色
  static const Color _torchGlow = Color(0x1AF59E0B); // amberの微量
  static const Color _mysticPurple = Color(0x0D7C3AED); // dungeon紫の微量

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ━━━ Layer 0: ダンジョン背景画像 ━━━
        // ComfyUI SD 1.5 で生成した和風ダンジョン背景
        Image.asset(
          'assets/images/dungeon_bg.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
        // ━━━ Layer 0.5: 暗色オーバーレイ（白文字の可読性確保）━━━
        Container(color: Colors.black.withValues(alpha: 0.10)),
        // ━━━ Layer 1: ベースグラデーション ━━━
        // 上から下へ：深い暗黒 → やや温かみのある石灰色
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _deepStone,   // 0%: 深い暗黒
                _midStone,    // 35%: 中間の石色
                _warmStone,   // 100%: やや暖色がかった石色
              ],
              stops: [0.0, 0.35, 1.0],
            ),
          ),
        ),

        // ━━━ Layer 2: 松明の灯り ━━━
        // 上部中央から放射状の暖かい光
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.7), // 画面上部から
              radius: 1.2,
              colors: [
                _torchGlow,       // 中心：暖色の灯り
                Colors.transparent,  // 周辺：透明
              ],
              stops: [0.0, 1.0],
            ),
          ),
        ),

        // ━━━ Layer 3: 神秘的な紫の灯り ━━━
        // 右下からの淡い紫色の空気感
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.6, 0.5),
              radius: 1.0,
              colors: [
                _mysticPurple,
                Colors.transparent,
              ],
              stops: [0.0, 1.0],
            ),
          ),
        ),

        // ━━━ 子Widget（最前面） ━━━
        if (child != null) child!,
      ],
    );
  }
}
