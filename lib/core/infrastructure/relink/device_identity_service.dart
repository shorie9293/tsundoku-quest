import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 匿名ユーザー再リンク機構のデバイス識別サービス。
///
/// セッション喪失（データクリア・再インストール等）で新しい匿名ユーザーが
/// 生成されても、デバイス固有の秘密鍵（device_secret）で旧蔵書を自動再リンクする。
///
/// - secret は SharedPreferences に永続化（アプリデータが消えなければ保持）
/// - 失敗してもアプリ起動を妨げない（debugPrint のみ）
class DeviceIdentityService {
  DeviceIdentityService({SupabaseClient? client, SharedPreferences? prefs})
      : _client = client, _prefs = prefs;

  static const _secretKey = 'device_secret_v1';

  final SupabaseClient? _client;
  SharedPreferences? _prefs;

  /// 起動時に呼ぶ。匿名サインイン成功後であること。
  /// 失敗しても例外を投げず、ログのみで継続する。
  Future<void> relinkOnStartup() async {
    try {
      final client = _client ?? Supabase.instance.client;
      if (client.auth.currentUser == null) {
        debugPrint('[DeviceIdentity] 未認証のため再リンクをスキップ');
        return;
      }
      final secret = await _getOrCreateSecret();
      final res = await client
          .rpc('relink_device', params: {'p_device_secret': secret});
      debugPrint('[DeviceIdentity] 再リンク結果: $res');
    } catch (e) {
      debugPrint('[DeviceIdentity] 再リンク失敗（起動は継続）: $e');
    }
  }

  /// secret を取得（無ければ生成して永続化）。
  Future<String> _getOrCreateSecret() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final existing = prefs.getString(_secretKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final secret = _generateUuidV4();
    await prefs.setString(_secretKey, secret);
    return secret;
  }

  /// UUID v4 を生成（crypto 依存を避け、乱数ベースで自前実装）。
  @visibleForTesting
  static String generateUuidV4() => _generateUuidV4();

  static String _generateUuidV4() {
    final rand = DateTime.now().microsecondsSinceEpoch;
    var seed = rand;
    String hex8() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return (seed & 0xffffffff).toRadixString(16).padLeft(8, '0');
    }

    final h = [hex8(), hex8().substring(0, 4), hex8().substring(0, 4),
        hex8().substring(0, 4), hex8().substring(0, 4) + hex8().substring(0, 8)];
    // version 4 / variant を設定
    final v3 = h[2];
    h[2] = '4${v3.substring(1)}';
    final v4 = h[3];
    final variant = int.parse(v4[0], radix: 16);
    final fixed = (variant & 0x3) | 0x8;
    h[3] = '${fixed.toRadixString(16)}${v4.substring(1)}';
    return '${h[0]}-${h[1]}-4${h[2].substring(1)}-${h[3]}-${h[4]}';
  }
}
