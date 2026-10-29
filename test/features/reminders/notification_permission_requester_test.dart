import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import 'package:tsundoku_quest/features/reminders/data/local_notification_scheduler.dart';
import 'package:tsundoku_quest/features/reminders/data/notification_permission_requester.dart';
import 'package:tsundoku_quest/features/reminders/data/reminder_providers.dart';
import 'package:tsundoku_quest/features/reminders/data/reminder_settings_repository.dart';
import 'package:tsundoku_quest/features/reminders/presentation/reminder_settings_screen.dart';

/// 通知権限の要求導線の試練。
///
/// Android 13+ では POST_NOTIFICATIONS を要求しない限り通知が出ないため、
/// 「要求が呼ばれた/呼ばれない」を画面の振る舞いとして固定する。
class _FakeRequester implements NotificationPermissionRequester {
  _FakeRequester(this.status);

  final NotificationPermissionStatus status;
  int ensureCalls = 0;
  int openSettingsCalls = 0;
  final List<bool> alreadyAskedArgs = <bool>[];

  @override
  Future<NotificationPermissionStatus> ensure({
    required bool alreadyAsked,
  }) async {
    ensureCalls++;
    alreadyAskedArgs.add(alreadyAsked);
    return status;
  }

  @override
  Future<void> openAppSettings() async {
    openSettingsCalls++;
  }
}

class _FakePlatform implements NotificationPermissionPlatform {
  _FakePlatform({
    this.enabled,
    this.androidRequestResult,
    this.iosRequestResult,
    this.throwOnStatus = false,
  });

  final bool? enabled;
  final bool? androidRequestResult;
  final bool? iosRequestResult;
  final bool throwOnStatus;

  int androidRequestCalls = 0;
  int iosRequestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<bool?> areNotificationsEnabled() async {
    if (throwOnStatus) throw StateError('channel failure');
    return enabled;
  }

  @override
  Future<bool?> requestNotificationsPermission() async {
    androidRequestCalls++;
    return androidRequestResult;
  }

  @override
  Future<bool?> requestIosPermissions() async {
    iosRequestCalls++;
    return iosRequestResult;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
  }
}

class _FakeRepo implements ReminderSettingsRepository {
  _FakeRepo(this.stored);

  ReadingReminderSettings stored;

  @override
  Future<ReadingReminderSettings> load() async => stored;

  @override
  Future<void> save(ReadingReminderSettings settings) async {
    stored = settings;
  }
}

class _FakeScheduler implements LocalNotificationScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String body,
  }) async {}

  @override
  Future<void> cancel() async {}
}

Widget _testApp({
  required NotificationPermissionRequester? requester,
  bool enabled = false,
}) {
  return ProviderScope(
    overrides: [
      hiveReminderSettingsRepositoryProvider
          .overrideWithValue(_FakeRepo(ReadingReminderSettings(enabled: enabled))),
      localNotificationSchedulerProvider.overrideWithValue(_FakeScheduler()),
    ],
    child: MaterialApp(
      home: ReminderSettingsScreen(permissionRequester: requester),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('画面を開くと権限要求がちょうど1回・alreadyAsked=false で呼ばれる',
      (tester) async {
    final requester = _FakeRequester(NotificationPermissionStatus.granted);
    await tester.pumpWidget(_testApp(requester: requester));
    await tester.pumpAndSettle();

    expect(requester.ensureCalls, 1);
    expect(requester.alreadyAskedArgs, <bool>[false]);
  });

  testWidgets('許可済み（granted）なら拒否バナーを出さない', (tester) async {
    await tester.pumpWidget(
      _testApp(requester: _FakeRequester(NotificationPermissionStatus.granted)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.reminderPermissionBanner), findsNothing);
  });

  testWidgets('リマインダーをONにすると権限要求が追加で呼ばれる', (tester) async {
    final requester = _FakeRequester(NotificationPermissionStatus.granted);
    await tester.pumpWidget(_testApp(requester: requester));
    await tester.pumpAndSettle();
    expect(requester.ensureCalls, 1);

    await tester.tap(find.byKey(AppKeys.reminderEnabledSwitch));
    await tester.pumpAndSettle();

    expect(requester.ensureCalls, 2);
  });

  testWidgets('リマインダーをOFFにしても権限要求は呼ばれない', (tester) async {
    final requester = _FakeRequester(NotificationPermissionStatus.granted);
    await tester.pumpWidget(_testApp(requester: requester, enabled: true));
    await tester.pumpAndSettle();
    expect(requester.ensureCalls, 1);

    await tester.tap(find.byKey(AppKeys.reminderEnabledSwitch));
    await tester.pumpAndSettle();

    expect(requester.ensureCalls, 1);
  });

  testWidgets('拒否（denied）なら恒久バナーが出て「設定を開く」で設定画面へ誘導する',
      (tester) async {
    final requester = _FakeRequester(NotificationPermissionStatus.denied);
    await tester.pumpWidget(_testApp(requester: requester));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.reminderPermissionBanner), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.reminderPermissionSettingsButton));
    await tester.pumpAndSettle();

    expect(requester.openSettingsCalls, 1);
  });

  testWidgets('恒久拒否（permanentlyDenied）でもバナーが出る', (tester) async {
    await tester.pumpWidget(
      _testApp(
        requester:
            _FakeRequester(NotificationPermissionStatus.permanentlyDenied),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.reminderPermissionBanner), findsOneWidget);
  });

  testWidgets('requester 未注入なら要求もバナーも出さない（従来挙動）', (tester) async {
    await tester.pumpWidget(_testApp(requester: null));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.reminderPermissionBanner), findsNothing);
    expect(find.byKey(AppKeys.reminderEnabledSwitch), findsOneWidget);
  });

  group('PlatformNotificationPermissionRequester', () {
    test('許可済みなら要求せず granted', () async {
      final platform = _FakePlatform(enabled: true, androidRequestResult: false);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.granted,
      );
      expect(platform.androidRequestCalls, 0);
    });

    test('alreadyAsked=true なら要求せず denied', () async {
      final platform = _FakePlatform(enabled: false);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      expect(
        await requester.ensure(alreadyAsked: true),
        NotificationPermissionStatus.denied,
      );
      expect(platform.androidRequestCalls, 0);
    });

    test('要求して許可されれば granted', () async {
      final platform = _FakePlatform(enabled: false, androidRequestResult: true);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.granted,
      );
      expect(platform.androidRequestCalls, 1);
    });

    test('要求が拒否されたら permanentlyDenied', () async {
      final platform =
          _FakePlatform(enabled: false, androidRequestResult: false);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.permanentlyDenied,
      );
    });

    test('例外は握って denied', () async {
      final requester = PlatformNotificationPermissionRequester(
        platform: _FakePlatform(throwOnStatus: true),
      );

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.denied,
      );
    });

    test('非対応プラットフォームは unsupported', () async {
      final requester = PlatformNotificationPermissionRequester(
        platform: _FakePlatform(enabled: null, iosRequestResult: null),
      );

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.unsupported,
      );
    });

    test('iOS の要求結果を反映する', () async {
      final platform = _FakePlatform(enabled: null, iosRequestResult: true);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      expect(
        await requester.ensure(alreadyAsked: false),
        NotificationPermissionStatus.granted,
      );
      expect(platform.iosRequestCalls, 1);
    });

    test('openAppSettings は例外を投げない', () async {
      final platform = _FakePlatform(enabled: false);
      final requester =
          PlatformNotificationPermissionRequester(platform: platform);

      await requester.openAppSettings();

      expect(platform.openSettingsCalls, 1);
    });
  });
}
