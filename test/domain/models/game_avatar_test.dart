import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/game_avatar.dart';

void main() {
  group('AvatarAngle', () {
    test('next returns correct next angle', () {
      expect(AvatarAngle.front.next, AvatarAngle.frontRight);
      expect(AvatarAngle.frontRight.next, AvatarAngle.right);
      expect(AvatarAngle.right.next, AvatarAngle.backRight);
      expect(AvatarAngle.backRight.next, AvatarAngle.back);
      expect(AvatarAngle.back.next, AvatarAngle.backLeft);
      expect(AvatarAngle.backLeft.next, AvatarAngle.left);
      expect(AvatarAngle.left.next, AvatarAngle.frontLeft);
    });

    test('prev returns correct previous angle', () {
      expect(AvatarAngle.frontRight.prev, AvatarAngle.front);
      expect(AvatarAngle.right.prev, AvatarAngle.frontRight);
      expect(AvatarAngle.backRight.prev, AvatarAngle.right);
      expect(AvatarAngle.back.prev, AvatarAngle.backRight);
      expect(AvatarAngle.backLeft.prev, AvatarAngle.back);
      expect(AvatarAngle.left.prev, AvatarAngle.backLeft);
      expect(AvatarAngle.frontLeft.prev, AvatarAngle.left);
    });

    test('wraps around correctly', () {
      // frontLeft.next wraps to front
      expect(AvatarAngle.frontLeft.next, AvatarAngle.front);
      // front.prev wraps to frontLeft
      expect(AvatarAngle.front.prev, AvatarAngle.frontLeft);
    });

    test('defaultAngle is front', () {
      expect(AvatarAngle.defaultAngle, AvatarAngle.front);
    });
  });

  group('GameAvatar', () {
    test('isComplete is true when all 8 angles present', () {
      final avatar = GameAvatar(
        id: 'test-1',
        name: 'テストアバター',
        spriteUrls: {
          for (final angle in AvatarAngle.values) angle: 'url_${angle.name}',
        },
      );
      expect(avatar.isComplete, isTrue);
    });

    test('isComplete is false when angles are missing', () {
      final avatar = GameAvatar(
        id: 'test-2',
        name: '不完全アバター',
        spriteUrls: {
          AvatarAngle.front: 'url_front',
          AvatarAngle.back: 'url_back',
        },
      );
      expect(avatar.isComplete, isFalse);
    });

    test('urlForAngle returns correct URL for given angle', () {
      final avatar = GameAvatar(
        id: 'test-3',
        name: '完全アバター',
        spriteUrls: {
          for (final angle in AvatarAngle.values) angle: 'url_${angle.name}',
        },
      );
      expect(avatar.urlForAngle(AvatarAngle.front), 'url_front');
      expect(avatar.urlForAngle(AvatarAngle.backRight), 'url_backRight');
    });

    test('urlForAngle falls back to front when angle missing', () {
      final avatar = GameAvatar(
        id: 'test-4',
        name: '部分アバター',
        spriteUrls: {
          AvatarAngle.front: 'url_front',
          AvatarAngle.right: 'url_right',
        },
      );
      // missing angle → fallback to front
      expect(avatar.urlForAngle(AvatarAngle.back), 'url_front');
      // existing angle → direct
      expect(avatar.urlForAngle(AvatarAngle.right), 'url_right');
    });

    test('urlForAngle throws when front is also missing', () {
      final avatar = GameAvatar(
        id: 'test-5',
        name: '空アバター',
        spriteUrls: {},
      );
      expect(
        () => avatar.urlForAngle(AvatarAngle.backLeft),
        throwsA(isA<TypeError>()),
      );
    });

    test('placeholder has correct values', () {
      final avatar = GameAvatar.placeholder();
      expect(avatar.id, 'placeholder');
      expect(avatar.name, '見習い冒険者');
      expect(avatar.spriteUrls.length, 1);
      expect(avatar.spriteUrls[AvatarAngle.front], '');
    });
  });
}
