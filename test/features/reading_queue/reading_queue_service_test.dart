import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/reading_queue/domain/reading_queue_service.dart';

ReadingQueueEntry _e(String id, int pos, [DateTime? at]) => ReadingQueueEntry(
      userBookId: id,
      position: pos,
      addedAt: at ?? DateTime(2026, 9, 21),
    );

UserBook _ub(
  String id, {
  BookStatus status = BookStatus.tsundoku,
}) =>
    UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      status: status,
      medium: BookMedium.physical,
      createdAt: '2026-09-21T00:00:00.000',
    );

void main() {
  group('normalize', () {
    test('position を 1..n に詰め直す', () {
      final result = ReadingQueueService.normalize([
        _e('a', 5),
        _e('b', 99),
        _e('c', 2),
      ]);
      expect(result.map((e) => e.position).toList(), [1, 2, 3]);
      expect(result.map((e) => e.userBookId).toList(), ['c', 'a', 'b']);
    });

    test('position 昇順 → addedAt 昇順 → userBookId 昇順で安定ソート', () {
      final result = ReadingQueueService.normalize([
        _e('b', 1, DateTime(2026, 1, 2)),
        _e('a', 1, DateTime(2026, 1, 1)),
        _e('z', 1, DateTime(2026, 1, 1)),
      ]);
      // 同 position なら addedAt 昇順、同 addedAt なら userBookId 昇順
      expect(result.map((e) => e.userBookId).toList(), ['a', 'z', 'b']);
    });

    test('引数リストを変更しない（非破壊）', () {
      final original = [_e('a', 3), _e('b', 1)];
      final snapshot = List.of(original);
      ReadingQueueService.normalize(original);
      expect(original.map((e) => e.userBookId), snapshot.map((e) => e.userBookId));
    });

    test('空リストは空リスト', () {
      expect(ReadingQueueService.normalize([]), isEmpty);
    });
  });

  group('enqueue', () {
    test('末尾に追加する', () {
      final result = ReadingQueueService.enqueue(
        [_e('a', 1)],
        'b',
        DateTime(2026, 9, 22),
      );
      expect(result.map((e) => e.userBookId).toList(), ['a', 'b']);
      expect(result.last.position, 2);
    });

    test('既存なら冪等（追加されない）', () {
      final current = [_e('a', 1), _e('b', 2)];
      final result = ReadingQueueService.enqueue(
        current,
        'a',
        DateTime(2026, 9, 22),
      );
      expect(result.map((e) => e.userBookId).toList(), ['a', 'b']);
      expect(result.length, 2);
    });

    test('空文字 userBookId は ArgumentError', () {
      expect(
        () => ReadingQueueService.enqueue([], '', DateTime(2026)),
        throwsArgumentError,
      );
    });
  });

  group('dequeue', () {
    test('指定を除去し position を詰め直す', () {
      final result = ReadingQueueService.dequeue(
        [_e('a', 1), _e('b', 2), _e('c', 3)],
        'b',
      );
      expect(result.map((e) => e.userBookId).toList(), ['a', 'c']);
      expect(result.map((e) => e.position).toList(), [1, 2]);
    });

    test('不存在でも無変更（normalize 相当）', () {
      final current = [_e('a', 1)];
      final result = ReadingQueueService.dequeue(current, 'zzz');
      expect(result.map((e) => e.userBookId).toList(), ['a']);
    });
  });

  group('moveUp / moveDown', () {
    test('moveUp で1つ前へ', () {
      final result = ReadingQueueService.moveUp(
        [_e('a', 1), _e('b', 2), _e('c', 3)],
        'c',
      );
      expect(result.map((e) => e.userBookId).toList(), ['a', 'c', 'b']);
      expect(result.map((e) => e.position).toList(), [1, 2, 3]);
    });

    test('moveUp: 先頭は無変更', () {
      final current = [_e('a', 1), _e('b', 2)];
      final result = ReadingQueueService.moveUp(current, 'a');
      expect(result.map((e) => e.userBookId).toList(), ['a', 'b']);
    });

    test('moveUp: 不存在は無変更', () {
      final result = ReadingQueueService.moveUp([_e('a', 1)], 'zzz');
      expect(result.map((e) => e.userBookId).toList(), ['a']);
    });

    test('moveDown で1つ後ろへ', () {
      final result = ReadingQueueService.moveDown(
        [_e('a', 1), _e('b', 2), _e('c', 3)],
        'a',
      );
      expect(result.map((e) => e.userBookId).toList(), ['b', 'a', 'c']);
    });

    test('moveDown: 末尾は無変更', () {
      final result = ReadingQueueService.moveDown(
        [_e('a', 1), _e('b', 2)],
        'b',
      );
      expect(result.map((e) => e.userBookId).toList(), ['a', 'b']);
    });

    test('並び替え後も normalize 再適用で順序が打ち消されない', () {
      // moveUp の結果を normalize しても順序は保たれるはず（position 再振り済み）
      final moved = ReadingQueueService.moveUp(
        [_e('a', 1), _e('b', 2), _e('c', 3)],
        'c',
      );
      final renormalized = ReadingQueueService.normalize(moved);
      expect(renormalized.map((e) => e.userBookId).toList(), ['a', 'c', 'b']);
    });
  });

  group('moveTo', () {
    test('0始まり index へ移動', () {
      final result = ReadingQueueService.moveTo(
        [_e('a', 1), _e('b', 2), _e('c', 3)],
        'c',
        0,
      );
      expect(result.map((e) => e.userBookId).toList(), ['c', 'a', 'b']);
      expect(result.map((e) => e.position).toList(), [1, 2, 3]);
    });

    test('範囲外 index は無変更', () {
      final current = [_e('a', 1), _e('b', 2)];
      expect(
        ReadingQueueService.moveTo(current, 'a', 2).map((e) => e.userBookId),
        ['a', 'b'],
      );
      expect(
        ReadingQueueService.moveTo(current, 'a', -1).map((e) => e.userBookId),
        ['a', 'b'],
      );
    });

    test('不存在は無変更', () {
      final result = ReadingQueueService.moveTo([_e('a', 1)], 'zzz', 0);
      expect(result.map((e) => e.userBookId).toList(), ['a']);
    });
  });

  group('resolveQueue', () {
    test('キュー順を保ち、存在しない id を除外', () {
      final result = ReadingQueueService.resolveQueue(
        [_e('a', 2), _e('ghost', 1), _e('b', 3)],
        [_ub('a'), _ub('b')],
      );
      expect(result.map((ub) => ub.id).toList(), ['a', 'b']);
    });

    test('status == completed を除外', () {
      final result = ReadingQueueService.resolveQueue(
        [_e('done', 1), _e('a', 2)],
        [_ub('done', status: BookStatus.completed), _ub('a')],
      );
      expect(result.map((ub) => ub.id).toList(), ['a']);
    });

    test('tsundoku / reading は残る', () {
      final result = ReadingQueueService.resolveQueue(
        [_e('a', 1), _e('b', 2)],
        [
          _ub('a', status: BookStatus.tsundoku),
          _ub('b', status: BookStatus.reading),
        ],
      );
      expect(result.map((ub) => ub.id).toList(), ['a', 'b']);
    });
  });

  group('nextToRead', () {
    test('resolveQueue の先頭を返す', () {
      final result = ReadingQueueService.nextToRead(
        [_e('a', 2), _e('b', 1)],
        [_ub('a'), _ub('b')],
      );
      expect(result?.id, 'b');
    });

    test('空キューなら null', () {
      expect(ReadingQueueService.nextToRead([], []), isNull);
    });

    test('全員 completed なら null', () {
      final result = ReadingQueueService.nextToRead(
        [_e('a', 1)],
        [_ub('a', status: BookStatus.completed)],
      );
      expect(result, isNull);
    });
  });
}
