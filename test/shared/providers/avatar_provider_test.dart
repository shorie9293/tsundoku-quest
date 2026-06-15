import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/game_avatar.dart';
import 'package:tsundoku_quest/shared/providers/avatar_provider.dart';

void main() {
  group('avatarAngleProvider', () {
    test('default value is AvatarAngle.front', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final angle = container.read(avatarAngleProvider);
      expect(angle, AvatarAngle.front);
    });

    test('state can be updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(avatarAngleProvider.notifier).state = AvatarAngle.backRight;
      expect(container.read(avatarAngleProvider), AvatarAngle.backRight);

      container.read(avatarAngleProvider.notifier).state = AvatarAngle.left;
      expect(container.read(avatarAngleProvider), AvatarAngle.left);
    });

    test('state cycles through all angles', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final angle in AvatarAngle.values) {
        container.read(avatarAngleProvider.notifier).state = angle;
        expect(container.read(avatarAngleProvider), angle);
      }
    });
  });

  group('avatarProvider', () {
    test('returns placeholder GameAvatar when overridden with placeholder',
        () async {
      // Override the avatarProvider to return a placeholder directly
      final container = ProviderContainer(
        overrides: [
          avatarProvider.overrideWith((ref) => GameAvatar.placeholder()),
        ],
      );
      addTearDown(container.dispose);

      final avatar = await container.read(avatarProvider.future);
      expect(avatar.id, 'placeholder');
      expect(avatar.name, '見習い冒険者');
      expect(avatar.spriteUrls[AvatarAngle.front], '');
    });

    test('returns full avatar when overridden with complete avatar', () async {
      final completeSprites = <AvatarAngle, String>{
        for (final angle in AvatarAngle.values) angle: 'url_${angle.name}',
      };

      final container = ProviderContainer(
        overrides: [
          avatarProvider.overrideWith(
            (ref) => GameAvatar(
              id: 'default',
              name: '冒険者',
              spriteUrls: completeSprites,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final avatar = await container.read(avatarProvider.future);
      expect(avatar.id, 'default');
      expect(avatar.name, '冒険者');
      expect(avatar.isComplete, isTrue);
    });
  });
}
