/// 復元可否の分類（純粋・I/O なし）
///
/// 「一覧の復元ボタンが嘘をつく」禍津の根治。
/// 一覧の表示・復元実行前の検証は必ず本分類器を通す。
/// [BackupRestorability.classify] は例外を絶対に投げない。
library;

import 'dart:convert';

import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';

/// 復元可否の状態
enum BackupRestoreState {
  /// 復元できる
  restorable,

  /// 中身が空
  empty,

  /// 壊れている／復元形式に合わない
  corrupt,

  /// 版番号が無い・未対応の版
  unsupportedVersion,
}

/// 復元可否と利用者向けの理由
class BackupRestorability {
  /// 状態
  final BackupRestoreState state;

  /// 利用者向けの理由（表示・失敗メッセージに使う）
  final String reason;

  const BackupRestorability({required this.state, required this.reason});

  /// 復元してよいか
  bool get isRestorable => state == BackupRestoreState.restorable;

  /// 一覧に出す短いラベル
  String get label {
    switch (state) {
      case BackupRestoreState.restorable:
        return '復元できます';
      case BackupRestoreState.empty:
        return '中身が空です';
      case BackupRestoreState.corrupt:
        return '復元できません（破損）';
      case BackupRestoreState.unsupportedVersion:
        return '復元できません（版番号なし）';
    }
  }

  /// 旧来の「復元可能フラグ」しか無い呼出向けの既定値
  static const restorableValue = BackupRestorability(
    state: BackupRestoreState.restorable,
    reason: '復元できます',
  );

  /// 旧来の「復元可能フラグ」しか無い呼出向けの既定値
  static const corruptValue = BackupRestorability(
    state: BackupRestoreState.corrupt,
    reason: '中身が復元形式に合いません',
  );

  /// JSON 文字列を分類する（例外を絶対に投げない）
  static BackupRestorability classify(String? json) {
    if (json == null) {
      return const BackupRestorability(
        state: BackupRestoreState.empty,
        reason: 'バックアップの中身が空です',
      );
    }
    final trimmed = json.trim();
    if (trimmed.isEmpty) {
      return const BackupRestorability(
        state: BackupRestoreState.empty,
        reason: 'バックアップの中身が空です',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return const BackupRestorability(
        state: BackupRestoreState.corrupt,
        reason: 'JSON として読み込めません',
      );
    }

    if (decoded is! Map) {
      return const BackupRestorability(
        state: BackupRestoreState.corrupt,
        reason: '中身が復元形式に合いません',
      );
    }

    final version = decoded['version'];
    if (version is! int || version < 1) {
      return const BackupRestorability(
        state: BackupRestoreState.unsupportedVersion,
        reason: '版番号が無い控えはこの版では復元できません',
      );
    }

    if (BackupData.tryFromJson(decoded) == null) {
      return const BackupRestorability(
        state: BackupRestoreState.corrupt,
        reason: '中身が復元形式に合いません',
      );
    }

    return restorableValue;
  }
}
