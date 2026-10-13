import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/core/widgets/dungeon_background.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/badges/data/badge_provider.dart';
import 'package:tsundoku_quest/features/badges/domain/badge_definition.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_provider.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

/// 読書達成バッジコレクション画面
///
/// セッション・蔵書からバッジ進捗を算出し、カテゴリ別に表示する。
/// 獲得日時は repository に記録・復元する。
class BadgeCollectionScreen extends ConsumerStatefulWidget {
  const BadgeCollectionScreen({
    super.key,
    this.sessionsOverride,
    this.userBooksOverride,
    this.nowOverride,
  });

  /// 試練用のセッション注入（null なら provider から取得）
  final List<ReadingSession>? sessionsOverride;

  /// 試練用の蔵書注入（null なら provider から取得）
  final List<UserBook>? userBooksOverride;

  /// 試練用の現在時刻注入
  final DateTime? nowOverride;

  @override
  ConsumerState<BadgeCollectionScreen> createState() =>
      _BadgeCollectionScreenState();
}

class _BadgeCollectionScreenState
    extends ConsumerState<BadgeCollectionScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  // widget の最新値に追随させる（late final で捕捉すると陳腐化する）
  List<ReadingSession> get _sessions =>
      widget.sessionsOverride ??
      ref.watch(readingHabitSessionsProvider).valueOrNull ??
      const <ReadingSession>[];

  List<UserBook> get _userBooks =>
      widget.userBooksOverride ?? ref.watch(bookDataProvider).userBooks;

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      await ref
          .read(badgeCollectionControllerProvider.notifier)
          .load(sessions: _sessions, userBooks: _userBooks, now: _now);
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<ReadingSession>>>(
      readingHabitSessionsProvider,
      (_, __) {
        _load();
      },
    );

    final collection = ref.watch(badgeCollectionControllerProvider);

    return Scaffold(
      key: AppKeys.badgeCollectionScreen,
      appBar: AppBar(title: const Text('🏆 実績バッジ')),
      body: DungeonBackground(
        screenType: ScreenType.history,
        child: collection == null
            ? const Center(child: CircularProgressIndicator())
            : _BadgeList(collection: collection),
      ),
    );
  }
}

class _BadgeList extends StatelessWidget {
  const _BadgeList({required this.collection});

  final BadgeCollection collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (collection.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'バッジはまだありません',
            key: AppKeys.badgeCollectionEmpty,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    final sections = <Widget>[
      // ── サマリー ──
      Card(
        key: AppKeys.badgeCollectionSummary,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '実績バッジ',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                collection.summaryLabel,
                key: AppKeys.badgeCollectionSummaryLabel,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: collection.completionRatio,
                minHeight: 8,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // ── カテゴリごとのセクション ──
      for (final category in BadgeCategory.values) ...[
        _CategorySection(
          category: category,
          badges: collection.badgesOf(category),
        ),
        const SizedBox(height: 16),
      ],
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sections,
    );
  }
}

/// カテゴリ別セクション
class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.badges});

  final BadgeCategory category;
  final List<BadgeProgress> badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earned = badges.where((b) => b.isEarned).length;

    return Column(
      key: AppKeys.badgeCategorySection(category.name),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(category.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.label,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              '獲得 $earned / ${badges.length}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final badge in badges) _BadgeRow(badge: badge),
      ],
    );
  }
}

/// バッジ1行分
class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badge});

  final BadgeProgress badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final def = badge.definition;
    final earnedAt = badge.earnedAt;

    final dateText = badge.isEarned && earnedAt != null
        ? '${earnedAt.year}-${earnedAt.month.toString().padLeft(2, '0')}-'
            '${earnedAt.day.toString().padLeft(2, '0')} 獲得'
        : null;

    final row = Padding(
      key: AppKeys.badgeRow(def.id),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(def.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            def.name,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          badgeTierLabel(def.tier),
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          badge.isEarned
                              ? Icons.check_circle
                              : Icons.lock_outline,
                          size: 18,
                          color: badge.isEarned ? Colors.amber : null,
                          key: badge.isEarned
                              ? AppKeys.badgeEarnedMark(def.id)
                              : null,
                        ),
                      ],
                    ),
                    Text(
                      def.description,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: badge.ratio,
                  minHeight: 6,
                ),
              ),
              const SizedBox(width: 8),
              Text(badge.progressLabel, style: theme.textTheme.bodySmall),
            ],
          ),
          if (dateText != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                dateText.toLowerCase(),
                style: theme.textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );

    if (badge.isEarned) return row;
    return Opacity(opacity: 0.55, child: row);
  }
}