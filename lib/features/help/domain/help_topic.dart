import 'package:flutter/foundation.dart';

/// ヘルプ1項目（読み返せる説明の最小単位）。
///
/// 文言はチュートリアル（`TutorialContent`）を正とし、ここでは
/// 「どの画面の話か」だけを [relatedScreenKey] で添える。
@immutable
class HelpTopic {
  const HelpTopic({
    required this.id,
    required this.title,
    required this.body,
    this.relatedScreenKey,
  });

  /// 一意な識別子（試練・Key・検索結果の同一性に使う）。
  final String id;

  /// 見出し。
  final String title;

  /// 本文（改行を含む）。
  final String body;

  /// 関連する画面の Key 名（任意）。
  final String? relatedScreenKey;
}
