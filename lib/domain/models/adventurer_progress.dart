/// 冒険者ステータスのうち、クライアント側で積み上げる項目のみを永続化するモデル。
///
/// サーバ（Supabase）由来の統計（冊数・分数・ストリーク）は従来経路のまま扱い、
/// ここでは **level / xp / xpToNextLevel / title / readingDates** だけを保存する。
library;

import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';

class AdventurerProgress {
  final int level;
  final int xp;
  final int xpToNextLevel;
  final String title;
  final List<String> readingDates;

  const AdventurerProgress({
    required this.level,
    required this.xp,
    required this.xpToNextLevel,
    required this.title,
    required this.readingDates,
  });

  /// 駆け出し状態（保存データなし・破損時のフォールバック先）
  factory AdventurerProgress.beginner() {
    return const AdventurerProgress(
      level: 1,
      xp: 0,
      xpToNextLevel: 100,
      title: '書庫の見習い',
      readingDates: [],
    );
  }

  /// 現在のステータスから永続化対象だけを抜き出す
  factory AdventurerProgress.fromStats(AdventurerStats stats) {
    return AdventurerProgress(
      level: stats.level < 1 ? 1 : stats.level,
      xp: stats.xp < 0 ? 0 : stats.xp,
      xpToNextLevel: stats.xpToNextLevel <= 0 ? 100 : stats.xpToNextLevel,
      title: stats.title.isEmpty ? '書庫の見習い' : stats.title,
      readingDates: normalizeReadingDates(stats.readingDates),
    );
  }

  /// サーバ由来の統計に、ローカルの積み上げを重ねる
  ///
  /// **サーバ側の level/xp は常に初期値（1 / 0）で返る**ため、レベル・XP・
  /// 称号・読書日はローカル値を正とする。冊数・分数・ストリークはサーバ値を維持する。
  AdventurerStats applyTo(AdventurerStats server) {
    return AdventurerStats(
      level: level,
      xp: xp,
      xpToNextLevel: xpToNextLevel,
      title: title,
      totalBooksRegistered: server.totalBooksRegistered,
      totalBooksCompleted: server.totalBooksCompleted,
      totalReadingMinutes: server.totalReadingMinutes,
      totalPagesRead: server.totalPagesRead,
      currentStreak: server.currentStreak,
      longestStreak: server.longestStreak,
      readingDates: normalizeReadingDates([
        ...server.readingDates,
        ...readingDates,
      ]),
      errorMessage: server.errorMessage,
    );
  }

  /// 読書日リストの正規化（先頭10文字・空除去・重複除去・昇順）
  static List<String> normalizeReadingDates(Iterable<String> dates) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in dates) {
      final value = raw.length >= 10 ? raw.substring(0, 10) : raw;
      if (value.isEmpty) continue;
      if (seen.add(value)) result.add(value);
    }
    result.sort();
    return List<String>.unmodifiable(result);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'level': level,
      'xp': xp,
      'xpToNextLevel': xpToNextLevel,
      'title': title,
      'readingDates': readingDates,
    };
  }

  /// 破損・欠損キーは既定値へフォールバックする（例外を投げない）
  factory AdventurerProgress.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    final level = readInt('level', 1);
    final xp = readInt('xp', 0);
    final xpToNextLevel = readInt('xpToNextLevel', 100);
    final rawTitle = json['title'];
    final rawDates = json['readingDates'];
    final dates = <String>[];
    if (rawDates is List) {
      for (final entry in rawDates) {
        if (entry is String) dates.add(entry);
      }
    }

    return AdventurerProgress(
      level: level < 1 ? 1 : level,
      xp: xp < 0 ? 0 : xp,
      xpToNextLevel: xpToNextLevel <= 0 ? 100 : xpToNextLevel,
      title: (rawTitle is String && rawTitle.isNotEmpty)
          ? rawTitle
          : '書庫の見習い',
      readingDates: normalizeReadingDates(dates),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AdventurerProgress) return false;
    if (other.level != level ||
        other.xp != xp ||
        other.xpToNextLevel != xpToNextLevel ||
        other.title != title ||
        other.readingDates.length != readingDates.length) {
      return false;
    }
    for (var i = 0; i < readingDates.length; i++) {
      if (other.readingDates[i] != readingDates[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        level,
        xp,
        xpToNextLevel,
        title,
        Object.hashAll(readingDates),
      );

  @override
  String toString() =>
      'AdventurerProgress(level: $level, xp: $xp, title: $title, '
      'readingDates: ${readingDates.length})';
}
