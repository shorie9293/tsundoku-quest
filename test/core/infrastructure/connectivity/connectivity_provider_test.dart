import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/infrastructure/connectivity/connectivity_provider.dart';
import 'package:hive/hive.dart';
import 'dart:io';


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

  TestWidgetsFlutterBinding.ensureInitialized();

  group('connectivity provider', () {
    test('isOnlineProvider should default to true when connectivity is null',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 初期状態（connectivityProvider が未評価）では true
      expect(container.read(isOnlineProvider), true);
    });
  });
}
