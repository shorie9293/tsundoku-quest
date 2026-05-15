import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/models/user_book.dart';
import '../../../domain/models/recommendation.dart';

/// ツンドク本から今日のおすすめを選ぶサービス
///
/// Supabase連携時は daily_pick / popular を試行し、
/// オフライン時はローカルのツンドク本からピックアップする。
class RecommendationService {
  /// ツンドク本リストから1冊をランダムに選び、おすすめ理由を付けて返す
  ///
  /// ルール:
  /// - 空リストの場合は null を返す
  /// - 作成日から30日以上経過: 「N日間待機中の冒険」
  /// - 作成日から7日以上経過: 「N日間待機中の冒険」
  /// - それ以外: 「今日のランダムな一冊」
  static Recommendation? pickOne(List<UserBook> tsundokuBooks) {
    if (tsundokuBooks.isEmpty) return null;

    final random = Random();
    final picked = tsundokuBooks[random.nextInt(tsundokuBooks.length)];

    final createdAt = DateTime.parse(picked.createdAt);
    final now = DateTime.now();
    final daysSinceCreated = now.difference(createdAt).inDays;

    String reason;
    if (daysSinceCreated >= 30) {
      reason = '$daysSinceCreated日間待機中の冒険';
    } else if (daysSinceCreated >= 7) {
      reason = '$daysSinceCreated日間待機中の冒険';
    } else {
      reason = '今日のランダムな一冊';
    }

    return Recommendation.fromUserBook(picked, reason: reason);
  }

  /// 今日のおすすめ一覧を取得（ローカルフォールバック付き）
  ///
  /// - Supabaseが利用可能なら daily_pick + random + popular を試行
  /// - オフライン時は tsundokuBooks から複数選出する
  static Future<List<Recommendation>> getDailyRecommendations({
    required List<UserBook> tsundokuBooks,
    SupabaseClient? client,
  }) async {
    // Supabaseが利用可能な場合、オンライン取得を試行
    if (client != null) {
      try {
        final response = await client
            .from('user_books')
            .select('*, book:books(*)')
            .eq('status', 'reading')
            .order('total_reading_minutes', ascending: false)
            .limit(5);
        if (response.isNotEmpty) {
          return (response as List<dynamic>).map((json) {
            final userBook = UserBook.fromSupabase(json as Map<String, dynamic>);
            return Recommendation.fromUserBook(
              userBook,
              reason: '人気の読書中アイテム',
            );
          }).toList();
        }
      } catch (_) {
        // RLS制限や接続エラー時はフォールバック
      }
    }

    // ローカルフォールバック: tsundokuBooksから3冊ランダムに選択
    if (tsundokuBooks.isEmpty) return [];

    final random = Random();
    final reasons = ['今日のランダムな一冊', '長期待機中の冒険', '隠れた名作'];
    final count = min(3, tsundokuBooks.length);
    final shuffled = List<UserBook>.from(tsundokuBooks)..shuffle(random);
    final picked = shuffled.take(count).toList();

    return picked.asMap().entries.map((entry) {
      final reason = reasons[entry.key % reasons.length];
      return Recommendation.fromUserBook(entry.value, reason: reason);
    }).toList();
  }

  /// 人気書籍（全ユーザーの reading 上位を取得）
  ///
  /// Supabaseの user_books から total_reading_minutes 順で5件取得する。
  /// エラー時は空リストを返す。
  static Future<List<Recommendation>> getPopularBooks(SupabaseClient client) async {
    try {
      final response = await client
          .from('user_books')
          .select('*, book:books(*)')
          .order('total_reading_minutes', ascending: false)
          .limit(5);
      return (response as List<dynamic>).map((json) {
        final userBook = UserBook.fromSupabase(json as Map<String, dynamic>);
        return Recommendation.fromUserBook(
          userBook,
          reason: 'みんなが読んでいる',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
