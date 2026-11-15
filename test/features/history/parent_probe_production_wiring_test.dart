import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/reading_session_adapter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/core/infrastructure/supabase/supabase_client_provider.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_provider.dart';
import 'package:tsundoku_quest/features/history/data/weekly_reading_provider.dart';
import 'package:tsundoku_quest/features/reading/data/reading_session_repository_provider.dart';

/// 親探針（本番配線）: **本番の** `readingSessionRepositoryProvider` が
/// 書き込み成功フック（単一窓口）を実際に配線しているかを撃つ。
///
/// 子の探針は Fallback を手組みするため「本番providerが窓口を渡しているか」を
/// 検証できない。ここでは Supabase を到達不能URLへ差し替えてローカル退避経路
/// （= 書き込み成功）を通し、派生Providerの再評価回数で配線の実在を測る。
class _FakeBoxManager implements BoxManagerInterface {
  @override
  Future<Box<T>> getBox<T>(String name) async => Hive.box<T>(name);

  @override
  Future<void> openAllBoxes() async {}

  @override
  Future<void> closeBox(String name) async {}

  @override
  Future<void> closeAllBoxes() async {}

  @override
  Future<void> clearBox(String name) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('parent_probe_wiring');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReadingSessionAdapter());
    }
  });

  setUp(() async {
    await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('本番provider経由: ローカル退避の書き込み成功で派生Providerが落ちる', () async {
    var habitBuilds = 0;
    var weeklyBuilds = 0;

    final container = ProviderContainer(
      overrides: [
        hiveBoxManagerProvider.overrideWithValue(_FakeBoxManager()),
        // 到達不能URL → Supabase書き込みは失敗し Hive 退避経路に入る
        supabaseClientProvider.overrideWithValue(
          SupabaseClient('http://127.0.0.1:1', 'dummy-key'),
        ),
        readingHabitSessionsProvider.overrideWith((ref) async {
          habitBuilds++;
          return <ReadingSession>[];
        }),
        weeklyReadingMinutesProvider.overrideWith((ref) async {
          weeklyBuilds++;
          return List<int>.filled(7, 0);
        }),
      ],
    );
    addTearDown(container.dispose);

    // キャッシュを温める（各1回build）
    await container.read(readingHabitSessionsProvider.future);
    await container.read(weeklyReadingMinutesProvider.future);
    expect(habitBuilds, 1);
    expect(weeklyBuilds, 1);

    // 本番providerから取り出したリポジトリで書き込み（ローカル退避＝成功）
    final repo = container.read(readingSessionRepositoryProvider);
    await repo.startSession('ub-1', 0);

    await container.read(readingHabitSessionsProvider.future);
    await container.read(weeklyReadingMinutesProvider.future);

    expect(habitBuilds, 2,
        reason: '本番providerが単一窓口を配線していればヒートマップProviderが再評価される');
    expect(weeklyBuilds, 2,
        reason: '本番providerが単一窓口を配線していれば週間グラフProviderが再評価される');
  });
}
