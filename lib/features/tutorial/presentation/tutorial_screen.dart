import 'package:flutter/material.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/core/theme/app_theme.dart';
import 'package:tsundoku_quest/features/tutorial/data/tutorial_preferences.dart';
import 'package:tsundoku_quest/features/tutorial/presentation/tutorial_content.dart';
import 'package:tsundoku_quest/features/tutorial/presentation/widgets/tutorial_page.dart';

/// 初回起動時チュートリアル画面
///
/// 世界観説明（4ページ）→ 操作説明（1ページ、スキップ可）の順に表示。
class TutorialScreen extends StatefulWidget {
  final TutorialPreferences prefs;

  const TutorialScreen({super.key, required this.prefs});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  /// 全ページ数（世界観4 + 操作1）
  int get _totalPages => TutorialContent.lorePageCount + 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == _totalPages - 1;

  bool get _isOperationPage => _currentPage == TutorialContent.lorePageCount;

  Future<void> _onFinish() async {
    await widget.prefs.markLoreSeen();
    await widget.prefs.markOperationSeen();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _onSkip() async {
    // 操作ページのみスキップ可能
    if (_isOperationPage) {
      await _onFinish();
    } else {
      // 世界観ページからスキップ→最終ページへ
      _pageController.animateToPage(
        _totalPages - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.tutorialScreen,
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ━━━ 上部: スキップ/インジケーター ━━━
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  if (_isOperationPage)
                    TextButton(
                      key: AppKeys.tutorialSkipButton,
                      onPressed: _onFinish,
                      child: const Text(
                        'スキップ',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  _PageIndicator(
                    key: AppKeys.tutorialPageIndicator,
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                  ),
                ],
              ),
            ),

            // ━━━ 中央: PageView ━━━
            Expanded(
              child: PageView(
                key: AppKeys.tutorialPageView,
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  // 世界観ページ（lorePages）
                  ...TutorialContent.lorePages.map(
                    (page) => TutorialPage(pageData: page),
                  ),
                  // 操作説明ページ
                  const TutorialPage(pageData: TutorialContent.operationPage),
                ],
              ),
            ),

            // ━━━ 下部: 「探索を始める」ボタン ━━━
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: AppKeys.tutorialStartButton,
                  onPressed: _isLastPage ? _onFinish : _onSkip,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isLastPage ? '探索を始める' : '次へ',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ページインジケーター（ドット）
class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const _PageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalPages, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accent : AppTheme.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
