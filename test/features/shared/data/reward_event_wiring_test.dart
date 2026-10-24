import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/data/daily_mission_provider.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_reward_event_exporter.dart';
import 'package:tsundoku_quest/features/shared/providers/reward_event_exporter_provider.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';
import 'package:tsundoku_quest/main.dart' show wireRewardEventExporter;
import 'package:tsundoku_quest/shared/providers/adventurer_provider.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

/// ──────────────────────────────────────────────────────────
/// 起動時配線の統合試練
///
/// 検証する3点（これが無いと実機で一度も書き出されない）:
///   1. main.dart の ProviderScope override → 4 Notifier が同一 exporter を持つ
///   2. Provider注入 → Notifier到達 → 実ファイル1行（rpg契約を満たす）
///   3. 認証状態の購読 → userId 追随 / 空userIdなら書き出さない
///
/// rpg-task 側契約の写しは reward_event_contract_test.dart と同じ。
/// ──────────────────────────────────────────────────────────
class _RpgContractViolation implements Exception {
  final String message;
  const _RpgContractViolation(this.message);
  @override
  String toString() => 'FormatException相当: $message';
}

/// rpg の `CrossAppRewardEvent.fromJson` と等価な最低限の検証。
Map<String, dynamic> _verifyRpgContract(Map<String, dynamic> json) {
  final eventId = json['event_id'];
  final eventType = json['event_type'];
  final timestamp = json['timestamp'];
  final userId = json['user_id'];

  if (eventId is! String || eventId.isEmpty) {
    throw const _RpgContractViolation('event_id は必須です');
  }
  if (eventType is! String || eventType.isEmpty) {
    throw const _RpgContractViolation('event_type は必須です');
  }
  if (timestamp is! String || DateTime.tryParse(timestamp) == null) {
    throw _RpgContractViolation('timestamp が不正です: $timestamp');
  }
  if (userId is! String || userId.isEmpty) {
    throw const _RpgContractViolation('user_id は必須です');
  }
  final metadata = json['metadata'];
  if (metadata != null && metadata is! Map<String, dynamic>) {
    throw const _RpgContractViolation('metadata は Map である必要があります');
  }
  return metadata as Map<String, dynamic>? ?? <String, dynamic>{};
}

Future<List<String>> _readLines(String path) async {
  final file = File(path);
  if (!await file.exists()) return const [];
  final content = await file.readAsString();
  return content.split('\n').where((l) => l.trim().isNotEmpty).toList();
}

/// Notifier は書き出しを await しないため、行が現れるまで待つ。
Future<List<String>> _waitForLines(
  String path,
  int expected, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  var lines = await _readLines(path);
  while (lines.length < expected && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    lines = await _readLines(path);
  }
  return lines;
}

