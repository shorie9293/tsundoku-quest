/// 復元前プレビュー（内訳＋上書き対象の抜粋＋文言）— 純粋層
///
/// 参照実装: kozuchi/lib/features/backup/domain/restore_preview.dart
/// 画面は届いた文字列を並べるだけにし、「0件の時どう言うか」の if 分岐は
/// すべてこのクラスへ閉じ込める。
///
/// 意味論は適用側（`mergeBackup` / `HiveBackupRepository.restore`）に合わせる:
/// - 蔵書・セッションは **既存 id を上書きしない**（既存は件数のみ「変更なし」）
/// - 設定は許可リスト通過済みのキーを1件ずつ書き戻す（差分キー＝上書き）
/// - 読書目標は新規エントリが1件以上ある時だけ書き戻される
///
/// 破損・空・巨大入力でも絶対に throw しない（[compose] は null を返す）。
library;

import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_settings_spec.dart';

/// 一覧表示に出す上書き対象キーの既定件数。
const int kRestorePreviewSampleLimit = 5;

/// 復元差分（新規・上書き・変更なし）。キーは表示用ラベル。
class BackupRestoreDiff {
  /// 新規に追加される対象（表示ラベル → 値）
  final Map<String, Object?> toCreate;

  /// 上書きされる対象（表示ラベル → 値）
  final Map<String, Object?> toOverwrite;

  /// 変更の無い対象数
  final int unchanged;

  const BackupRestoreDiff({
    this.toCreate = const <String, Object?>{},
    this.toOverwrite = const <String, Object?>{},
    this.unchanged = 0,
  });

  int get created => toCreate.length;

  int get restored => toOverwrite.length;

  bool get isEmpty => created == 0 && restored == 0;
}

/// バックアップ内容と現状から差分を求める（純粋・throw しない）。
BackupRestoreDiff diffBackup({
  required BackupData incoming,
  required BackupData existing,
}) {
  final toCreate = <String, Object?>{};
  final toOverwrite = <String, Object?>{};
  var unchanged = 0;

  // 蔵書: 既存 id はスキップ（mergeBackup と同じ「既存優先」）
  var newEntries = 0;
  final bookIds = existing.books.map((b) => b.id).toSet();
  for (final book in incoming.books) {
    if (bookIds.contains(book.id)) {
      unchanged++;
      continue;
    }
    bookIds.add(book.id);
    newEntries++;
    toCreate[_bookKey(book)] = book.id;
  }

  // セッション: 同じく既存 id はスキップ
  final sessionIds = existing.sessions.map((s) => s.id).toSet();
  for (final session in incoming.sessions) {
    if (sessionIds.contains(session.id)) {
      unchanged++;
      continue;
    }
    sessionIds.add(session.id);
    newEntries++;
    toCreate[_sessionKey(session)] = session.id;
  }

  // 設定: 許可リスト通過済みのキーだけを1件ずつ突き合わせる
  final incomingSettings = incoming.settings;
  if (incomingSettings != null) {
    final existingValues =
        existing.settings?.values ?? const <String, Object?>{};
    final keys = incomingSettings.values.keys.toList()..sort();
    for (final key in keys) {
      final value = incomingSettings.values[key];
      final label = _settingKey(key);
      if (!existingValues.containsKey(key)) {
        toCreate[label] = value;
      } else if (_sameValue(existingValues[key], value)) {
        unchanged++;
      } else {
        toOverwrite[label] = value;
      }
    }
  }

  // 読書目標: 新規エントリがある時だけ書き戻される（適用側の条件に一致）
  final goal = incoming.goal;
  if (goal != null && newEntries > 0) {
    final current = existing.goal;
    if (current == null) {
      toCreate['読書目標'] = goal.toJson();
    } else if (current.monthlyTarget == goal.monthlyTarget &&
        current.yearlyTarget == goal.yearlyTarget) {
      unchanged++;
    } else {
      toOverwrite['読書目標'] = goal.toJson();
    }
  }

  return BackupRestoreDiff(
    toCreate: toCreate,
    toOverwrite: toOverwrite,
    unchanged: unchanged,
  );
}

String _bookKey(UserBook book) {
  final title = book.book?.title;
  final label = (title == null || title.isEmpty) ? book.bookId : title;
  return '蔵書「$label」(${book.id})';
}

