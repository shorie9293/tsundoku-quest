import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// 討伐完了時の勝利演出オーバーレイ
///
/// 読了完了時に全画面オーバーレイで表示し、
/// 「⚔️ 討伐完了！」のテキストアニメーション、
/// XP獲得表示、背景パーティクルエフェクトを表示する。
/// 2.5秒後に自動で消え、onComplete コールバックを呼ぶ。
class CompletionEffectOverlay {
  static OverlayEntry? _currentEntry;

  /// 演出オーバーレイを表示する。
  ///
  /// [xpGained] 表示する獲得XP（0の場合はデフォルトの200を表示）。
  /// [onComplete] 演出終了後に呼ばれるコールバック。
  static void show(
    BuildContext context, {
    required int xpGained,
    VoidCallback? onComplete,
  }) {
    // 二重表示防止: 既存のオーバーレイがあれば除去
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _CompletionEffectWidget(
        xpGained: xpGained > 0 ? xpGained : 200,
        onComplete: () {
          entry.remove();
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          onComplete?.call();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _CompletionEffectWidget extends StatefulWidget {
  final int xpGained;
  final VoidCallback onComplete;

  const _CompletionEffectWidget({
    required this.xpGained,
    required this.onComplete,
  });

  @override
  State<_CompletionEffectWidget> createState() =>
      _CompletionEffectWidgetState();
}

class _CompletionEffectWidgetState extends State<_CompletionEffectWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();

    // 2.5秒後に自動的に消える
    _dismissTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            // 演出中はユーザー操作をブロック
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // タップを吸収
            child: Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: Stack(
                children: [
                  // パーティクル背景
                  const _ParticleBackground(),
                  // 中央のテキスト
                  Center(
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '⚔️ 討伐完了！',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFFFFD700),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '+${widget.xpGained} XP',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFFD700),
                                shadows: [
                                  Shadow(
                                    color: Color(0xFFFF8C00),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// キラキラ粒子エフェクトを描画する背景ウィジェット
class _ParticleBackground extends StatefulWidget {
  const _ParticleBackground();

  @override
  State<_ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<_ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _particleController;
  final _random = Random(42);

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _ParticlePainter(
            progress: _particleController.value,
            random: _random,
          ),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Random random;

  _ParticlePainter({required this.progress, required this.random});

  @override
  void paint(Canvas canvas, Size size) {
    const particleCount = 50;
    const colors = [
      Color(0xFFFFD700), // Gold
      Color(0xFFFFA500), // Orange
      Color(0xFFFF6347), // Tomato
      Color(0xFFFFF8DC), // Cornsilk
      Color(0xFFFFB6C1), // Light pink
    ];

    // 乱数シードを固定して位置を安定させる
    final seededRandom = Random(random.nextInt(10000));

    for (int i = 0; i < particleCount; i++) {
      final x = seededRandom.nextDouble() * size.width;
      final baseY = seededRandom.nextDouble() * size.height;
      // 上昇アニメーション — progress が進むにつれて上に動く
      final y = (baseY - progress * size.height * 0.5) % size.height;
      final radius = 2.0 + seededRandom.nextDouble() * 3.0;
      final opacity =
          (0.3 + seededRandom.nextDouble() * 0.7) * (1.0 - progress * 0.6);
      final color = colors[seededRandom.nextInt(colors.length)];

      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
