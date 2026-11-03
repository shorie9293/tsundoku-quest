import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/logging/app_logger.dart';

/// 試練: 本番（release）でログを垂れ流さないための [AppLogger]。
///
/// 設計の芯:
/// - debug/info は `isDebug == false` で**無出力**（＝release ビルドで消える）
/// - warn/error は常時出力（障害調査の生命線なので抑制しない）
/// - 出力先（sink）を差し替え可能にして、試練から捕捉できる
/// - どのレベルも **throw しない**（ログがアプリを壊してはならない）
void main() {
  late List<String> lines;

  /// 出力を捕捉する logger を作る（既定は debug 有効）。
  AppLogger build({bool? isDebug}) {
    lines = <String>[];
    return AppLogger(isDebug: isDebug, sink: lines.add);
  }

  group('AppLogger — release 相当 (isDebug: false)', () {
    test('debug() は無出力', () {
      final log = build(isDebug: false);

      log.debug('詳細ログ');

      expect(lines, isEmpty);
    });

    test('info() は無出力', () {
      final log = build(isDebug: false);

      log.info('起動しました');

      expect(lines, isEmpty);
    });

    test('warn() / error() は常時出力される', () {
      final log = build(isDebug: false);

      log.warn('警告です');
      log.error('障害です');

      expect(lines, hasLength(2));
      expect(lines[0], contains('警告です'));
      expect(lines[1], contains('障害です'));
    });
  });

  group('AppLogger — debug 有効 (isDebug: true)', () {
    test('debug() / info() が出力される', () {
      final log = build(isDebug: true);

      log.debug('詳細ログ');
      log.info('情報ログ');

      expect(lines, hasLength(2));
      expect(lines[0], contains('詳細ログ'));
      expect(lines[1], contains('情報ログ'));
    });

    test('タグ書式: 各レベルが [LEVEL] 接頭辞とメッセージ本文を持つ', () {
      final log = build(isDebug: true);

      log.debug('d');
      log.info('i');
      log.warn('w');
      log.error('e');

      expect(lines[0], startsWith('[DEBUG]'));
      expect(lines[1], startsWith('[INFO]'));
      expect(lines[2], startsWith('[WARN]'));
      expect(lines[3], startsWith('[ERROR]'));
      expect(lines[0], endsWith('d'));
    });

    test('sink 差し替えで出力先が変わる（既定の debugPrint へは流れない）', () {
      final captured = <String>[];
      lines = <String>[]; // 前試練の捕捉結果を引き継がない
      final log = AppLogger(isDebug: true, sink: captured.add);

      log.info('差し替え確認');

      expect(captured, hasLength(1));
      expect(captured.single, contains('差し替え確認'));
      expect(lines, isEmpty, reason: '捕捉用リストには流れない');
    });
  });

  group('AppLogger — 堅牢性', () {
    test('warn/error は例外・スタックトレース付きでも throw しない', () {
      final log = build();
      final error = StateError('boom');

      expect(
        () => log.warn('失敗', error, StackTrace.current),
        returnsNormally,
      );
      expect(
        () => log.error('致命的', error, StackTrace.current),
        returnsNormally,
      );
      expect(lines, hasLength(2));
      expect(lines[0], contains('boom'));
      expect(lines[1], contains('致命的'));
    });

    test('例外情報のみ（stack なし）でも throw しない', () {
      final log = build(isDebug: false);

      expect(() => log.error('通信失敗', Exception('timeout')),
          returnsNormally);
      expect(lines.single, contains('timeout'));
    });

    test('グローバル appLog が利用可能（生成しても throw しない）', () {
      expect(() => appLog.info('起動'), returnsNormally);
      expect(() => appLog.error('異常'), returnsNormally);
    });
  });
}
