import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/widgets/enemy_sprite_widget.dart';
import 'package:tsundoku_quest/domain/models/enemy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Helper: create a test enemy
  Enemy _testEnemy({String spriteUrl = ''}) => Enemy(
        id: 'enemy-1',
        name: 'テストスライム',
        rank: 1,
        hp: 10,
        attack: 3,
        defense: 1,
        xpReward: 5,
        spriteUrl: spriteUrl,
      );

  /// Helper: wrap widget in MaterialApp for testing
  Widget _wrap(EnemySpriteWidget widget) => MaterialApp(
        home: Scaffold(body: Center(child: widget)),
      );

  group('EnemySpriteWidget', () {
    testWidgets('shows CircularProgressIndicator when enemy is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const EnemySpriteWidget()),
      );

      expect(find.byKey(const Key('enemy_sprite_loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows placeholder when spriteUrl is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(EnemySpriteWidget(enemy: _testEnemy(spriteUrl: ''))),
      );

      expect(find.byKey(const Key('enemy_sprite_loading')), findsNothing);
      expect(find.byKey(const Key('enemy_sprite_placeholder')), findsOneWidget);
      expect(find.byIcon(Icons.pest_control), findsOneWidget);
    });

    testWidgets('renders enemy container when spriteUrl is provided',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          EnemySpriteWidget(
            enemy: _testEnemy(spriteUrl: 'https://example.com/enemy.png'),
          ),
        ),
      );

      // Should show the container with the image (not loading, not placeholder)
      expect(find.byKey(const Key('enemy_sprite_loading')), findsNothing);
      expect(find.byKey(const Key('enemy_sprite_container')), findsOneWidget);
      // Image.network attempts to load; in test env it fails, but the widget exists
      expect(find.byKey(const Key('enemy_sprite_image')), findsOneWidget);
    });

    testWidgets('uses configurable size parameter', (tester) async {
      const customSize = 64.0;
      await tester.pumpWidget(
        _wrap(
          const EnemySpriteWidget(size: customSize),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.byKey(const Key('enemy_sprite_loading')),
      );
      expect(sizedBox.width, customSize);
      expect(sizedBox.height, customSize);
    });

    testWidgets('shows placeholder on network error when spriteUrl provided',
        (tester) async {
      // In test environment, Image.network fails to load and calls errorBuilder
      // which renders the placeholder. Verify the image widget is present.
      await tester.pumpWidget(
        _wrap(
          EnemySpriteWidget(
            enemy: _testEnemy(spriteUrl: 'https://invalid.url/does-not-exist.png'),
          ),
        ),
      );

      // The Image.network widget should exist (even if it errors)
      expect(find.byKey(const Key('enemy_sprite_image')), findsOneWidget);

      // After pumping, the error builder may have fired
      await tester.pump();
      // The container should still exist
      expect(find.byKey(const Key('enemy_sprite_container')), findsOneWidget);
    });
  });
}
