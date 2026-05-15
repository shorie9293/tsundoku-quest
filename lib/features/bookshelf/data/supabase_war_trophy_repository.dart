import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/models/war_trophy.dart';
import '../../../domain/repositories/war_trophy_repository.dart';

/// Supabaseをデータストアに使用したWarTrophyRepositoryの具象実装
///
/// Supabaseテーブル: war_trophies
/// カラムはスネークケース: user_book_id, user_id, learnings, action,
/// favorite_quote, created_at
class SupabaseWarTrophyRepository implements WarTrophyRepository {
  final SupabaseClient _client;

  SupabaseWarTrophyRepository(this._client);

  @override
  Future<List<WarTrophy>> getMyTrophies() async {
    final response = await _client
        .from('war_trophies')
        .select()
        .order('created_at', ascending: false);
    return (response)
        .map((json) => _fromSupabase(json))
        .toList();
  }

  @override
  Future<WarTrophy> createTrophy(WarTrophy trophy) async {
    final data = _toSupabase(trophy);
    data.remove('id');
    final response = await _client
        .from('war_trophies')
        .insert(data)
        .select()
        .single();
    return _fromSupabase(response);
  }

  @override
  Future<WarTrophy> updateTrophy(WarTrophy trophy) async {
    final response = await _client
        .from('war_trophies')
        .update(_toSupabase(trophy))
        .eq('id', trophy.id)
        .select()
        .single();
    return _fromSupabase(response);
  }

  /// SupabaseのスネークケースJSON → WarTrophy
  WarTrophy _fromSupabase(Map<String, dynamic> json) {
    return WarTrophy(
      id: json['id'] as String,
      userBookId: json['user_book_id'] as String,
      userId: json['user_id'] as String,
      learnings:
          (json['learnings'] as List<dynamic>).map((e) => e as String).toList(),
      action: json['action'] as String,
      favoriteQuote: json['favorite_quote'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  /// WarTrophy → Supabase保存用のスネークケースMap
  Map<String, dynamic> _toSupabase(WarTrophy trophy) {
    return {
      'id': trophy.id,
      'user_book_id': trophy.userBookId,
      'user_id': trophy.userId,
      'learnings': trophy.learnings,
      'action': trophy.action,
      'favorite_quote': trophy.favoriteQuote,
      'created_at': trophy.createdAt,
    };
  }
}
