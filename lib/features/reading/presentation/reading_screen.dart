import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/widgets/dungeon_background.dart';
import '../../../../shared/providers/book_data_provider.dart';
import '../../../../shared/providers/adventurer_provider.dart';
import '../../../../shared/providers/xp_calculator.dart';
import '../../../../features/shared/providers/war_trophy_provider.dart';
import '../../../../domain/models/user_book.dart';
import '../../../../domain/models/war_trophy.dart';
import '../../bookshelf/data/daily_mission_provider.dart';
import '../data/reading_session_repository_provider.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 読書中画面
class ReadingScreen extends ConsumerStatefulWidget {
  final String? id;
  const ReadingScreen({super.key, this.id});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  final _pageController = TextEditingController();
  final _memoController = TextEditingController();
  bool _showCompleteModal = false;
  final _learningControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController()
  ];
  final _actionController = TextEditingController();
  final _quoteController = TextEditingController();

  String? _sessionId;
  int _startPage = 0;
  int _lastSavedSeconds = 0; // 前回保存時点の経過秒数（二重保存防止）
  DateTime? _sessionStartTime; // セッション開始時刻（タイマー永続化用）
  static const _prefsKeyStartTime = 'reading_session_start_time';
  static const _prefsKeyBookId = 'reading_session_book_id';
  static const _prefsKeyElapsedSeconds = 'reading_session_elapsed_seconds';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSession();
    });
  }

  Future<void> _startSession() async {
    if (widget.id == null) return;
    try {
      final repo = ref.read(readingSessionRepositoryProvider);
      final session = await repo.startSession(widget.id!, 0);
      _sessionId = session.id;
    } catch (e) {
      // Supabase未初期化（テスト/オフライン）→ セッションなしで動作
    }

    // タイマー永続化：前回のセッションがあれば復元
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBookId = prefs.getString(_prefsKeyBookId);
      if (savedBookId == widget.id) {
        final savedStartMillis = prefs.getInt(_prefsKeyStartTime);
        final savedElapsed = prefs.getInt(_prefsKeyElapsedSeconds) ?? 0;
        if (savedStartMillis != null && savedStartMillis > 0) {
          final savedStart = DateTime.fromMillisecondsSinceEpoch(savedStartMillis);
          final now = DateTime.now();
          // セッションが24時間以内なら復元（それ以上は放置による不正な加算を防止）
          if (now.difference(savedStart).inHours < 24) {
            final additionalSeconds = now.difference(savedStart).inSeconds;
            setState(() {
              _elapsedSeconds = savedElapsed + additionalSeconds;
            });
            // タイマーも自動再開
            _sessionStartTime = savedStart;
            _timer = Timer.periodic(const Duration(seconds: 1), (_) {
              setState(() {
                _elapsedSeconds++;
                // 30秒ごとにタイマー状態を保存
                if (_elapsedSeconds % 30 == 0) {
                  _saveTimerState();
                }
              });
            });
            _isRunning = true;
          } else {
            // 古いセッションは破棄
            await prefs.remove(_prefsKeyStartTime);
            await prefs.remove(_prefsKeyBookId);
            await prefs.remove(_prefsKeyElapsedSeconds);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ReadingScreen] タイマー復元失敗: $e');
    }

    // 読書開始 → ステータスを reading に遷移
    try {
      ref.read(bookDataProvider.notifier).updateUserBook(
            id: widget.id!,
            status: BookStatus.reading,
            startedAt: DateTime.now().toUtc().toIso8601String(),
          );
    } catch (e) {
      debugPrint('⚠️ [ReadingScreen] ステータス更新失敗: $e');
    }
  }

  Future<void> _endSessionIfNeeded() async {
    if (_sessionId == null) return;
    final sessionId = _sessionId!;
    _sessionId = null; // 即座にnull化して二重実行を防止

    // 未保存分のみ計算（_saveSessionProgressで既保存分を除外）
    final remainingSeconds = _elapsedSeconds - _lastSavedSeconds;
    final durationMinutes = remainingSeconds ~/ 60;
    _lastSavedSeconds += durationMinutes * 60;
    if (durationMinutes <= 0) return;

    final endPage = _pageController.text.isNotEmpty
        ? int.tryParse(_pageController.text) ?? _book?.currentPage ?? 0
        : _book?.currentPage ?? 0;

    // 読書時間に応じたXPを付与 (分×2)
    if (durationMinutes > 0) {
      final xp = calculateXp(type: 'reading_session', minutes: durationMinutes);
      if (xp > 0) {
        try {
          ref.read(adventurerProvider.notifier).addXp(xp);
        } catch (e) {
          debugPrint('⚠️ [ReadingScreen] XP付与失敗: $e');
        }
      }
    }

    // デイリーミッションの進捗を更新
    final pagesReadForMission = endPage - _startPage;
    _updateDailyMissionProgress(
        minutes: durationMinutes, pagesRead: pagesReadForMission > 0 ? pagesReadForMission : 0);

    try {
      final repo = ref.read(readingSessionRepositoryProvider);
      final totalMinutes = _elapsedSeconds ~/ 60;
      await repo.endSession(sessionId, endPage, totalMinutes);
    } catch (e) {
      debugPrint('⚠️ [ReadingScreen] セッション終了失敗（Supabase未接続/オフライン）: $e');
    }

    try {
      final adventurer = ref.read(adventurerProvider.notifier);
      adventurer.updateReadingStats(minutes: durationMinutes, pages: endPage - _startPage);

      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      adventurer.addReadingDate(today);
    } catch (e) {
      debugPrint('⚠️ [ReadingScreen] 統計更新失敗: $e');
    }

    // UserBookのtotalReadingMinutesも永続化
    if (widget.id != null) {
      try {
        final book = ref.read(bookDataProvider.notifier).getUserBook(widget.id!);
        if (book != null) {
          ref.read(bookDataProvider.notifier).updateUserBook(
                id: widget.id!,
                totalReadingMinutes: book.totalReadingMinutes + durationMinutes,
              );
        }
      } catch (e) {
        debugPrint('⚠️ [ReadingScreen] UserBook更新失敗: $e');
      }
    }
  }

  /// 一時停止時点の読書進捗を即座に保存（二重保存防止付き）
  void _saveSessionProgress() {
    final newSeconds = _elapsedSeconds - _lastSavedSeconds;
    final minutes = newSeconds ~/ 60;
    if (minutes <= 0) return;

    _lastSavedSeconds += minutes * 60; // 保存済み分を記録

    // 読書時間に応じたXPを付与 (分×2)
    final xp = calculateXp(type: 'reading_session', minutes: minutes);
    if (xp > 0) {
      try {
        ref.read(adventurerProvider.notifier).addXp(xp);
      } catch (e) {
        debugPrint('⚠️ [ReadingScreen] XP付与失敗: $e');
      }
    }

    // デイリーミッションの進捗を更新
    _updateDailyMissionProgress(minutes: minutes, pagesRead: 0);

    // UserBookのtotalReadingMinutes更新
    if (widget.id != null) {
      try {
        final book = ref.read(bookDataProvider.notifier).getUserBook(widget.id!);
        if (book != null) {
          ref.read(bookDataProvider.notifier).updateUserBook(
                id: widget.id!,
                totalReadingMinutes: book.totalReadingMinutes + minutes,
              );
        }
      } catch (e) {
        debugPrint('⚠️ [ReadingScreen] 進捗保存失敗: $e');
      }
    }

    // 冒険者の統計更新
    try {
      ref.read(adventurerProvider.notifier).updateReadingStats(minutes: minutes, pages: 0);
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      ref.read(adventurerProvider.notifier).addReadingDate(today);
    } catch (e) {
      debugPrint('⚠️ [ReadingScreen] 統計更新失敗: $e');
    }

    // Supabaseのreading_sessionsに現在の累積読書時間を保存
    if (_sessionId != null) {
      try {
        final totalMinutes = _elapsedSeconds ~/ 60;
        final endPage = _pageController.text.isNotEmpty
            ? int.tryParse(_pageController.text) ?? _book?.currentPage ?? 0
            : _book?.currentPage ?? 0;
        final repo = ref.read(readingSessionRepositoryProvider);
        repo.endSession(_sessionId!, endPage, totalMinutes);
      } catch (e) {
        debugPrint('⚠️ [ReadingScreen] 進捗のSupabase保存失敗: $e');
      }
    }
  }

  UserBook? get _book {
    if (widget.id == null) return null;
    return ref.read(bookDataProvider.notifier).getUserBook(widget.id!);
  }

  void _toggleTimer() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _startPage = _pageController.text.isNotEmpty
            ? int.tryParse(_pageController.text) ?? _book?.currentPage ?? 0
            : _book?.currentPage ?? 0;
        _sessionStartTime = DateTime.now();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() {
            _elapsedSeconds++;
            // 30秒ごとにタイマー状態を保存（アプリ強制終了対策）
            if (_elapsedSeconds % 30 == 0) {
              _saveTimerState();
            }
          });
        });
        // タイマー永続化：開始時刻を保存
        _saveTimerState();
      } else {
        _timer?.cancel();
        // 一時停止時に即座に読書時間を保存
        _saveSessionProgress();
        // 経過秒数を保存してタイマーをクリア
        _clearTimerState(saveElapsed: true);
      }
    });
  }

  /// タイマー状態を SharedPreferences に保存
  Future<void> _saveTimerState() async {
    if (_sessionStartTime == null || widget.id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyStartTime, _sessionStartTime!.millisecondsSinceEpoch);
      await prefs.setString(_prefsKeyBookId, widget.id!);
      await prefs.setInt(_prefsKeyElapsedSeconds, _elapsedSeconds);
    } catch (e) {
      debugPrint('⚠️ [ReadingScreen] タイマー保存失敗: $e');
    }
  }

  /// タイマー状態をクリア
  Future<void> _clearTimerState({bool saveElapsed = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (saveElapsed) {
        await prefs.setInt(_prefsKeyElapsedSeconds, _elapsedSeconds);
      } else {
        await prefs.remove(_prefsKeyStartTime);
        await prefs.remove(_prefsKeyBookId);
        await prefs.remove(_prefsKeyElapsedSeconds);
      }
    } catch (e) {
      debugPrint('⚠️ [ReadingScreen] タイマー状態クリア失敗: $e');
    }
  }

  /// デイリーミッションの進捗を更新し、達成XPを付与
  void _updateDailyMissionProgress({
    required int minutes,
    required int pagesRead,
  }) {
    try {
      final missionNotifier = ref.read(dailyMissionProvider.notifier);
      if (minutes > 0) {
        missionNotifier.addReadingMinutes(minutes).then((xp) {
          if (xp > 0) {
            ref.read(adventurerProvider.notifier).addXp(xp);
          }
        });
      }
      if (pagesRead > 0) {
        missionNotifier.addReadingPages(pagesRead).then((xp) {
          if (xp > 0) {
            ref.read(adventurerProvider.notifier).addXp(xp);
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ [ReadingScreen] デイリーミッション更新失敗: $e');
    }
  }

  /// 読了時のデイリーミッション進捗更新
  void _updateDailyMissionBookComplete() {
    try {
      ref.read(dailyMissionProvider.notifier).addBookCompleted().then((xp) {
        if (xp > 0) {
          ref.read(adventurerProvider.notifier).addXp(xp);
        }
      });
    } catch (e) {
      debugPrint('⚠️ [ReadingScreen] デイリーミッション読了更新失敗: $e');
    }
  }

  void _updatePage(String value) {
    final page = int.tryParse(value) ?? 0;
    if (widget.id != null && _book != null) {
      ref.read(bookDataProvider.notifier).updateUserBook(
            id: widget.id!,
            currentPage: page,
          );
    }
  }

  void _showComplete() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _showCompleteModal = true;
    });
    _clearTimerState(); // タイマー永続化状態をクリア
  }

  /// 読了確認モーダルを表示（誤操作防止）
  void _showCompleteConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🏁 冒険を完了しますか？'),
        content: Text(
          '「${_book?.book?.title ?? '不明な本'}」を読了として記録します。\n'
          'この操作は元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('まだ読む'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showComplete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.completedColor,
            ),
            child: const Text('読了する'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopReading() async {
    _timer?.cancel();
    setState(() => _isRunning = false);
    try {
      await _endSessionIfNeeded();
    } catch (_) {
      // dispose 中など、contextが無効な場合のクラッシュ防止
    }
    await _clearTimerState(); // タイマー永続化状態を完全クリア
    if (mounted) context.pop();
  }

  Future<void> _submitTrophy() async {
    if (widget.id == null) return;
    await _endSessionIfNeeded();
    _clearTimerState(); // タイマー永続化状態を完全クリア

    // 読了XPを付与（200 + ページ数）
    final pagesRead = _pageController.text.isNotEmpty
        ? (int.tryParse(_pageController.text) ?? 0) - _startPage
        : 0;
    final completionXp = calculateXp(
        type: 'complete_book', pages: pagesRead > 0 ? pagesRead : null);
    if (completionXp > 0) {
      try {
        ref.read(adventurerProvider.notifier).addXp(completionXp);
      } catch (e) {
        debugPrint('⚠️ [ReadingScreen] 読了XP付与失敗: $e');
      }
    }

    // デイリーミッション：読了達成チェック
    _updateDailyMissionBookComplete();

    final trophy = WarTrophy(
      id: 'trophy-${DateTime.now().millisecondsSinceEpoch}',
      userBookId: widget.id!,
      userId: 'local-user',
      learnings: _learningControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      action: _actionController.text.trim(),
      favoriteQuote: _quoteController.text.trim().isEmpty
          ? null
          : _quoteController.text.trim(),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    ref.read(warTrophyProvider.notifier).addTrophy(trophy);
    ref.read(bookDataProvider.notifier).updateUserBook(
          id: widget.id!,
          status: BookStatus.completed,
          completedAt: DateTime.now().toUtc().toIso8601String(),
        );
    if (mounted) context.go('/');
  }

  String get _formattedTime {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    try {
      _endSessionIfNeeded();
    } catch (_) {
      // dispose内でのクラッシュ防止
    }
    _pageController.dispose();
    _memoController.dispose();
    for (final c in _learningControllers) {
      c.dispose();
    }
    _actionController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;

    if (book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('読書中')),
        body: const DungeonBackground(
          screenType: ScreenType.reading,
          child: Center(child: Text('本が見つかりません')),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _stopReading();
        }
      },
      child: Scaffold(
        key: AppKeys.readingScreen,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _stopReading,
          ),
          title: Text(book.book?.title ?? '読書中'),
        ),
        body: DungeonBackground(
          screenType: ScreenType.reading,
        child: ListView(
          padding: const EdgeInsets.all(16),
        children: [
          // Cover + Title
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: book.book?.coverImageUrl != null
                      ? Image.network(
                          book.book!.coverImageUrl!,
                          width: 100,
                          height: 140,
                          fit: BoxFit.cover,
                          headers: const {
                            'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.accent.withAlpha(40),
                            child: const Icon(Icons.menu_book,
                                size: 48, color: AppTheme.textSecondary),
                          ),
                        )
                      : Container(
                          color: AppTheme.accent.withAlpha(40),
                          child: const Icon(Icons.menu_book,
                              size: 48, color: AppTheme.textSecondary),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  book.book?.title ?? '不明な本',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                ),
                if (book.book?.authors.isNotEmpty == true)
                  Text(book.book!.authors.join(', '),
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Timer
          Center(
            child: GestureDetector(
              onTap: _toggleTimer,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _isRunning ? AppTheme.progress : AppTheme.border,
                      width: 4),
                ),
                child: Center(
                  child: Text(
                    _formattedTime,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isRunning
                            ? AppTheme.progress
                            : AppTheme.textPrimary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: SemanticHelper.interactive(
              testId: 'btn_reading_timer_text',
              child: TextButton(
                onPressed: _toggleTimer,
                child: Text(_isRunning ? '⏸ 一時停止' : '▶ 開始',
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Page progress
          Row(
            children: [
              const Text('現在のページ',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: AppKeys.readingPageInput,
                  controller: _pageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '${book.currentPage}',
                    suffixText: '/ ${book.book?.pageCount ?? "?"}',
                  ),
                  onChanged: _updatePage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Memo
          TextField(
            key: AppKeys.readingMemo,
            controller: _memoController,
            decoration:
                const InputDecoration(hintText: 'メモ...', labelText: 'クイックメモ'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Complete button — テキストリンク風に抑制して誤操作防止
          Center(
            child: TextButton.icon(
              key: AppKeys.readingComplete,
              onPressed: _showCompleteConfirm,
              icon: const Text('🏁', style: TextStyle(fontSize: 14)),
              label: const Text(
                '冒険を完了する',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
      ),
      // Complete modal
      bottomSheet: _showCompleteModal ? _buildCompleteModal() : null,
    ),
    );
  }

  Widget _buildCompleteModal() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚔️ 戦利品カード',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('この本から得た学びを3つ、そして1つの行動を記録しよう',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ...List.generate(
              3,
              (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      key: [
                        AppKeys.trophyLearning1,
                        AppKeys.trophyLearning2,
                        AppKeys.trophyLearning3
                      ][i],
                      controller: _learningControllers[i],
                      decoration: InputDecoration(hintText: '学び ${i + 1}'),
                    ),
                  )),
          TextField(
            key: AppKeys.trophyAction,
            controller: _actionController,
            decoration: const InputDecoration(hintText: 'これから取る1つの行動'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: AppKeys.trophyQuote,
            controller: _quoteController,
            decoration: const InputDecoration(hintText: 'お気に入りの一文 (任意)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SemanticHelper.interactive(
              testId: 'btn_reading_submit_trophy',
              child: ElevatedButton(
                key: AppKeys.trophySubmit,
                onPressed: _submitTrophy,
                child: const Text('討伐完了！'),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
