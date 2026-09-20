import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_provider.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_repository.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

ReadingQueueEntry _e(String id, int pos) => ReadingQueueEntry(
      userBookId: id,
      position: pos,
      addedAt: DateTime(2026, 9, 21),
    );

UserBook _ub(String id, {BookStatus status = BookStatus.tsundoku}) => UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      status: status,
      medium: BookMedium.physical,
      createdAt: '2026-09-21T00:00:00Z',
    );

void main() {
  group('ReadingQueueController', () {
    test('load で repository のエントリを復元する', () async {
      final repo = InMemoryReadingQueueRepository();
      await repo.saveEntries([_e('a', 2), _e('b', 1)]);

      final container = ProviderContainer(
        overrides: [readingQueueRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final controller = container.read(readingQueueControllerProvider.notifier);
      await controller.load();

      final state = container.read(readingQueueControllerProvider);
      expect(state.map((e) => e.userBookId), ['b', 'a']);
      expect(state.map((e) => e.position).toList(), [1, 2]);
    });

    test('enqueue で末尾追加・永続化される', () async {
      final repo = InMemoryReadingQueueRepository();
      final container = ProviderContainer(
        overrides: [readingQueueRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(readingQueueControllerProvider.notifier);
      final now = DateTime(2026, 9, 21);
      await notifier.enqueue('a', addedAt: now);
      await notifier.enqueue('b', addedAt: now);

      expect(
        container.read(readingQueueControllerProvider).map((e) => e.userBookId),
        ['a', 'b'],
      );
      expect(repo.length, 2);
    });

    test('enqueue は重複時に冪等', () async {
      final repo = InMemoryReadingQueueRepository();
      final container = ProviderContainer(
        overrides: [readingQueueRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(readingQueueControllerProvider.notifier);
      final now = DateTime(2026, 9, 21);
      await notifier.enqueue('a', addedAt: now);
      await notifier.enqueue('a', addedAt: now);

      expect(container.read(readingQueueControllerProvider).length, 1);
    });

    test('moveUp / moveDown / dequeue で並び替え・除去が永続化される', () async {
      final repo = InMemoryReadingQueueRepository();
      final container = ProviderContainer(
        overrides: [readingQueueRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(readingQueueControllerProvider.notifier);
      final now = DateTime(2026, 9, 21);
      await notifier.enqueue('a', addedAt: now);
      await notifier.enqueue('b', addedAt: now);
      await notifier.enqueue('c', addedAt: now);

      await notifier.moveUp('b');
      expect(
        container.read(readingQueueControllerProvider).map((e) => e.userBookId),
        ['b', 'a', 'c'],
      );

      await notifier.moveDown('b');
      expect(
        container.read(readingQueueControllerProvider).map((e) => e.userBookId),
        ['a', 'b', 'c'],
      );

      await notifier.dequeue('a');
      expect(
        container.read(readingQueueControllerProvider).map((e) => e.userBookId),
        ['b', 'c'],
      );
      expect(repo.length, 2);
    });

    test('moveTo で指定位置へ移動する', () async {
      final repo = InMemoryReadingQueueRepository();
      final container = ProviderContainer(
        overrides: [readingQueueRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(readingQueueControllerProvider.notifier);
      final now = DateTime(2026, 9, 21);
      await notifier.enqueue('a', addedAt: now);
      await notifier.enqueue('b', addedAt: now);
      await notifier.enqueue('c', addedAt: now);

      await notifier.moveTo('c', 0);
      expect(
        container.read(readingQueueControllerProvider).map((e) => e.userBookId),
        ['c', 'a', 'b'],
      );
    });
  });

  group('nextToReadProvider / queuedBooksProvider', () {
    test('次の一冊とキュー順を解決する', () async {
      final repo = InMemoryReadingQueueRepository();
      await repo.saveEntries([_e('ub-2', 1), _e('ub-1', 2), _e('ub-3', 3)]);

      final container = ProviderContainer(
        overrides: [readingQueueRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container
          .read(readingQueueControllerProvider.notifier)
          .load();

      final notifier = container.read(bookDataProvider.notifier);
      notifier.addUserBook(_ub('ub-1'));
      notifier.addUserBook(_ub('ub-2'));
      notifier.addUserBook(_ub('ub-3'));

      expect(container.read(nextToReadProvider)?.id, 'ub-2');
      expect(
        container.read(queuedBooksProvider).map((ub) => ub.id),
        ['ub-2', 'ub-1', 'ub-3'],
      );
    });

    test('読了済み・不明な本はキューから除外される', () async {
      final repo = InMemoryReadingQueueRepository();
      await repo.saveEntries([_e('ub-1', 1), _e('ub-2', 2), _e('ub-x', 3)]);

      final container = ProviderContainer(
        overrides: [readingQueueRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container
          .read(readingQueueControllerProvider.notifier)
          .load();

      final notifier = container.read(bookDataProvider.notifier);
      notifier.addUserBook(_ub('ub-1'));
      notifier.addUserBook(_ub('ub-2', status: BookStatus.completed));

      expect(container.read(nextToReadProvider)?.id, 'ub-1');
      expect(
        container.read(queuedBooksProvider).map((ub) => ub.id),
        ['ub-1'],
      );
    });
  });
}
