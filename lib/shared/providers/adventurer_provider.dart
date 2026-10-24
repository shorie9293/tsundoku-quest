import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/models/adventurer_progress.dart';
import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';
import 'package:tsundoku_quest/domain/repositories/adventurer_repository.dart';
import 'package:tsundoku_quest/features/shared/data/adventurer_progress_repository.dart';
import 'package:tsundoku_quest/features/shared/data/tsundoku_reward_event_exporter.dart';
import 'xp_calculator.dart';

/// XPマイルストーン閾値
const _xpMilestones = [100, 500, 1000, 5000, 10000, 50000, 100000];

/// 読書ページ数マイルストーン閾値
const _pagesMilestones = [100, 500, 1000, 5000, 10000];

/// 読書継続日数マイルストーン閾値
const _streakMilestones = [7, 14, 30, 60, 100];

/// 冒険者ステータスを管理するStateNotifier
class AdventurerNotifier extends StateNotifier<AdventurerStats> {
  final TsundokuRewardEventExporter? _rewardExporter;
  final AdventurerProgressRepository? _progressRepository;

  /// ローカルに復元した積み上げ（level/xp/title/readingDates）
  AdventurerProgress? _localProgress;

  /// [rewardExporter] が指定された場合、レベルアップやマイルストーン達成時に
  /// イベントを共有ストレージに書き出す。
  /// [progressRepository] が指定された場合、積み上げ（レベル・XP・称号・読書日）を
  /// 永続化し、再起動時に復元する。
  AdventurerNotifier({
    TsundokuRewardEventExporter? rewardExporter,
    AdventurerProgressRepository? progressRepository,
  })  : _rewardExporter = rewardExporter,
        _progressRepository = progressRepository,
        super(AdventurerStats.beginner());

  /// 保存済みの積み上げを復元する（起動時に一度だけ呼ぶ）
  Future<void> loadProgress() async {
    final repository = _progressRepository;
    if (repository == null) return;
    try {
      final progress = await repository.load();
      _localProgress = progress;
      state = progress.applyTo(state);
    } catch (e) {
      debugPrint('⚠️ 冒険者ステータスの復元失敗: $e');
    }
  }

  /// 現在の state を永続化する（失敗しても本処理は止めない）
  void persistProgress() {
    final repository = _progressRepository;
    if (repository == null) return;
    final progress = AdventurerProgress.fromStats(state);
    _localProgress = progress;
    repository.save(progress).catchError((Object e) {
      debugPrint('⚠️ 冒険者ステータスの保存失敗: $e');
    });
  }

  /// Supabase から冒険者ステータスを読み込んで state を更新する
  ///
  /// サーバ側は level/xp を常に初期値で返すため、ローカルの積み上げを重ねる。
  void loadFromRepository(AdventurerRepository repository) {
    repository.stats().then((stats) {
      final progress =
          _localProgress ?? AdventurerProgress.fromStats(state);
      _localProgress = progress;
      state = progress.applyTo(stats);
    }).catchError((error, stackTrace) {
      // Supabase が使えない場合はローカルの積み上げを保ったまま
      debugPrint('⚠️ Supabase から冒険者ステータス取得失敗: $error\n$stackTrace');
      state = _copyWith(errorMessage: 'サーバーに接続できません（オフラインモード）');
    });
  }

  // ━━━ XP操作 ━━━

  void addXp(int amount) {
    final oldLevel = state.level;
    final oldTotalXp = _computeTotalXpFromLevel(state.level, state.xp);
    final newTotalXp = oldTotalXp + amount;
    final levelResult = calculateLevel(newTotalXp);
    state = AdventurerStats(
      level: levelResult.level,
      xp: levelResult.xp,
      xpToNextLevel: levelResult.xpToNextLevel,
      title: levelResult.title,
      totalBooksRegistered: state.totalBooksRegistered,
      totalBooksCompleted: state.totalBooksCompleted,
      totalReadingMinutes: state.totalReadingMinutes,
      totalPagesRead: state.totalPagesRead,
      currentStreak: state.currentStreak,
      longestStreak: state.longestStreak,
      readingDates: state.readingDates,
    );

    // レベルアップ検知
    if (levelResult.level > oldLevel) {
      _rewardExporter?.exportLevelUp(
        newLevel: levelResult.level,
        title: levelResult.title,
      );
    }

    // XPマイルストーン検知
    for (final milestone in _xpMilestones) {
      if (oldTotalXp < milestone && newTotalXp >= milestone) {
        _rewardExporter?.exportXpMilestone(
          milestone: milestone,
          totalXp: newTotalXp,
        );
      }
    }

    // 積み上げ（レベル・XP・称号）を永続化
    persistProgress();
  }

