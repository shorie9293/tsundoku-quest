import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/widgets/dungeon_background.dart';
import '../../../../shared/providers/book_data_provider.dart';
import '../../../../shared/providers/adventurer_provider.dart';
import '../../../../domain/models/user_book.dart';
import '../../../../domain/models/war_trophy.dart';
import '../data/reading_session_repository_provider.dart';

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
  }

  Future<void> _endSessionIfNeeded() async {
    if (_sessionId == null) return;
    final durationMinutes = _elapsedSeconds ~/ 60;
    if (durationMinutes <= 0) return;

    final endPage = _pageController.text.isNotEmpty
        ? int.tryParse(_pageController.text) ?? _book?.currentPage ?? 0
        : _book?.currentPage ?? 0;

    try {
      final repo = ref.read(readingSessionRepositoryProvider);
      await repo.endSession(_sessionId!, endPage, durationMinutes);
    } catch (e) {
      // Supabase未初期化 → セッション記録スキップ、Statsは更新する
    }

    final adventurer = ref.read(adventurerProvider.notifier);
    adventurer.updateReadingStats(minutes: durationMinutes, pages: endPage - _startPage);

    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    adventurer.addReadingDate(today);

    // UserBookのtotalReadingMinutesも永続化
    if (widget.id != null) {
      final book = ref.read(bookDataProvider.notifier).getUserBook(widget.id!);
      if (book != null) {
        ref.read(bookDataProvider.notifier).updateUserBook(
              id: widget.id!,
              totalReadingMinutes: book.totalReadingMinutes + durationMinutes,
            );
      }
    }

    _sessionId = null;
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
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _elapsedSeconds++);
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _updatePage(String value) {
    final page = int.tryParse(value) ?? 0;
    if (widget.id != null && _book != null) {
      ref.read(bookDataProvider.notifier).updateUserBook(
            id: widget.id!,
            currentPage: page,
            totalReadingMinutes:
                _book!.totalReadingMinutes + (_elapsedSeconds ~/ 60),
          );
    }
  }

  void _showComplete() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _showCompleteModal = true;
    });
  }

  void _stopReading() {
    _timer?.cancel();
    setState(() => _isRunning = false);
    _endSessionIfNeeded();
    if (mounted) context.pop();
  }

  Future<void> _submitTrophy() async {
    if (widget.id == null) return;
    await _endSessionIfNeeded();
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
    ref.read(bookDataProvider.notifier).addTrophy(trophy);
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
    _endSessionIfNeeded();
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
                    color: AppTheme.accent.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book,
                      size: 48, color: AppTheme.textSecondary),
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
            child: TextButton(
              onPressed: _toggleTimer,
              child: Text(_isRunning ? '⏸ 一時停止' : '▶ 開始',
                  style: const TextStyle(fontSize: 16)),
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

          // Complete button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: AppKeys.readingComplete,
              onPressed: _showComplete,
              icon: const Text('🏆'),
              label: const Text('冒険完了（読了）'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.completedColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
            child: ElevatedButton(
              key: AppKeys.trophySubmit,
              onPressed: _submitTrophy,
              child: const Text('討伐完了！'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