void main() {
  late Directory tmpDir;
  late String filePath;
  late TsundokuRewardEventExporter exporter;

  setUpAll(() {
    tmpDir = Directory.systemTemp.createTempSync('reward_wiring_test_');
  });

  tearDownAll(() async {
    try {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    filePath =
        '${tmpDir.path}/wiring_events_${DateTime.now().microsecondsSinceEpoch}.jsonl';
    exporter = TsundokuRewardEventExporter(
      filePath: filePath,
      userId: 'user-wiring-1',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ── 1. ProviderScope override → 4 Notifier が同一 exporter ──────────
  group('起動時配線: ProviderScope override', () {
    test('4つの Notifier が override した同一 exporter を受け取る', () async {
      final container = ProviderContainer(
        overrides: [
          tsundokuRewardEventExporterProvider.overrideWithValue(exporter),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(tsundokuRewardEventExporterProvider),
        same(exporter),
        reason: 'override が効いていない',
      );
      expect(
        container.read(adventurerProvider.notifier).rewardExporter,
        same(exporter),
        reason: 'adventurerProvider に override が届いていない',
      );
      expect(
        container.read(bookDataProvider.notifier).rewardExporter,
        same(exporter),
        reason: 'bookDataProvider に override が届いていない',
      );
      expect(
        container.read(warTrophyProvider.notifier).rewardExporter,
        same(exporter),
        reason: 'warTrophyProvider に override が届いていない',
      );
      expect(
        container.read(dailyMissionProvider.notifier).rewardExporter,
        same(exporter),
        reason: 'dailyMissionProvider に override が届いていない',
      );

      // DailyMissionNotifier の非同期初期化が dispose 後に走らないよう待つ
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });

  // ── 2. Provider注入 → Notifier到達 → 実ファイル ─────────────────────
  group('end-to-end: 読了イベントが実ファイルに1行追記される', () {
    test('bookDataProvider 経由の読了で rpg 契約を満たす行が書かれる', () async {
      final container = ProviderContainer(
        overrides: [
          tsundokuRewardEventExporterProvider.overrideWithValue(exporter),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(bookDataProvider.notifier);
      // Provider 注入経路の確認（Notifier が保持する exporter を取り出す）
      expect(notifier.rewardExporter, same(exporter));

      notifier.addUserBook(
        UserBook(
          id: 'ub-1',
          userId: 'user-wiring-1',
          bookId: 'b-1',
          book: const Book(
            id: 'b-1',
            title: '走れメロス',
            authors: ['太宰治'],
            source: BookSource.manual,
            createdAt: '2026-10-24T00:00:00Z',
          ),
          status: BookStatus.reading,
          medium: BookMedium.physical,
          createdAt: '2026-10-24T00:00:00Z',
        ),
      );
      // 読了へ遷移（Notifier の公開メソッドで発火）
      notifier.updateUserBook(id: 'ub-1', status: BookStatus.completed);

      final lines = await _waitForLines(filePath, 1);
      expect(lines.length, 1, reason: '読了イベントが1行も書き出されていない');

      final json = jsonDecode(lines.single) as Map<String, dynamic>;
      final metadata = _verifyRpgContract(json); // 例外なら rpg 側で行が捨てられる
      expect(json['event_type'], 'book_completed');
      expect(json['user_id'], 'user-wiring-1');
      expect(DateTime.tryParse(json['timestamp'] as String), isNotNull);
      expect(metadata['count'], 1, reason: 'rpg は metadata["count"] で回数を数える');

      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });

  // ── 3. 起動時配線: 認証状態の購読 ──────────────────────────────────
  group('wireRewardEventExporter', () {
    test('サインインで userId が入り、サインアウトで空に戻る', () async {
      final controller = StreamController<String?>();
      addTearDown(controller.close);
      final e = TsundokuRewardEventExporter(filePath: filePath);

      wireRewardEventExporter(exporter: e, userIdChanges: controller.stream);

      controller.add('user-signed-in');
      await Future<void>.delayed(Duration.zero);
      expect(e.userId, 'user-signed-in');

      controller.add(null); // サインアウト相当
      await Future<void>.delayed(Duration.zero);
      expect(e.userId, '');
    });

    test('ストリーム未指定・Supabase未初期化でも例外を投げない', () {
      final e = TsundokuRewardEventExporter(filePath: filePath);
      expect(() => wireRewardEventExporter(exporter: e), returnsNormally);
      expect(e.userId, '');
    });
  });

  // ── 4. userId 空ガードの統合確認 ───────────────────────────────────
  group('userId空ガード（統合）', () {
    test('userId が空のまま Notifier 経由で読了しても行数が増えない', () async {
      final anonymous = TsundokuRewardEventExporter(filePath: filePath);
      expect(anonymous.userId, '');

      final container = ProviderContainer(
        overrides: [
          tsundokuRewardEventExporterProvider.overrideWithValue(anonymous),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(bookDataProvider.notifier);
      notifier.addUserBook(
        UserBook(
          id: 'ub-anon',
          userId: 'anonymous',
          bookId: 'b-anon',
          book: const Book(
            id: 'b-anon',
            title: '匿名の書',
            source: BookSource.manual,
            createdAt: '2026-10-24T00:00:00Z',
          ),
          status: BookStatus.reading,
          medium: BookMedium.physical,
          createdAt: '2026-10-24T00:00:00Z',
        ),
      );
      notifier.updateUserBook(id: 'ub-anon', status: BookStatus.completed);

      // 書き出しは非同期 — 反映猶予を与えてから行数を数える
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final lines = await _readLines(filePath);
      expect(lines, isEmpty, reason: 'userId 空では1行も書いてはならない');

      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}
