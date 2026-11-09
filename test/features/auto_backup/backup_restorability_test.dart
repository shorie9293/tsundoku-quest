/// 復元可否の分類（純粋ロジック）の試練
///
/// 「一覧の復元ボタンが嘘をつく」禍津の根治。
/// 分類は 4 状態・例外を絶対に投げない・復元形式は BackupData.tryFromJson に従う。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/backup_restorability.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_models.dart';

/// tryFromJson を通る最小の正当な控え
const _validJson =
    '{"tsundoku_quest_backup":true,"version":1,"books":[],"readingSessions":[]}';

void main() {
  group('BackupRestorability.classify', () {
    test('null・空・空白は empty', () {
      expect(
          BackupRestorability.classify(null).state, BackupRestoreState.empty);
      expect(BackupRestorability.classify('').state, BackupRestoreState.empty);
      expect(
          BackupRestorability.classify('   ').state, BackupRestoreState.empty);
      expect(BackupRestorability.classify('\n\t ').state,
          BackupRestoreState.empty);
    });

    test('壊れた JSON は corrupt（例外を投げない）', () {
      expect(BackupRestorability.classify('not json').state,
          BackupRestoreState.corrupt);
      expect(BackupRestorability.classify('{"broken": ').state,
          BackupRestoreState.corrupt);
      expect(
          BackupRestorability.classify('{').state, BackupRestoreState.corrupt);
    });

    test('トップが Map でない（配列・文字列・数値）は corrupt', () {
      expect(BackupRestorability.classify('[1,2,3]').state,
          BackupRestoreState.corrupt);
      expect(BackupRestorability.classify('"string"').state,
          BackupRestoreState.corrupt);
      expect(
          BackupRestorability.classify('42').state, BackupRestoreState.corrupt);
      expect(BackupRestorability.classify('null').state,
          BackupRestoreState.corrupt);
      expect(BackupRestorability.classify('true').state,
          BackupRestoreState.corrupt);
    });

    test('version 欠落は unsupportedVersion（理由文つき）', () {
      final r = BackupRestorability.classify(
          '{"tsundoku_quest_backup":true,"books":[]}');
      expect(r.state, BackupRestoreState.unsupportedVersion);
      expect(r.reason, contains('版番号が無い控えはこの版では復元できません'));
      expect(r.isRestorable, isFalse);
    });

    test('version の型違いは unsupportedVersion', () {
      expect(
          BackupRestorability.classify(
                  '{"tsundoku_quest_backup":true,"version":"1"}')
              .state,
          BackupRestoreState.unsupportedVersion);
      expect(
          BackupRestorability.classify(
                  '{"tsundoku_quest_backup":true,"version":null}')
              .state,
          BackupRestoreState.unsupportedVersion);
    });

    test('version=0 は unsupportedVersion', () {
      expect(
          BackupRestorability.classify(
                  '{"tsundoku_quest_backup":true,"version":0}')
              .state,
          BackupRestoreState.unsupportedVersion);
      expect(
          BackupRestorability.classify(
                  '{"tsundoku_quest_backup":true,"version":-3}')
              .state,
          BackupRestoreState.unsupportedVersion);
    });

    test('版番号はあるが復元形式に合わない（フラグ欠落等）は corrupt', () {
      expect(BackupRestorability.classify('{"version":1}').state,
          BackupRestoreState.corrupt);
      expect(
          BackupRestorability.classify(
                  '{"tsundoku_quest_backup":false,"version":1}')
              .state,
          BackupRestoreState.corrupt);
      // 空オブジェクトは版番号も無いので unsupportedVersion が先に立つ。
      expect(BackupRestorability.classify('{}').state,
          BackupRestoreState.unsupportedVersion);
    });

    test('最小の正当 JSON は restorable', () {
      final r = BackupRestorability.classify(_validJson);
      expect(r.state, BackupRestoreState.restorable);
      expect(r.isRestorable, isTrue);
      expect(r.label, isNotEmpty);
    });

    test('BackupData.toJson の実出力は版番号を持ち restorable（既存控えの実測）', () {
      final data =
          BackupData(exportedAt: '2026-11-09T00:00:00', books: const []);
      final encoded = jsonEncode(data.toJson());
      expect(encoded, contains('"version":1'));
      expect(encoded, contains('"tsundoku_quest_backup":true'));
      expect(BackupRestorability.classify(encoded).state,
          BackupRestoreState.restorable);
    });

    test('1MB の壊れ文字列でも throw しない', () {
      final huge = 'x' * (1024 * 1024);
      final r = BackupRestorability.classify(huge);
      expect(r.state, BackupRestoreState.corrupt);
      expect(r.isRestorable, isFalse);
    });

    test('1MB の壊れた JSON 風文字列でも throw しない', () {
      final huge = '{"books": [${'x' * (1024 * 1024)}';
      final r = BackupRestorability.classify(huge);
      expect(r.state, BackupRestoreState.corrupt);
    });

    test('状態ごとに isRestorable と label が対応する', () {
      const states = BackupRestoreState.values;
      expect(states, hasLength(4));
      final labels = <String>{};
      for (final state in states) {
        final r = BackupRestorability(state: state, reason: '理由');
        expect(r.isRestorable, state == BackupRestoreState.restorable);
        expect(r.label, isNotEmpty);
        labels.add(r.label);
      }
      expect(labels, hasLength(4));
    });
  });
}
