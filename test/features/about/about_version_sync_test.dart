/// kAboutInfo.version と pubspec.yaml の version ドリフト防止試練
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/about/domain/about_info.dart';

void main() {
  test('pubspec.yaml の version と kAboutInfo.version が一致する', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(
      pubspec,
    );
    expect(match, isNotNull, reason: 'pubspec.yaml に version 行が必要');

    final pubspecVersion = match!.group(1)!;
    // ビルド番号（+91 等）は除外して比較
    final pubspecSemver = pubspecVersion.split('+').first;

    expect(
      kAboutInfo.version,
      pubspecSemver,
      reason: 'pubspec を bump したら kAboutInfo も同期すること',
    );
  });
}
