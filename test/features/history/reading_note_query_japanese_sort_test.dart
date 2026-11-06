import 'package:flutter_test/flutter_test.dart';

import 'package:tsundoku_quest/features/history/data/reading_notes_provider.dart';
import 'package:tsundoku_quest/features/history/domain/reading_note_query.dart';

ReadingNoteItem note({
  required String id,
  String? bookTitle,
  List<String> learnings = const [],
  String action = '',
  String? favoriteQuote,
  String createdAt = '2026-01-01T00:00:00Z',
}) {
  return ReadingNoteItem(
    id: id,
    userBookId: 'ub-$id',
    bookTitle: bookTitle,
    learnings: List.of(learnings),
    action: action,
    favoriteQuote: favoriteQuote,
    createdAt: createdAt,
  );
}

void main() {
  group('ReadingNoteQueryService.sort / titleAsc 日本語かな順', () {
    test('かな同士は五十音順（あ→ん）になる', () {
      final notes = [
        note(id: 'n', bookTitle: 'ん'),
        note(id: 'a', bookTitle: 'あ'),
        note(id: 'i', bookTitle: 'い'),
      ];
      final r =
          ReadingNoteQueryService.sort(notes, ReadingNoteSortOrder.titleAsc);
      expect(r.map((e) => e.id), ['a', 'i', 'n']);
    });

    test('カタカナが「ん」の後ろへ落ちず、ひらがなと混在して並ぶ', () {
      final notes = [
        note(id: 'kara', bookTitle: 'カラス'),
        note(id: 'ahi', bookTitle: 'あひる'),
        note(id: 'n', bookTitle: 'ん'),
      ];
      final r =
          ReadingNoteQueryService.sort(notes, ReadingNoteSortOrder.titleAsc);
      expect(r.map((e) => e.id), ['ahi', 'kara', 'n']);
    });

    test('漢字など非かなはかなの後ろ、漢字同士はコードポイント順のまま', () {
      final notes = [
        note(id: 'gin', bookTitle: '銀河鉄道の夜'),
        note(id: 'ai', bookTitle: 'あい'),
        note(id: 'waga', bookTitle: '吾輩は猫である'),
      ];
      final r =
          ReadingNoteQueryService.sort(notes, ReadingNoteSortOrder.titleAsc);
      expect(r.map((e) => e.id), ['ai', 'waga', 'gin']);
    });

    test('bookTitle が null の行は末尾のまま', () {
      final notes = [
        note(id: 'z9', bookTitle: null),
        note(id: 'b', bookTitle: 'ん'),
        note(id: 'a1', bookTitle: null),
        note(id: 'a', bookTitle: 'あ'),
      ];
      final r =
          ReadingNoteQueryService.sort(notes, ReadingNoteSortOrder.titleAsc);
      expect(r.map((e) => e.id), ['a', 'b', 'a1', 'z9']);
    });

    test('かな表記ゆれで同値なら id 昇順（安定ソート維持）', () {
      final notes = [
        note(id: 'b', bookTitle: 'ココロ'),
        note(id: 'a', bookTitle: 'こころ'),
      ];
      final r =
          ReadingNoteQueryService.sort(notes, ReadingNoteSortOrder.titleAsc);
      expect(r.map((e) => e.id), ['a', 'b']);
    });

    test('入力リストを破壊的に変更しない（日本語ソートでも）', () {
      final notes = [
        note(id: 'kara', bookTitle: 'カラス'),
        note(id: 'ahi', bookTitle: 'あひる'),
      ];
      final before = List.of(notes);
      ReadingNoteQueryService.sort(notes, ReadingNoteSortOrder.titleAsc);
      expect(notes, equals(before));
    });
  });
}