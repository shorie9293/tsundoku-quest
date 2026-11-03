import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 静的ゲート: 本番ログ垂れ流しの再発防止。
///
/// `lib` 配下の `.dart` を走査し、`debugPrint(` / `print(` の出現総数が
/// `tool/print_baseline.txt` の上限以下であることを assert する。
/// 新規に raw print を足すと必ずここで赤くなる（＝ appLog 経由を強制）。
///
/// 上限を下げるときは、移行後に `tool/print_baseline.txt` を実測値へ更新する。
void main() {
  test('lib 配下の raw print/debugPrint が baseline 以下', () {
    final baselineFile = File('tool/print_baseline.txt');
    expect(
      baselineFile.existsSync(),
      isTrue,
      reason: 'tool/print_baseline.txt が見つからない（作業ディレクトリは '
          'プロジェクトルートである必要がある）',
    );

    final baselineText = baselineFile.readAsStringSync().trim();
    final baseline = int.parse(
      baselineText.split('\n').first.trim(),
    );

    final callPattern = RegExp(r'\b(debugPrint|print)\s*\(');
    final offenders = <String>[];
    var total = 0;

    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib ディレクトリが無い');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // コメント行（//, ///）は数えない
        if (line.trimLeft().startsWith('//')) continue;
        final matches = callPattern.allMatches(line).length;
        if (matches == 0) continue;
        total += matches;
        offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
      }
    }

    expect(
      total,
      lessThanOrEqualTo(baseline),
      reason: '本番ログ垂れ流しが増えた（$total 件 > 上限 $baseline 件）。'
          'raw print ではなく core/logging/app_logger.dart の appLog を使うこと。\n'
          '${offenders.join('\n')}',
    );
  });
}
