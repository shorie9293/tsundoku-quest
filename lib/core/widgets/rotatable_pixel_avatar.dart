import 'package:flutter/material.dart';
import '../../domain/models/game_avatar.dart';

class RotatablePixelAvatar extends StatefulWidget {
  final GameAvatar? avatar;
  final AvatarAngle angle;
  final double size;
  final ValueChanged<AvatarAngle>? onAngleChanged;

  const RotatablePixelAvatar({
    super.key,
    this.avatar,
    required this.angle,
    this.size = 128.0,
    this.onAngleChanged,
  });

  @override
  State<RotatablePixelAvatar> createState() => _RotatablePixelAvatarState();
}

class _RotatablePixelAvatarState extends State<RotatablePixelAvatar> {
  double _dragStart = 0;

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStart = details.localPosition.dx;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.localPosition.dx - _dragStart;
    if (delta.abs() > 20) {
      final newAngle = delta > 0 ? widget.angle.next : widget.angle.prev;
      widget.onAngleChanged?.call(newAngle);
      _dragStart = details.localPosition.dx;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.avatar;
    if (avatar == null) {
      return SizedBox(
        key: const Key('avatar_loading'),
        width: widget.size,
        height: widget.size,
        child: const CircularProgressIndicator(),
      );
    }

    final spriteUrl = avatar.urlForAngle(widget.angle);

    return GestureDetector(
      key: const Key('avatar_gesture_detector'),
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: SizedBox(
          key: ValueKey(widget.angle),
          width: widget.size,
          height: widget.size,
          child: spriteUrl.isNotEmpty
              ? Image.network(
                  spriteUrl,
                  key: const Key('avatar_sprite_image'),
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      key: const Key('avatar_placeholder'),
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF1A1035)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, size: 48, color: Color(0xFFA78BFA)),
      ),
    );
  }
}
