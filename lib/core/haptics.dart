import 'package:flutter/services.dart';

/// 操作の触覚フィードバック（軽い選択クリック）
///
/// fire-and-forget で送る。`await` してはならない — flutter_test では
/// プラットフォームチャネルが解決されず、await すると試練が永久に完了しない。
void hapticTap() => HapticFeedback.selectionClick().ignore();
