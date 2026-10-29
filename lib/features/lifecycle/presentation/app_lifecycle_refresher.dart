import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/day_rollover_detector.dart';

/// 前面復帰（resumed）時に日付跨ぎを検出し、[onRollover] を1回だけ走らせる。
///
/// 既存ツリーを**包むだけ**のウィジェット。初期化順序は変えない
/// （[child] をそのまま build する）。
class AppLifecycleRefresher extends StatefulWidget {
  const AppLifecycleRefresher({
    super.key,
    required this.detector,
    required this.onRollover,
    required this.child,
    this.now,
  });

  /// 日付跨ぎ判定器（呼び出し側が単一インスタンスを保持する）。
  final DayRolloverDetector detector;

  /// 跨ぎを検出したときの再計算処理。投げっぱなしで1回だけ呼ばれる。
  final Future<void> Function() onRollover;

  final Widget child;

  /// 現在時刻の取得方法（試練用の注入点）。既定は [DateTime.now]。
  final DateTime Function()? now;

  @override
  State<AppLifecycleRefresher> createState() => _AppLifecycleRefresherState();
}

class _AppLifecycleRefresherState extends State<AppLifecycleRefresher>
    with WidgetsBindingObserver {
  /// 再入防止（onRollover 実行中に再度 resumed が来ても二重に走らせない）。
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // resumed のときだけ判定する（paused/inactive/hidden/detached は無視）
    if (state != AppLifecycleState.resumed) return;
    if (_running) return;

    final DayRolloverResult result;
    try {
      final now = (widget.now ?? DateTime.now)();
      result = widget.detector.check(now);
    } catch (e) {
      debugPrint('⚠️ 日付跨ぎの判定に失敗（アプリは継続）: $e');
      return;
    }
    if (result != DayRolloverResult.rolledOver) return;

    _running = true;
    unawaited(_runRollover());
  }

  Future<void> _runRollover() async {
    try {
      await widget.onRollover();
    } catch (e, stackTrace) {
      // 再計算の失敗でアプリを落とさない
      debugPrint('⚠️ 日付跨ぎの再計算に失敗（アプリは継続）: $e\n$stackTrace');
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
