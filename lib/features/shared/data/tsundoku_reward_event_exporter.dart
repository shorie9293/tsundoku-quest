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
  ///
  /// [metadata] は rpg-task 側の報酬計算が読む入れ子オブジェクト。
  /// 参照: rpg-task/lib/features/crossapp/data/cross_app_reward_service.dart は
  /// `event.metadata['count'|'streak_days'|'xp'|'pages']` を読む。
  /// トップレベルフィールド（streak/total_xp/total_pages 等）は後方互換のため残す。
  ///
  /// userId が空のまま書き出すと rpg の `CrossAppRewardEvent.fromJson` が
  /// FormatException を投げて行ごとスキップされる（=報酬ゼロ）ため、
  /// 空のときは書き出さない。認証前のイベントは捨てるのが正しい挙動。
  Future<void> _writeEvent(
    Map<String, dynamic> event, {
    Map<String, dynamic>? metadata,
  }) async {
    if (_userId.trim().isEmpty) return;
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      final payload = <String, dynamic>{
        ...event,
        'metadata': metadata ?? const <String, dynamic>{},
      };
      final line = jsonEncode(payload);
      await file.writeAsString('$line\n', mode: FileMode.append);
    } catch (_) {
      // Best-effort export — silently ignore write failures
    }
  }

  /// レベルアップイベント
  Future<void> exportLevelUp({
    required int newLevel,
    required String title,
    String? timestamp,
  }) async {
    await _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'level_up',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'new_level': newLevel,
      'title': title,
    }, metadata: {
      'new_level': newLevel,
      'title': title,
    });
  }

  /// XPマイルストーン達成イベント
  Future<void> exportXpMilestone({
    required int milestone,
    required int totalXp,
    String? timestamp,
  }) async {
    await _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'xp_milestone',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'milestone': milestone,
      'total_xp': totalXp,
    }, metadata: {
      'milestone': milestone,
      'xp': totalXp,
    });
  }

  /// デイリーミッション全達成イベント
  Future<void> exportDailyMissionComplete({
    required String date,
    required int completedCount,
    required int totalCount,
    String? timestamp,
  }) async {
    await _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'daily_mission_complete',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'date': date,
      'completed_count': completedCount,
      'total_count': totalCount,
    }, metadata: {
      'date': date,
      'completed': completedCount,
      'total': totalCount,
    });
  }

  /// 戦利品執筆イベント
  Future<void> exportTrophyWritten({
    required String trophyId,
    required String userBookId,
    required int learningCount,
    String? timestamp,
  }) async {
    await _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'trophy_written',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'trophy_id': trophyId,
      'user_book_id': userBookId,
      'learning_count': learningCount,
    }, metadata: {
      'trophy_id': trophyId,
      'user_book_id': userBookId,
      'learning_count': learningCount,
    });
  }

  /// 読了イベント
  Future<void> exportBookCompleted({
    required String bookId,
    required String? bookTitle,
    String? timestamp,
  }) async {
    await _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'book_completed',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'book_id': bookId,
      'book_title': bookTitle ?? '',
    }, metadata: {
      'book_id': bookId,
      'book_title': bookTitle ?? '',
      // rpg は book_completed の回数を metadata['count'] で数える
      'count': 1,
    });
  }

  /// 読書ページ数マイルストーン達成イベント
  Future<void> exportPagesMilestone({
    required int milestone,
    required int totalPages,
    String? timestamp,
  }) async {
    await _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'pages_milestone',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'milestone': milestone,
      'total_pages': totalPages,
    }, metadata: {
      'milestone': milestone,
      'pages': totalPages,
    });
  }

  /// 読書継続日数マイルストーン達成イベント
  Future<void> exportReadingStreak({
    required int streak,
    String? timestamp,
  }) async {
    await _writeEvent({
      'event_id': _generateEventId(),
      'event_type': 'reading_streak',
      'user_id': _userId,
      'timestamp': timestamp ?? _nowTimestamp(),
      'streak': streak,
    }, metadata: {
      // rpg は reading_streak を metadata['streak_days'] で読む
      'streak_days': streak,
    });
  }
}
