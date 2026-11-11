import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/core/infrastructure/cross_app_link_status.dart';

void main() {
  group('CrossAppTransferRecord', () {
    test('toJson → tryFromJson の往復で全項目が保たれる', () {
      final at = DateTime(2026, 11, 11, 9, 12);
      final record = CrossAppTransferRecord(
        at: at,
        ok: true,
        count: 3,
        fileName: 'tsundoku_reward_events.jsonl',
      );

      final back = CrossAppTransferRecord.tryFromJson(record.toJson());

      expect(back, isNotNull);
      expect(back!.at, at);
      expect(back.ok, isTrue);
      expect(back.count, 3);
      expect(back.fileName, 'tsundoku_reward_events.jsonl');
      expect(back.error, isNull);
    });

    test('失敗記録の error も往復する', () {
      final record = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9, 12),
        ok: false,
        count: 0,
        fileName: 'a.jsonl',
        error: 'boom',
      );

      final back = CrossAppTransferRecord.tryFromJson(record.toJson());

      expect(back!.ok, isFalse);
      expect(back.count, 0);
      expect(back.error, 'boom');
    });

    test('Map 以外・at 欠落・at 不正では null を返し throw しない', () {
      expect(CrossAppTransferRecord.tryFromJson(null), isNull);
      expect(CrossAppTransferRecord.tryFromJson('not-a-map'), isNull);
      expect(CrossAppTransferRecord.tryFromJson(<String, Object?>{}), isNull);
      expect(
        CrossAppTransferRecord.tryFromJson(<String, Object?>{
          'at': 'not-a-date',
        }),
        isNull,
      );
      expect(
        CrossAppTransferRecord.tryFromJson(<String, Object?>{
          'at': 123,
        }),
        isNull,
      );
    });

    test('count は num を丸め、文字列など型違いは 0 にする', () {
      final numCount = CrossAppTransferRecord.tryFromJson(<String, Object?>{
        'at': '2026-11-11T09:12:00',
        'ok': true,
        'count': 2.7,
      });
      expect(numCount!.count, 2);

      final stringCount = CrossAppTransferRecord.tryFromJson(<String, Object?>{
        'at': '2026-11-11T09:12:00',
        'count': '3',
      });
      expect(stringCount!.count, 0);
    });

    test('空の fileName / error は null、ok は true のみ真', () {
      final record = CrossAppTransferRecord.tryFromJson(<String, Object?>{
        'at': '2026-11-11T09:12:00',
        'ok': 'true',
        'file': '',
        'error': '',
      });

      expect(record!.ok, isFalse);
      expect(record.fileName, isNull);
      expect(record.error, isNull);
    });
  });

  group('CrossAppLinkSnapshot', () {
    final at = DateTime(2026, 11, 11, 9, 12);

    test('encode → decode の往復で送受信とフォルダ状態が保たれる', () {
      final snapshot = CrossAppLinkSnapshot(
        lastSent: CrossAppTransferRecord(
          at: at,
          ok: true,
          count: 3,
          fileName: 'sent.jsonl',
        ),
        lastReceived: CrossAppTransferRecord(
          at: at,
          ok: false,
          count: 0,
          fileName: 'recv.jsonl',
          error: 'read failed',
        ),
        sharedFolderReady: true,
      );

      final back = CrossAppLinkSnapshot.decode(snapshot.encode());

      expect(back.sharedFolderReady, isTrue);
      expect(back.lastSent!.count, 3);
      expect(back.lastSent!.fileName, 'sent.jsonl');
      expect(back.lastReceived!.ok, isFalse);
      expect(back.lastReceived!.error, 'read failed');
    });

    test('null・空文字・空白・破損 JSON・型違いは empty を返す', () {
      expect(CrossAppLinkSnapshot.decode(null).lastSent, isNull);
      expect(CrossAppLinkSnapshot.decode('').lastSent, isNull);
      expect(CrossAppLinkSnapshot.decode('   ').lastSent, isNull);
      expect(CrossAppLinkSnapshot.decode('{broken').lastSent, isNull);
      expect(CrossAppLinkSnapshot.decode('[1,2,3]').lastSent, isNull);
      expect(CrossAppLinkSnapshot.decode('"string"').lastSent, isNull);
    });

    test('壊れた入れ子の送信記録は null に落ち、他の項目は残る', () {
      final back = CrossAppLinkSnapshot.decode(
        '{"sharedFolderReady":true,"lastSent":{"at":"bad"},"lastReceived":null}',
      );

      expect(back.sharedFolderReady, isTrue);
      expect(back.lastSent, isNull);
      expect(back.lastReceived, isNull);
    });

    test('copyWith は指定項目だけ差し替える', () {
      final base = CrossAppLinkSnapshot(
        lastSent: CrossAppTransferRecord(at: at, ok: true, count: 1),
      );

      final copied = base.copyWith(sharedFolderReady: true);

      expect(copied.sharedFolderReady, isTrue);
      expect(copied.lastSent!.count, 1);
    });
  });

  group('CrossAppLinkStatusText', () {
    final at = DateTime(2026, 11, 11, 9, 12);

    test('time は 2026/11/11 09:12 形式、null は未記録', () {
      expect(CrossAppLinkStatusText.time(at), '2026/11/11 09:12');
      expect(CrossAppLinkStatusText.time(null), '未記録');
    });

    test('outcome は 成功・失敗・未記録', () {
      expect(
        CrossAppLinkStatusText.outcome(
          CrossAppTransferRecord(at: at, ok: true, count: 1),
        ),
        '成功',
      );
      expect(
        CrossAppLinkStatusText.outcome(
          CrossAppTransferRecord(at: at, ok: false, count: 0),
        ),
        '失敗',
      );
      expect(CrossAppLinkStatusText.outcome(null), '未記録');
    });

    test('row は 成否・時刻・件数・ファイル名を結合する', () {
      final record = CrossAppTransferRecord(
        at: at,
        ok: true,
        count: 3,
        fileName: 'tsundoku_reward_events.jsonl',
      );

      expect(
        CrossAppLinkStatusText.row(record),
        '成功・2026/11/11 09:12・3件・tsundoku_reward_events.jsonl',
      );
      expect(CrossAppLinkStatusText.row(null), '未記録');
    });

    test('row はファイル名なしなら3要素だけ', () {
      final record = CrossAppTransferRecord(at: at, ok: false, count: 0);

      expect(CrossAppLinkStatusText.row(record), '失敗・2026/11/11 09:12・0件');
    });

    test('folder は 設定済み / 未設定', () {
      expect(CrossAppLinkStatusText.folder(true), '設定済み');
      expect(CrossAppLinkStatusText.folder(false), '未設定（連携は停止中）');
    });

    test('detail は失敗理由のみ返し、長すぎれば切り詰める', () {
      expect(CrossAppLinkStatusText.detail(null), '');
      expect(
        CrossAppLinkStatusText.detail(
          CrossAppTransferRecord(at: at, ok: true, count: 1),
        ),
        '',
      );
      expect(
        CrossAppLinkStatusText.detail(
          CrossAppTransferRecord(
            at: at,
            ok: false,
            count: 0,
            error: 'boom',
          ),
        ),
        'boom',
      );

      final long = 'x' * 200;
      final truncated = CrossAppLinkStatusText.detail(
        CrossAppTransferRecord(at: at, ok: false, count: 0, error: long),
      );
      expect(truncated.length, 161);
      expect(truncated.endsWith('…'), isTrue);
    });

    test('countLines は行数を数え、null/空は 0', () {
      expect(CrossAppLinkStatusText.countLines(null), 0);
      expect(CrossAppLinkStatusText.countLines(''), 0);
      expect(CrossAppLinkStatusText.countLines('   '), 0);
      expect(CrossAppLinkStatusText.countLines('one'), 1);
      expect(CrossAppLinkStatusText.countLines('one\ntwo'), 2);
      expect(CrossAppLinkStatusText.countLines('one\ntwo\n'), 2);
      expect(CrossAppLinkStatusText.countLines('{"a":1}'), 1);
    });
  });
}
