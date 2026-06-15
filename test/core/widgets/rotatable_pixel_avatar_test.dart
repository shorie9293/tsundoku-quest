import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/widgets/rotatable_pixel_avatar.dart';
import 'package:tsundoku_quest/domain/models/game_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Helper: build a complete GameAvatar with all 8 sprite URLs
  GameAvatar _completeAvatar() => GameAvatar(
        id: 'test-avatar',
        name: 'テスト冒険者',
        spriteUrls: {
          for (final angle in AvatarAngle.values) angle: 'https://example.com/${angle.name}.png',
        },
      );

  /// Helper: build a GameAvatar with empty sprite URL (placeholder)
  GameAvatar _emptyUrlAvatar() => GameAvatar(
        id: 'test-empty',
        name: '空アバター',
        spriteUrls: {AvatarAngle.front: ''},
      );

  /// Helper: wrap widget in MaterialApp for testing
  Widget _wrap(RotatablePixelAvatar widget) => MaterialApp(
        home: Scaffold(body: Center(child: widget)),
      );

  group('RotatablePixelAvatar', () {
    testWidgets('shows CircularProgressIndicator when avatar is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RotatablePixelAvatar(angle: AvatarAngle.front),
        ),
      );

      // Should show loading indicator
      expect(find.byKey(const Key('avatar_loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows placeholder when spriteUrl is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RotatablePixelAvatar(
            avatar: _emptyUrlAvatar(),
            angle: AvatarAngle.front,
          ),
        ),
      );

      // Should show placeholder, not loading
      expect(find.byKey(const Key('avatar_loading')), findsNothing);
      expect(find.byKey(const Key('avatar_placeholder')), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('renders avatar container when spriteUrl is provided',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          RotatablePixelAvatar(
            avatar: _completeAvatar(),
            angle: AvatarAngle.front,
          ),
        ),
      );

      // Should show the gesture detector (not loading)
      expect(find.byKey(const Key('avatar_loading')), findsNothing);
      expect(find.byKey(const Key('avatar_gesture_detector')), findsOneWidget);

      // Image.network attempts to load; in test env it fails and falls to errorBuilder
      // So we verify the widget hierarchy is correct
      expect(find.byKey(const Key('avatar_sprite_image')), findsOneWidget);
    });

    testWidgets('uses configurable size parameter', (tester) async {
      const customSize = 64.0;
      await tester.pumpWidget(
        _wrap(
          const RotatablePixelAvatar(
            angle: AvatarAngle.front,
            size: customSize,
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.byKey(const Key('avatar_loading')),
      );
      expect(sizedBox.width, customSize);
      expect(sizedBox.height, customSize);
    });

    testWidgets('onAngleChanged callback fires on horizontal drag right',
        (tester) async {
      AvatarAngle? changedTo;
      await tester.pumpWidget(
        _wrap(
          RotatablePixelAvatar(
            avatar: _completeAvatar(),
            angle: AvatarAngle.front,
            onAngleChanged: (angle) => changedTo = angle,
          ),
        ),
      );

      // Simulate drag from left to right (delta > 20)
      final gestureDetector = find.byKey(const Key('avatar_gesture_detector'));
      await tester.drag(gestureDetector, const Offset(30, 0));
      await tester.pump();

      expect(changedTo, AvatarAngle.frontRight); // next angle
    });

    testWidgets('onAngleChanged callback fires on horizontal drag left',
        (tester) async {
      AvatarAngle? changedTo;
      await tester.pumpWidget(
        _wrap(
          RotatablePixelAvatar(
            avatar: _completeAvatar(),
            angle: AvatarAngle.front,
            onAngleChanged: (angle) => changedTo = angle,
          ),
        ),
      );

      // Simulate drag from right to left (delta < -20)
      final gestureDetector = find.byKey(const Key('avatar_gesture_detector'));
      await tester.drag(gestureDetector, const Offset(-30, 0));
      await tester.pump();

      expect(changedTo, AvatarAngle.frontLeft); // prev angle
    });

    testWidgets('small drag does not trigger onAngleChanged', (tester) async {
      AvatarAngle? changedTo;
      await tester.pumpWidget(
        _wrap(
          RotatablePixelAvatar(
            avatar: _completeAvatar(),
            angle: AvatarAngle.front,
            onAngleChanged: (angle) => changedTo = angle,
          ),
        ),
      );

      // Simulate small drag (delta.abs() < 20)
      final gestureDetector = find.byKey(const Key('avatar_gesture_detector'));
      await tester.drag(gestureDetector, const Offset(10, 0));
      await tester.pump();

      expect(changedTo, isNull); // should not have fired
    });

    testWidgets('avatar with partial sprites falls back to front angle',
        (tester) async {
      final partialAvatar = GameAvatar(
        id: 'partial',
        name: '部分アバター',
        spriteUrls: {
          AvatarAngle.front: 'https://example.com/front.png',
          AvatarAngle.right: 'https://example.com/right.png',
        },
      );

      await tester.pumpWidget(
        _wrap(
          RotatablePixelAvatar(
            avatar: partialAvatar,
            angle: AvatarAngle.back, // back is missing, falls back to front
          ),
        ),
      );

      // Should render (not loading), using fallback URL
      expect(find.byKey(const Key('avatar_loading')), findsNothing);
      expect(find.byKey(const Key('avatar_gesture_detector')), findsOneWidget);
    });
  });
}
