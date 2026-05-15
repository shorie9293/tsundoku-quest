import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/testing/widget_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dungeon_background.dart';
import '../../../domain/models/recommendation.dart';
import '../../../domain/models/user_book.dart';
import '../../../shared/providers/book_data_provider.dart';
import '../domain/recommendation_service.dart';
import 'widgets/recommendation_card.dart';
import 'widgets/recommendation_list.dart';
import 'widgets/social_reading_section.dart';

/// おすすめ画面
///
/// ツンドク本から今日のおすすめ一覧を表示する。
/// Supabaseが利用可能な場合はサーバーサイドのおすすめも取得する。
class RecommendationScreen extends ConsumerStatefulWidget {
  const RecommendationScreen({super.key});

  @override
  ConsumerState<RecommendationScreen> createState() =>
      _RecommendationScreenState();
}

class _RecommendationScreenState extends ConsumerState<RecommendationScreen> {
  List<Recommendation> _recommendations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final state = ref.read(bookDataProvider);
      final tsundokuBooks =
          state.userBooks.where((ub) => ub.status == BookStatus.tsundoku).toList();

      final recommendations =
          await RecommendationService.getDailyRecommendations(
        tsundokuBooks: tsundokuBooks,
        client: null, // テスト環境ではSupabaseクライアントなし
      );

      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'おすすめの取得に失敗しました: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.recommendationScreen,
      appBar: AppBar(
        title: const Text('おすすめ'),
      ),
      body: DungeonBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRecommendations,
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        if (_recommendations.isNotEmpty) ...[
          // 最初の1件を大きなカードで表示
          RecommendationCard(
            recommendation: _recommendations.first,
          ),
          const SizedBox(height: 8),
          // 残りのおすすめをリスト表示
          RecommendationList(
            recommendations: _recommendations.skip(1).toList(),
          ),
        ] else ...[
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                '現在のおすすめはありません',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
        // もっと見るボタン
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // 再読み込み
                _loadRecommendations();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'もっと見る',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        // みんなが読んでいるセクション
        const SocialReadingSection(),
        const SizedBox(height: 32),
      ],
    );
  }
}
