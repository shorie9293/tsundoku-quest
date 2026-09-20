/// バックアップ画面のウィジェットキー
///
/// 共有キークラスの不可視禍津回避のため独立ファイル。
library;

import 'package:flutter/foundation.dart';

class BackupKeys {
  BackupKeys._();

  static const Key screen = Key('backup_screen');
  static const Key exportJsonButton = Key('backup_export_json');
  static const Key exportCsvButton = Key('backup_export_csv');
  static const Key importField = Key('backup_import_field');
  static const Key importButton = Key('backup_import_button');
  static const Key summary = Key('backup_summary');
  static const Key resultMessage = Key('backup_result');
}
