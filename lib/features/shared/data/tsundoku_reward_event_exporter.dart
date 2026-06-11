import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

/// 報酬イベントを共有ストレージにJSONLとして書き出すエクスポーター
///
/// Kozuchiアプリが読み取れるよう、共有ストレージにJSONLファイルを書き出す。
/// パス: /data/local/tmp/takamagahara_shared/tsundoku_reward_events.jsonl
///
/// イベントタイプ:
/// - level_up: 冒険者のレベルが上昇
/// - xp_milestone: 累計XPが特定のマイルストーンを達成
/// - daily_mission_complete: デイリーミッションを全て達成
/// - trophy_written: 戦利品（読書メモ）を執筆
/// - book_completed: 本を読了
/// - pages_milestone: 累計読書ページ数が特定のマイルストーンを達成
/// - reading_streak: 読書継続日数が特定のマイルストーンを達成
class TsundokuRewardEventExporter {
  final String filePath;
  String _userId;
  static const _uuid = Uuid();

  TsundokuRewardEventExporter({
    this.filePath =
        '/data/local/tmp/takamagahara_shared/tsundoku_reward_events.jsonl',
    String? userId,
  }) : _userId = userId ?? '';

  /// ユーザーIDを設定（Supabase認証状態の変更に応じて更新）
  set userId(String value) => _userId = value;
  String get userId => _userId;

  String _generateEventId() => _uuid.v4();
  String _nowTimestamp() => DateTime.now().toUtc().toIso8601String();

  /// JSONLに1行追記。書き込み失敗は握りつぶす（best-effort）。
  /// 同期的に書き込む — 呼び出し元からawaitされないfire-and-forgetパターンのため。
  void _writeEvent(Map<String, dynamic> event) {
    try {
      final file = File(filePath);
      file.parent.createSync(recursive: true);
      final line = jsonEncode(event);
      file.writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {
      // Best-effort export — silently ignore write failures
    }
  }

  /// レベルアップイベント
  void exportLevelUp({
    required int newLevel,
    required String title,
    String? timestamp,
  }) {
    _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'level_up',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'new_level': newLevel,
      'title': title,
    });
  }

  /// XPマイルストーン達成イベント
  void exportXpMilestone({
    required int milestone,
    required int totalXp,
    String? timestamp,
  }) {
    _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'xp_milestone',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'milestone': milestone,
      'total_xp': totalXp,
    });
  }

  /// デイリーミッション全達成イベント
  void exportDailyMissionComplete({
    required String date,
    required int completedCount,
    required int totalCount,
    String? timestamp,
  }) {
    _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'daily_mission_complete',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'date': date,
      'completed_count': completedCount,
      'total_count': totalCount,
    });
  }

  /// 戦利品執筆イベント
  void exportTrophyWritten({
    required String trophyId,
    required String userBookId,
    required int learningCount,
    String? timestamp,
  }) {
    _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'trophy_written',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'trophy_id': trophyId,
      'user_book_id': userBookId,
      'learning_count': learningCount,
    });
  }

  /// 読了イベント
  void exportBookCompleted({
    required String bookId,
    required String? bookTitle,
    String? timestamp,
  }) {
    _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'book_completed',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'book_id': bookId,
      'book_title': bookTitle ?? '',
    });
  }

  /// 読書ページ数マイルストーン達成イベント
  void exportPagesMilestone({
    required int milestone,
    required int totalPages,
    String? timestamp,
  }) {
    _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'pages_milestone',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'milestone': milestone,
      'total_pages': totalPages,
    });
  }

  /// 読書継続日数マイルストーン達成イベント
  void exportReadingStreak({
    required int streak,
    String? timestamp,
  }) {
    _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'reading_streak',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'streak': streak,
    });
  }
}
