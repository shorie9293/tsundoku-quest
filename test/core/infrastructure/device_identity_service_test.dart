import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/core/infrastructure/relink/device_identity_service.dart';

/// PostgrestFilterBuilder の型制約を回避するため、
/// rpc 呼出を記録するだけの最小スタブ。
class _StubClient extends Fake implements SupabaseClient {
  _StubClient(this.auth);

  @override
  final GoTrueClient auth;

  Object? lastRpcName;
  Map<String, dynamic>? lastRpcParams;
  Object? throwOnRpc;

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fnName, {
    dynamic get,
    Map<String, dynamic>? params,
  }) {
    lastRpcName = fnName;
    lastRpcParams = params;
    if (throwOnRpc != null) throw throwOnRpc!;
    // 実際の通信は行わないスタブ（結果は使われない前提のテストのみ）
    throw UnimplementedError('stub: RPC結果は本テストで検証しない');
  }
}

class _StubAuth extends Fake implements GoTrueClient {
  @override
  User? get currentUser => user;
  User? user;
}

class _FakeUser extends Fake implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceIdentityService', () {
    test('未認証時は RPC を呼ばずにスキップする', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = _StubAuth()..user = null;
      final client = _StubClient(auth);

      final service = DeviceIdentityService(client: client);
      await service.relinkOnStartup(); // 例外が出ないこと

      expect(client.lastRpcName, isNull);
    });

    test('UUID v4 形式で secret を生成する', () {
      final s = DeviceIdentityService.generateUuidV4();
      expect(
        RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(s),
        isTrue,
        reason: '生成値: $s',
      );
    });

    test('生成した UUID は都度異なる', () {
      expect(DeviceIdentityService.generateUuidV4(),
          isNot(DeviceIdentityService.generateUuidV4()));
    });

    test('RPC 失敗時も例外を投げず継続する', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = _StubAuth()..user = _FakeUser();
      final client = _StubClient(auth)..throwOnRpc = Exception('network error');

      final service = DeviceIdentityService(client: client);
      await expectLater(service.relinkOnStartup(), completes);
    });

    test('認証済みなら secret 付きで RPC を呼ぶ', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = _StubAuth()..user = _FakeUser();
      final client = _StubClient(auth);

      final service = DeviceIdentityService(client: client);
      // RPC結果取得はスタブが例外を投げるが、サービスは握り潰すため completes
      await service.relinkOnStartup();

      expect(client.lastRpcName, 'relink_device');
      final secret = client.lastRpcParams?['p_device_secret'] as String?;
      expect(secret, isNotNull);
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(secret!),
        isTrue,
        reason: 'secret: $secret',
      );
    });
  });
}
