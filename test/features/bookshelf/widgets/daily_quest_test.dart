import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/daily_quest.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/daily_mission.dart';
import 'package:hive/hive.dart';
import 'dart:io';

Widget createTestWidget({
  required bool hasBooks,
  required VoidCallback onStartQuest,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: DailyQuest(
          hasBooks: hasBooks,
          onStartQuest: onStartQuest,
        ),
      ),
    ),
  );
}


void _initTestHive() {
  final tempDir = Directory.systemTemp.createTempSync('hive_test_');
  Hive.init(tempDir.path);
}

void main() {
  setUpAll(() {
    _initTestHive();
  });
  tearDownAll(() async {
    await Hive.close();
  });

  // SharedPreferences のテスト用モック初期化
  SharedPreferences.setMockInitialValues({});

  group('DailyQuest', () {
    testWidgets('should display quest header', (tester) async {
      await tester.pumpWidget(createTestWidget(
        hasBooks: true,
        onStartQuest: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('今日のクエスト'), findsOneWidget);
    });

    testWidgets(
        "should show '冒険をはじめる' button text when hasBooks is true",
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        hasBooks: true,
        onStartQuest: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('冒険をはじめる'), findsOneWidget);
    });

    testWidgets(
        "should show '最初の冒険の書を登録する' button text when hasBooks is false",
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        hasBooks: false,
        onStartQuest: () {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('最初の冒険の書を登録する'), findsOneWidget);
    });

    testWidgets('should call onStartQuest when button tapped',
        (tester) async {
      bool started = false;
      await tester.pumpWidget(createTestWidget(
        hasBooks: true,
        onStartQuest: () {
          started = true;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('冒険をはじめる'));
      expect(started, isTrue);
    });

    testWidgets('mission progress bar should be visible', (tester) async {
      await tester.pumpWidget(createTestWidget(
        hasBooks: true,
        onStartQuest: () {},
      ));
      await tester.pumpAndSettle();

      // LinearProgressIndicator should exist for each mission
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });
  });

  group('DailyMission', () {
    test('generateDailyMissions should return max 3 missions', () {
      final today = DateTime(2026, 6, 7);
      final missions = DailyMission.generateDailyMissions(today);
      expect(missions.length, lessThanOrEqualTo(3));
      expect(missions.isNotEmpty, isTrue);
    });

    test('generateDailyMissions should not duplicate mission types', () {
      final today = DateTime(2026, 6, 7);
      final missions = DailyMission.generateDailyMissions(today);
      final types = missions.map((m) => m.type).toSet();
      expect(types.length, missions.length);
    });

    test('addProgress should work correctly', () {
      final mission = DailyMission(
        id: 'test',
        type: DailyMissionType.readTime,
        target: 15,
        xpReward: 50,
        title: 'Test',
        description: 'Test',
        icon: '📖',
      );

      expect(mission.progress, 0.0);

      // 10分追加 → 未達成
      final completed = mission.addProgress(10);
      expect(completed, isFalse);
      expect(mission.currentProgress, 10);
      expect(mission.progress, closeTo(10 / 15, 0.01));

      // さらに10分追加 → 達成（capされる）
      final completed2 = mission.addProgress(10);
      expect(completed2, isTrue);
      expect(mission.currentProgress, 15);
      expect(mission.isCompleted, isTrue);
      expect(mission.progress, 1.0);

      // 達成済み → それ以上追加されない
      final completed3 = mission.addProgress(100);
      expect(completed3, isFalse);
      expect(mission.currentProgress, 15);
    });

    test('toJson and fromJson should round-trip', () {
      final mission = DailyMission(
        id: 'test',
        type: DailyMissionType.readPages,
        target: 50,
        xpReward: 120,
        title: 'Test',
        description: 'Desc',
        icon: '📚',
        isCompleted: true,
        currentProgress: 50,
      );

      final json = mission.toJson();
      final restored = DailyMission.fromJson(json);

      expect(restored.id, mission.id);
      expect(restored.type, mission.type);
      expect(restored.target, mission.target);
      expect(restored.xpReward, mission.xpReward);
      expect(restored.isCompleted, mission.isCompleted);
      expect(restored.currentProgress, mission.currentProgress);
    });
  });
}
