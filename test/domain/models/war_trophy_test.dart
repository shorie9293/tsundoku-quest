import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';

void main() {
  group('WarTrophy', () {
    const sampleTrophy = WarTrophy(
      id: 'trophy-1',
      userBookId: 'ub-1',
      userId: 'user-1',
      learnings: ['学び1', '学び2', '学び3'],
      action: '毎日10分読書する',
      favoriteQuote: '本は心の栄養',
      createdAt: '2025-06-01T10:00:00Z',
    );

    test('constructorTest: 全必須フィールドが正しく設定される（learningsに3要素）', () {
      expect(sampleTrophy.id, 'trophy-1');
      expect(sampleTrophy.userBookId, 'ub-1');
      expect(sampleTrophy.userId, 'user-1');
      expect(sampleTrophy.learnings, ['学び1', '学び2', '学び3']);
      expect(sampleTrophy.learnings.length, 3);
      expect(sampleTrophy.action, '毎日10分読書する');
      expect(sampleTrophy.favoriteQuote, '本は心の栄養');
      expect(sampleTrophy.createdAt, '2025-06-01T10:00:00Z');
    });

    test('optionalQuoteNullTest: favoriteQuoteがnullでも正しく構築', () {
      const trophy = WarTrophy(
        id: 'trophy-2',
        userBookId: 'ub-2',
        userId: 'user-2',
        learnings: ['学びA', '学びB', '学びC'],
        action: '毎週振り返りをする',
        createdAt: '2025-06-02T10:00:00Z',
      );

      expect(trophy.id, 'trophy-2');
      expect(trophy.favoriteQuote, isNull);
      expect(trophy.learnings.length, 3);
      expect(trophy.action, '毎週振り返りをする');
    });

    group('fromJson', () {
      test('fromJsonTest: JSONから正しくデシリアライズ（learningsがList<String>になること）', () {
        final json = {
          'id': 'trophy-3',
          'userBookId': 'ub-3',
          'userId': 'user-3',
          'learnings': ['学びX', '学びY', '学びZ'],
          'action': '本を人に勧める',
          'favoriteQuote': '読書は冒険',
          'createdAt': '2025-06-03T10:00:00Z',
        };

        final trophy = WarTrophy.fromJson(json);

        expect(trophy.id, 'trophy-3');
        expect(trophy.userBookId, 'ub-3');
        expect(trophy.userId, 'user-3');
        expect(trophy.learnings, ['学びX', '学びY', '学びZ']);
        expect(trophy.learnings, isA<List<String>>());
        expect(trophy.learnings.length, 3);
        expect(trophy.action, '本を人に勧める');
        expect(trophy.favoriteQuote, '読書は冒険');
        expect(trophy.createdAt, '2025-06-03T10:00:00Z');
      });

      test('favoriteQuoteがnullのJSONでも正しくデシリアライズ', () {
        final json = {
          'id': 'trophy-4',
          'userBookId': 'ub-4',
          'userId': 'user-4',
          'learnings': ['学び1', '学び2', '学び3'],
          'action': '行動する',
          'createdAt': '2025-06-04T10:00:00Z',
        };

        final trophy = WarTrophy.fromJson(json);

        expect(trophy.favoriteQuote, isNull);
        expect(trophy.learnings, ['学び1', '学び2', '学び3']);
      });
    });

    group('toJson', () {
      test('toJsonTest: toJson()が正しいMapを返す', () {
        final json = sampleTrophy.toJson();

        expect(json['id'], 'trophy-1');
        expect(json['userBookId'], 'ub-1');
        expect(json['userId'], 'user-1');
        expect(json['learnings'], ['学び1', '学び2', '学び3']);
        expect(json['action'], '毎日10分読書する');
        expect(json['favoriteQuote'], '本は心の栄養');
        expect(json['createdAt'], '2025-06-01T10:00:00Z');
      });
    });

    test('roundTripTest: toJson→fromJson で元の値が復元される（learnings含む）', () {
      final json = sampleTrophy.toJson();
      final restored = WarTrophy.fromJson(json);

      expect(restored.id, sampleTrophy.id);
      expect(restored.userBookId, sampleTrophy.userBookId);
      expect(restored.userId, sampleTrophy.userId);
      expect(restored.learnings, sampleTrophy.learnings);
      expect(restored.learnings, isA<List<String>>());
      expect(restored.action, sampleTrophy.action);
      expect(restored.favoriteQuote, sampleTrophy.favoriteQuote);
      expect(restored.createdAt, sampleTrophy.createdAt);
    });

    test('emptyLearningsTest: learningsが空リストでも構築可能', () {
      const trophy = WarTrophy(
        id: 'trophy-5',
        userBookId: 'ub-5',
        userId: 'user-5',
        learnings: [],
        action: 'とにかく読む',
        createdAt: '2025-06-05T10:00:00Z',
      );

      expect(trophy.learnings, isEmpty);
      expect(trophy.id, 'trophy-5');
      expect(trophy.action, 'とにかく読む');

      // 空リストでもラウンドトリップ可能
      final json = trophy.toJson();
      final restored = WarTrophy.fromJson(json);
      expect(restored.learnings, isEmpty);
    });
  });
}
