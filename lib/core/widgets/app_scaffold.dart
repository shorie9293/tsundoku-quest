import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;
import 'dungeon_background.dart';
import '../../features/bookshelf/presentation/bookshelf_screen.dart';
import '../../features/explore/presentation/explore_screen.dart';
import '../../features/history/presentation/history_screen.dart';

/// ShellRoute用のScaffold — BottomNavigationBar付き＋PageViewスワイプ切替
///
/// go_routerのShellRouteから呼ばれる。
/// PageViewで3タブ間をスワイプ遷移可能。
/// BottomNavタップでもPageViewをアニメーション。
class AppScaffold extends StatefulWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  late final PageController _pageController;

  /// タブ定義（読書中タブ削除 → 3タブ化）
  static final _tabs = <_TabItem>[
    const _TabItem(
      route: '/',
      icon: Icons.auto_stories,
      tabKey: AppKeys.tabBookshelf,
      semanticId: 'nav_bookshelf',
      label: '書庫',
    ),
    const _TabItem(
      route: '/explore',
      icon: Icons.explore,
      tabKey: AppKeys.tabExplore,
      semanticId: 'nav_explore',
      label: '探索',
    ),
    const _TabItem(
      route: '/history',
      icon: Icons.bar_chart,
      tabKey: AppKeys.tabHistory,
      semanticId: 'nav_history',
      label: '足跡',
    ),
  ];

  static const _screens = <Widget>[
    BookshelfScreen(),
    ExploreScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // PageController with initialPage=0 (default '/' route)
    // Deep-link sync handled via addPostFrameCallback after first build
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        final targetIndex = _currentIndex(context);
        if (targetIndex != 0) {
          _pageController.jumpToPage(targetIndex);
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static int _currentIndexForLocation(String location) {
    final index = _tabs.indexWhere((t) => t.route == location);
    return index >= 0 ? index : 0;
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return _currentIndexForLocation(location);
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    context.go(_tabs[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    // Sync PageController with GoRouter on every rebuild.
    // When context.go() is called from within a page (not BottomNav tap),
    // GoRouter triggers a ShellRoute rebuild, but _pageController isn't updated.
    // This postFrameCallback ensures PageView jumps to the correct page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        final pageIndex = _pageController.page?.round() ?? 0;
        if (pageIndex != currentIndex) {
          _pageController.jumpToPage(currentIndex);
        }
      }
    });

    return Scaffold(
      body: DungeonBackground(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => context.go(_tabs[index].route),
          children: _screens,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        key: AppKeys.mainTabBar,
        currentIndex: currentIndex,
        onTap: _onTabTapped,
        items: _tabs.map((tab) {
          return BottomNavigationBarItem(
            icon: SemanticHelper.navigation(
              testId: tab.semanticId,
              child: Icon(tab.icon, key: tab.tabKey),
            ),
            label: tab.label,
          );
        }).toList(),
      ),
    );
  }
}

/// タブ項目の定義
class _TabItem {
  final String route;
  final IconData icon;
  final Key tabKey;
  final String semanticId;
  final String label;

  const _TabItem({
    required this.route,
    required this.icon,
    required this.tabKey,
    required this.semanticId,
    required this.label,
  });
}
