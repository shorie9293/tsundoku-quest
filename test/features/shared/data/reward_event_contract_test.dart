import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/features/bookshelf/data/daily_mission_provider.dart';
import 'package:tsundoku_quest/features/shared/data/reward_event_user_linker.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_reward_event_exporter.dart';
import 'package:tsundoku_quest/features/shared/providers/reward_event_exporter_provider.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';
import 'package:tsundoku_quest/shared/providers/adventurer_provider.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

/// ──────────────────────────────────────────────────────────
/// rpg-task 側の消費契約を写したローカル検証
///
/// 参照: rpg-task/lib/features/crossapp/domain/cross_app_reward_event.dart
///       (`CrossAppRewardEvent.fromJson` / `parseLine`)
///       rpg-task/lib/features/crossapp/data/cross_app_reward_service.dart
///       (metadata['count'|'streak_days'|'xp'|'pages'] を報酬計算に使用)
///
/// rpg-task は別リポジトリのため import できない。契約だけを写す。
/// ──────────────────────────────────────────────────────────
class _RpgContractViolation implements Exception {
  final String message;
  const _RpgContractViolation(this.message);
  @override
  String toString() => 'FormatException相当: $message';
}

/// rpg の `CrossAppRewardEvent.fromJson` と等価な検証。
/// 例外が出なければ rpg 側でも行が受理される（=報酬ゼロにならない）。
Map<String, dynamic> verifyRpgContract(Map<String, dynamic> json) {
  final eventId = json['event_id'];
  final eventType = json['event_type'];
  final timestampStr = json['timestamp'];
  final userId = json['user_id'];

  if (eventId is! String || eventId.isEmpty) {
    throw const _RpgContractViolation('event_id は必須です');
  }
  if (eventType is! String || eventType.isEmpty) {
    throw const _RpgContractViolation('event_type は必須です');
  }
  if (timestampStr is! String || timestampStr.isEmpty) {
    throw const _RpgContractViolation('timestamp は必須です');
  }
  if (userId is! String || userId.isEmpty) {
    throw const _RpgContractViolation('user_id は必須です');
  }
  if (DateTime.tryParse(timestampStr) == null) {
    throw _RpgContractViolation('timestamp の形式が不正です: $timestampStr');
  }
  final metadata = json['metadata'];
  if (metadata != null && metadata is! Map<String, dynamic>) {
    throw const _RpgContractViolation('metadata は Map である必要があります');
  }
  return metadata as Map<String, dynamic>? ?? <String, dynamic>{};
}

/// rpg の `parseLine` 相当
Map<String, dynamic> verifyRpgLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) throw const _RpgContractViolation('空行です');
  final decoded = jsonDecode(trimmed);
  if (decoded is! Map<String, dynamic>) {
    throw const _RpgContractViolation('JSON オブジェクトではありません');
  }
  verifyRpgContract(decoded);
  return decoded;
}

Future<List<Map<String, dynamic>>> _readJsonl(String path) async {
  final file = File(path);
  if (!await file.exists()) return [];
  final content = await file.readAsString();
  return content
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .map((l) => jsonDecode(l) as Map<String, dynamic>)
      .toList();
}

