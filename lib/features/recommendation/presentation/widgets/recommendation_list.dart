import 'package:flutter/material.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../domain/models/recommendation.dart';
import 'recommendation_card.dart';

/// おすすめ一覧を縦に並べるWidget
///
/// [Recommendation] のリストを受け取り、[RecommendationCard] を列挙する。
class RecommendationList extends StatelessWidget {
  final List<Recommendation> recommendations;

  const RecommendationList({
    super.key,
    required this.recommendations,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: AppKeys.recommendationList,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: recommendations
          .map((rec) => RecommendationCard(recommendation: rec))
          .toList(),
    );
  }
}
