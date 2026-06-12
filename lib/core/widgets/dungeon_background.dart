import 'package:flutter/material.dart';

/// ダンジョンのような暗く神秘的な背景Widget
///
/// 全画面の背景として使用し、暗い和風幻想の雰囲気を演出する。
/// Stackで構成され、最背面にグラデーション背景を配置する。
///
/// 使用例:
// ```dart
// Scaffold(
//   body: DungeonBackground(
//     child: Center(child: Text('本棚の中身')),
//   ),
// )
// ```
enum ScreenType { bookshelf, explore, history, recommendation, reading, auth }

class DungeonBackground extends StatelessWidget {
  /// 背景の上に表示する子Widget
  final Widget? child;

  /// 画面タイプに応じた背景を切り替える
  final ScreenType screenType;

  const DungeonBackground({
    super.key,
    this.child,
    this.screenType = ScreenType.bookshelf,
  });

  // ━━━ 背景色 ━━━
  // 深いダンジョンの石壁の色調（半透明で画像を透過）
  static const Color _deepStone = Color(0xCC0A080C);
  static const Color _midStone = Color(0xCC141013);
  static const Color _warmStone = Color(0xCC1A1514);

  // 灯りの色
  static const Color _torchGlow = Color(0x1AF59E0B); // amberの微量
  static const Color _mysticPurple = Color(0x0D7C3AED); // dungeon紫の微量

  // 画面タイプごとのグラデーション色
  List<Color> _getGradientColors() {
    switch (screenType) {
      case ScreenType.bookshelf:
        return [_deepStone, _midStone, _warmStone];
      case ScreenType.explore:
        // 探索画面：やや緑がかった石壁
        return [
          const Color(0xCC0A0C08), // 深い暗黒（緑み）
          const Color(0xCC141310), // 中間の石色（緑み）
          const Color(0xCC1A1A14), // やや暖色がかった石色（緑み）
        ];
      case ScreenType.history:
        // 足跡画面：セピアトーンの石壁
        return [
          const Color(0xCC0A080A), // 深い暗黒（セピア）
          const Color(0xCC141210), // 中間の石色（セピア）
          const Color(0xCC1A1814), // やや暖色がかった石色（セピア）
        ];
      case ScreenType.recommendation:
        // おすすめ画面：紫がかった石壁
        return [
          const Color(0xCC0A080C), // 深い暗黒（紫み）
          const Color(0xCC14101A), // 中間の石色（紫み）
          const Color(0xCC1A151E), // やや暖色がかった石色（紫み）
        ];
      case ScreenType.reading:
        // 読書中画面：青みがかった石壁
        return [
          const Color(0xCC080A0C), // 深い暗黒（青み）
          const Color(0xCC12141A), // 中間の石色（青み）
          const Color(0xCC1A1A1E), // やや暖色がかった石色（青み）
        ];
      case ScreenType.auth:
        // 認証画面：赤みがかった石壁
        return [
          const Color(0xCC0C080A), // 深い暗黒（赤み）
          const Color(0xCC1A1010), // 中間の石色（赤み）
          const Color(0xCC1E1514), // やや暖色がかった石色（赤み）
        ];
    }
  }

  // 画面タイプごとの背景画像カラーフィルター
  // ColorFiltered + BlendMode.srcATop で既存画像に色味の上塗りを適用
  ColorFilter _getColorFilter() {
    switch (screenType) {
      case ScreenType.bookshelf:
        // 暖色セピア
        return const ColorFilter.mode(Color(0x38D4A574), BlendMode.srcATop);
      case ScreenType.explore:
        // 緑がかり
        return const ColorFilter.mode(Color(0x386B8F5A), BlendMode.srcATop);
      case ScreenType.history:
        // モノクロ寄り
        return const ColorFilter.mode(Color(0x38969290), BlendMode.srcATop);
      case ScreenType.recommendation:
        // 紫
        return const ColorFilter.mode(Color(0x388B6FC4), BlendMode.srcATop);
      case ScreenType.reading:
        // 青
        return const ColorFilter.mode(Color(0x385A7DBF), BlendMode.srcATop);
      case ScreenType.auth:
        // 赤
        return const ColorFilter.mode(Color(0x38BF6B5A), BlendMode.srcATop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _getGradientColors();

    return Stack(
      fit: StackFit.expand,
      children: [
        // ━━━ Layer 0: ダンジョン背景画像 ━━━
        // ComfyUI SD 1.5 で生成した和風ダンジョン背景
        // 画面タイプに応じた色調フィルターを適用
        ColorFiltered(
          colorFilter: _getColorFilter(),
          child: Image.asset(
            'assets/images/dungeon_bg.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // ━━━ Layer 0.5: 暗色オーバーレイ（白文字の可読性確保）━━━
        Container(color: Colors.black.withValues(alpha: 0.10)),
        // ━━━ Layer 1: ベースグラデーション ━━━
        // 上から下へ：深い暗黒 → やや温かみのある石灰色（画面タイプごとに色調変化）
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
              stops: const [0.0, 0.35, 1.0],
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