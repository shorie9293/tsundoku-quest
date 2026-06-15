import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/domain/models/game_avatar.dart';
import 'package:tsundoku_quest/core/infrastructure/supabase/supabase_storage_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}
class MockStorageFileApi extends Mock implements StorageFileApi {}

void main() {
  late MockSupabaseClient mockClient;
  late MockSupabaseStorageClient mockStorage;
  late MockStorageFileApi mockFileApi;
  late SupabaseStorageService service;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockStorage = MockSupabaseStorageClient();
    mockFileApi = MockStorageFileApi();

    when(() => mockClient.storage).thenReturn(mockStorage);
    when(() => mockStorage.from(any())).thenReturn(mockFileApi);
    when(() => mockFileApi.getPublicUrl(any()))
        .thenReturn('https://example.com/game-assets/test.png');

    service = SupabaseStorageService(mockClient);
  });

  group('fetchAvatarSprites', () {
    test('returns map with 8 entries (all AvatarAngle values)', () async {
      final urls = await service.fetchAvatarSprites('default');

      expect(urls.length, 8);
      expect(urls.keys.toSet(), AvatarAngle.values.toSet());
    });

    test('URLs contain bucket name', () async {
      when(() => mockFileApi.getPublicUrl(any()))
          .thenReturn('https://cdn.example.com/game-assets/avatars/hero/front.png');

      final urls = await service.fetchAvatarSprites('hero');

      for (final url in urls.values) {
        expect(url, contains('game-assets'));
      }
    });

    test('constructs correct path for each angle', () async {
      await service.fetchAvatarSprites('warrior');

      for (final angle in AvatarAngle.values) {
        final expectedPath = 'avatars/warrior/${angle.name}.png';
        verify(() => mockFileApi.getPublicUrl(expectedPath)).called(1);
      }
    });

    test('returns URLs for all 8 angles', () async {
      // Each angle gets a unique URL in real usage
      when(() => mockFileApi.getPublicUrl(any())).thenAnswer((invocation) {
        final path = invocation.positionalArguments[0] as String;
        return 'https://storage.example/game-assets/$path';
      });

      final urls = await service.fetchAvatarSprites('mage');

      expect(urls[AvatarAngle.front], contains('front.png'));
      expect(urls[AvatarAngle.back], contains('back.png'));
      expect(urls[AvatarAngle.left], contains('left.png'));
      expect(urls[AvatarAngle.right], contains('right.png'));
      expect(urls[AvatarAngle.frontRight], contains('frontRight.png'));
      expect(urls[AvatarAngle.backRight], contains('backRight.png'));
      expect(urls[AvatarAngle.backLeft], contains('backLeft.png'));
      expect(urls[AvatarAngle.frontLeft], contains('frontLeft.png'));
    });
  });

  group('fetchEnemySpriteUrl', () {
    test('returns non-empty URL containing enemyId and bucket', () {
      when(() => mockFileApi.getPublicUrl('enemies/slime.png'))
          .thenReturn('https://storage.example/game-assets/enemies/slime.png');

      final url = service.fetchEnemySpriteUrl('slime');

      expect(url, isNotEmpty);
      expect(url, contains('game-assets'));
      expect(url, contains('slime'));
      verify(() => mockFileApi.getPublicUrl('enemies/slime.png')).called(1);
    });

    test('returns URL with correct path for different enemyId', () {
      when(() => mockFileApi.getPublicUrl('enemies/dragon.png'))
          .thenReturn('https://storage.example/game-assets/enemies/dragon.png');

      final url = service.fetchEnemySpriteUrl('dragon');

      expect(url, contains('dragon.png'));
      verify(() => mockFileApi.getPublicUrl('enemies/dragon.png')).called(1);
    });
  });

  group('fetchEnemyList', () {
    test('returns empty list when download throws', () async {
      when(() => mockFileApi.download('enemies/enemies.json'))
          .thenThrow(Exception('Network error'));

      final enemies = await service.fetchEnemyList();

      expect(enemies, isEmpty);
    });

    test('returns empty list when download returns empty data', () async {
      when(() => mockFileApi.download('enemies/enemies.json'))
          .thenAnswer((_) async => Uint8List(0));

      final enemies = await service.fetchEnemyList();

      expect(enemies, isEmpty);
    });

    test('parses JSON object with enemies key', () async {
      const json = '{"enemies":[{"id":"goblin","name":"ゴブリン","rank":1,'
          '"hp":30,"attack":8,"defense":3,"xp_reward":15,'
          '"sprite_url":"https://example.com/game-assets/enemies/goblin.png"}]}';
      when(() => mockFileApi.download('enemies/enemies.json'))
          .thenAnswer((_) async => Uint8List.fromList(utf8.encode(json)));

      final enemies = await service.fetchEnemyList();

      expect(enemies.length, 1);
      expect(enemies.first.id, 'goblin');
      expect(enemies.first.name, 'ゴブリン');
      expect(enemies.first.rank, 1);
      expect(enemies.first.hp, 30);
      expect(enemies.first.attack, 8);
      expect(enemies.first.defense, 3);
      expect(enemies.first.xpReward, 15);
    });

    test('parses JSON array of enemies', () async {
      const json = '['
          '{"id":"slime","name":"スライム","rank":1,"hp":20,"attack":5,'
          '"defense":2,"xp_reward":10,'
          '"sprite_url":"https://example.com/game-assets/enemies/slime.png"},'
          '{"id":"dragon","name":"ドラゴン","rank":5,"hp":200,"attack":50,'
          '"defense":30,"xp_reward":500,'
          '"sprite_url":"https://example.com/game-assets/enemies/dragon.png"}'
          ']';
      when(() => mockFileApi.download('enemies/enemies.json'))
          .thenAnswer((_) async => Uint8List.fromList(utf8.encode(json)));

      final enemies = await service.fetchEnemyList();

      expect(enemies.length, 2);
      expect(enemies[0].id, 'slime');
      expect(enemies[1].name, 'ドラゴン');
      expect(enemies[1].rank, 5);
    });
  });

  group('getPublicUrl', () {
    test('returns URL containing bucket name and path', () {
      when(() => mockFileApi.getPublicUrl('test/path.png'))
          .thenReturn('https://cdn.example.com/game-assets/test/path.png');

      final url = service.getPublicUrl('test/path.png');

      expect(url, contains('game-assets'));
      expect(url, contains('test/path.png'));
      verify(() => mockFileApi.getPublicUrl('test/path.png')).called(1);
    });

    test('delegates to storage bucket for path construction', () {
      when(() => mockFileApi.getPublicUrl('avatars/custom.png'))
          .thenReturn('https://supabase.co/storage/v1/object/public/game-assets/avatars/custom.png');

      final url = service.getPublicUrl('avatars/custom.png');

      expect(url, isNotEmpty);
      verify(() => mockFileApi.getPublicUrl('avatars/custom.png')).called(1);
    });
  });
}
