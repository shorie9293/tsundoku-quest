import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ロック方式。
enum AppLockMethod { none, passcode, biometric }

/// アプリロック設定の永続化の抽象（テスト容易性のため抽象化）。
abstract class AppLockRepository {
  bool isEnabled();

  Future<void> setEnabled(bool enabled);

  AppLockMethod getMethod();

  Future<void> setMethod(AppLockMethod method);

  String? getPasscodeHash();

  Future<void> setPasscode(String passcode);

  Future<void> clearPasscode();

  bool verifyPasscode(String passcode);
}

/// アプリロック設定の永続化（SharedPreferences）。
class SharedPreferencesAppLockRepository implements AppLockRepository {
  static const _kEnabled = 'app_lock.enabled';
  static const _kHash = 'app_lock.passcode_hash';
  static const _kMethod = 'app_lock.method';

  static const _salt = 'tsundoku-app-lock:';

  final SharedPreferences _prefs;
  SharedPreferencesAppLockRepository(this._prefs);

  @override
  bool isEnabled() => _prefs.getBool(_kEnabled) ?? false;

  @override
  Future<void> setEnabled(bool enabled) => _prefs.setBool(_kEnabled, enabled);

  @override
  AppLockMethod getMethod() {
    final name = _prefs.getString(_kMethod);
    return AppLockMethod.values
        .firstWhere((m) => m.name == name, orElse: () => AppLockMethod.none);
  }

  @override
  Future<void> setMethod(AppLockMethod method) =>
      _prefs.setString(_kMethod, method.name);

  @override
  String? getPasscodeHash() => _prefs.getString(_kHash);

  @override
  Future<void> setPasscode(String passcode) async {
    await _prefs.setString(_kHash, _hash(passcode));
  }

  @override
  bool verifyPasscode(String passcode) {
    final stored = getPasscodeHash();
    if (stored == null) return false;
    return _constantTimeEquals(stored, _hash(passcode));
  }

  @override
  Future<void> clearPasscode() => _prefs.remove(_kHash);

  String _hash(String passcode) =>
      sha256.convert(utf8.encode('$_salt$passcode')).toString();
}

/// 試練用のメモリ内実装。
class InMemoryAppLockRepository implements AppLockRepository {
  bool _enabled = false;
  AppLockMethod _method = AppLockMethod.none;
  String? _hash;

  @override
  bool isEnabled() => _enabled;

  @override
  Future<void> setEnabled(bool enabled) async => _enabled = enabled;

  @override
  AppLockMethod getMethod() => _method;

  @override
  Future<void> setMethod(AppLockMethod method) async => _method = method;

  @override
  String? getPasscodeHash() => _hash;

  @override
  Future<void> setPasscode(String passcode) async =>
      _hash = _hashPasscode(passcode);

  @override
  bool verifyPasscode(String passcode) {
    final stored = _hash;
    if (stored == null) return false;
    return _constantTimeEquals(stored, _hashPasscode(passcode));
  }

  @override
  Future<void> clearPasscode() async => _hash = null;
}

/// パスコードは salt 'tsundoku-app-lock:' + utf8 → sha256 でハッシュ化。
String _hashPasscode(String passcode) =>
    sha256.convert(utf8.encode('tsundoku-app-lock:$passcode')).toString();

/// タイミング攻撃に強い定数時間比較。
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
