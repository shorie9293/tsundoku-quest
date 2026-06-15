import 'package:flutter/material.dart';
import '../../domain/models/enemy.dart';

class EnemySpriteWidget extends StatelessWidget {
  final Enemy? enemy;
  final double size;

  const EnemySpriteWidget({
    super.key,
    this.enemy,
    this.size = 96.0,
  });

  @override
  Widget build(BuildContext context) {
    if (enemy == null) {
      return SizedBox(
        key: const Key('enemy_sprite_loading'),
        width: size,
        height: size,
        child: const CircularProgressIndicator(),
      );
    }

    final spriteUrl = enemy!.spriteUrl;

    return SizedBox(
      key: const Key('enemy_sprite_container'),
      width: size,
      height: size,
      child: spriteUrl.isNotEmpty
          ? Image.network(
              spriteUrl,
              key: const Key('enemy_sprite_image'),
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      key: const Key('enemy_sprite_placeholder'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF1A1035),
        border: Border.all(color: const Color(0xFFA78BFA).withAlpha(80)),
      ),
      child: const Center(
        child: Icon(Icons.pest_control, size: 40, color: Color(0xFFA78BFA)),
      ),
    );
  }
}
