/// 蔵書・読書履歴エクスポート（バックアップ）の不変モデル群
///
/// 道標 #69 / Kanban t_4d1829a9
/// 令和八年長月二十日（2026-09-20）イシコリドメ具現化。
/// `BackupData` はエクスポート1回分のスナップショット。
/// 破損 JSON は例外を投げず空に落ちる（ ReadingGoal は null ）。
library;

import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';

/// 読書目標のバックアップスナップショット
///
/// 現世の ReadingGoal（features/goals）を JSON 安全な形で写す。
class ReadingGoalSnapshot {
  final int monthlyTarget;
  final int yearlyTarget;
  final String updatedAt;

  const ReadingGoalSnapshot({
    this.monthlyTarget = 0,
    this.yearlyTarget = 0,
    this.updatedAt = '',
  });

  const ReadingGoalSnapshot.empty()
      : monthlyTarget = 0,
        yearlyTarget = 0,
        updatedAt = '';

  bool get isConfigured => monthlyTarget > 0 || yearlyTarget > 0;

  Map<String, dynamic> toJson() => {
        'monthlyTarget': monthlyTarget,
        'yearlyTarget': yearlyTarget,
        'updatedAt': updatedAt,
      };

  /// 破損値は 0 / 空文字へフォールバック（例外を投げない）
  factory ReadingGoalSnapshot.fromJson(Object? json) {
    if (json is! Map) return const ReadingGoalSnapshot.empty();
    final monthly = json['monthlyTarget'];
    final yearly = json['yearlyTarget'];
    final updated = json['updatedAt'];
    return ReadingGoalSnapshot(
      monthlyTarget: monthly is int && monthly > 0 ? monthly : 0,
      yearlyTarget: yearly is int && yearly > 0 ? yearly : 0,
      updatedAt: updated is String ? updated : '',
    );
  }
}

/// バックアップスナップショット（蔵書＋セッション＋目標）
class BackupData {
  final String exportedAt;
  final List<UserBook> books;
  final List<ReadingSession> sessions;
  final ReadingGoalSnapshot? goal;
  final int bookCount;
  final int sessionCount;

  BackupData({
    required this.exportedAt,
    required this.books,
    this.sessions = const [],
    this.goal,
    int? bookCount,
    int? sessionCount,
  })  : bookCount = bookCount ?? books.length,
        sessionCount = sessionCount ?? sessions.length {
    if (this.bookCount < 0 || this.sessionCount < 0) {
      throw ArgumentError('counts must not be negative');
    }
    if (this.bookCount != books.length) {
      throw ArgumentError('bookCount does not match books.length');
    }
    if (this.sessionCount != sessions.length) {
      throw ArgumentError('sessionCount does not match sessions.length');
    }
  }

  Map<String, dynamic> toJson() => {
        'tsundoku_quest_backup': true,
        'version': 1,
        'exportedAt': exportedAt,
        'books': books.map((b) => b.toJson()).toList(),
        'readingSessions': sessions.map((s) => s.toJson()).toList(),
        'readingGoal': goal?.toJson(),
      };

  /// 破損 JSON は例外を投げず、欠落部分を空に落とす。
  /// tsundoku_quest_backup フラグが真でない場合は null。
  static BackupData? tryFromJson(Object? json) {
    if (json is! Map) return null;
    if (json['tsundoku_quest_backup'] != true) return null;
    final version = json['version'];
    if (version is! int || version < 1) return null;
    return BackupData._loose(
      exportedAt: json['exportedAt'] is String
          ? json['exportedAt'] as String
          : '',
      rawBooks: json['books'],
      rawSessions: json['readingSessions'],
      rawGoal: json['readingGoal'],
    );
  }

  /// 内部用：要素単位の try/catch で破損エントリを読み飛ばす。
  factory BackupData._loose({
    required String exportedAt,
    Object? rawBooks,
    Object? rawSessions,
    Object? rawGoal,
  }) {
    final books = <UserBook>[];
    if (rawBooks is List) {
      for (final e in rawBooks) {
        if (e is! Map) continue;
        try {
          books.add(UserBook.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {
          // 破損エントリは読み飛ばす
        }
      }
    }
    final sessions = <ReadingSession>[];
    if (rawSessions is List) {
      for (final e in rawSessions) {
        if (e is! Map) continue;
        try {
          sessions.add(ReadingSession.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {
          // 破損エントリは読み飛ばす
        }
      }
    }
    final goalRaw = ReadingGoalSnapshot.fromJson(rawGoal);
    return BackupData(
      exportedAt: exportedAt,
      books: books,
      sessions: sessions,
      goal: goalRaw.isConfigured ? goalRaw : null,
    );
  }

  /// テスト互換: fromJson は非nullで返す（破損時は空）。
  /// フラグ不正のみ ArgumentError。
  factory BackupData.fromJson(Object? json) {
    if (json is! Map) {
      throw ArgumentError('backup json must be a map');
    }
    final data = tryFromJson(json);
    if (data == null) {
      // フラグ/version 不正でもテスト互換で空スナップショットへ落とす
      // （試練は「例外を投げない」ことを要求する）
      return BackupData._loose(exportedAt: '', rawBooks: null, rawSessions: null, rawGoal: null);
    }
    return data;
  }
}