  /// 現在のレベルとXPから総XPを逆算
  int _computeTotalXpFromLevel(int level, int xp) {
    return ((level - 1) * (level - 1)) * 100 + xp;
  }

  // ━━━ カウント操作 ━━━

  void incrementBooksRegistered() {
    state = _copyWith(totalBooksRegistered: state.totalBooksRegistered + 1);
  }

  void incrementBooksCompleted() {
    state = _copyWith(totalBooksCompleted: state.totalBooksCompleted + 1);
  }

  // ━━━ 読書統計 ━━━

  void updateReadingStats({required int minutes, required int pages}) {
    final oldTotalPages = state.totalPagesRead;
    final newTotalPages = oldTotalPages + pages;
    state = _copyWith(
      totalReadingMinutes: state.totalReadingMinutes + minutes,
      totalPagesRead: newTotalPages,
    );

    // 読書ページ数マイルストーン検知
    for (final milestone in _pagesMilestones) {
      if (oldTotalPages < milestone && newTotalPages >= milestone) {
        _rewardExporter?.exportPagesMilestone(
          milestone: milestone,
          totalPages: newTotalPages,
        );
      }
    }
  }

  // ━━━ ストリーク ━━━

  void updateStreak({required int current, required int longest}) {
    final oldStreak = state.currentStreak;
    state = _copyWith(
      currentStreak: current,
      longestStreak:
          longest > state.longestStreak ? longest : state.longestStreak,
    );

    // 読書継続日数マイルストーン検知
    for (final milestone in _streakMilestones) {
      if (oldStreak < milestone && current >= milestone) {
        _rewardExporter?.exportReadingStreak(streak: milestone);
      }
    }
  }

  AdventurerStats _copyWith({
    int? level,
    int? xp,
    int? xpToNextLevel,
    String? title,
    int? totalBooksRegistered,
    int? totalBooksCompleted,
    int? totalReadingMinutes,
    int? totalPagesRead,
    int? currentStreak,
    int? longestStreak,
    List<String>? readingDates,
    String? errorMessage,
  }) {
    return AdventurerStats(
      level: level ?? state.level,
      xp: xp ?? state.xp,
      xpToNextLevel: xpToNextLevel ?? state.xpToNextLevel,
      title: title ?? state.title,
      totalBooksRegistered: totalBooksRegistered ?? state.totalBooksRegistered,
      totalBooksCompleted: totalBooksCompleted ?? state.totalBooksCompleted,
      totalReadingMinutes: totalReadingMinutes ?? state.totalReadingMinutes,
      totalPagesRead: totalPagesRead ?? state.totalPagesRead,
      currentStreak: currentStreak ?? state.currentStreak,
      longestStreak: longestStreak ?? state.longestStreak,
      readingDates: readingDates ?? state.readingDates,
      errorMessage: errorMessage ?? state.errorMessage,
    );
  }

  // ━━━ 読書日付操作 ━━━

  void addReadingDate(String date) {
    final dateStr = date.length >= 10 ? date.substring(0, 10) : date;
    if (!state.readingDates.contains(dateStr)) {
      state = _copyWith(
        readingDates: [...state.readingDates, dateStr],
      );
      // 読書日リストを永続化
      persistProgress();
    }
  }
}

/// 冒険者ステータスの永続化リポジトリ
///
/// Hive が初期化されていれば Hive 実装、それ以外はインメモリ実装にフォールバックする。
final adventurerProgressRepositoryProvider =
    Provider<AdventurerProgressRepository>((ref) {
  try {
    final boxManager = ref.read(hiveBoxManagerProvider);
    return HiveAdventurerProgressRepository(boxManager);
  } catch (_) {
    return InMemoryAdventurerProgressRepository();
  }
});

/// Riverpod プロバイダ
final adventurerProvider =
    StateNotifierProvider<AdventurerNotifier, AdventurerStats>((ref) {
  return AdventurerNotifier(
    progressRepository: ref.read(adventurerProgressRepositoryProvider),
  );
});