void main() {
  late Directory tmpDir;
  late String filePath;
  late TsundokuRewardEventExporter exporter;

  setUpAll(() {
    tmpDir = Directory.systemTemp.createTempSync('reward_contract_test_');
  });

  tearDownAll(() async {
    try {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    filePath = '${tmpDir.path}/contract_events_${DateTime.now().microsecondsSinceEpoch}.jsonl';
    exporter = TsundokuRewardEventExporter(
      filePath: filePath,
      userId: 'user-contract-1',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ── 1. 契約フィールドが全種別で揃う ──────────────────────
  group('rpg契約: 全イベント種別のフィールド', () {
    /// 種別 → (書き出し実行, metadataに必須のキー, 既存トップレベルで残すべきキー)
    Future<Map<String, dynamic>> writeOne(String type) async {
      switch (type) {
        case 'book_completed':
          await exporter.exportBookCompleted(bookId: 'b-1', bookTitle: 'メロス');
        case 'reading_streak':
          await exporter.exportReadingStreak(streak: 30);
        case 'level_up':
          await exporter.exportLevelUp(newLevel: 5, title: '見習い冒険者');
        case 'xp_milestone':
          await exporter.exportXpMilestone(milestone: 1000, totalXp: 1500);
        case 'trophy_written':
          await exporter.exportTrophyWritten(
            trophyId: 't-1',
            userBookId: 'ub-1',
            learningCount: 3,
          );
        case 'daily_mission_complete':
          await exporter.exportDailyMissionComplete(
            date: '2026-10-24',
            completedCount: 5,
            totalCount: 5,
          );
        case 'pages_milestone':
          await exporter.exportPagesMilestone(milestone: 1000, totalPages: 5000);
        default:
          fail('未知の種別: $type');
      }
      final lines = await _readJsonl(filePath);
      expect(lines.length, 1, reason: '$type は1行だけ書かれるべき');
      return lines.single;
    }

    final expectedMetadataKeys = <String, List<String>>{
      'book_completed': ['count'],
      'reading_streak': ['streak_days'],
      'level_up': [], // 意味のある metadata（空でも可）
      'xp_milestone': ['xp'],
      'trophy_written': [], // 空でも可
      'daily_mission_complete': ['completed', 'total'],
      'pages_milestone': ['pages'],
    };

    for (final type in expectedMetadataKeys.keys) {
      test('$type: event_id/event_type/timestamp/user_id/metadata が揃う', () async {
        final json = await writeOne(type);

        // rpg の fromJson 相当の検証（例外が出たら報酬ゼロ）
        final metadata = verifyRpgContract(json);

        expect(json['event_type'], type);
        expect(DateTime.tryParse(json['timestamp'] as String), isNotNull);
        expect(json['user_id'], isNotEmpty);
        for (final key in expectedMetadataKeys[type]!) {
          expect(metadata.containsKey(key), isTrue,
              reason: '$type の metadata に "$key" が必要（rpg の報酬計算キー）');
          expect(metadata[key], isA<int>(), reason: 'rpg は as int? で読む');
        }
      });
    }

    test('metadata の値が既存トップレベル値と一致する（後方互換）', () async {
      await exporter.exportReadingStreak(streak: 42);
      await exporter.exportXpMilestone(milestone: 500, totalXp: 8000);
      await exporter.exportPagesMilestone(milestone: 500, totalPages: 2600);
      await exporter.exportBookCompleted(bookId: 'b-9', bookTitle: 't');
      await exporter.exportDailyMissionComplete(
        date: '2026-10-24',
        completedCount: 3,
        totalCount: 4,
      );

      final lines = await _readJsonl(filePath);
      expect(lines.length, 5);

      final streak = lines[0];
      expect(streak['streak'], 42); // 既存フィールド維持
      expect((streak['metadata'] as Map)['streak_days'], 42);

      final xp = lines[1];
      expect(xp['total_xp'], 8000);
      expect(xp['milestone'], 500);
      expect((xp['metadata'] as Map)['xp'], 8000);

      final pages = lines[2];
      expect(pages['total_pages'], 2600);
      expect(pages['milestone'], 500);
      expect((pages['metadata'] as Map)['pages'], 2600);

      final book = lines[3];
      expect(book['book_id'], 'b-9');
      expect((book['metadata'] as Map)['count'], 1);

      final daily = lines[4];
      expect(daily['completed_count'], 3);
      expect(daily['total_count'], 4);
      expect((daily['metadata'] as Map)['completed'], 3);
      expect((daily['metadata'] as Map)['total'], 4);
    });

    test('level_up / trophy_written の metadata は Map である', () async {
      await exporter.exportLevelUp(newLevel: 7, title: '熟練');
      await exporter.exportTrophyWritten(
        trophyId: 't-7',
        userBookId: 'ub-7',
        learningCount: 2,
      );
      final lines = await _readJsonl(filePath);
      expect(lines[0]['metadata'], isA<Map<String, dynamic>>());
      expect(lines[1]['metadata'], isA<Map<String, dynamic>>());
      // 既存トップレベルフィールドは残る
      expect(lines[0]['new_level'], 7);
      expect(lines[1]['learning_count'], 2);
    });
  });

  // ── 2. 往復一致（実ファイル → rpg parseLine 相当）──────────
  group('rpg契約: 実ファイル往復', () {
    test('全7種別を書き出し、全行が parseLine 相当を通過する', () async {
      await exporter.exportBookCompleted(bookId: 'b', bookTitle: '題');
      await exporter.exportReadingStreak(streak: 14);
      await exporter.exportLevelUp(newLevel: 3, title: 't');
      await exporter.exportXpMilestone(milestone: 100, totalXp: 120);
      await exporter.exportTrophyWritten(
        trophyId: 'tr',
        userBookId: 'ub',
        learningCount: 1,
      );
      await exporter.exportDailyMissionComplete(
        date: '2026-10-24',
        completedCount: 5,
        totalCount: 5,
      );
      await exporter.exportPagesMilestone(milestone: 100, totalPages: 130);

      final raw = await File(filePath).readAsString();
      final rawLines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(rawLines.length, 7);

      final parsed = rawLines.map(verifyRpgLine).toList();
      expect(parsed.map((e) => e['event_type']).toSet().length, 7);
      // event_id は一意
      expect(parsed.map((e) => e['event_id']).toSet().length, 7);
      // 全行 user_id が入っている
      expect(parsed.every((e) => e['user_id'] == 'user-contract-1'), isTrue);
    });
  });

  // ── 3. userId 空なら書き出さない ──────────────────────────
  group('userIdガード', () {
    test('userId が空なら1行も書き出さない（rpg で全滅するため）', () async {
      final anonymous = TsundokuRewardEventExporter(filePath: filePath);
      expect(anonymous.userId, '');

      await anonymous.exportLevelUp(newLevel: 2, title: 't');
      await anonymous.exportBookCompleted(bookId: 'b', bookTitle: null);
      await anonymous.exportReadingStreak(streak: 7);
      await anonymous.exportXpMilestone(milestone: 100, totalXp: 100);
      await anonymous.exportPagesMilestone(milestone: 100, totalPages: 100);
      await anonymous.exportTrophyWritten(
        trophyId: 't',
        userBookId: 'ub',
        learningCount: 1,
      );
      await anonymous.exportDailyMissionComplete(
        date: '2026-10-24',
        completedCount: 1,
        totalCount: 1,
      );

      expect(await File(filePath).exists(), isFalse,
          reason: 'userId 空ではファイル自体が作られない');
    });

    test('userId が空白のみでも書き出さない', () async {
      final blank = TsundokuRewardEventExporter(
        filePath: filePath,
        userId: '   ',
      );
      await blank.exportReadingStreak(streak: 7);
      expect(await File(filePath).exists(), isFalse);
    });

    test('userId を後から設定すれば書き出される', () async {
      final e = TsundokuRewardEventExporter(filePath: filePath);
      await e.exportReadingStreak(streak: 7); // スキップ
      e.userId = 'user-late';
      await e.exportReadingStreak(streak: 8);

      final lines = await _readJsonl(filePath);
      expect(lines.length, 1);
      expect(lines.single['user_id'], 'user-late');
    });
  });

  // ── 4. Provider が同一 exporter インスタンスを注入する ──────
  group('Provider 注入', () {
    test('tsundokuRewardEventExporterProvider は単一インスタンスを返す', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(tsundokuRewardEventExporterProvider),
        same(container.read(tsundokuRewardEventExporterProvider)),
      );
    });

    test('4つの Provider が同じ exporter を Notifier に渡す', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final shared = container.read(tsundokuRewardEventExporterProvider);

      expect(container.read(adventurerProvider.notifier).rewardExporter,
          same(shared),
          reason: 'adventurerProvider が exporter を渡していない');
      expect(container.read(bookDataProvider.notifier).rewardExporter,
          same(shared),
          reason: 'bookDataProvider が exporter を渡していない');
      expect(container.read(warTrophyProvider.notifier).rewardExporter,
          same(shared),
          reason: 'warTrophyProvider が exporter を渡していない');
      expect(container.read(dailyMissionProvider.notifier).rewardExporter,
          same(shared),
          reason: 'dailyMissionProvider が exporter を渡していない');

      // DailyMissionNotifier の初期化（SharedPreferences 保存）完了を待ってから
      // container を破棄する（dispose 後に書き込む警告を避ける）
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });

  // ── 5. linker ────────────────────────────────────────────
  group('RewardEventUserLinker', () {
    test('サインインで userId が設定され、サインアウトで空に戻る', () async {
      final e = TsundokuRewardEventExporter(filePath: filePath);
      final controller = StreamController<String?>();
      addTearDown(controller.close);

      final linker = RewardEventUserLinker(exporter: e);
      linker.bind(controller.stream);
      expect(linker.isLinked, isTrue);

      controller.add('user-signed-in');
      await Future<void>.delayed(Duration.zero);
      expect(e.userId, 'user-signed-in');

      controller.add(null); // サインアウト相当
      await Future<void>.delayed(Duration.zero);
      expect(e.userId, '');
    });

    test('ストリームが null でも bind は静かに何もしない', () {
      final e = TsundokuRewardEventExporter(filePath: filePath);
      final linker = RewardEventUserLinker(exporter: e);
      expect(() => linker.bind(null), returnsNormally);
      expect(linker.isLinked, isFalse);
      expect(e.userId, '');
    });

    test('ストリームのエラーで例外を投げない', () async {
      final e = TsundokuRewardEventExporter(filePath: filePath);
      final controller = StreamController<String?>();
      addTearDown(controller.close);

      final linker = RewardEventUserLinker(exporter: e);
      linker.bind(controller.stream);
      controller.addError(StateError('auth stream failure'));
      await Future<void>.delayed(Duration.zero);
      expect(e.userId, ''); // 変化なし・例外なし
    });

    test('unbind 後はイベントを無視する', () async {
      final e = TsundokuRewardEventExporter(filePath: filePath);
      final controller = StreamController<String?>();
      addTearDown(controller.close);

      final linker = RewardEventUserLinker(exporter: e);
      linker.bind(controller.stream);
      await linker.unbind();
      expect(linker.isLinked, isFalse);

      controller.add('user-after-unbind');
      await Future<void>.delayed(Duration.zero);
      expect(e.userId, '');
    });

    test('Supabase 未初期化でも tryCreate は例外を投げない', () {
      final e = TsundokuRewardEventExporter(filePath: filePath);
      expect(
        () => RewardEventUserLinker.tryCreateForSupabase(e),
        returnsNormally,
      );
    });
  });
}
