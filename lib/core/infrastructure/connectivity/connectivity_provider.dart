import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ネットワーク接続状態を監視する StreamProvider
///
/// オンライン/オフラインをリアルタイムに通知する。
/// ConnectivityResult.none の場合はオフラインと判定。
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// オンラインかどうかの簡易判定用プロバイダ
final isOnlineProvider = Provider<bool>((ref) {
  final results = ref.watch(connectivityProvider).valueOrNull;
  if (results == null) return true; // 初期状態はオンライン想定
  return !results.contains(ConnectivityResult.none);
});
