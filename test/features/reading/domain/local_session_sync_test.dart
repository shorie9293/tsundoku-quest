import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/reading/data/local_session_sync_executor.dart';
import 'package:tsundoku_quest/features/reading/domain/local_session_sync.dart';

/// 純粋層（LocalSessionSyncPlanner / isAlreadyPresentError）と
/// 実行層（LocalSessionSyncExecutor）の意味論を固定する試練。
///
/// 受入基準の不変条件だけを撃つ（実装の内部手順ではなく）:
/// - 冪等: 同じ plan を2回 run しても終端状態が同一
/// - データ消失なし: 反映できていないローカル行は消さない
/// - 部分失敗で継続: 1件の失敗が残りを止めない・throw しない
ReadingSession _session(
  String id, {
  int? durationMinutes = 60,
  String? endedAt = '2026-11-10T01:00:00.000Z',
}) =>
    ReadingSession(
      id: id,
      userBookId: 'ub-1',
      startedAt: '2026-11-10T00:00:00.000Z',
      endedAt: endedAt,
      startPage: 0,
      endPage: 100,
      durationMinutes: durationMinutes,
      createdAt: '2026-11-10T00:00:00.000Z',
    );

/// PostgrestException 相当（純粋層は Supabase 型を知らないので偽装で撃つ）
class _FakePostgrestException implements Exception {
  _FakePostgrestException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => 'PostgrestException(message: $message, code: $code)';
}

/// code / message だけを持つ最小の重複キー例外
class _CodeOnlyException implements Exception {
  _CodeOnlyException(this.code);
  final String code;
  @override
  String toString() => 'unexpected failure';
}

class _MessageOnlyException implements Exception {
  _MessageOnlyException(this.message);
  final String message;
  @override
  String toString() => 'unexpected failure';
}

