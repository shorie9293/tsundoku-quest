/// CSV 共有時の UTF-8 BOM 付与と日本語バイト健全性の試練
///
/// 背景: `Uint8List.fromList(body.codeUnits)` は UTF-16 コードユニットを
/// 下位バイトへ切り詰めるため、日本語（例 'あ'=0x3042）のバイト列が破壊される。
/// 併せて Excel(Windows/macOS) は BOM 無し UTF-8 を ANSI と解釈するため BOM を付す。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_csv.dart';
import 'package:tsundoku_quest/features/backup/domain/csv_bom.dart';

UserBook _ub(String id, String title) {
  return UserBook(
    id: id,
    userId: 'u1',
    bookId: 'book-$id',
    book: Book(
      id: 'book-$id',
      title: title,
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    ),
    status: BookStatus.tsundoku,
    medium: BookMedium.physical,
    createdAt: '2026-01-02T00:00:00Z',
  );
}

void main() {
  group('withUtf8Bom', () {
    test('先頭に U+FEFF が付き、本体は改変されない', () {
      final result = withUtf8Bom('a,b');
      expect(result.codeUnitAt(0), 0xFEFF);
      expect(result.substring(1), 'a,b');
      expect(result.length, 'a,b'.length + 1);
    });

    test('空文字でも BOM のみを返す', () {
      final result = withUtf8Bom('');
      expect(result.length, 1);
      expect(result.codeUnitAt(0), 0xFEFF);
    });
  });

  group('csvBytes', () {
    test('先頭3要素が 0xEF,0xBB,0xBF（UTF-8 BOM）', () {
      final bytes = csvBytes('書名,著者');
      expect(bytes.length, greaterThan(3));
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    });

    test('BOM 以降は utf8.decode で元の文字列へ戻る（codeUnits 切り詰めなし）', () {
      const csv = '書名,著者\nあいう,えお';
      final bytes = csvBytes(csv);
      expect(utf8.decode(bytes.sublist(3)), csv);
    });

    test('日本語1文字が 3 バイトで表現される（破壊の回帰防止）', () {
      final bytes = csvBytes('あ');
      // BOM 3 + 'あ' 3
      expect(bytes.length, 6);
      expect(bytes.sublist(3), [0xE3, 0x81, 0x82]);
    });
  });

  group('shareFileBytes（共有バイト列の組み立て）', () {
    test('text/csv は BOM 付き UTF-8', () {
      final bytes = shareFileBytes(mimeType: 'text/csv', body: '書名');
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.sublist(3)), '書名');
    });

    test('text/csv 以外（JSON）は BOM 無し UTF-8', () {
      final bytes = shareFileBytes(mimeType: 'application/json', body: '{"a":"あ"}');
      expect(bytes.sublist(0, 3), isNot([0xEF, 0xBB, 0xBF]));
      expect(bytes.first, '{'.codeUnitAt(0));
      expect(utf8.decode(bytes), '{"a":"あ"}');
    });
  });

  group('backupBooksToCsv の既存契約', () {
    test('戻り値は BOM を含まない（従来通りの文字列）', () {
      final csv = backupBooksToCsv([_ub('a', 'あ')]);
      expect(csv.contains('\uFEFF'), isFalse);
      expect(csv.startsWith(backupCsvHeader), isTrue);
      expect(csv.contains('あ'), isTrue);
    });
  });
}
