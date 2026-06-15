import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/enemy.dart';

void main() {
  group('Enemy model', () {
    test('Enemy.fromJson parses all fields correctly', () {
      final json = {
        'id': 'enemy-1',
        'name': 'Slime',
        'rank': 2,
        'hp': 50,
        'attack': 10,
        'defense': 5,
        'xp_reward': 30,
        'sprite_url': 'https://example.com/sprites/slime.png',
      };

      final enemy = Enemy.fromJson(json);

      expect(enemy.id, 'enemy-1');
      expect(enemy.name, 'Slime');
      expect(enemy.rank, 2);
      expect(enemy.hp, 50);
      expect(enemy.attack, 10);
      expect(enemy.defense, 5);
      expect(enemy.xpReward, 30);
      expect(enemy.spriteUrl, 'https://example.com/sprites/slime.png');
    });

    test('Enemy.toJson produces correct map', () {
      const enemy = Enemy(
        id: 'enemy-2',
        name: 'Goblin',
        rank: 3,
        hp: 80,
        attack: 15,
        defense: 8,
        xpReward: 50,
        spriteUrl: 'https://example.com/sprites/goblin.png',
      );

      final json = enemy.toJson();

      expect(json['id'], 'enemy-2');
      expect(json['name'], 'Goblin');
      expect(json['rank'], 3);
      expect(json['hp'], 80);
      expect(json['attack'], 15);
      expect(json['defense'], 8);
      expect(json['xp_reward'], 50);
      expect(json['sprite_url'], 'https://example.com/sprites/goblin.png');
    });

    test('round-trip: fromJson → toJson → fromJson gives identical enemy', () {
      final originalJson = {
        'id': 'enemy-3',
        'name': 'Dragon',
        'rank': 5,
        'hp': 200,
        'attack': 40,
        'defense': 25,
        'xp_reward': 150,
        'sprite_url': 'https://example.com/sprites/dragon.png',
      };

      final enemy1 = Enemy.fromJson(originalJson);
      final intermediateJson = enemy1.toJson();
      final enemy2 = Enemy.fromJson(intermediateJson);

      expect(enemy2.id, enemy1.id);
      expect(enemy2.name, enemy1.name);
      expect(enemy2.rank, enemy1.rank);
      expect(enemy2.hp, enemy1.hp);
      expect(enemy2.attack, enemy1.attack);
      expect(enemy2.defense, enemy1.defense);
      expect(enemy2.xpReward, enemy1.xpReward);
      expect(enemy2.spriteUrl, enemy1.spriteUrl);
    });

    test('rank validation: rank 1-5 accepted', () {
      for (final rank in [1, 2, 3, 4, 5]) {
        final json = {
          'id': 'enemy-rank-$rank',
          'name': 'Rank Test',
          'rank': rank,
          'hp': 100,
          'attack': 20,
          'defense': 10,
          'xp_reward': 40,
          'sprite_url': 'https://example.com/sprite.png',
        };

        final enemy = Enemy.fromJson(json);
        expect(enemy.rank, rank);
      }
    });
  });
}