String _sessionKey(ReadingSession session) => 'セッション ${session.id}';

String _settingKey(String key) {
  for (final spec in kBackupSettingSpecs) {
    if (spec.key == key) return '設定「${spec.label}」';
  }
  return '設定 $key';
}

/// JSON スカラー/リスト/マップの値比較（同一性ではなく内容で比べる）
bool _sameValue(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameValue(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_sameValue(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

/// 復元前プレビュー（内訳＋上書き対象の抜粋＋文言）。
class RestorePreview {
  /// 新規作成される対象キー数。
  final int created;

  /// 上書きされる対象キー数。
  final int overwritten;

  /// 変更の無い対象キー数。
  final int unchanged;

  /// 上書き対象キーの先頭 [kRestorePreviewSampleLimit] 件（昇順）。
  final List<String> overwriteSampleKeys;

  /// 抜粋から漏れた上書き対象キー数。
  final int hiddenOverwriteCount;

  const RestorePreview({
    required this.created,
    required this.overwritten,
    required this.unchanged,
    required this.overwriteSampleKeys,
    required this.hiddenOverwriteCount,
  });

  /// 差分の総件数（バックアップに含まれる対象キー数）。
  int get total => created + overwritten + unchanged;

  /// 書き換えが1件でも起きるか。
  bool get hasChanges => created > 0 || overwritten > 0;

  /// 要約行。例: `新規 12件 / 上書き 3件 / 変更なし 8件`
  String get summary => '新規 $created件 / 上書き $overwritten件 / 変更なし $unchanged件';

  /// 上書き対象キーの抜粋。上書き0件なら null（表示しない）。
  ///
  /// 例:
  /// ```
  /// 上書きされるキー:
  /// ・設定「テーマ」
  /// ・読書目標
  /// ほか 3件
  /// ```
  String? get samplesText {
    if (overwriteSampleKeys.isEmpty) return null;
    final buffer = StringBuffer('上書きされるキー:');
    for (final key in overwriteSampleKeys) {
      buffer.write('\n・$key');
    }
    if (hiddenOverwriteCount > 0) {
      buffer.write('\nほか $hiddenOverwriteCount件');
    }
    return buffer.toString();
  }

  /// 状況に応じた一文（境界ごとに言い回しを変える）。
  String get message {
    if (total == 0) return '復元対象のデータはありません';
    if (created == 0 && overwritten == 0) {
      return '現在のデータと一致しています。変更はありません';
    }
    if (overwritten == 0) return '既存データは上書きされません（新規データのみ追加されます）';
    if (created == 0) return '新規データはありません。上書きのみ行われます';
    return '新規データの追加と、既存データの上書きが行われます';
  }

  /// [BackupRestoreDiff] からプレビューを組み立てる。
  ///
  /// - 上書き対象キーは決定的（昇順）に並べ、先頭 [sampleLimit] 件を抜粋する
  /// - [sampleLimit] が 0 以下なら既定値に丸める（表示経路で throw しない）
  static RestorePreview build(
    BackupRestoreDiff diff, {
    int sampleLimit = kRestorePreviewSampleLimit,
  }) {
    final limit = sampleLimit > 0 ? sampleLimit : kRestorePreviewSampleLimit;
    final keys = diff.toOverwrite.keys.toList()..sort();
    final sample = List<String>.unmodifiable(keys.take(limit));
    return RestorePreview(
      created: diff.created,
      overwritten: diff.restored,
      unchanged: diff.unchanged,
      overwriteSampleKeys: sample,
      hiddenOverwriteCount: keys.length - sample.length,
    );
  }
}

/// バックアップと現状からプレビューを合成する薄い入口。
///
/// 想定外の破損（null 相当・型不一致）では throw せず null を返す。
/// 画面は null の時、従来どおりの確認表示に落ちる。
RestorePreview? compose({
  required BackupData incoming,
  required BackupData existing,
  int sampleLimit = kRestorePreviewSampleLimit,
}) {
  try {
    return RestorePreview.build(
      diffBackup(incoming: incoming, existing: existing),
      sampleLimit: sampleLimit,
    );
  } catch (_) {
    return null;
  }
}