void main() {
  group('LocalSessionSyncPlanner.plan', () {
    test('完了データだけを entries に載せ、未完了は同期対象にしない', () {
      final plan = LocalSessionSyncPlanner.plan(
        markedIds: ['local:a', 'local:b', 'local:c', 'local:d'],
        rawById: {
          'a': _session('a'),
          // duration 欠落
          'b': _session('b', durationMinutes: null),
          // endedAt 欠落
          'c': _session('c', endedAt: null),
          'd': _session('d', durationMinutes: 5),
        },
      );

      expect(plan.entries.map((e) => e.rawId), ['a', 'd'],
          reason: 'duration と endedAt が揃った行だけ同期する');
      expect(plan.entries.map((e) => e.session.id), ['a', 'd']);
      expect(plan.orphanMarkedIds, isEmpty,
          reason: '未完了は印の掃除対象でもない（次回同期で完了し得る）');
    });

    test('元キー行が無い印は orphanMarkedIds に載る（印だけ掃除する）', () {
      final plan = LocalSessionSyncPlanner.plan(
        markedIds: ['local:gone', 'local:here'],
        rawById: {'here': _session('here')},
      );

      expect(plan.entries.map((e) => e.rawId), ['here']);
      expect(plan.orphanMarkedIds, ['local:gone']);
    });

    test('印でない id は entries にも orphan にも載らない', () {
      final plan = LocalSessionSyncPlanner.plan(
        markedIds: ['remote-1', 'local:ok'],
        rawById: {'remote-1': _session('remote-1'), 'ok': _session('ok')},
      );

      expect(plan.entries.map((e) => e.rawId), ['ok']);
      expect(plan.orphanMarkedIds, isEmpty);
    });

    test('順序は markedIds の順で安定し、同一入力2回で同一結果', () {
      final markedIds = ['local:z', 'local:m', 'local:a'];
      final rawById = {
        'z': _session('z'),
        'm': _session('m'),
        'a': _session('a'),
      };

      final first = LocalSessionSyncPlanner.plan(
        markedIds: markedIds,
        rawById: rawById,
      );
      final second = LocalSessionSyncPlanner.plan(
        markedIds: markedIds,
        rawById: rawById,
      );

      expect(first.entries.map((e) => e.rawId).toList(), ['z', 'm', 'a']);
      expect(second.entries.map((e) => e.rawId).toList(),
          first.entries.map((e) => e.rawId).toList());
      expect(second.orphanMarkedIds, first.orphanMarkedIds);
      for (var i = 0; i < first.entries.length; i++) {
        expect(identical(first.entries[i].session, second.entries[i].session),
            isTrue,
            reason: '同一入力からは同一セッション実体を参照する（順序・内容が揺れない）');
      }
    });

    test('空入力は空 plan（no-op）', () {
      final plan =
          LocalSessionSyncPlanner.plan(markedIds: const [], rawById: {});
      expect(plan.entries, isEmpty);
      expect(plan.orphanMarkedIds, isEmpty);
      expect(plan.isEmpty, isTrue);
    });

    test('entry の markedId は local: 前置きを復元できる', () {
      final plan = LocalSessionSyncPlanner.plan(
        markedIds: ['local:abc'],
        rawById: {'abc': _session('abc')},
      );
      expect(plan.entries.single.markedId, 'local:abc');
    });
  });

  group('LocalSessionSyncPlanner.decideAfterPush', () {
    test('成功（error == null）はローカル行を削除する', () {
      expect(
        LocalSessionSyncPlanner.decideAfterPush(),
        SessionSyncDecision.deleteLocal,
      );
      expect(
        LocalSessionSyncPlanner.decideAfterPush(error: null),
        SessionSyncDecision.deleteLocal,
      );
    });

    test('重複キーは「反映済み」と解釈しローカル行を削除する', () {
      final error = _FakePostgrestException(
        code: '23505',
        message: 'duplicate key value violates unique constraint '
            '"reading_sessions_pkey"',
      );
      expect(
        LocalSessionSyncPlanner.decideAfterPush(error: error),
        SessionSyncDecision.deleteLocal,
        reason: '同一 PK が既にある＝リモートへは反映済み。再送は永久に失敗する',
      );
    });

    test('無関係なエラーはローカル行を残す（データ消失防止）', () {
      expect(
        LocalSessionSyncPlanner.decideAfterPush(error: Exception('offline')),
        SessionSyncDecision.keepLocal,
      );
    });
  });

  group('isAlreadyPresentError', () {
    test('code が 23505 の例外は重複キー（PostgrestException 相当）', () {
      expect(
        isAlreadyPresentError(
          _FakePostgrestException(
            code: '23505',
            message: 'duplicate key value violates unique constraint '
                '"reading_sessions_pkey"',
          ),
        ),
        isTrue,
      );
      expect(isAlreadyPresentError(_CodeOnlyException('23505')), isTrue,
          reason: 'message が無くても code だけで判定できる');
    });

    test('メッセージ文字列の一致でも重複キーと判定する', () {
      expect(
        isAlreadyPresentError(_MessageOnlyException(
          'duplicate key value violates unique constraint "x_pkey"',
        )),
        isTrue,
      );
      expect(
        isAlreadyPresentError(
          _MessageOnlyException('new row violates unique constraint'),
        ),
        isTrue,
      );
      expect(isAlreadyPresentError('postgres error 23505'), isTrue,
          reason: '文字列そのものも受け取れる');
    });

    test('無関係な例外・文字列は false', () {
      expect(isAlreadyPresentError(Exception('network timeout')), isFalse);
      expect(isAlreadyPresentError(StateError('Session not found')), isFalse);
      expect(isAlreadyPresentError('connection refused'), isFalse);
      expect(isAlreadyPresentError(_CodeOnlyException('42501')), isFalse);
    });
  });

  group('LocalSessionSyncExecutor.run', () {
    test('部分成功: removeLocal が投げても throw せず failed に載り残りを継続する', () async {
      final pushed = <String>[];
      final removed = <String>[];
      final executor = LocalSessionSyncExecutor(
        push: (session) async => pushed.add(session.id),
        removeLocal: (rawId, markedId) async {
          removed.add(rawId);
          if (rawId == 'a') throw StateError('hive delete failed');
        },
      );
      final plan = LocalSessionSyncPlanner.plan(
        markedIds: ['local:a', 'local:b'],
        rawById: {'a': _session('a'), 'b': _session('b')},
      );

      final report = await executor.run(plan);

      expect(pushed, ['a', 'b'], reason: '1件目の失敗で残りを止めない');
      expect(report.pushed, 2);
      expect(report.failed, 1, reason: '掃除に失敗した1件を failed に載せる');
      expect(report.failedRawIds, ['a']);
      expect(report.cleaned, 1, reason: 'b の掃除は成功している');
    });

    test('重複キーは alreadyPresent に載り、removeLocal が呼ばれる', () async {
      final removed = <String>[];
      final executor = LocalSessionSyncExecutor(
        push: (session) async => throw _FakePostgrestException(
          code: '23505',
          message: 'duplicate key value violates unique constraint',
        ),
        removeLocal: (rawId, markedId) async => removed.add(markedId),
      );
      final plan = LocalSessionSyncPlanner.plan(
        markedIds: ['local:a'],
        rawById: {'a': _session('a')},
      );

      final report = await executor.run(plan);

      expect(report.alreadyPresent, 1);
      expect(report.pushed, 0);
      expect(report.failed, 0);
      expect(report.cleaned, 1);
      expect(removed, ['local:a'], reason: '印→元キーの順で渡す');
    });

    test('無関係なエラーは keepLocal（removeLocal を呼ばない＝データ消失防止）', () async {
      final removed = <String>[];
      final executor = LocalSessionSyncExecutor(
        push: (session) async => throw Exception('offline'),
        removeLocal: (rawId, markedId) async => removed.add(rawId),
      );
      final plan = LocalSessionSyncPlanner.plan(
        markedIds: ['local:a'],
        rawById: {'a': _session('a')},
      );

      final report = await executor.run(plan);

      expect(report.failed, 1);
      expect(report.failedRawIds, ['a']);
      expect(report.cleaned, 0);
      expect(removed, isEmpty, reason: '反映できていない行を消してはならない');
    });

    test('同一 plan を2回 run しても終端状態が同一（冪等）', () async {
      final remote = <String>{};
      final local = <String>{'a', 'b'};
      final executor = LocalSessionSyncExecutor(
        push: (session) async {
          if (!remote.add(session.id)) {
            throw _FakePostgrestException(
              code: '23505',
              message: 'duplicate key value violates unique constraint',
            );
          }
        },
        removeLocal: (rawId, markedId) async => local.remove(rawId),
      );
      final plan = LocalSessionSyncPlanner.plan(
        markedIds: ['local:a', 'local:b'],
        rawById: {'a': _session('a'), 'b': _session('b')},
      );

      final first = await executor.run(plan);
      final second = await executor.run(plan);

      expect(first.pushed, 2);
      expect(first.cleaned, 2);
      expect(second.pushed, 0);
      expect(second.alreadyPresent, 2, reason: '2回目は重複キー→反映済みとして扱う');
      expect(local, isEmpty, reason: '終端状態は1回目と同じ（ローカル行なし）');
      expect(remote, {'a', 'b'}, reason: 'リモートの行は増えない');
    });

    test('orphan の印だけを掃除し、push はしない', () async {
      final pushed = <String>[];
      final removed = <String>[];
      final executor = LocalSessionSyncExecutor(
        push: (session) async => pushed.add(session.id),
        removeLocal: (rawId, markedId) async => removed.add(markedId),
      );
      final plan = LocalSessionSyncPlanner.plan(
        markedIds: ['local:gone'],
        rawById: const {},
      );

      final report = await executor.run(plan);

      expect(pushed, isEmpty);
      expect(removed, ['local:gone']);
      expect(report.cleaned, 1);
      expect(report.failed, 0);
    });

    test('空 plan は何もしない', () async {
      var calls = 0;
      final executor = LocalSessionSyncExecutor(
        push: (session) async => calls++,
        removeLocal: (rawId, markedId) async => calls++,
      );

      final report = await executor.run(LocalSessionSyncPlanner.plan(
        markedIds: const [],
        rawById: const {},
      ));

      expect(calls, 0);
      expect(report.pushed, 0);
      expect(report.cleaned, 0);
      expect(report.failed, 0);
    });
  });
}
