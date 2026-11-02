/// クイックメモの下書きと保存方針（純粋層）
///
/// 読書画面の「クイックメモ」は入力欄が表示されるだけで値が保存されず、
/// ユーザーが書いた文章が 100% 失われていた（#201）。
/// 本ファイルは端末ローカル下書きの表現と、保存可否の判断だけを持つ。
/// 時刻は必ず引数注入とし、実時計を直読みしない（時限爆弾の回避）。
library;

/// 端末ローカルに保持するクイックメモ下書き
class QuickMemoDraft {
  /// 下書きの最大文字数（入力欄の肥大化・無限成長を防ぐ）
  static const int maxLength = 2000;

  final String body;
  final DateTime updatedAt;

  const QuickMemoDraft({required this.body, required this.updatedAt});

  /// 正規化・最大長丸めを適用して下書きを生成する
  factory QuickMemoDraft.create(String raw, {required DateTime now}) {
    final normalized = QuickMemoPolicy.normalize(raw);
    return QuickMemoDraft(
      body: QuickMemoPolicy.truncate(normalized),
      updatedAt: now,
    );
  }

  bool get isEmpty => body.isEmpty;

  bool get isNotEmpty => body.isNotEmpty;

  int get charCount => body.length;

  Map<String, dynamic> toJson() => {
        'body': body,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// 破損・欠損 JSON は null を返す（例外を投げない）
  static QuickMemoDraft? fromJson(Object? json) {
    if (json is! Map) return null;
    final body = json['body'];
    final updatedAt = json['updatedAt'];
    if (body is! String || updatedAt is! String) return null;
    final parsed = DateTime.tryParse(updatedAt);
    if (parsed == null) return null;
    return QuickMemoDraft(body: body, updatedAt: parsed);
  }

  @override
  bool operator ==(Object other) =>
      other is QuickMemoDraft &&
      other.body == body &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(body, updatedAt);

  @override
  String toString() => 'QuickMemoDraft(body: $body, updatedAt: $updatedAt)';
}

/// クイックメモの保存方針（純粋関数のみ）
class QuickMemoPolicy {
  /// 前後の空白のみ除去し、改行はそのまま保持する
  static String normalize(String raw) => raw.trim();

  /// 最大長を超えた分を切り捨てる（文字単位）
  static String truncate(String value) => value.length <= QuickMemoDraft.maxLength
      ? value
      : value.substring(0, QuickMemoDraft.maxLength);

  /// 下書きを書き込む必要があるか。
  /// 本文が変化していなければ書き込みを省く（無駄な I/O の抑止）。
  static bool shouldPersist({
    required String previousBody,
    required String nextBody,
  }) =>
      normalize(previousBody) != normalize(nextBody);

  /// 戦利品カード（既存の読書メモ保存経路）へ渡すべき本文があるか。
  /// 空メモで既存メモを上書きしないための門番。
  static bool shouldAttachToTrophy(String memo) => normalize(memo).isNotEmpty;
}
