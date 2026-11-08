import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/data/book_deletion_service.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_deletion_plan.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

/// run() に渡された plan を記録するフェイク
class _FakeBookDeletionService extends BookDeletionService {
  final List<BookDeletionPlan> plans = [];
  bool shouldThrow = false;

  @override
  Future<BookDeletionReport> run(BookDeletionPlan plan) async {
    plans.add(plan);
    if (shouldThrow) throw StateError('連鎖削除の想定外失敗');
    return const BookDeletionReport();
  }
}

UserBook _userBook(String id) => UserBook(
      id: id,
      userId: 'u-1',
      bookId: 'b-$id',
      status: BookStatus.tsundoku,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  group('BookDataNotifier × BookDeletionService 配線', () {
    test('removeUserBook で対象IDの plan が service に渡る', () async {
      final fake = _FakeBookDeletionService();
      final notifier = BookDataNotifier(null, null, null, null, null, fake);

      notifier.removeUserBook('ub-1');
      await pumpEventQueue();

      expect(fake.plans, hasLength(1));
      expect(fake.plans.single.userBookId, 'ub-1');
      expect(fake.plans.single.steps, BookDeletionStep.values);
    });

    test('state.userBooks からは即時に消える（既存契約の維持）', () {
      final fake = _FakeBookDeletionService();
      final notifier = BookDataNotifier(null, null, null, null, null, fake);
      notifier.addUserBook(_userBook('ub-1'));
      notifier.addUserBook(_userBook('ub-2'));

      notifier.removeUserBook('ub-1');

      // 同期直後（await 前）に既に消えている
      expect(notifier.state.userBooks.map((ub) => ub.id), ['ub-2']);
    });

    test('service が throw しても removeUserBook は落ちない', () async {
      final fake = _FakeBookDeletionService()..shouldThrow = true;
      final notifier = BookDataNotifier(null, null, null, null, null, fake);
      notifier.addUserBook(_userBook('ub-1'));

      expect(() => notifier.removeUserBook('ub-1'), returnsNormally);
      await pumpEventQueue();

      expect(notifier.state.userBooks, isEmpty);
    });

    test('service 未指定（既存呼出）でも removeUserBook は従来どおり動く', () {
      final notifier = BookDataNotifier();
      notifier.addUserBook(_userBook('ub-1'));

      expect(() => notifier.removeUserBook('ub-1'), returnsNormally);
      expect(notifier.state.userBooks, isEmpty);
    });

    test('trophyCleanup は Notifier 側の1回だけ呼ばれる（二重削除なし）', () async {
      final fake = _FakeBookDeletionService();
      final notifier = BookDataNotifier(null, null, null, null, null, fake);
      final cleaned = <String>[];
      notifier.trophyCleanup = cleaned.add;

      notifier.removeUserBook('ub-1');
      await pumpEventQueue();

      expect(cleaned, ['ub-1']);
    });
  });
}
