import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/war_trophy.dart';
import '../../../shared/providers/book_data_provider.dart';
import '../../shared/providers/war_trophy_provider.dart';

/// 読書感想（戦利品の学び）を表示用に整形したデータ
class ReadingNoteItem {
  final String id;
  final String userBookId;
  final String? bookTitle;
  final List<String> learnings;
  final String action;
  final String? favoriteQuote;
  final String createdAt;

  const ReadingNoteItem({
    required this.id,
    required this.userBookId,
    this.bookTitle,
    required this.learnings,
    required this.action,
    this.favoriteQuote,
    required this.createdAt,
  });

  factory ReadingNoteItem.fromTrophy(
    WarTrophy trophy, {
    String? bookTitle,
  }) {
    return ReadingNoteItem(
      id: trophy.id,
      userBookId: trophy.userBookId,
      bookTitle: bookTitle,
      learnings: trophy.learnings,
      action: trophy.action,
      favoriteQuote: trophy.favoriteQuote,
      createdAt: trophy.createdAt,
    );
  }

  /// 何かしらの感想が存在するか
  bool get hasContent =>
      learnings.isNotEmpty ||
      action.isNotEmpty ||
      (favoriteQuote != null && favoriteQuote!.isNotEmpty);
}

/// 読書感想一覧を提供するProvider
/// WarTrophy（戦利品）から読書感想を取得する
final readingNotesProvider = Provider<List<ReadingNoteItem>>((ref) {
  final trophies = ref.watch(warTrophyProvider);
  final bookData = ref.watch(bookDataProvider);

  return trophies.map((trophy) {
    // 該当するUserBookを検索して書籍タイトルを取得
    String? bookTitle;
    try {
      final userBook = bookData.userBooks.firstWhere(
        (ub) => ub.id == trophy.userBookId,
      );
      bookTitle = userBook.book?.title;
    } catch (_) {
      bookTitle = null;
    }
    return ReadingNoteItem.fromTrophy(trophy, bookTitle: bookTitle);
  }).toList();
});
