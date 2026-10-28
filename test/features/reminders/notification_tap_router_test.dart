import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tsundoku_quest/features/reminders/domain/notification_route_resolver.dart';
import 'package:tsundoku_quest/features/reminders/presentation/notification_tap_router.dart';

/// 遷移先の代役。現在地 URI を表示するだけのプローブ。
class _Probe extends StatelessWidget {
  const _Probe({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          '${GoRouterState.of(context).uri}',
          key: Key('probe_$name'),
        ),
      ),
    );
  }
}

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const _Probe(name: 'library')),
        GoRoute(
          path: '/reading',
          builder: (_, __) => const _Probe(name: 'reading'),
        ),
        GoRoute(
          path: '/explore',
          builder: (_, __) => const _Probe(name: 'explore'),
        ),
        GoRoute(
          path: '/history',
          builder: (_, __) => const _Probe(name: 'history'),
        ),
        GoRoute(
          path: '/reading-queue',
          builder: (_, __) => const _Probe(name: 'queue'),
        ),
      ],
    );

/// 通知タップ相当のコールバックを router に繋いだ状態で pump する。
Future<(GoRouter, NotificationTapRouter)> _pumpTapRouter(
  WidgetTester tester,
) async {
  final router = _buildRouter();
  final tapRouter = NotificationTapRouter(router: router);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  return (router, tapRouter);
}

void main() {
  testWidgets('library 通知のタップで書庫（/）へ遷移する', (tester) async {
    final (_, tapRouter) = await _pumpTapRouter(tester);

    // 一度別画面へ移ってから、通知タップ相当のコールバックを撃つ。
    tapRouter.onNotificationTap(
      ResolvedNotificationRoute(route: NotificationRoutes.reading),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('probe_reading')), findsOneWidget);

    tapRouter.onNotificationTap(
      ResolvedNotificationRoute(route: NotificationRoutes.library),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('probe_library')), findsOneWidget);
    expect(find.byKey(const Key('probe_reading')), findsNothing);
  });

  testWidgets('reading 通知のタップで id 付きの /reading へ遷移する', (tester) async {
    final (router, tapRouter) = await _pumpTapRouter(tester);

    tapRouter.onNotificationTap(
      ResolvedNotificationRoute(
        route: NotificationRoutes.reading,
        id: 'ub-1',
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/reading');
    expect(router.state.uri.queryParameters['id'], 'ub-1');
    expect(
      tester.widget<Text>(find.byKey(const Key('probe_reading'))).data,
      '/reading?id=ub-1',
    );
  });

  testWidgets('payload 文字列から解決して遷移する（resolver との結合点）', (tester) async {
    final (router, tapRouter) = await _pumpTapRouter(tester);

    // 通知発火側が載せる payload と同じ経路で解決する。
    tapRouter.handlePayload(
      NotificationRouteResolver.buildPayload(
        NotificationRoutes.queue,
      ),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/reading-queue');
    expect(find.byKey(const Key('probe_queue')), findsOneWidget);
  });

  testWidgets('未知 route では遷移しない（現在地のまま）', (tester) async {
    final (router, tapRouter) = await _pumpTapRouter(tester);

    final navigated = tapRouter.handle(
      ResolvedNotificationRoute(route: 'unknown_screen'),
    );
    await tester.pumpAndSettle();

    expect(navigated, isFalse);
    expect(router.state.uri.path, '/');
    expect(find.byKey(const Key('probe_library')), findsOneWidget);
    expect(find.byKey(const Key('probe_queue')), findsNothing);
  });

  testWidgets('解決不能な payload（壊れた JSON）では遷移しない', (tester) async {
    final (router, tapRouter) = await _pumpTapRouter(tester);

    tapRouter.handlePayload('{"route":');
    tapRouter.handlePayload(null);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
    expect(find.byKey(const Key('probe_library')), findsOneWidget);
  });

  test('allowedRoutes は対応表のキーと一致する（resolver と router の食い違い防止）', () {
    expect(
      NotificationTapRouter.defaultAllowedRoutes,
      NotificationRoutes.paths.keys.toSet(),
    );
    expect(NotificationRoutes.all, NotificationTapRouter.defaultAllowedRoutes);
    expect(
      NotificationTapRouter(router: _buildRouter()).allowedRoutes,
      NotificationTapRouter.defaultAllowedRoutes,
    );
  });
}
