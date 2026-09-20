/// 蔵書の CSV 書き出し（RFC4180 相当のエスケープ）
///
/// 道標 #69 / Kanban t_4d1829a9
library;

import 'package:tsundoku_quest/domain/models/user_book.dart';

/// ヘッダ行
const String backupCsvHeader =
    'id,title,status,medium,currentPage,totalReadingMinutes,rating,completedAt';

String _escapeCsvField(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// 蔵書リストを CSV へ書き出す（status→id の安定ソート）
String backupBooksToCsv(List<UserBook> books) {
  final sorted = [...books]..sort((a, b) {
      final byStatus = a.status.value.compareTo(b.status.value);
      if (byStatus != 0) return byStatus;
      return a.id.compareTo(b.id);
    });
  final rows = <String>[backupCsvHeader];
  for (final b in sorted) {
    rows.add([
      _escapeCsvField(b.id),
      _escapeCsvField(b.book?.title ?? ''),
      _escapeCsvField(b.status.value),
      _escapeCsvField(b.medium.value),
      '${b.currentPage}',
      '${b.totalReadingMinutes}',
      b.rating == null ? '' : '${b.rating}',
      _escapeCsvField(b.completedAt ?? ''),
    ].join(','));
  }
  return rows.join('\n');
}
